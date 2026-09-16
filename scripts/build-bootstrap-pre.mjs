/**
 * Genera supabase/bootstrap_pre.sql concatenando migraciones en orden.
 *
 * Uso:
 *   node scripts/build-bootstrap-pre.mjs
 *
 * Luego en el proyecto PRE (SQL Editor): pegar/ejecutar bootstrap_pre.sql
 * NO ejecutar en producción.
 */
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const supabaseDir = resolve(root, 'supabase');
const outPath = resolve(supabaseDir, 'bootstrap_pre.sql');

/** Orden pensado para proyecto vacío (= pre). Idempotente en la medida de lo posible. */
const ORDERED = [
  'schema.sql',

  // __BASE_PILLARS__ se inserta aquí por código

  'notifications_triggers.sql',
  'storage_avatars.sql',
  'notifications_delete_policy.sql',
  'forum_subreplies_and_follow_notify.sql',
  'reply_likes_and_moderation.sql',
  'reply_reactions.sql',
  'reply_reactions_emoji.sql',
  'notification_social.sql',
  'reply_reaction_notify.sql',
  'reply_reactions_mobile_fix.sql',
  'topic_views_dedup.sql',
  'sync_topic_comment_counts.sql',
  'topic_moderation.sql',
  'admin_roles.sql',
  'admin_roles_fix_trigger.sql',
  'profile_verification.sql',
  'notify_admins_moderation.sql',
  'topic_rejection_reason.sql',
  'topic_follows.sql',
  'sync_forum_pillar_stats.sql',
  'mention_notify_fix.sql',
  'mention_reply_scroll.sql',
  'hashtag_notify_fix.sql',
  'follows_see_followers.sql',
  'admin_forum_pillars.sql',

  // Deps mínimas de roles_v2 → crear forum_moderators YA
  'calendar_events.sql',
  'hermandad_official_posts.sql',
  'roles_v2.sql',
  'forum_moderators_public_read.sql',
  'delete_rejected_topics.sql',

  'forum_pillar_covers.sql',
  'forum_pillar_icons.sql',
  'forum_pillar_about.sql',
  'topic_icons.sql',
  'forum_topic_user_covers.sql',
  'forum_topic_reactions.sql',
  'calendar_notify.sql',
  'calendar_event_reminders.sql',
  'calendar_event_moderator_manage_fix.sql',
  'event_bookmarks.sql',
  'event_live_updates.sql',
  'google_oauth_profile.sql',
  'search_trends.sql',
  'forum_reply_edit_delete.sql',
  'device_tokens.sql',
  'device_tokens_unique.sql',
  'notifications_push.sql',
  'push_opt_in_default.sql',
  'noticias_forum.sql',
  'noticias_related_forum.sql',
  'noticias_forum_follow.sql',
  'hermandad_official_edit.sql',
  'hermandad_scheduled_posts.sql',
  'hermandad_scheduled_posts_drafts.sql',
  'hermandad_official_notify.sql',
  'hermandad_official_post_notify.sql',
  'hermandad_follow_notify_sections.sql',
  'forum_official_post_images.sql',
  'junta_create_hermandad_account.sql',
  'hermandades_todos_los_dias.sql',
  'pinned_topics.sql',
  'pinned_topics_admin.sql',
  'forum_trophies.sql',
  'forum_trophies_topic_views.sql',
  'forum_trophies_rank_notify.sql',
  'ads.sql',
  'ads_forum_targeting.sql',
  'ads_featured_topic.sql',
  'ads_forums_event_placement.sql',
  'ads_rpc_fix.sql',
  'ads_statistics_period.sql',
  'sponsor_settings.sql',
  'sponsor_waitlist.sql',
  'finance_sponsor_payments.sql',
  'liturgical_countdown.sql',
  'quiz_daily.sql',
  'quiz_authors.sql',
  'quiz_fixes.sql',
  'quiz_audio.sql',
  'quiz_forfeit.sql',
  'quiz_day_long_rounds.sql',
  'quiz_ranking_views.sql',
  'quiz_season_cleanup.sql',
  'staff_notifications_overview.sql',
  'notifications_realtime.sql',
  'forum_topics_replies_realtime.sql',
  'forum_pillars_realtime.sql',
  'forum_moderators_realtime.sql',
  'calendar_events_realtime.sql',
  'liturgical_countdown_realtime.sql',
];

/** Opcional: puede fallar sin extensiones / Edge Functions. */
const OPTIONAL = [
  'calendar_event_reminders_cron.sql',
  'push_webhook_trigger.sql',
];

const SKIP = new Set([
  'seed.sql',
  'profile_suspension.sql',
  'topic_view_counter.sql',
  'hermandades_domingo_ramos.sql',
  'hermandades_lunes_santo.sql',
  'reply_reactions_fix.sql',
  'verify_calendar_oauth_deploy.sql',
  'verify_push_not_duplicated.sql',
  'bootstrap_pre.sql',
]);

const BASE_PILLARS = `
-- ---------------------------------------------------------------------------
-- Pilares base (Círculo / Pentagrama / Martillo) — ya no viven en seed.sql
-- ---------------------------------------------------------------------------
insert into public.forum_pillars (
  id, name, description, icon_key, sort_order,
  topic_count, message_count, is_enabled, is_active
) values
  ('foro-cofradiero', 'Círculo Cofrade', 'La tertulia cofrade de Sevilla, los 365 días del año.', 'church', 1, 0, 0, true, true),
  ('pentagrama-cofrade', 'Pentagrama Cofrade', 'Agrupaciones, cornetas y tambores, bandas de música y repertorios.', 'music_note', 2, 0, 0, true, true),
  ('martillo-trabajadera', 'Martillo y Trabajadera', 'La actualidad de los capataces y el mundo del costal.', 'workspace_premium_outlined', 3, 0, 0, true, true)
on conflict (id) do nothing;
`;

function banner(title) {
  return `\n\n-- ###########################################################################\n-- ${title}\n-- ###########################################################################\n\n`;
}

function makePoliciesIdempotent(sql) {
  return sql.replace(
    /create policy\s+"([^"]+)"\s*\r?\n\s*on\s+(public\.\w+)/gi,
    (match, name, table, offset, full) => {
      const before = full.slice(Math.max(0, offset - 160), offset);
      const dropRe = new RegExp(
        `drop\\s+policy\\s+if\\s+exists\\s+"${name.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&')}"\\s+on\\s+${table.replace('.', '\\.')}`,
        'i',
      );
      if (dropRe.test(before)) return match;
      return `drop policy if exists "${name}" on ${table};\ncreate policy "${name}"\n  on ${table}`;
    },
  ).replace(
    /create policy\s+"([^"]+)"\s+on\s+(public\.\w+)/gi,
    (match, name, table, offset, full) => {
      // Evitar tocar los que ya reescribimos en multilínea (empiezan justo tras drop)
      const before = full.slice(Math.max(0, offset - 160), offset);
      const dropRe = new RegExp(
        `drop\\s+policy\\s+if\\s+exists\\s+"${name.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&')}"\\s+on\\s+${table.replace('.', '\\.')}`,
        'i',
      );
      if (dropRe.test(before)) return match;
      return `drop policy if exists "${name}" on ${table};\ncreate policy "${name}" on ${table}`;
    },
  );
}

function readSql(name) {
  const path = resolve(supabaseDir, name);
  if (!existsSync(path)) {
    throw new Error(`Falta archivo: supabase/${name}`);
  }
  return makePoliciesIdempotent(readFileSync(path, 'utf8').trimEnd() + '\n');
}

const parts = [];
parts.push(`-- Cofradeo · BOOTSTRAP PRE (esquema + catálogo)
-- Generado por scripts/build-bootstrap-pre.mjs — no editar a mano; regenera el script.
--
-- SOLO para proyecto PRE vacío (u otro entorno de pruebas).
-- NO ejecutar en producción.
--
-- Qué hace: tablas, RLS, triggers, foros base, hermandades, ads, quiz, etc.
-- Qué NO hace: usuarios reales de prod, temas de usuarios, auth Google/FCM.
--
-- Tras ejecutarlo:
-- 1) Auth → Email ON (en pre puedes desactivar "Confirm email")
-- 2) Regístrate en la app/admin apuntando a env.pre.json
-- 3) update public.profiles set role = 'admin' where handle = 'tu_handle';
--
-- Si falla a mitad: copia el error, NO re-ejecutes todo a ciegas (pregunta).
`);

const missing = [];
for (const name of ORDERED) {
  if (SKIP.has(name)) continue;
  const path = resolve(supabaseDir, name);
  if (!existsSync(path)) {
    missing.push(name);
    continue;
  }
  parts.push(banner(`FILE: ${name}`));
  parts.push(readSql(name));
  if (name === 'schema.sql') {
    parts.push(banner('INLINE: pilares base'));
    parts.push(BASE_PILLARS.trimStart());
  }
}

parts.push(banner('OPCIONAL (puede fallar sin pg_cron / webhook / Edge)'));
parts.push(`-- Los siguientes bloques están comentados a propósito.
-- Descomenta solo si ya tienes la extensión/config en pre.
`);

for (const name of OPTIONAL) {
  if (!existsSync(resolve(supabaseDir, name))) {
    missing.push(name);
    continue;
  }
  const body = readSql(name)
    .split('\n')
    .map((line) => (line.length ? `-- ${line}` : '--'))
    .join('\n');
  parts.push(banner(`OPTIONAL (comentado): ${name}`));
  parts.push(body);
  parts.push('\n');
}

if (missing.length) {
  console.error('Archivos faltantes:', missing.join(', '));
  process.exit(1);
}

const output = parts.join('');
writeFileSync(outPath, output, 'utf8');
const kb = Math.round(Buffer.byteLength(output, 'utf8') / 1024);
console.log(`OK → supabase/bootstrap_pre.sql (${kb} KB, ${ORDERED.length} archivos + pilares)`);
console.log('Ábrelo en el SQL Editor del proyecto PRE y ejecuta Run.');
