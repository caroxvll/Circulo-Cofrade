import { createClient } from "npm:@supabase/supabase-js@2";

/**
 * Webhook de Cloudflare Stream (video.ready / notifications).
 * Configura en Stream → Webhooks la URL de esta function + secreto opcional.
 *
 * Esperamos meta.topicId (lo enviamos en direct_upload).
 */
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, webhook-signature",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
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
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const webhookSecret = Deno.env.get("CF_STREAM_WEBHOOK_SECRET");

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ error: "Faltan variables" }, 500);
    }

    if (webhookSecret) {
      const header =
        req.headers.get("Webhook-Signature") ??
        req.headers.get("cf-webhook-auth") ??
        "";
      // Stream puede enviar el secreto como header personalizado que configures.
      if (header && header !== webhookSecret) {
        return jsonResponse({ error: "unauthorized" }, 401);
      }
    }

    const payload = await req.json();
    // Formatos posibles: notificación directa o envuelta.
    const uid = String(payload.uid ?? payload.video?.uid ?? "").trim();
    const topicId = String(
      payload.meta?.topicId ??
        payload.video?.meta?.topicId ??
        payload.data?.meta?.topicId ??
        "",
    ).trim();
    const readyToStream =
      payload.readyToStream === true ||
      payload.status?.state === "ready" ||
      payload.video?.readyToStream === true;

    if (!uid || !topicId) {
      // ACK para no reintentar basura; logueamos.
      console.warn("webhook sin uid/topicId", payload);
      return jsonResponse({ ok: true, skipped: true });
    }

    if (!readyToStream) {
      return jsonResponse({ ok: true, status: "ignored" });
    }

    const playbackHls =
      (payload.playback?.hls as string | undefined) ??
      (payload.video?.playback?.hls as string | undefined) ??
      streamPlaybackUrls(uid).hlsUrl;
    const poster =
      (payload.thumbnail as string | undefined) ??
      (payload.video?.thumbnail as string | undefined) ??
      streamPlaybackUrls(uid).posterUrl;

    const admin = createClient(supabaseUrl, serviceRoleKey);
    await admin.rpc("finalize_editorial_video", {
      p_topic_id: topicId,
      p_video_url: playbackHls,
      p_video_poster_url: poster,
      p_video_external_id: uid,
      p_video_provider: "stream",
    });

    return jsonResponse({ ok: true, topicId, uid });
  } catch (error) {
    console.error("editorial-video-webhook", error);
    return jsonResponse({ error: "webhook failed" }, 500);
  }
});
