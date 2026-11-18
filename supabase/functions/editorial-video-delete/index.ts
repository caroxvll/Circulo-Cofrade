import { createClient } from "npm:@supabase/supabase-js@2";
import { AwsClient } from "npm:aws4fetch@1.0.20";

/**
 * Borra el medio remoto (Stream o R2) de una publicación editorial.
 * Llamar ANTES de delete_forum_topic para liberar almacenamiento.
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
    const r2AccountId = Deno.env.get("R2_ACCOUNT_ID");
    const r2AccessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
    const r2SecretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");
    const r2Bucket = Deno.env.get("R2_BUCKET") ?? "cofradeo-editorial";

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return jsonResponse({ error: "Faltan variables Supabase" }, 500);
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
        "id, is_editorial, video_provider, video_external_id, video_url",
      )
      .eq("id", topicId)
      .maybeSingle();

    if (topicError || !topic) {
      return jsonResponse({ ok: true, skipped: true, reason: "not_found" });
    }
    if (topic.is_editorial !== true) {
      return jsonResponse({ ok: true, skipped: true, reason: "not_editorial" });
    }

    const provider = topic.video_provider as string | null;
    const externalId = (topic.video_external_id as string | null)?.trim();

    if (!provider || !externalId) {
      return jsonResponse({ ok: true, skipped: true, reason: "no_media" });
    }

    if (provider === "stream") {
      if (!cfAccountId || !cfStreamToken) {
        return jsonResponse({ error: "Stream no configurado" }, 500);
      }
      const delRes = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${cfAccountId}/stream/${externalId}`,
        {
          method: "DELETE",
          headers: { Authorization: `Bearer ${cfStreamToken}` },
        },
      );
      // 404 = ya no estaba; OK para liberar el tema.
      if (!delRes.ok && delRes.status !== 404) {
        const errBody = await delRes.text();
        console.error("stream delete", delRes.status, errBody);
        return jsonResponse({ error: "No se pudo borrar en Stream" }, 502);
      }
      return jsonResponse({
        ok: true,
        provider: "stream",
        externalId,
        deleted: delRes.status !== 404,
      });
    }

    if (provider === "r2") {
      if (!r2AccountId || !r2AccessKeyId || !r2SecretAccessKey) {
        return jsonResponse({ error: "R2 no configurado" }, 500);
      }
      const endpoint = `https://${r2AccountId}.r2.cloudflarestorage.com`;
      const objectUrl = `${endpoint}/${r2Bucket}/${externalId}`;
      const r2 = new AwsClient({
        accessKeyId: r2AccessKeyId,
        secretAccessKey: r2SecretAccessKey,
        service: "s3",
        region: "auto",
      });
      const signed = await r2.sign(
        new Request(objectUrl, { method: "DELETE" }),
        { aws: { signQuery: true } },
      );
      const delRes = await fetch(signed.url, { method: "DELETE" });
      if (!delRes.ok && delRes.status !== 404) {
        console.error("r2 delete", delRes.status, await delRes.text());
        return jsonResponse({ error: "No se pudo borrar en R2" }, 502);
      }
      return jsonResponse({
        ok: true,
        provider: "r2",
        externalId,
        deleted: delRes.status !== 404,
      });
    }

    return jsonResponse({ ok: true, skipped: true, reason: "unknown_provider" });
  } catch (error) {
    console.error("editorial-video-delete", error);
    return jsonResponse({ error: "No se pudo borrar el vídeo" }, 500);
  }
});
