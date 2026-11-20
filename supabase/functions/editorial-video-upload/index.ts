import { createClient } from "npm:@supabase/supabase-js@2";
import { AwsClient } from "npm:aws4fetch@1.0.20";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/** R2 (MP4 directo). */
const MAX_BYTES_R2 = 150 * 1024 * 1024;
/**
 * Tope de la app. Stream recibe el archivo por tus: el POST simple corta en
 * 200 MB y no se puede subir en el panel. La duración reservada va en
 * maxDurationSeconds (Cloudflare admite hasta 36000 s).
 */
const MAX_BYTES_STREAM = 500 * 1024 * 1024;
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

function streamPrepareError(status: number, body: string): string {
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
  if (status === 401 || status === 403 || lower.includes("authentication")) {
    return "El token de Stream no vale o el id de cuenta no coincide.";
  }
  if (
    lower.includes("storage") ||
    lower.includes("quota") ||
    lower.includes("duration")
  ) {
    return "Stream no tiene minutos libres para reservar este vídeo.";
  }
  if (raw) return `Stream ha rechazado la subida: ${raw}`;
  return "No se pudo preparar la subida a Stream";
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
      Deno.env.get("CF_STREAM_ACCOUNT_ID") ?? Deno.env.get("R2_ACCOUNT_ID");
    const cfStreamToken = Deno.env.get("CF_STREAM_API_TOKEN");
    const useStream = Boolean(cfAccountId && cfStreamToken);

    const r2AccountId = Deno.env.get("R2_ACCOUNT_ID");
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
            ? "El vídeo supera 500 MB"
            : "El vídeo supera 150 MB",
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

      const createRes = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${cfAccountId}/stream?direct_user=true`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${cfStreamToken}`,
            "Tus-Resumable": "1.0.0",
            "Upload-Length": String(byteLength),
            "Upload-Metadata": metadata,
          },
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
      if (!createRes.ok || !uploadURL || !uid) {
        const detail = await createRes.text();
        console.error("stream tus", createRes.status, detail);
        return jsonResponse(
          { error: streamPrepareError(createRes.status, detail) },
          502,
        );
      }

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
