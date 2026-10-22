import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type Body = {
  profileId?: string;
  displayName?: string;
  handle?: string;
  email?: string;
  password?: string;
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
    .replace(/[^a-z0-9_]/g, "")
    .slice(0, 30);
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
      return jsonResponse({ error: "Solo un admin puede editar usuarios" }, 403);
    }

    const body = (await req.json()) as Body;
    const profileId = (body.profileId ?? "").trim();
    if (!profileId) {
      return jsonResponse({ error: "Falta profileId" }, 400);
    }

    const { data: target, error: targetError } = await admin
      .from("profiles")
      .select("id, handle, display_name")
      .eq("id", profileId)
      .maybeSingle();

    if (targetError || !target) {
      return jsonResponse({ error: "Usuario no encontrado" }, 404);
    }

    const { data: authUser, error: authError } =
      await admin.auth.admin.getUserById(profileId);
    if (authError || !authUser.user) {
      return jsonResponse(
        { error: authError?.message ?? "No se pudo leer Auth" },
        400,
      );
    }

    const currentEmail = (authUser.user.email ?? "").trim().toLowerCase();
    let nextDisplayName = (body.displayName ?? target.display_name ?? "")
      .trim()
      .slice(0, 80);
    let nextHandle = normalizeHandle(body.handle ?? target.handle ?? "");
    const nextEmail = (body.email ?? "").trim().toLowerCase();
    const nextPassword = (body.password ?? "").trim();

    if (nextDisplayName.length < 2) {
      return jsonResponse({ error: "El nombre debe tener al menos 2 caracteres" }, 400);
    }
    if (nextHandle.length < 2) {
      return jsonResponse(
        { error: "El handle debe tener al menos 2 caracteres (a-z, 0-9, _)" },
        400,
      );
    }

    const profilePatch: Record<string, unknown> = {
      updated_at: new Date().toISOString(),
    };
    let profileUpdated = false;

    if (nextDisplayName !== (target.display_name ?? "").trim()) {
      profilePatch.display_name = nextDisplayName;
      profileUpdated = true;
    }
    if (nextHandle !== (target.handle ?? "")) {
      const { data: clash } = await admin
        .from("profiles")
        .select("id")
        .eq("handle", nextHandle)
        .neq("id", profileId)
        .maybeSingle();
      if (clash) {
        return jsonResponse({ error: `El handle @${nextHandle} ya está en uso` }, 400);
      }
      profilePatch.handle = nextHandle;
      profileUpdated = true;
    }

    if (profileUpdated) {
      const { error: profileError } = await admin
        .from("profiles")
        .update(profilePatch)
        .eq("id", profileId);
      if (profileError) {
        return jsonResponse({ error: profileError.message }, 400);
      }
    }

    const authPatch: {
      email?: string;
      password?: string;
      email_confirm?: boolean;
      user_metadata?: Record<string, string>;
    } = {
      user_metadata: {
        handle: nextHandle,
        display_name: nextDisplayName,
      },
    };

    let emailUpdated = false;
    let passwordUpdated = false;

    if (nextEmail && nextEmail !== currentEmail) {
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(nextEmail)) {
        return jsonResponse({ error: "Email no válido" }, 400);
      }
      authPatch.email = nextEmail;
      authPatch.email_confirm = true;
      emailUpdated = true;
    }
    if (nextPassword) {
      if (nextPassword.length < 8) {
        return jsonResponse(
          { error: "La contraseña debe tener al menos 8 caracteres" },
          400,
        );
      }
      authPatch.password = nextPassword;
      passwordUpdated = true;
    }

    if (emailUpdated || passwordUpdated || profileUpdated) {
      const { data: updated, error: updateError } =
        await admin.auth.admin.updateUserById(profileId, authPatch);
      if (updateError) {
        // Perfil ya pudo actualizarse; Auth falló (p. ej. email duplicado).
        return jsonResponse(
          {
            error: updateError.message,
            profileUpdated,
            emailUpdated: false,
            passwordUpdated: false,
          },
          400,
        );
      }
      return jsonResponse({
        ok: true,
        profileId,
        handle: nextHandle,
        displayName: nextDisplayName,
        email: (
          updated.user?.email ??
          (nextEmail || currentEmail)
        ).toLowerCase(),
        profileUpdated,
        emailUpdated,
        passwordUpdated,
      });
    }

    return jsonResponse({
      ok: true,
      profileId,
      handle: nextHandle,
      displayName: nextDisplayName,
      email: currentEmail,
      profileUpdated: false,
      emailUpdated: false,
      passwordUpdated: false,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Error inesperado";
    return jsonResponse({ error: message }, 500);
  }
});
