import { createClient } from "npm:@supabase/supabase-js@2";

/**
 * Comprueba si un vídeo Stream ya está listo y actualiza forum_topics.
 * Lo llama la app tras subir, o un cron / webhook.
 */
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
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
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const cfAccountId =
      Deno.env.get("CF_STREAM_ACCOUNT_ID") ?? Deno.env.get("R2_ACCOUNT_ID");
    const cfStreamToken = Deno.env.get("CF_STREAM_API_TOKEN");

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return jsonResponse({ error: "Faltan variables Supabase" }, 500);
    }
    if (!cfAccountId || !cfStreamToken) {
      return jsonResponse({ error: "Stream no configurado" }, 500);
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

    const body = await req.json();
    const topicId = String(body.topicId ?? "").trim();
    if (!topicId) {
      return jsonResponse({ error: "topicId obligatorio" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: juntaOk } = await admin.rpc("is_junta_member", {
      p_user_id: user.id,
    });
    if (juntaOk !== true) {
      return jsonResponse({ error: "forbidden" }, 403);
    }

    const { data: topic, error: topicError } = await admin
      .from("forum_topics")
      .select(
        "id, is_editorial, video_provider, video_external_id, video_status",
      )
      .eq("id", topicId)
      .maybeSingle();

    if (topicError || !topic || topic.is_editorial !== true) {
      return jsonResponse({ error: "not found" }, 404);
    }

    if (topic.video_provider !== "stream" || !topic.video_external_id) {
      return jsonResponse({
        status: topic.video_status ?? "unknown",
        ready: topic.video_status === "ready",
      });
    }

    const uid = topic.video_external_id as string;
    const cfRes = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${cfAccountId}/stream/${uid}`,
      {
        headers: { Authorization: `Bearer ${cfStreamToken}` },
      },
    );
    const cfJson = await cfRes.json();
    if (!cfRes.ok || !cfJson?.success) {
      console.error("stream get", cfJson);
      return jsonResponse({ error: "No se pudo consultar Stream" }, 502);
    }

    const result = cfJson.result;
    const state = result?.status?.state as string | undefined;
    const ready = result?.readyToStream === true || state === "ready";
    const errored = state === "error";

    if (errored) {
      await admin
        .from("forum_topics")
        .update({
          video_status: "failed",
          edited_at: new Date().toISOString(),
        })
        .eq("id", topicId);
      return jsonResponse({ status: "failed", ready: false });
    }

    if (!ready) {
      await admin
        .from("forum_topics")
        .update({
          video_status: "processing",
          edited_at: new Date().toISOString(),
        })
        .eq("id", topicId);
      return jsonResponse({
        status: "processing",
        ready: false,
        percent: result?.status?.pctComplete ?? null,
      });
    }

    const playbackHls =
      (result?.playback?.hls as string | undefined) ??
      streamPlaybackUrls(uid).hlsUrl;
    const poster =
      (result?.thumbnail as string | undefined) ??
      streamPlaybackUrls(uid).posterUrl;

    await admin.rpc("finalize_editorial_video", {
      p_topic_id: topicId,
      p_video_url: playbackHls,
      p_video_poster_url: poster,
      p_video_external_id: uid,
      p_video_provider: "stream",
    });

    return jsonResponse({
      status: "ready",
      ready: true,
      videoUrl: playbackHls,
      posterUrl: poster,
    });
  } catch (error) {
    console.error("editorial-video-finalize", error);
    return jsonResponse({ error: "No se pudo finalizar" }, 500);
  }
});
