import { createClient } from "npm:@supabase/supabase-js@2";
import * as jose from "npm:jose@5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type NotificationRecord = {
  user_id: string;
  type: string;
  title: string;
  subtitle: string | null;
  payload: Record<string, unknown> | null;
};

type WebhookPayload = {
  type: string;
  table: string;
  record: NotificationRecord;
};

type NotificationPreferences = {
  push_enabled: boolean;
  notify_hashtags: boolean;
  notify_profiles: boolean;
  notify_topics: boolean;
  notify_mentions: boolean;
  notify_followers: boolean;
  notify_reactions: boolean;
  notify_calendar: boolean;
  notify_quiz: boolean;
  notify_news: boolean;
};

const TYPE_PREF: Record<string, keyof NotificationPreferences> = {
  hashtag_activity: "notify_hashtags",
  topic_activity: "notify_topics",
  user_post: "notify_profiles",
  user_reply: "notify_topics",
  mention: "notify_mentions",
  new_follower: "notify_followers",
  reply_reaction: "notify_reactions",
  calendar: "notify_calendar",
  quiz: "notify_quiz",
  news_published: "notify_news",
};

const PREF_DEFAULTS: Record<keyof NotificationPreferences, boolean> = {
  push_enabled: false,
  notify_hashtags: true,
  notify_profiles: true,
  notify_topics: true,
  notify_mentions: true,
  notify_followers: false,
  notify_reactions: true,
  notify_calendar: false,
  notify_quiz: true,
  notify_news: true,
};

function prefEnabled(
  prefs: NotificationPreferences,
  key: keyof NotificationPreferences,
): boolean {
  const value = prefs[key];
  if (typeof value === "boolean") return value;
  return PREF_DEFAULTS[key];
}

function shouldSendPush(
  type: string,
  prefs: NotificationPreferences | null,
): boolean {
  if (!prefs?.push_enabled) return false;

  const prefKey = TYPE_PREF[type];
  if (!prefKey) return true;
  return prefEnabled(prefs, prefKey);
}

function hermandadSectionQueryValue(category: string): string {
  switch (category) {
    case "culto":
      return "cultos";
    case "acto":
      return "actos";
    case "patrimonio":
      return "patrimonio";
    default:
      return "noticias";
  }
}

function buildRoute(record: NotificationRecord): string {
  const data = record.payload ?? {};
  if (typeof data.route === "string" && data.route.length > 0) {
    return data.route;
  }

  const forumId = data.forumId;
  const topicId = data.topicId;
  if (typeof forumId === "string" && typeof topicId === "string") {
    const params = new URLSearchParams();
    const replyId = data.replyId;
    if (typeof replyId === "string" && replyId.length > 0) {
      params.set("reply", replyId);
    }
    const officialCategory = data.officialCategory;
    if (
      forumId === "hermandades" &&
      typeof officialCategory === "string" &&
      officialCategory.length > 0
    ) {
      params.set("seccion", hermandadSectionQueryValue(officialCategory));
    }
    const qs = params.toString();
    return `/foros/${forumId}/tema/${topicId}${qs ? `?${qs}` : ""}`;
  }

  if (
    record.type === "new_follower" &&
    typeof data.profileId === "string"
  ) {
    return `/perfil/usuario/${data.profileId}`;
  }

  return "";
}

function notificationBody(record: NotificationRecord): string {
  const subtitle = record.subtitle?.trim();
  if (subtitle) return subtitle;
  return record.title?.trim() || "Círculo Cofrade";
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** OAuth2 access token para FCM (sin google-auth-library: rompe el boot en Deno). */
async function getFcmAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const pem = serviceAccount.private_key.replace(/\\n/g, "\n");
  const privateKey = await jose.importPKCS8(pem, "RS256");

  const assertion = await new jose.SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(privateKey);

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!tokenRes.ok) {
    const text = await tokenRes.text();
    throw new Error(`OAuth Firebase falló: ${tokenRes.status} ${text}`);
  }

  const json = await tokenRes.json() as { access_token?: string };
  if (!json.access_token) {
    throw new Error("No se pudo obtener access_token de Firebase");
  }
  return json.access_token;
}

async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<boolean> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: {
            priority: "high",
          },
          webpush: {
            headers: { Urgency: "high" },
            notification: {
              title,
              body,
              icon: "/icons/Icon-192.png",
            },
          },
        },
      }),
    },
  );

  if (!response.ok) {
    const text = await response.text();
    console.error("FCM error", token.slice(0, 8), text);
    return false;
  }
  return true;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!serviceAccountRaw || !supabaseUrl || !serviceRoleKey) {
      return jsonResponse({
        error: "Faltan secretos de entorno",
        hasServiceAccount: Boolean(serviceAccountRaw),
        hasSupabaseUrl: Boolean(supabaseUrl),
        hasServiceRoleKey: Boolean(serviceRoleKey),
      }, 500);
    }

    let serviceAccount: {
      project_id: string;
      client_email: string;
      private_key: string;
    };
    try {
      serviceAccount = JSON.parse(serviceAccountRaw);
    } catch (parseError) {
      const hint = serviceAccountRaw.trimStart().startsWith("{")
        ? "El JSON parece truncado o con comillas rotas."
        : "El valor no empieza por {. ¿Se guardaron comillas simples de más al hacer secrets set?";
      return jsonResponse({
        error: "FIREBASE_SERVICE_ACCOUNT no es JSON válido",
        hint,
        detail: parseError instanceof Error
          ? parseError.message
          : String(parseError),
        startsWith: serviceAccountRaw.slice(0, 24),
      }, 500);
    }

    if (
      !serviceAccount.project_id ||
      !serviceAccount.client_email ||
      !serviceAccount.private_key
    ) {
      return jsonResponse({
        error: "FIREBASE_SERVICE_ACCOUNT incompleto",
        hasProjectId: Boolean(serviceAccount.project_id),
        hasClientEmail: Boolean(serviceAccount.client_email),
        hasPrivateKey: Boolean(serviceAccount.private_key),
      }, 500);
    }

    let webhook: WebhookPayload;
    try {
      webhook = (await req.json()) as WebhookPayload;
    } catch (parseError) {
      return jsonResponse({
        error: "Cuerpo de la petición no es JSON válido",
        detail: parseError instanceof Error
          ? parseError.message
          : String(parseError),
      }, 400);
    }

    if (webhook.type !== "INSERT" || webhook.table !== "notifications") {
      return jsonResponse({ skipped: true, reason: "evento ignorado" });
    }

    const record = webhook.record;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: prefs, error: prefsError } = await supabase
      .from("notification_preferences")
      .select(
        "push_enabled, notify_hashtags, notify_profiles, notify_topics, notify_mentions, notify_followers, notify_reactions, notify_calendar, notify_quiz",
      )
      .eq("user_id", record.user_id)
      .maybeSingle();

    if (prefsError) {
      console.error("prefs error", record.type, prefsError.message);
    }

    if (!shouldSendPush(record.type, prefs as NotificationPreferences | null)) {
      const prefKey = TYPE_PREF[record.type];
      return jsonResponse({
        skipped: true,
        reason: "preferencias",
        type: record.type,
        push_enabled: prefs?.push_enabled ?? null,
        pref: prefKey ? prefs?.[prefKey] ?? null : null,
      });
    }

    const { data: tokenRows, error: tokensError } = await supabase
      .from("device_tokens")
      .select("fcm_token, platform, updated_at")
      .eq("user_id", record.user_id)
      .order("updated_at", { ascending: false });

    if (tokensError) {
      return jsonResponse({ error: tokensError.message }, 500);
    }

    const seenPlatforms = new Set<string>();
    const tokens = (tokenRows ?? []).filter((row) => {
      if (seenPlatforms.has(row.platform)) return false;
      seenPlatforms.add(row.platform);
      return true;
    });

    if (!tokens.length) {
      return jsonResponse({ skipped: true, reason: "sin tokens" });
    }

    const route = buildRoute(record);
    const body = notificationBody(record);
    const accessToken = await getFcmAccessToken(serviceAccount);
    const data: Record<string, string> = {
      route,
      type: record.type,
      title: record.title,
      body,
    };

    const notifPayload = record.payload ?? {};
    if (typeof notifPayload.forumId === "string") {
      data.forumId = notifPayload.forumId;
    }
    if (typeof notifPayload.topicId === "string") {
      data.topicId = notifPayload.topicId;
    }
    if (typeof notifPayload.replyId === "string") {
      data.replyId = notifPayload.replyId;
    }
    if (typeof notifPayload.officialCategory === "string") {
      data.officialCategory = notifPayload.officialCategory;
    }

    const results = await Promise.all(
      tokens.map(async (row) => {
        const ok = await sendFcmMessage(
          serviceAccount.project_id,
          accessToken,
          row.fcm_token,
          record.title,
          body,
          data,
        );
        return { tokenPrefix: row.fcm_token.slice(0, 12), ok };
      }),
    );

    const sent = results.filter((r) => r.ok).length;
    const failed = results.filter((r) => !r.ok);

    return jsonResponse({
      sent,
      total: tokens.length,
      failed: failed.length > 0 ? failed : undefined,
    });
  } catch (error) {
    console.error(error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Error desconocido" },
      500,
    );
  }
});
