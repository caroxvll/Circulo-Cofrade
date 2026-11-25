import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type Body = {
  force?: boolean;
  skipBacklog?: boolean;
  accountId?: string;
};

type SettingsRow = {
  enabled: boolean;
  interval_minutes: number;
  max_posts_per_account: number;
  last_run_at: string | null;
  last_run_started_at: string | null;
};

type AccountRow = {
  id: string;
  topic_id: string;
  handle: string;
  x_user_id: string | null;
  since_id: string | null;
  ingest_enabled: boolean;
};

type XTweet = {
  id: string;
  text: string;
  created_at?: string;
  attachments?: { media_keys?: string[] };
  note_tweet?: { text?: string };
};

type XMedia = {
  media_key: string;
  type: string;
  url?: string;
  preview_image_url?: string;
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function minutesAgo(iso: string | null, minutes: number): boolean {
  if (!iso) return true;
  const then = Date.parse(iso);
  if (Number.isNaN(then)) return true;
  return Date.now() - then >= minutes * 60_000;
}

function tweetText(tweet: XTweet): string {
  const note = tweet.note_tweet?.text?.trim();
  if (note) return note;
  return (tweet.text ?? "").trim();
}

function mediaForTweet(
  tweet: XTweet,
  mediaByKey: Map<string, XMedia>,
): Array<Record<string, string>> {
  const keys = tweet.attachments?.media_keys ?? [];
  const out: Array<Record<string, string>> = [];
  for (const key of keys) {
    const media = mediaByKey.get(key);
    if (!media) continue;
    const item: Record<string, string> = { type: media.type || "unknown" };
    if (media.url) item.url = media.url;
    if (media.preview_image_url) item.previewUrl = media.preview_image_url;
    out.push(item);
  }
  return out;
}

async function xGet(
  path: string,
  bearer: string,
): Promise<{ ok: boolean; status: number; json: Record<string, unknown> }> {
  const res = await fetch(`https://api.x.com/2${path}`, {
    headers: {
      Authorization: `Bearer ${bearer}`,
      "User-Agent": "CofradeoXIngest/1.0",
    },
  });
  let json: Record<string, unknown> = {};
  try {
    json = await res.json() as Record<string, unknown>;
  } catch {
    json = {};
  }
  return { ok: res.ok, status: res.status, json };
}

async function resolveUserId(
  handle: string,
  bearer: string,
  cached: string | null,
): Promise<{ id: string | null; error: string | null }> {
  if (cached) return { id: cached, error: null };
  const { ok, status, json } = await xGet(
    `/users/by/username/${encodeURIComponent(handle)}`,
    bearer,
  );
  if (!ok) {
    const detail = JSON.stringify(json).slice(0, 280);
    return { id: null, error: `No se resolvió @${handle} (${status}) ${detail}` };
  }
  const data = json.data as { id?: string } | undefined;
  const id = data?.id;
  if (!id) return { id: null, error: `X no devolvió id para @${handle}` };
  return { id, error: null };
}

async function fetchTweets(opts: {
  userId: string;
  sinceId: string | null;
  maxResults: number;
  bearer: string;
}): Promise<{
  tweets: XTweet[];
  mediaByKey: Map<string, XMedia>;
  newestId: string | null;
  error: string | null;
  capped: boolean;
}> {
  const params = new URLSearchParams({
    max_results: String(Math.min(Math.max(opts.maxResults, 5), 20)),
    "tweet.fields": "created_at,attachments,entities,note_tweet,text",
    expansions: "attachments.media_keys",
    "media.fields": "url,preview_image_url,type,alt_text",
    exclude: "retweets,replies",
  });
  if (opts.sinceId) params.set("since_id", opts.sinceId);

  const { ok, status, json } = await xGet(
    `/users/${opts.userId}/tweets?${params.toString()}`,
    opts.bearer,
  );
  if (!ok) {
    const detail = JSON.stringify(json).slice(0, 280);
    return {
      tweets: [],
      mediaByKey: new Map(),
      newestId: null,
      error: `Timeline ${status}: ${detail}`,
      capped: false,
    };
  }

  const tweets = Array.isArray(json.data) ? json.data as XTweet[] : [];
  const includes = json.includes as { media?: XMedia[] } | undefined;
  const mediaByKey = new Map<string, XMedia>();
  for (const media of includes?.media ?? []) {
    mediaByKey.set(media.media_key, media);
  }
  const newestId = tweets[0]?.id ?? opts.sinceId;
  const meta = json.meta as { result_count?: number; next_token?: string } | undefined;
  const capped = Boolean(meta?.next_token) || tweets.length >= opts.maxResults;
  return { tweets, mediaByKey, newestId: newestId ?? null, error: null, capped };
}

async function assertCaller(
  req: Request,
  supabaseUrl: string,
  anonKey: string,
  serviceRoleKey: string,
): Promise<{ ok: true } | { ok: false; status: number; error: string }> {
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) return { ok: false, status: 401, error: "No autenticado" };

  if (token === serviceRoleKey) return { ok: true };

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) {
    return { ok: false, status: 401, error: "Sesión inválida" };
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { data: profile } = await admin
    .from("profiles")
    .select("role, suspended_at")
    .eq("id", user.id)
    .maybeSingle();
  if (!profile || profile.role !== "admin" || profile.suspended_at != null) {
    return { ok: false, status: 403, error: "Solo un admin puede lanzar el job de X" };
  }
  return { ok: true };
}

async function notifyAdmins(
  admin: SupabaseClient,
  count: number,
  sampleHandle: string | null,
) {
  if (count <= 0) return;
  const { data: admins } = await admin
    .from("profiles")
    .select("id")
    .eq("role", "admin")
    .is("suspended_at", null);
  if (!admins?.length) return;

  const title = count === 1
    ? "Nuevo borrador de X"
    : `${count} borradores nuevos de X`;
  const subtitle = sampleHandle
    ? `Revisar en Junta · @${sampleHandle}`
    : "Revisar en Junta · Redes X";
  const rows = admins.map((row) => ({
    user_id: row.id,
    type: "x_ingest_draft",
    title,
    subtitle,
    payload: { route: "/perfil/junta" },
  }));
  await admin.from("notifications").insert(rows);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST" && req.method !== "GET") {
    return jsonResponse({ error: "Método no permitido" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const bearer = Deno.env.get("X_BEARER_TOKEN")?.trim() ?? "";

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return jsonResponse({ error: "Faltan variables de entorno Supabase" }, 500);
    }

    const auth = await assertCaller(req, supabaseUrl, anonKey, serviceRoleKey);
    if (!auth.ok) return jsonResponse({ error: auth.error }, auth.status);

    let body: Body = {};
    try {
      if (req.method !== "GET") body = await req.json();
    } catch {
      body = {};
    }
    const force = body.force === true;
    const skipBacklog = body.skipBacklog === true;
    const onlyAccountId = body.accountId?.trim() || null;

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: settings, error: settingsError } = await admin
      .from("x_ingest_settings")
      .select(
        "enabled, interval_minutes, max_posts_per_account, last_run_at, last_run_started_at",
      )
      .eq("id", 1)
      .maybeSingle();

    if (settingsError || !settings) {
      return jsonResponse({
        error: "Falta x_ingest.sql en este proyecto",
        detail: settingsError?.message,
      }, 500);
    }

    const row = settings as SettingsRow;
    if (!force && !row.enabled) {
      return jsonResponse({
        skipped: true,
        reason: "disabled",
        message: "Job apagado. Enciéndelo o pulsa Lanzar ahora.",
      });
    }

    if (
      !force &&
      !minutesAgo(row.last_run_at, row.interval_minutes)
    ) {
      return jsonResponse({
        skipped: true,
        reason: "interval",
        message: `Aún no toca: intervalo ${row.interval_minutes} min.`,
      });
    }

    if (
      row.last_run_started_at &&
      !minutesAgo(row.last_run_started_at, 4)
    ) {
      return jsonResponse({
        skipped: true,
        reason: "busy",
        message: "Ya hay una pasada en curso.",
      });
    }

    if (!bearer) {
      await admin.from("x_ingest_settings").update({
        last_run_at: new Date().toISOString(),
        last_run_started_at: null,
        last_run_status: "error",
        last_run_error: "Falta el secreto X_BEARER_TOKEN",
        last_run_forced: force,
      }).eq("id", 1);
      return jsonResponse({
        error: "Falta X_BEARER_TOKEN en los secretos de la Edge Function",
      }, 500);
    }

    await admin.from("x_ingest_settings").update({
      last_run_started_at: new Date().toISOString(),
      last_run_status: "running",
      last_run_error: null,
    }).eq("id", 1);

    let accountsQuery = admin
      .from("x_ingest_accounts")
      .select("id, topic_id, handle, x_user_id, since_id, ingest_enabled")
      .order("handle");
    if (onlyAccountId) {
      accountsQuery = accountsQuery.eq("id", onlyAccountId);
    } else {
      accountsQuery = accountsQuery.eq("ingest_enabled", true);
    }

    const { data: accounts, error: accountsError } = await accountsQuery;
    if (accountsError) {
      await admin.from("x_ingest_settings").update({
        last_run_at: new Date().toISOString(),
        last_run_started_at: null,
        last_run_status: "error",
        last_run_error: accountsError.message,
        last_run_forced: force,
      }).eq("id", 1);
      return jsonResponse({ error: accountsError.message }, 500);
    }

    const list = (accounts ?? []) as AccountRow[];
    let newPosts = 0;
    let scanned = 0;
    let firstHandle: string | null = null;
    const errors: string[] = [];

    for (const account of list) {
      scanned += 1;
      const resolved = await resolveUserId(
        account.handle,
        bearer,
        account.x_user_id,
      );
      if (!resolved.id) {
        errors.push(resolved.error ?? account.handle);
        await admin.from("x_ingest_accounts").update({
          last_error: resolved.error,
          last_pulled_at: new Date().toISOString(),
        }).eq("id", account.id);
        continue;
      }

      if (resolved.id !== account.x_user_id) {
        await admin.from("x_ingest_accounts").update({
          x_user_id: resolved.id,
        }).eq("id", account.id);
      }

      const pulled = await fetchTweets({
        userId: resolved.id,
        sinceId: skipBacklog ? null : account.since_id,
        maxResults: row.max_posts_per_account,
        bearer,
      });

      if (pulled.error) {
        errors.push(`@${account.handle}: ${pulled.error}`);
        await admin.from("x_ingest_accounts").update({
          last_error: pulled.error,
          last_pulled_at: new Date().toISOString(),
        }).eq("id", account.id);
        continue;
      }

      const newestId = pulled.newestId ?? account.since_id;
      if (skipBacklog) {
        await admin.from("x_ingest_accounts").update({
          since_id: newestId,
          last_error: null,
          last_pulled_at: new Date().toISOString(),
          last_capped: false,
        }).eq("id", account.id);
        continue;
      }

      const chronological = [...pulled.tweets].reverse();
      for (const tweet of chronological) {
        const bodyText = tweetText(tweet);
        const sourceUrl = `https://x.com/${account.handle}/status/${tweet.id}`;
        const { error: insertError } = await admin.from("x_ingest_drafts").insert({
          account_id: account.id,
          topic_id: account.topic_id,
          handle: account.handle,
          x_post_id: tweet.id,
          body: bodyText,
          source_url: sourceUrl,
          media: mediaForTweet(tweet, pulled.mediaByKey),
          posted_at: tweet.created_at ?? null,
          status: "pending",
          suggested_category: "noticia",
        });
        if (insertError) {
          if (insertError.code === "23505") continue;
          errors.push(`@${account.handle} ${tweet.id}: ${insertError.message}`);
          continue;
        }
        newPosts += 1;
        firstHandle ??= account.handle;
      }

      await admin.from("x_ingest_accounts").update({
        since_id: newestId,
        last_error: null,
        last_pulled_at: new Date().toISOString(),
        last_capped: pulled.capped,
      }).eq("id", account.id);
    }

    const status = errors.length && newPosts === 0 ? "error" : "ok";
    await admin.from("x_ingest_settings").update({
      last_run_at: new Date().toISOString(),
      last_run_started_at: null,
      last_run_status: status,
      last_run_error: errors.length ? errors.slice(0, 4).join(" · ") : null,
      last_run_new_posts: newPosts,
      last_run_accounts: scanned,
      last_run_forced: force,
    }).eq("id", 1);

    if (!skipBacklog) {
      await notifyAdmins(admin, newPosts, firstHandle);
    }

    return jsonResponse({
      ok: true,
      skipped: false,
      skipBacklog,
      accounts: scanned,
      newPosts,
      errors,
    });
  } catch (error) {
    return jsonResponse({
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
});
