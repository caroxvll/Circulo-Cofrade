import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type Body = {
  action?: "get" | "update";
  profileId?: string;
  email?: string;
  password?: string;
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
      return jsonResponse(
        { error: "Solo un admin puede gestionar cuentas hermandad" },
        403,
      );
    }

    const body = (await req.json()) as Body;
    const action = body.action === "update" ? "update" : "get";
    const profileId = (body.profileId ?? "").trim();
    if (!profileId) {
      return jsonResponse({ error: "Falta profileId" }, 400);
    }

    const { data: target, error: targetError } = await admin
      .from("profiles")
      .select("id, handle, display_name, account_type")
      .eq("id", profileId)
      .maybeSingle();

    if (targetError || !target) {
      return jsonResponse({ error: "Cuenta no encontrada" }, 404);
    }
    if (target.account_type !== "brotherhood") {
      return jsonResponse(
        { error: "Solo se pueden gestionar cuentas brotherhood" },
        400,
      );
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

    if (action === "get") {
      return jsonResponse({
        profileId,
        handle: target.handle,
        displayName: target.display_name,
        email: currentEmail,
      });
    }

    const nextEmail = (body.email ?? "").trim().toLowerCase();
    const nextPassword = (body.password ?? "").trim();
    const patch: { email?: string; password?: string; email_confirm?: boolean } =
      {};

    if (nextEmail && nextEmail !== currentEmail) {
      if (!nextEmail.includes("@")) {
        return jsonResponse({ error: "Email no válido" }, 400);
      }
      patch.email = nextEmail;
      patch.email_confirm = true;
    }
    if (nextPassword) {
      if (nextPassword.length < 8) {
        return jsonResponse(
          { error: "La contraseña debe tener al menos 8 caracteres" },
          400,
        );
      }
      patch.password = nextPassword;
    }

    if (!patch.email && !patch.password) {
      return jsonResponse(
        { error: "Indica un email nuevo y/o una contraseña (≥ 8)" },
        400,
      );
    }

    const { data: updated, error: updateError } =
      await admin.auth.admin.updateUserById(profileId, patch);
    if (updateError || !updated.user) {
      return jsonResponse(
        { error: updateError?.message ?? "No se pudo actualizar Auth" },
        400,
      );
    }

    return jsonResponse({
      profileId,
      handle: target.handle,
      displayName: target.display_name,
      email: (
        updated.user.email ??
        (nextEmail || currentEmail)
      ).toLowerCase(),
      passwordUpdated: Boolean(patch.password),
      emailUpdated: Boolean(patch.email),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Error inesperado";
    return jsonResponse({ error: message }, 500);
  }
});
