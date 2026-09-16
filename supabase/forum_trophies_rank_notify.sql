-- Cofradeo · notificación sorpresa al ascender de rango cofrade
-- Ejecutar después de forum_trophies.sql

create or replace function public.cofrade_rank_level(p_points int)
returns int
language sql
immutable
as $$
  select case
    when coalesce(p_points, 0) >= 163 then 27
    when coalesce(p_points, 0) >= 158 then 26
    when coalesce(p_points, 0) >= 152 then 25
    when coalesce(p_points, 0) >= 147 then 24
    when coalesce(p_points, 0) >= 143 then 23
    when coalesce(p_points, 0) >= 138 then 22
    when coalesce(p_points, 0) >= 132 then 21
    when coalesce(p_points, 0) >= 124 then 20
    when coalesce(p_points, 0) >= 114 then 19
    when coalesce(p_points, 0) >= 104 then 18
    when coalesce(p_points, 0) >= 94 then 17
    when coalesce(p_points, 0) >= 84 then 16
    when coalesce(p_points, 0) >= 74 then 15
    when coalesce(p_points, 0) >= 65 then 14
    when coalesce(p_points, 0) >= 56 then 13
    when coalesce(p_points, 0) >= 48 then 12
    when coalesce(p_points, 0) >= 40 then 11
    when coalesce(p_points, 0) >= 33 then 10
    when coalesce(p_points, 0) >= 27 then 9
    when coalesce(p_points, 0) >= 22 then 8
    when coalesce(p_points, 0) >= 17 then 7
    when coalesce(p_points, 0) >= 13 then 6
    when coalesce(p_points, 0) >= 9 then 5
    when coalesce(p_points, 0) >= 6 then 4
    when coalesce(p_points, 0) >= 3 then 3
    when coalesce(p_points, 0) >= 1 then 2
    else 1
  end;
$$;

create or replace function public.cofrade_rank_title(p_points int)
returns text
language sql
immutable
as $$
  select case public.cofrade_rank_level(p_points)
    when 27 then 'Hermano Mayor'
    when 26 then 'Teniente de Hermano Mayor'
    when 25 then 'Diputado Mayor de Gobierno'
    when 24 then 'Fiscal'
    when 23 then 'Secretario'
    when 22 then 'Mayordomo I'
    when 21 then 'Mayordomo II'
    when 20 then 'Prioste I'
    when 19 then 'Prioste II'
    when 18 then 'Auxiliar de Priostía'
    when 17 then 'Diputado de Juventud'
    when 16 then 'Diputado de Formación'
    when 15 then 'Diputado de Caridad'
    when 14 then 'Diputado de Cultos'
    when 13 then 'Diputado de Tramo'
    when 12 then 'Capataz'
    when 11 then 'Contraguía'
    when 10 then 'Costalero'
    when 9 then 'Nazareno Último Tramo'
    when 8 then 'Nazareno 5.º Tramo'
    when 7 then 'Nazareno 4.º Tramo'
    when 6 then 'Nazareno 3.º Tramo'
    when 5 then 'Nazareno 2.º Tramo'
    when 4 then 'Nazareno 1.º Tramo'
    when 3 then 'Nazareno'
    when 2 then 'Hermano'
    else 'Cofrade de a pie'
  end;
$$;

create or replace function public.sync_profile_trophy_points(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_points int := 0;
  v_points int := 0;
  v_old_level int;
  v_new_level int;
  v_title text;
begin
  if p_user_id is null then
    return;
  end if;

  select coalesce(trophy_points, 0)
  into v_old_points
  from public.profiles
  where id = p_user_id;

  select coalesce(sum(
    case trophy_id
      when 'first_reply' then 1
      when 'replies_10' then 2
      when 'replies_30' then 3
      when 'replies_100' then 5
      when 'first_topic' then 3
      when 'topics_5' then 4
      when 'topics_15' then 8
      when 'topics_40' then 12
      when 'topic_views_100' then 2
      when 'topic_views_500' then 5
      when 'topic_views_2000' then 10
      when 'topic_views_10000' then 15
      when 'reactions_1' then 2
      when 'reactions_25' then 5
      when 'reactions_100' then 10
      when 'reactions_250' then 15
      when 'reactions_500' then 20
      when 'followers_5' then 3
      when 'followers_25' then 8
      when 'followers_100' then 15
      when 'hashtag_followers_5' then 4
      when 'hashtag_followers_25' then 10
      when 'topic_followers_10' then 4
      when 'topic_followers_50' then 8
      else 0
    end
  ), 0)
  into v_points
  from public.profile_trophies
  where user_id = p_user_id;

  v_old_level := public.cofrade_rank_level(v_old_points);
  v_new_level := public.cofrade_rank_level(v_points);

  update public.profiles
  set trophy_points = v_points
  where id = p_user_id;

  if v_new_level > v_old_level then
    perform set_config('row_security', 'off', true);
    v_title := public.cofrade_rank_title(v_points);

    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      p_user_id,
      'cofrade_rank_up',
      'Has ascendido a ' || v_title,
      'Enhorabuena, cofrade.',
      jsonb_build_object(
        'route', '/perfil',
        'rankLevel', v_new_level,
        'rankTitle', v_title
      )
    );
  end if;
end;
$$;

grant execute on function public.cofrade_rank_level(int) to authenticated, anon;
grant execute on function public.cofrade_rank_title(int) to authenticated, anon;
