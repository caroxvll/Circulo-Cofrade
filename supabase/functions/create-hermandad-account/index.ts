import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type CreateBody = {
  email?: string;
  password?: string;
  handle?: string;
  displayName?: string;
  topicId?: string | null;
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeHandle(raw: string): string {
  return raw
    .trim()
    .replace(/^@+/, "")
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, "");
}

function generatePassword(length = 14): string {
  const alphabet =
    "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@$%";
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  let out = "";
  for (const b of bytes) {
    out += alphabet[b % alphabet.length];
  }
  return out;
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
      return jsonResponse({ error: "Solo un admin puede crear cuentas hermandad" }, 403);
    }

    const body = (await req.json()) as CreateBody;
    const email = (body.email ?? "").trim().toLowerCase();
    const displayName = (body.displayName ?? "").trim();
    const handle = normalizeHandle(body.handle ?? "");
    const topicId = (body.topicId ?? "").trim() || null;
    const password =
      (body.password ?? "").trim().length >= 8
        ? (body.password ?? "").trim()
        : generatePassword();

    if (!email || !email.includes("@")) {
      return jsonResponse({ error: "Email no válido" }, 400);
    }
    if (displayName.length < 2 || displayName.length > 40) {
      return jsonResponse({ error: "El nombre debe tener entre 2 y 40 caracteres" }, 400);
    }
    if (handle.length < 3) {
      return jsonResponse({ error: "Handle demasiado corto" }, 400);
    }

    const { data: existingHandle } = await admin
      .from("profiles")
      .select("id")
      .eq("handle", handle)
      .maybeSingle();
    if (existingHandle) {
      return jsonResponse({ error: "Ese handle ya está en uso" }, 409);
    }

    if (topicId) {
      const { data: topic } = await admin
        .from("forum_topics")
        .select("id, forum_id")
        .eq("id", topicId)
        .maybeSingle();
      if (!topic || topic.forum_id !== "hermandades") {
        return jsonResponse({ error: "Tablón de hermandad no válido" }, 400);
      }
    }

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        handle,
        display_name: displayName,
        account_type: "brotherhood",
        verified: true,
        onboarding_completed: true,
        provisioned_by_junta: true,
      },
    });

    if (createError || !created.user) {
      return jsonResponse(
        { error: createError?.message ?? "No se pudo crear el usuario Auth" },
        400,
      );
    }

    const profileId = created.user.id;

    // Asegura tipo/verificación aunque el trigger sea una versión antigua.
    const { error: profileError } = await admin
      .from("profiles")
      .update({
        handle,
        display_name: displayName,
        account_type: "brotherhood",
        verified: true,
        updated_at: new Date().toISOString(),
      })
      .eq("id", profileId);

    if (profileError) {
      return jsonResponse(
        {
          error:
            `Usuario Auth creado, pero falló el perfil: ${profileError.message}`,
          profileId,
        },
        500,
      );
    }

    if (topicId) {
      const { error: assignError } = await admin
        .from("hermandad_topic_accounts")
        .upsert({
          profile_id: profileId,
          topic_id: topicId,
        });
      if (assignError) {
        return jsonResponse(
          {
            error:
              `Cuenta creada, pero no se pudo vincular al tablón: ${assignError.message}`,
            profileId,
            handle,
            temporaryPassword: password,
          },
          500,
        );
      }
    }

    return jsonResponse({
      profileId,
      handle,
      displayName,
      email,
      topicId,
      temporaryPassword: password,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Error inesperado";
    return jsonResponse({ error: message }, 500);
  }
});
