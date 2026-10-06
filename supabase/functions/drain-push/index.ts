import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
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

type PushJob = {
  id: string;
  notification_id: string;
  user_id: string;
  type: string;
  title: string;
  subtitle: string | null;
  payload: Record<string, unknown> | null;
  retry_count: number;
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

type FcmSendResult = {
  ok: boolean;
  permanent: boolean;
  errorText?: string;
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
  ss_live_official: "notify_calendar",
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

  if (record.type === "new_follower" && typeof data.profileId === "string") {
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

function isPermanentFcmError(errorText: string): boolean {
  const t = errorText.toUpperCase();
  return (
    t.includes("UNREGISTERED") ||
    t.includes("NOT_FOUND") ||
    t.includes("INVALID_ARGUMENT") ||
    t.includes("REGISTRATION-TOKEN-NOT-REGISTERED")
  );
}

async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<FcmSendResult> {
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
          android: { priority: "high" },
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

  if (response.ok) return { ok: true, permanent: false };

  const text = await response.text();
  console.error("FCM error", token.slice(0, 8), text);
  return {
    ok: false,
    permanent: isPermanentFcmError(text),
    errorText: text.slice(0, 400),
  };
}

async function mapPool<T, R>(
  items: T[],
  concurrency: number,
  worker: (item: T) => Promise<R>,
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let next = 0;

  async function run() {
    while (next < items.length) {
      const i = next++;
      results[i] = await worker(items[i]);
    }
  }

  const n = Math.max(1, Math.min(concurrency, items.length || 1));
  await Promise.all(Array.from({ length: n }, () => run()));
  return results;
}

async function finishJob(
  supabase: SupabaseClient,
  id: string,
  status: "done" | "failed" | "skipped",
  error?: string,
) {
  const { error: rpcError } = await supabase.rpc("finish_push_delivery_job", {
    p_id: id,
    p_status: status,
    p_error: error ?? null,
  });
  if (rpcError) {
    console.error("finish_push_delivery_job", id, rpcError.message);
  }
}

async function processJob(
  supabase: SupabaseClient,
  serviceAccount: { project_id: string; client_email: string; private_key: string },
  accessToken: string,
  job: PushJob,
): Promise<"done" | "failed" | "skipped"> {
  const record: NotificationRecord = {
    user_id: job.user_id,
    type: job.type,
    title: job.title,
    subtitle: job.subtitle,
    payload: job.payload,
  };

  const { data: prefs, error: prefsError } = await supabase
    .from("notification_preferences")
    .select(
      "push_enabled, notify_hashtags, notify_profiles, notify_topics, notify_mentions, notify_followers, notify_reactions, notify_calendar, notify_quiz, notify_news",
    )
    .eq("user_id", job.user_id)
    .maybeSingle();

  if (prefsError) {
    await finishJob(supabase, job.id, "failed", prefsError.message);
    return "failed";
  }

  if (!shouldSendPush(job.type, prefs as NotificationPreferences | null)) {
    await finishJob(supabase, job.id, "skipped", "preferencias");
    return "skipped";
  }

  const { data: tokenRows, error: tokensError } = await supabase
    .from("device_tokens")
    .select("fcm_token, platform, updated_at")
    .eq("user_id", job.user_id)
    .order("updated_at", { ascending: false });

  if (tokensError) {
    await finishJob(supabase, job.id, "failed", tokensError.message);
    return "failed";
  }

  const seenPlatforms = new Set<string>();
  const tokens = (tokenRows ?? []).filter((row) => {
    if (seenPlatforms.has(row.platform)) return false;
    seenPlatforms.add(row.platform);
    return true;
  });

  if (!tokens.length) {
    await finishJob(supabase, job.id, "skipped", "sin tokens");
    return "skipped";
  }

  const route = buildRoute(record);
  const body = notificationBody(record);
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

  let sent = 0;
  let transientFail = false;
  let lastError: string | undefined;

  for (const row of tokens) {
    const result = await sendFcmMessage(
      serviceAccount.project_id,
      accessToken,
      row.fcm_token,
      record.title,
      body,
      data,
    );

    if (result.ok) {
      sent += 1;
      continue;
    }

    lastError = result.errorText;
    if (result.permanent) {
      await supabase.rpc("delete_device_token_by_fcm", {
        p_fcm_token: row.fcm_token,
      });
    } else {
      transientFail = true;
    }
  }

  if (sent > 0 && !transientFail) {
    await finishJob(supabase, job.id, "done");
    return "done";
  }

  if (sent > 0 && transientFail) {
    // Al menos un dispositivo OK; no reencolar por el otro.
    await finishJob(supabase, job.id, "done", lastError);
    return "done";
  }

  if (!transientFail && lastError && isPermanentFcmError(lastError)) {
    await finishJob(supabase, job.id, "skipped", lastError);
    return "skipped";
  }

  await finishJob(supabase, job.id, "failed", lastError ?? "FCM falló");
  return "failed";
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
      return jsonResponse({ error: "Faltan secretos de entorno" }, 500);
    }

    let serviceAccount: {
      project_id: string;
      client_email: string;
      private_key: string;
    };
    try {
      serviceAccount = JSON.parse(serviceAccountRaw);
    } catch (parseError) {
      return jsonResponse({
        error: "FIREBASE_SERVICE_ACCOUNT no es JSON válido",
        detail: parseError instanceof Error
          ? parseError.message
          : String(parseError),
      }, 500);
    }

    let body: {
      batchSize?: number;
      maxBatches?: number;
      concurrency?: number;
    } = {};
    try {
      if (req.method !== "GET") {
        body = await req.json();
      }
    } catch {
      body = {};
    }

    const batchSize = Math.min(Math.max(body.batchSize ?? 40, 1), 100);
    const maxBatches = Math.min(Math.max(body.maxBatches ?? 25, 1), 50);
    const concurrency = Math.min(Math.max(body.concurrency ?? 20, 1), 40);

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const accessToken = await getFcmAccessToken(serviceAccount);

    let claimed = 0;
    let done = 0;
    let failed = 0;
    let skipped = 0;

    for (let batch = 0; batch < maxBatches; batch++) {
      const { data: jobs, error: claimError } = await supabase.rpc(
        "claim_push_delivery_jobs",
        { p_limit: batchSize },
      );

      if (claimError) {
        return jsonResponse({ error: claimError.message, claimed, done, failed, skipped }, 500);
      }

      const list = (jobs ?? []) as PushJob[];
      if (!list.length) break;

      claimed += list.length;

      const outcomes = await mapPool(list, concurrency, (job) =>
        processJob(supabase, serviceAccount, accessToken, job)
      );

      for (const o of outcomes) {
        if (o === "done") done += 1;
        else if (o === "skipped") skipped += 1;
        else failed += 1;
      }
    }

    return jsonResponse({
      ok: true,
      claimed,
      done,
      failed,
      skipped,
      batchSize,
      concurrency,
      maxBatches,
    });
  } catch (error) {
    console.error(error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Error desconocido" },
      500,
    );
  }
});
