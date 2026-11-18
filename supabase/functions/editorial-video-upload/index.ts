import { createClient } from "npm:@supabase/supabase-js@2";
import { AwsClient } from "npm:aws4fetch@1.0.20";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/** R2 (MP4 directo). */
const MAX_BYTES_R2 = 150 * 1024 * 1024;
/** Stream admite piezas más largas; el límite duro lo pone maxDurationSeconds. */
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

    // ——— Cloudflare Stream (HLS + poster) ———
    if (useStream) {
      const createRes = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${cfAccountId}/stream/direct_upload`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${cfStreamToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            maxDurationSeconds: MAX_DURATION_SECONDS,
            requireSignedURLs: false,
            thumbnailTimestampPct: 0.05,
            meta: {
              topicId,
              source: "cofradeo-editorial",
            },
          }),
        },
      );
      const createJson = await createRes.json();
      if (!createRes.ok || !createJson?.success) {
        console.error("stream direct_upload", createJson);
        return jsonResponse(
          { error: "No se pudo preparar la subida a Stream" },
          502,
        );
      }

      const uploadURL = createJson.result?.uploadURL as string | undefined;
      const uid = createJson.result?.uid as string | undefined;
      if (!uploadURL || !uid) {
        return jsonResponse({ error: "Respuesta Stream incompleta" }, 502);
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
        uploadMethod: "POST",
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
