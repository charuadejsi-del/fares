-- الخزنة: سلسلة الأيام، الموسم الأسبوعي (نقاط وألقاب)، تقييم الشريك (يؤثّر في المطابقة).

alter table public.profiles add column if not exists streak_days int not null default 0;
insert into public.settings (key, value) values ('streak_step_seconds', '200') on conflict (key) do nothing;

create table if not exists public.season_points (
  week date not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  points int not null default 0,
  wins int not null default 0,
  primary key (week, user_id)
);
create index if not exists season_points_week_points on public.season_points (week, points desc);

create table if not exists public.partner_ratings (
  rater uuid not null references public.profiles(id) on delete cascade,
  rated uuid not null references public.profiles(id) on delete cascade,
  session_id uuid not null,
  good boolean not null,
  created_at timestamptz not null default now(),
  primary key (rater, session_id)
);
create index if not exists partner_ratings_rated on public.partner_ratings (rated, created_at);

alter table public.season_points enable row level security;
alter table public.partner_ratings enable row level security;

-- ===== سلسلة الأيام =====
create or replace function public.claim_daily() returns integer
language plpgsql security definer set search_path = public as $$
declare
  base int := public.setting_int('daily_free_seconds', 600);
  step int := public.setting_int('streak_step_seconds', 200);
  p public.profiles;
  st int;
  amt int;
  bal int;
  today date := public.algiers_today();
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into p from public.profiles where id = auth.uid() for update;
  if p.id is null or p.banned then raise exception 'banned'; end if;
  if p.daily_claimed_on is not null and p.daily_claimed_on >= today then raise exception 'already claimed'; end if;
  st := case when p.daily_claimed_on = today - 1 then p.streak_days + 1 else 1 end;
  amt := base + step * (least(st, 7) - 1);
  update public.profiles set balance_seconds = balance_seconds + amt, daily_claimed_on = today, streak_days = st
   where id = p.id returning balance_seconds into bal;
  insert into public.time_ledger (user_id, delta_seconds, reason, ref) values (p.id, amt, 'daily', 'streak:' || st);
  return bal;
end;
$$;

-- ===== الموسم =====
create or replace function public.season_week(p_offset int default 0) returns date
language sql stable as $$
  select (public.algiers_today() - (extract(isodow from public.algiers_today())::int - 1) - 7 * p_offset)::date;
$$;

-- لقب اللاعب من ترتيب الأسبوع الماضي: legend (الأول)، elite (2–10)، top100.
create or replace function public._title(u uuid) returns text
language sql stable security definer set search_path = public as $$
  select case when rk = 1 then 'legend' when rk <= 10 then 'elite' when rk <= 100 then 'top100' end
  from (
    select user_id, rank() over (order by points desc, wins desc) rk
    from public.season_points where week = public.season_week(1) and points > 0
  ) z where user_id = u;
$$;

create or replace function public.season_board(p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare wk date := public.season_week(greatest(p_offset, 0));
begin
  return jsonb_build_object(
    'week', wk,
    'ends_at', (wk + 7)::timestamp at time zone 'Africa/Algiers',
    'rows', (select coalesce(jsonb_agg(x order by x->>'rank_n'), '[]'::jsonb) from (
        select jsonb_build_object('rank', rk, 'rank_n', lpad(rk::text, 6, '0'), 'nickname', p.nickname, 'points', s.points,
                                  'wins', s.wins, 'title', public._title(s.user_id), 'me', s.user_id = auth.uid()) x
        from (select user_id, points, wins, rank() over (order by points desc, wins desc) rk
                from public.season_points where week = wk and points > 0) s
        join public.profiles p on p.id = s.user_id
        where not p.banned and s.rk <= 100) q),
    'me', (select jsonb_build_object('rank', rk, 'points', points, 'wins', wins) from (
        select user_id, points, wins, rank() over (order by points desc, wins desc) rk
          from public.season_points where week = wk and points > 0) z where user_id = auth.uid()),
    'title', public._title(auth.uid()));
end;
$$;

-- ===== تقييم الشريك =====
create or replace function public._rep(u uuid) returns int
language sql stable security definer set search_path = public as $$
  select coalesce(sum(case when good then 0 else 2 end) - sum(case when good then 1 else 0 end), 0)::int
  from public.partner_ratings where rated = u and created_at > now() - interval '30 days';
$$;

create or replace function public.rate_partner(p_user uuid, p_session uuid, p_good boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_user = auth.uid() then raise exception 'self rate'; end if;
  if not exists (select 1 from public.play_sessions where id = p_session and auth.uid() = any(players) and p_user = any(players)) then
    raise exception 'no session';
  end if;
  insert into public.partner_ratings (rater, rated, session_id, good) values (auth.uid(), p_user, p_session, p_good)
  on conflict (rater, session_id) do update set good = excluded.good, created_at = now();
end;
$$;

-- المطابقة: أصحاب التقييمات السيئة في آخر الطابور
create or replace function public.match_search() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid(); q public.match_queue; cand public.match_queue; r jsonb; waited int; others int; nick text;
begin
  if me is null then raise exception 'not signed in'; end if;
  if exists (select 1 from public.profiles where id = me and (banned or balance_seconds <= 0)) then raise exception 'no balance'; end if;
  update public.profiles set last_seen = now() where id = me;
  delete from public.match_queue where seen_at < now() - interval '20 seconds' and room_code is null;
  delete from public.match_queue where seen_at < now() - interval '2 minutes';
  insert into public.match_queue (user_id, skill) values (me, public._skill(me))
  on conflict (user_id) do update set seen_at = now();
  select * into q from public.match_queue where user_id = me for update;
  if q.room_code is null then
    waited := extract(epoch from now() - q.joined_at)::int;
    select * into cand from public.match_queue m
     where m.user_id <> me and m.room_code is null and m.seen_at > now() - interval '20 seconds'
       and abs(m.skill - q.skill) <= 2 + waited / 10
       and not public._is_blocked(me, m.user_id)
       and not exists (select 1 from public.profiles p where p.id = m.user_id and (p.banned or p.balance_seconds <= 0))
     order by (public._rep(m.user_id) >= 4), m.joined_at limit 1 for update skip locked;
    if cand.user_id is not null then
      r := public._room_create(me);
      update public.rooms set guest_id = cand.user_id, matched = true where code = r->>'code';
      update public.match_queue set room_code = r->>'code', channel = (r->>'code') || '-' || (r->>'key'),
             partner = cand.user_id, is_host = true where user_id = me;
      update public.match_queue set room_code = r->>'code', channel = (r->>'code') || '-' || (r->>'key'),
             partner = me, is_host = false, seen_at = now() where user_id = cand.user_id;
      insert into public.match_log (a, b, waited_seconds)
      values (me, cand.user_id, greatest(waited, extract(epoch from now() - cand.joined_at)::int));
      select * into q from public.match_queue where user_id = me;
    end if;
  end if;
  if q.room_code is not null then
    select nickname into nick from public.profiles where id = q.partner;
    delete from public.match_queue where user_id = me;
    return jsonb_build_object('status', 'matched', 'code', q.room_code, 'channel', q.channel,
      'host', q.is_host, 'partner', q.partner, 'partner_nick', nick, 'partner_skill', public._skill(q.partner));
  end if;
  select count(*) into others from public.match_queue where user_id <> me and room_code is null;
  return jsonb_build_object('status', 'searching', 'waited', extract(epoch from now() - q.joined_at)::int,
    'others', others, 'bot_after', public.setting_int('bot_after_seconds', 60));
end;
$$;

-- ===== نهاية الجلسة: + نقاط الموسم =====
create or replace function public.session_end(p_session uuid, p_status text) returns integer
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid(); bal int;
  st text := case when p_status in ('won', 'lost', 'abandoned') then p_status else 'abandoned' end;
  s public.play_sessions; u uuid; was_matched boolean; mins int; refby uuid; pts int;
  bonus int := public.setting_int('referral_bonus_seconds', 1800);
begin
  perform public.session_beat(p_session, true);
  update public.session_players set ended = true where session_id = p_session and user_id = me;
  update public.play_sessions set status = st, ended_at = now()
   where id = p_session and host_id = me and status in ('active', 'paused')
  returning * into s;
  if s.id is not null then
    update public.rooms set status = 'open', updated_at = now() where code = s.room_code;
    select coalesce(matched, false) into was_matched from public.rooms where code = s.room_code;
    pts := 20 + least(greatest(s.stage, 0), 100) + greatest(0, 30 - s.errors * 10)
           + case when s.hints = 0 then 10 else 0 end + case when coalesce(was_matched, false) then 10 else 0 end;
    foreach u in array s.players loop
      perform public._ensure_challenges(u);
      select coalesce(sum(charged_seconds), 0) / 60 into mins from public.session_players where session_id = s.id and user_id = u;
      if mins > 0 then perform public._challenge_bump(u, 'play20', mins); end if;
      if st in ('won', 'lost') and coalesce(was_matched, false) then perform public._challenge_bump(u, 'stranger', 1); end if;
      if st = 'won' then
        perform public._challenge_bump(u, 'win2', 1);
        perform public._challenge_bump(u, 'win3', 1);
        if s.errors = 0 then perform public._challenge_bump(u, 'flawless', 1); end if;
        if s.hints = 0 then perform public._challenge_bump(u, 'nohint', 1); end if;
        insert into public.season_points (week, user_id, points, wins) values (public.season_week(0), u, pts, 1)
        on conflict (week, user_id) do update set points = season_points.points + excluded.points, wins = season_points.wins + 1;
        refby := null;
        select referred_by into refby from public.profiles where id = u and not referral_rewarded and referred_by is not null for update;
        if refby is not null then
          update public.profiles set referral_rewarded = true where id = u;
          perform public._grant(u, bonus, 'referral', refby::text);
          perform public._grant(refby, bonus, 'referral', u::text);
        end if;
      end if;
    end loop;
  end if;
  select balance_seconds into bal from public.profiles where id = me;
  return bal;
end;
$$;

-- ===== الإدارة =====
create or replace function public.admin_season() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin();
  return jsonb_build_object(
    'week', public.season_week(0),
    'players', (select count(*) from public.season_points where week = public.season_week(0)),
    'top', (select coalesce(jsonb_agg(jsonb_build_object('nickname', p.nickname, 'points', s.points, 'wins', s.wins) order by s.points desc), '[]'::jsonb)
              from (select * from public.season_points where week = public.season_week(0) order by points desc limit 10) s
              join public.profiles p on p.id = s.user_id),
    'last_week', (select coalesce(jsonb_agg(jsonb_build_object('nickname', p.nickname, 'points', s.points) order by s.points desc), '[]'::jsonb)
              from (select * from public.season_points where week = public.season_week(1) order by points desc limit 3) s
              join public.profiles p on p.id = s.user_id),
    'worst', (select coalesce(jsonb_agg(jsonb_build_object('id', z.rated, 'nickname', p.nickname, 'bad', z.bad, 'good', z.good, 'banned', p.banned) order by z.bad desc), '[]'::jsonb)
              from (select rated, count(*) filter (where not good) bad, count(*) filter (where good) good
                      from public.partner_ratings where created_at > now() - interval '30 days'
                     group by rated having count(*) filter (where not good) > 0
                     order by 2 desc limit 15) z
              join public.profiles p on p.id = z.rated),
    'ratings_week', (select count(*) from public.partner_ratings where created_at > now() - interval '7 days'),
    'streak_7plus', (select count(*) from public.profiles where streak_days >= 7 and daily_claimed_on >= public.algiers_today() - 1)
  );
end;
$$;

revoke execute on function public._title(uuid), public._rep(uuid) from public, anon, authenticated;
