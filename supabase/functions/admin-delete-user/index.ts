import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type Body = {
  profileId?: string;
  /** Si true, borra temas y comentarios del usuario antes de Auth. */
  deleteContent?: boolean;
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
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return jsonResponse({ error: "Faltan variables de entorno Supabase" }, 500);
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

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: callerProfile, error: callerError } = await admin
      .from("profiles")
      .select("id, role, suspended_at")
      .eq("id", user.id)
      .maybeSingle();

    if (
      callerError ||
      !callerProfile ||
      callerProfile.role !== "admin" ||
      callerProfile.suspended_at != null
    ) {
      return jsonResponse({ error: "Solo un admin puede eliminar usuarios" }, 403);
    }

    const body = (await req.json()) as Body;
    const profileId = (body.profileId ?? "").trim();
    const deleteContent = body.deleteContent !== false;

    if (!profileId) {
      return jsonResponse({ error: "Falta profileId" }, 400);
    }
    if (profileId === user.id) {
      return jsonResponse({ error: "No puedes eliminarte a ti mismo" }, 400);
    }

    const { data: target, error: targetError } = await admin
      .from("profiles")
      .select("id, handle, display_name, role, account_type")
      .eq("id", profileId)
      .maybeSingle();

    if (targetError || !target) {
      return jsonResponse({ error: "Usuario no encontrado" }, 404);
    }

    let deletedTopics = 0;
    let deletedReplies = 0;

    if (deleteContent) {
      // Respuestas del usuario (en cualquier hilo).
      const { data: replyRows, error: replySelError } = await admin
        .from("forum_replies")
        .select("id")
        .eq("author_id", profileId);
      if (replySelError) {
        return jsonResponse({ error: replySelError.message }, 500);
      }
      deletedReplies = replyRows?.length ?? 0;
      if (deletedReplies > 0) {
        const { error: replyDelError } = await admin
          .from("forum_replies")
          .delete()
          .eq("author_id", profileId);
        if (replyDelError) {
          return jsonResponse({ error: replyDelError.message }, 500);
        }
      }

      // Temas del usuario: no tocar tablones de hermandad ni temas de sistema.
      const { data: topicRows, error: topicSelError } = await admin
        .from("forum_topics")
        .select("id")
        .eq("author_id", profileId)
        .eq("is_system", false)
        .neq("forum_id", "hermandades");
      if (topicSelError) {
        return jsonResponse({ error: topicSelError.message }, 500);
      }
      deletedTopics = topicRows?.length ?? 0;
      if (deletedTopics > 0) {
        const { error: topicDelError } = await admin
          .from("forum_topics")
          .delete()
          .eq("author_id", profileId)
          .eq("is_system", false)
          .neq("forum_id", "hermandades");
        if (topicDelError) {
          return jsonResponse({ error: topicDelError.message }, 500);
        }
      }
    }

    // Auth → cascada a profiles (y asignaciones hermandad, follows, etc.).
    const { error: authDelError } = await admin.auth.admin.deleteUser(profileId);
    if (authDelError) {
      return jsonResponse(
        {
          error: `Contenido limpiado, pero falló Auth: ${authDelError.message}`,
          deletedTopics,
          deletedReplies,
        },
        500,
      );
    }

    return jsonResponse({
      ok: true,
      profileId,
      handle: target.handle,
      displayName: target.display_name,
      deletedTopics,
      deletedReplies,
      deleteContent,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Error inesperado";
    return jsonResponse({ error: message }, 500);
  }
});
