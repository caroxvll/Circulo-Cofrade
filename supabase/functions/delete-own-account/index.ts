import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const USER_FOLDER_BUCKETS = [
  "avatars",
  "event-icons",
  "event-covers",
  "ss-live-images",
  "historia-covers",
];

const TOPIC_FOLDER_BUCKETS = ["topic-covers", "forum-post-images"];

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function idsFrom(
  admin: SupabaseClient,
  table: string,
  column: string,
  profileId: string,
): Promise<string[]> {
  const { data, error } = await admin.from(table).select("id").eq(column, profileId);
  if (error || !data) return [];
  return data
    .map((row) => (row as { id?: unknown }).id)
    .filter((id): id is string => typeof id === "string" && id.length > 0);
}

async function removeFolder(
  admin: SupabaseClient,
  bucket: string,
  prefix: string,
): Promise<void> {
  const walk = async (path: string) => {
    const { data, error } = await admin.storage.from(bucket).list(path, {
      limit: 1000,
    });
    if (error || !data?.length) return;
    const files: string[] = [];
    for (const item of data) {
      if (!item.name) continue;
      const full = path ? `${path}/${item.name}` : item.name;
      if (item.id) {
        files.push(full);
      } else {
        await walk(full);
      }
    }
    if (files.length > 0) {
      await admin.storage.from(bucket).remove(files);
    }
  };
  try {
    await walk(prefix);
  } catch {
    // Bucket o carpeta inexistente: no bloquear el borrado de la cuenta.
  }
}

async function deleteBy(
  admin: SupabaseClient,
  table: string,
  column: string,
  profileId: string,
): Promise<void> {
  const { error } = await admin.from(table).delete().eq(column, profileId);
  if (error && !/does not exist|schema cache/i.test(error.message)) {
    throw error;
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

    const profileId = user.id;
    const admin = createClient(supabaseUrl, serviceRoleKey);

    const { data: topics, error: topicSelError } = await admin
      .from("forum_topics")
      .select("id")
      .eq("is_system", false)
      .or(`author_id.eq.${profileId},via_author_id.eq.${profileId}`);
    if (topicSelError) {
      return jsonResponse({ error: topicSelError.message }, 500);
    }
    const topicIds = (topics ?? [])
      .map((row) => row.id as string)
      .filter((id) => typeof id === "string" && id.length > 0);

    const historiaIds = await idsFrom(admin, "historias", "author_id", profileId);
    const eventIds = await idsFrom(admin, "calendar_events", "created_by", profileId);
    const questionIds = await idsFrom(admin, "quiz_questions", "created_by", profileId);

    for (const bucket of USER_FOLDER_BUCKETS) {
      await removeFolder(admin, bucket, profileId);
    }
    for (const topicId of topicIds) {
      for (const bucket of TOPIC_FOLDER_BUCKETS) {
        await removeFolder(admin, bucket, topicId);
      }
    }
    for (const historiaId of historiaIds) {
      await removeFolder(admin, "historia-covers", `${profileId}/${historiaId}`);
    }
    for (const eventId of eventIds) {
      await removeFolder(admin, "event-covers", eventId);
      await removeFolder(admin, "event-icons", eventId);
    }
    for (const questionId of questionIds) {
      await removeFolder(admin, "quiz-images", questionId);
      await removeFolder(admin, "quiz-audio", questionId);
    }

    await deleteBy(admin, "forum_replies", "author_id", profileId);
    await deleteBy(admin, "hermandad_scheduled_posts", "author_id", profileId);
    await deleteBy(admin, "event_live_updates", "user_id", profileId);
    await deleteBy(admin, "ss_live_updates", "user_id", profileId);
    await deleteBy(admin, "ss_live_update_replies", "user_id", profileId);
    await deleteBy(admin, "historia_comments", "user_id", profileId);
    await deleteBy(admin, "quiz_answers", "user_id", profileId);

    if (questionIds.length > 0) {
      await admin.from("quiz_rounds").delete().in("question_id", questionIds);
      await admin.from("quiz_questions").delete().in("id", questionIds);
    }

    if (topicIds.length > 0) {
      const { error: topicDelError } = await admin
        .from("forum_topics")
        .delete()
        .in("id", topicIds);
      if (topicDelError) {
        return jsonResponse({ error: topicDelError.message }, 500);
      }
    }

    if (eventIds.length > 0) {
      const { error: eventDelError } = await admin
        .from("calendar_events")
        .delete()
        .in("id", eventIds);
      if (eventDelError) {
        return jsonResponse({ error: eventDelError.message }, 500);
      }
    }

    if (historiaIds.length > 0) {
      await admin.from("historias").delete().in("id", historiaIds);
    }

    const { error: authDelError } = await admin.auth.admin.deleteUser(profileId);
    if (authDelError) {
      return jsonResponse(
        { error: `No se pudo eliminar la cuenta: ${authDelError.message}` },
        500,
      );
    }

    return jsonResponse({ ok: true, profileId });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Error inesperado";
    return jsonResponse({ error: message }, 500);
  }
});
