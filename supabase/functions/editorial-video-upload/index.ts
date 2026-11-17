import { createClient } from "npm:@supabase/supabase-js@2";
import { AwsClient } from "npm:aws4fetch@1.0.20";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MAX_BYTES = 80 * 1024 * 1024;
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
    const r2AccountId = Deno.env.get("R2_ACCOUNT_ID");
    const r2AccessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
    const r2SecretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");
    const r2Bucket = Deno.env.get("R2_BUCKET") ?? "cofradeo-editorial";
    const r2PublicBase = Deno.env.get("R2_PUBLIC_BASE_URL");

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return jsonResponse({ error: "Faltan variables de entorno Supabase" }, 500);
    }
    if (!r2AccountId || !r2AccessKeyId || !r2SecretAccessKey || !r2PublicBase) {
      return jsonResponse(
        {
          error:
            "Faltan variables R2 (R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_PUBLIC_BASE_URL)",
        },
        500,
      );
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

    if (!topicId) {
      return jsonResponse({ error: "topicId obligatorio" }, 400);
    }
    if (!ALLOWED_TYPES.has(contentType)) {
      return jsonResponse({ error: "Tipo de vídeo no permitido" }, 400);
    }
    if (!Number.isFinite(byteLength) || byteLength <= 0) {
      return jsonResponse({ error: "byteLength inválido" }, 400);
    }
    if (byteLength > MAX_BYTES) {
      return jsonResponse({ error: "El vídeo supera 80 MB" }, 400);
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

    const isOwner =
      topic.via_author_id === user.id || topic.author_id === user.id;
    if (!isOwner) {
      // Junta member already verified; allow attach on behalf of review flow.
    }

    const ext = extensionFor(contentType);
    const objectKey = `editorial/${topicId}/${crypto.randomUUID()}.${ext}`;
    const endpoint = `https://${r2AccountId}.r2.cloudflarestorage.com`;
    const putUrl = `${endpoint}/${r2Bucket}/${objectKey}`;

    const r2 = new AwsClient({
      accessKeyId: r2AccessKeyId,
      secretAccessKey: r2SecretAccessKey,
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
      .update({ video_status: "uploading", edited_at: new Date().toISOString() })
      .eq("id", topicId);

    const publicBase = r2PublicBase.replace(/\/$/, "");
    return jsonResponse({
      uploadUrl: signed.url,
      publicUrl: `${publicBase}/${objectKey}`,
      objectKey,
      maxBytes: MAX_BYTES,
    });
  } catch (error) {
    console.error("editorial-video-upload", error);
    return jsonResponse({ error: "No se pudo preparar la subida" }, 500);
  }
});
