import { createClient } from "npm:@supabase/supabase-js@2";
import { AwsClient } from "npm:aws4fetch@1.0.20";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/** R2 (MP4 directo). 1 GB: un clip de iPhone 4K de ~30–40 s. */
const MAX_BYTES_R2 = 1024 * 1024 * 1024;
/**
 * Tope de la app. Stream recibe el archivo por tus: el POST simple corta en
 * 200 MB y no se puede subir en el panel. 2 GB cubre un par de minutos en
 * 4K de iPhone. La duración reservada va en maxDurationSeconds
 * (Cloudflare admite hasta 36000 s).
 */
const MAX_BYTES_STREAM = 2 * 1024 * 1024 * 1024;
const MAX_DURATION_SECONDS = 10 * 60;

const ALLOWED_TYPES = new Set([
  "video/mp4",
  "video/quicktime",
  "video/webm",
]);

type Body = {
  topicId?: string;
  contentType?: string;
  byteLength?: number;
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function envTrim(name: string): string {
  return (Deno.env.get(name) ?? "").trim().replace(/^["']|["']$/g, "");
}

function extensionFor(contentType: string): string {
  switch (contentType) {
    case "video/webm":
      return "webm";
    case "video/quicktime":
      return "mov";
    default:
      return "mp4";
  }
}

function uidFromStreamLocation(url: string): string | null {
  try {
    const parts = new URL(url).pathname.split("/").filter(Boolean);
    const last = parts[parts.length - 1] ?? "";
    return /^[a-z0-9]{16,}$/i.test(last) ? last : null;
  } catch {
    return null;
  }
}

function streamPrepareError(
  status: number,
  body: string,
  canList = false,
): string {
  let raw = "";
  try {
    const parsed = JSON.parse(body) as {
      errors?: Array<{ message?: string }>;
    };
    raw = parsed.errors?.[0]?.message?.trim() ?? "";
  } catch {
    raw = body.replace(/\s+/g, " ").trim().slice(0, 160);
  }
  const lower = raw.toLowerCase();
  if (
    status === 401 ||
    status === 403 ||
    lower.includes("authoriz") ||
    lower.includes("authenticat")
  ) {
    if (canList) {
      return "Esta cuenta sí ve Stream, pero la subida grande pide un token de cuenta. En Cloudflare, la cuenta (no Mi perfil) → Manage Account → Account API Tokens → Stream Edit.";
    }
    return "El Account ID no es el de Stream. Ábrelo en Cloudflare (menú Stream) y copia los 32 caracteres de la URL dash.cloudflare.com/ESTO/stream.";
  }
  if (raw) return `Stream ha rechazado la subida: ${raw}`;
  if (
    lower.includes("storage") ||
    lower.includes("quota") ||
    lower.includes("duration")
  ) {
    return "Stream no tiene minutos libres para reservar este vídeo.";
  }
  return "No se pudo preparar la subida a Stream";
}

function isStreamAuthFailure(status: number, body: string): boolean {
  if (status === 401 || status === 403) return true;
  const lower = body.toLowerCase();
  return lower.includes("authoriz") || lower.includes("authenticat");
}

async function canListStream(
  accountId: string,
  token: string,
): Promise<{ ok: boolean; status: number; detail: string }> {
  try {
    const res = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream?per_page=1`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    if (res.ok) return { ok: true, status: res.status, detail: "" };
    return { ok: false, status: res.status, detail: await res.text() };
  } catch (error) {
    return { ok: false, status: 0, detail: String(error) };
  }
}

async function createStreamTusUpload(opts: {
  accountId: string;
  token: string;
  byteLength: number;
  metadata: string;
}): Promise<
  | { ok: true; uploadURL: string; uid: string }
  | { ok: false; status: number; detail: string }
> {
  const schemes = [`Bearer ${opts.token}`, `bearer ${opts.token}`];
  const metadatas = [opts.metadata, ""];
  let last: { status: number; detail: string } = { status: 502, detail: "" };
  for (const authorization of schemes) {
    for (const metadata of metadatas) {
      const headers: Record<string, string> = {
        Authorization: authorization,
        "Tus-Resumable": "1.0.0",
        "Upload-Length": String(opts.byteLength),
      };
      if (metadata) headers["Upload-Metadata"] = metadata;
      const createRes = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${opts.accountId}/stream?direct_user=true`,
        {
          method: "POST",
          redirect: "manual",
          headers,
        },
      );
      const location = createRes.headers.get("Location");
      const uploadURL = location == null
        ? null
        : location.startsWith("http")
        ? location
        : new URL(location, "https://api.cloudflare.com").toString();
      const uid =
        createRes.headers.get("stream-media-id") ??
        (uploadURL ? uidFromStreamLocation(uploadURL) : null);
      if (createRes.status < 400 && uploadURL && uid) {
        return { ok: true, uploadURL, uid };
      }
      last = { status: createRes.status, detail: await createRes.text() };
      if (!isStreamAuthFailure(last.status, last.detail)) {
        return { ok: false, ...last };
      }
    }
  }
  return { ok: false, ...last };
}

function streamPlaybackUrls(uid: string) {
  const base = `https://videodelivery.net/${uid}`;
  return {
    hlsUrl: `${base}/manifest/video.m3u8`,
    posterUrl: `${base}/thumbnails/thumbnail.jpg?time=1s&height=720`,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Método no permitido" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    // Stream (Fase 2b) — opcional; si falta, R2 (2a).
    const cfAccountId =
      envTrim("CF_STREAM_ACCOUNT_ID") || envTrim("R2_ACCOUNT_ID");
    const cfStreamToken = envTrim("CF_STREAM_API_TOKEN");
    const useStream = Boolean(cfAccountId && cfStreamToken);

    const r2AccountId = envTrim("R2_ACCOUNT_ID");
    const r2AccessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
    const r2SecretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");
    const r2Bucket = Deno.env.get("R2_BUCKET") ?? "cofradeo-editorial";
    const r2PublicBase = Deno.env.get("R2_PUBLIC_BASE_URL");

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return jsonResponse({ error: "Faltan variables de entorno Supabase" }, 500);
    }
    if (!useStream) {
      if (!r2AccountId || !r2AccessKeyId || !r2SecretAccessKey || !r2PublicBase) {
        return jsonResponse(
          {
            error:
              "Configura CF_STREAM_API_TOKEN (HLS) o las variables R2 (MP4)",
          },
          500,
        );
      }
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "No autenticado" }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) {
      return jsonResponse({ error: "Sesión inválida" }, 401);
    }

    const body = (await req.json()) as Body;
    const topicId = body.topicId?.trim();
    const contentType = (body.contentType ?? "video/mp4").trim().toLowerCase();
    const byteLength = Number(body.byteLength ?? 0);
    const maxBytes = useStream ? MAX_BYTES_STREAM : MAX_BYTES_R2;

    if (!topicId) {
      return jsonResponse({ error: "topicId obligatorio" }, 400);
    }
    if (!ALLOWED_TYPES.has(contentType)) {
      return jsonResponse({ error: "Tipo de vídeo no permitido" }, 400);
    }
    if (!Number.isFinite(byteLength) || byteLength <= 0) {
      return jsonResponse({ error: "byteLength inválido" }, 400);
    }
    if (byteLength > maxBytes) {
      return jsonResponse(
        {
          error: useStream
            ? "El vídeo supera 2 GB"
            : "El vídeo supera 1 GB",
        },
        400,
      );
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: juntaOk, error: juntaError } = await admin.rpc(
      "is_junta_member",
      { p_user_id: user.id },
    );
    if (juntaError || juntaOk !== true) {
      return jsonResponse({ error: "Solo la Junta puede subir vídeo oficial" }, 403);
    }

    const { data: topic, error: topicError } = await admin
      .from("forum_topics")
      .select("id, is_editorial, author_id, via_author_id")
      .eq("id", topicId)
      .maybeSingle();

    if (topicError || !topic || topic.is_editorial !== true) {
      return jsonResponse({ error: "Publicación oficial no encontrada" }, 404);
    }

    // ——— Cloudflare Stream (HLS + poster), subida tus ———
    // El POST simple de Stream rechaza todo lo que pase de 200 MB. tus admite
    // el tope de la app y el móvil manda el archivo a trozos, sin el token.
    if (useStream) {
      // Solo claves que Stream admite. topicId iba fuera de la lista y
      // Cloudflare rechazaba toda la petición.
      const metadata = [
        `maxdurationseconds ${btoa(String(MAX_DURATION_SECONDS))}`,
        `thumbnailtimestamppct ${btoa("0.05")}`,
        `name ${btoa(`editorial-${topicId}`)}`,
      ].join(",");

      const accountCandidates = [
        ...new Set(
          [cfAccountId, r2AccountId].filter((id) => id.length > 0),
        ),
      ];
      let created: Awaited<ReturnType<typeof createStreamTusUpload>> | null =
        null;
      for (const accountId of accountCandidates) {
        created = await createStreamTusUpload({
          accountId,
          token: cfStreamToken,
          byteLength,
          metadata,
        });
        if (created.ok) break;
        console.error("stream tus", accountId.slice(-4), created.status, created.detail);
        if (!isStreamAuthFailure(created.status, created.detail)) break;
      }
      if (!created || !created.ok) {
        const listed = await canListStream(
          accountCandidates[0] ?? "",
          cfStreamToken,
        );
        return jsonResponse(
          {
            error: streamPrepareError(
              created?.status ?? listed.status,
              created?.detail || listed.detail,
              listed.ok,
            ),
          },
          502,
        );
      }
      const { uploadURL, uid } = created;

      const { hlsUrl, posterUrl } = streamPlaybackUrls(uid);

      await admin
        .from("forum_topics")
        .update({
          video_status: "uploading",
          video_provider: "stream",
          video_external_id: uid,
          video_poster_url: posterUrl,
          edited_at: new Date().toISOString(),
        })
        .eq("id", topicId);

      return jsonResponse({
        mode: "stream",
        uploadMethod: "TUS",
        uploadUrl: uploadURL,
        publicUrl: hlsUrl,
        posterUrl,
        objectKey: uid,
        externalId: uid,
        maxBytes,
        maxDurationSeconds: MAX_DURATION_SECONDS,
      });
    }

    // ——— Fallback R2 (MP4) ———
    const ext = extensionFor(contentType);
    const objectKey = `editorial/${topicId}/${crypto.randomUUID()}.${ext}`;
    const endpoint = `https://${r2AccountId}.r2.cloudflarestorage.com`;
    const putUrl = `${endpoint}/${r2Bucket}/${objectKey}`;

    const r2 = new AwsClient({
      accessKeyId: r2AccessKeyId!,
      secretAccessKey: r2SecretAccessKey!,
      service: "s3",
      region: "auto",
    });

    const signed = await r2.sign(
      new Request(putUrl, {
        method: "PUT",
        headers: {
          "Content-Type": contentType,
          "Content-Length": String(byteLength),
        },
      }),
      { aws: { signQuery: true } },
    );

    await admin
      .from("forum_topics")
      .update({
        video_status: "uploading",
        video_provider: "r2",
        video_external_id: objectKey,
        edited_at: new Date().toISOString(),
      })
      .eq("id", topicId);

    const publicBase = r2PublicBase!.replace(/\/$/, "");
    return jsonResponse({
      mode: "r2",
      uploadMethod: "PUT",
      uploadUrl: signed.url,
      publicUrl: `${publicBase}/${objectKey}`,
      objectKey,
      externalId: objectKey,
      maxBytes,
    });
  } catch (error) {
    console.error("editorial-video-upload", error);
    return jsonResponse({ error: "No se pudo preparar la subida" }, 500);
  }
});
