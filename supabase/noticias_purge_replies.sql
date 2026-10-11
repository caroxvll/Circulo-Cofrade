-- Cofradeo · borrar comentarios/opiniones ya existentes en Noticias
-- Ejecutar DESPUÉS de noticias_no_replies.sql (idempotente).

-- 1) Avisos en bandeja ligados a esas respuestas / actividad de comentario
delete from public.notifications n
using public.forum_replies r
join public.forum_topics t on t.id = r.topic_id
where t.forum_id = 'noticias'
  and (
    n.payload->>'replyId' = r.id::text
    or (
      n.payload->>'topicId' = t.id
      and n.type in (
        'user_reply',
        'topic_activity',
        'mention',
        'reply_reaction'
      )
    )
  );

-- 2) Respuestas (likes/reacciones suelen ir en cascada por FK)
delete from public.forum_replies r
using public.forum_topics t
where r.topic_id = t.id
  and t.forum_id = 'noticias';

-- 3) Contador a cero
update public.forum_topics
set comment_count = 0
where forum_id = 'noticias'
  and comment_count <> 0;

-- Comprobación rápida
select
  (select count(*)::int
   from public.forum_replies r
   join public.forum_topics t on t.id = r.topic_id
   where t.forum_id = 'noticias') as replies_left,
  (select coalesce(sum(comment_count), 0)::int
   from public.forum_topics
   where forum_id = 'noticias') as comment_count_sum;
