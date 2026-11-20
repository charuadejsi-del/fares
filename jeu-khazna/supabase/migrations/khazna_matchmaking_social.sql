-- الخزنة: المطابقة العشوائية (الرادار)، الأصدقاء والدعوات، الحظر والإبلاغ، كود الدعوة، التحديات اليومية، العودة للمهمّة.

-- ===== أعمدة جديدة =====
alter table public.rooms add column if not exists matched boolean not null default false;
alter table public.profiles add column if not exists referral_code text;
alter table public.profiles add column if not exists referred_by uuid references public.profiles(id) on delete set null;
alter table public.profiles add column if not exists referral_rewarded boolean not null default false;

update public.profiles set referral_code = upper(substr(md5(id::text || 'khz'), 1, 6)) where referral_code is null;
create unique index if not exists profiles_referral_code_key on public.profiles (referral_code);

insert into public.settings (key, value) values
  ('referral_bonus_seconds', '1800'),
  ('challenge_reward_seconds', '300'),
  ('bot_after_seconds', '60')
on conflict (key) do nothing;

-- ===== جداول =====
create table if not exists public.match_queue (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  skill int not null default 0,
  joined_at timestamptz not null default now(),
  seen_at timestamptz not null default now(),
  room_code text,
  channel text,
  partner uuid,
  is_host boolean
);
create table if not exists public.match_log (
  id bigserial primary key,
  a uuid, b uuid,
  waited_seconds int,
  created_at timestamptz not null default now()
);
create table if not exists public.friendships (
  a uuid not null references public.profiles(id) on delete cascade,
  b uuid not null references public.profiles(id) on delete cascade,
  requested_by uuid not null,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  primary key (a, b),
  check (a < b)
);
create table if not exists public.blocks (
  blocker uuid not null references public.profiles(id) on delete cascade,
  blocked uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked)
);
create table if not exists public.reports (
  id bigserial primary key,
  reporter uuid not null references public.profiles(id) on delete cascade,
  reported uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  details text,
  status text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid
);
create table if not exists public.room_invites (
  id bigserial primary key,
  from_user uuid not null references public.profiles(id) on delete cascade,
  to_user uuid not null references public.profiles(id) on delete cascade,
  room_code text not null,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);
create table if not exists public.daily_challenges (
  user_id uuid not null references public.profiles(id) on delete cascade,
  day date not null,
  code text not null,
  progress int not null default 0,
  target int not null,
  claimed boolean not null default false,
  primary key (user_id, day, code)
);

-- كل شيء يمرّ عبر الدوال (SECURITY DEFINER) فقط.
alter table public.match_queue enable row level security;
alter table public.match_log enable row level security;
alter table public.friendships enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;
alter table public.room_invites enable row level security;
alter table public.daily_challenges enable row level security;

-- ===== أدوات =====
create or replace function public._is_blocked(x uuid, y uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.blocks where (blocker = x and blocked = y) or (blocker = y and blocked = x));
$$;

create or replace function public._skill(u uuid) returns int
language sql stable security definer set search_path = public as $$
  select coalesce(max(tp.stage), 0) from public.team_progress tp
    join public.teams t on t.id = tp.team_id
   where t.player_a = u or t.player_b = u;
$$;

create or replace function public._room_create(p_host uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c text; k text := substr(md5(gen_random_uuid()::text), 1, 8); tries int := 0;
begin
  update public.rooms set status = 'closed', updated_at = now() where host_id = p_host and status <> 'closed';
  loop
    tries := tries + 1;
    c := (1000 + floor(random() * 9000))::int::text;
    exit when not exists (
      select 1 from public.rooms where code = c and status <> 'closed' and updated_at > now() - interval '20 minutes');
    if tries > 60 then raise exception 'no free code'; end if;
  end loop;
  insert into public.rooms (code, host_id, status, channel_key) values (c, p_host, 'open', k)
  on conflict (code) do update set host_id = excluded.host_id, guest_id = null, team_id = null, stage = null,
         status = 'open', channel_key = excluded.channel_key, matched = false, created_at = now(), updated_at = now();
  return jsonb_build_object('code', c, 'key', k);
end;
$$;

create or replace function public.room_create() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  return public._room_create(auth.uid());
end;
$$;

-- ===== المطابقة (الرادار) =====
create or replace function public.match_search() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  q public.match_queue;
  cand public.match_queue;
  r jsonb;
  waited int;
  others int;
  nick text;
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
     order by m.joined_at
     limit 1
     for update skip locked;
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

create or replace function public.match_cancel() returns void
language sql security definer set search_path = public as $$
  delete from public.match_queue where user_id = auth.uid();
$$;

-- ===== الأصدقاء =====
create or replace function public.friend_request(p_nickname text) returns text
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); other uuid; x uuid; y uuid; f public.friendships;
begin
  if me is null then raise exception 'not signed in'; end if;
  select id into other from public.profiles where lower(nickname) = lower(trim(p_nickname));
  if other is null or public._is_blocked(me, other) then raise exception 'unknown player'; end if;
  if other = me then raise exception 'self friend'; end if;
  x := least(me, other); y := greatest(me, other);
  select * into f from public.friendships where a = x and b = y;
  if f.a is not null then
    if f.status = 'pending' and f.requested_by <> me then
      update public.friendships set status = 'accepted' where a = x and b = y;
      return 'accepted';
    end if;
    return f.status;
  end if;
  if (select count(*) from public.friendships where a = me or b = me) >= 200 then raise exception 'friend limit'; end if;
  insert into public.friendships (a, b, requested_by) values (x, y, me);
  return 'pending';
end;
$$;

create or replace function public.friend_respond(p_user uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if p_accept then
    update public.friendships set status = 'accepted'
     where a = least(me, p_user) and b = greatest(me, p_user) and status = 'pending' and requested_by = p_user;
  else
    delete from public.friendships
     where a = least(me, p_user) and b = greatest(me, p_user) and status = 'pending';
  end if;
end;
$$;

create or replace function public.friend_remove(p_user uuid) returns void
language sql security definer set search_path = public as $$
  delete from public.friendships where a = least(auth.uid(), p_user) and b = greatest(auth.uid(), p_user);
$$;

create or replace function public.friend_list() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', p.id, 'nickname', p.nickname, 'status', f.status,
      'incoming', f.status = 'pending' and f.requested_by <> auth.uid(),
      'online', p.last_seen > now() - interval '2 minutes',
      'skill', public._skill(p.id))
    order by (f.status = 'pending') desc, p.last_seen desc nulls last), '[]'::jsonb)
  from public.friendships f
  join public.profiles p on p.id = case when f.a = auth.uid() then f.b else f.a end
  where (f.a = auth.uid() or f.b = auth.uid()) and not p.banned;
$$;

-- دعوة صديق إلى غرفة جديدة: يُنشئ الغرفة (أنا القائد) ويُرجع {code, key}.
create or replace function public.friend_invite(p_user uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); r jsonb;
begin
  if not exists (select 1 from public.friendships
                  where a = least(me, p_user) and b = greatest(me, p_user) and status = 'accepted') then
    raise exception 'not friends';
  end if;
  if (select count(*) from public.room_invites where from_user = me and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'invite limit';
  end if;
  r := public._room_create(me);
  update public.room_invites set status = 'expired' where from_user = me and status = 'pending';
  insert into public.room_invites (from_user, to_user, room_code) values (me, p_user, r->>'code');
  return r;
end;
$$;

create or replace function public.my_invites() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'from', i.from_user, 'nickname', p.nickname, 'code', i.room_code)
                  order by i.created_at desc), '[]'::jsonb)
  from public.room_invites i
  join public.profiles p on p.id = i.from_user
  join public.rooms r on r.code = i.room_code and r.host_id = i.from_user and r.status <> 'closed'
  where i.to_user = auth.uid() and i.status = 'pending' and i.created_at > now() - interval '3 minutes';
$$;

-- قبول دعوة: يُرجع القناة السرّية كاملة، أو null عند الرفض.
create or replace function public.invite_respond(p_id bigint, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare i public.room_invites; k text;
begin
  select * into i from public.room_invites where id = p_id and to_user = auth.uid() and status = 'pending' for update;
  if i.id is null then raise exception 'invite expired'; end if;
  update public.room_invites set status = case when p_accept then 'accepted' else 'declined' end where id = p_id;
  if not p_accept then return null; end if;
  select channel_key into k from public.rooms
   where code = i.room_code and host_id = i.from_user and status <> 'closed' and updated_at > now() - interval '20 minutes';
  if k is null then raise exception 'invite expired'; end if;
  update public.rooms set guest_id = auth.uid(), updated_at = now() where code = i.room_code;
  return i.room_code || '-' || k;
end;
$$;

-- ===== الحظر والإبلاغ =====
create or replace function public.block_player(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_user = auth.uid() then return; end if;
  insert into public.blocks (blocker, blocked) values (auth.uid(), p_user) on conflict do nothing;
  delete from public.friendships where a = least(auth.uid(), p_user) and b = greatest(auth.uid(), p_user);
end;
$$;

create or replace function public.unblock_player(p_user uuid) returns void
language sql security definer set search_path = public as $$
  delete from public.blocks where blocker = auth.uid() and blocked = p_user;
$$;

create or replace function public.my_blocks() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'nickname', p.nickname)), '[]'::jsonb)
  from public.blocks b join public.profiles p on p.id = b.blocked where b.blocker = auth.uid();
$$;

create or replace function public.report_player(p_user uuid, p_reason text, p_details text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_user = auth.uid() or not exists (select 1 from public.profiles where id = p_user) then raise exception 'unknown player'; end if;
  if p_reason not in ('insult', 'cheat', 'spam', 'inappropriate', 'other') then raise exception 'invalid reason'; end if;
  if (select count(*) from public.reports where reporter = auth.uid() and created_at > now() - interval '1 day') >= 10 then
    raise exception 'report limit';
  end if;
  insert into public.reports (reporter, reported, reason, details) values (auth.uid(), p_user, p_reason, left(p_details, 300));
end;
$$;

-- ===== كود الدعوة =====
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  nick text := left(coalesce(nullif(trim(new.raw_user_meta_data->>'nickname'), ''), 'agent'), 16);
  bonus int := coalesce((select (value)::text::int from public.settings where key = 'signup_bonus_seconds'), 6000);
  refby uuid;
begin
  if char_length(nick) < 2 then nick := 'agent'; end if;
  if exists (select 1 from public.profiles where lower(nickname) = lower(nick)) then
    nick := left(nick, 15) || '_' || floor(random() * 9000 + 1000)::int;
  end if;
  select id into refby from public.profiles where referral_code = upper(trim(coalesce(new.raw_user_meta_data->>'ref', '')));
  insert into public.profiles (id, nickname, balance_seconds, referral_code, referred_by)
  values (new.id, nick, bonus, upper(substr(md5(new.id::text || 'khz'), 1, 6)), refby);
  insert into public.time_ledger (user_id, delta_seconds, reason) values (new.id, bonus, 'signup');
  return new;
end;
$$;

-- إدخال الكود بعد التسجيل (خلال 3 أيام، مرّة واحدة).
create or replace function public.referral_apply(p_code text) returns void
language plpgsql security definer set search_path = public as $$
declare me public.profiles; refby uuid;
begin
  select * into me from public.profiles where id = auth.uid();
  if me.id is null then raise exception 'not signed in'; end if;
  if me.referred_by is not null then raise exception 'referral used'; end if;
  if me.created_at < now() - interval '3 days' then raise exception 'referral late'; end if;
  select id into refby from public.profiles where referral_code = upper(trim(p_code));
  if refby is null or refby = me.id then raise exception 'invalid referral'; end if;
  update public.profiles set referred_by = refby where id = me.id;
end;
$$;

create or replace function public.my_referral() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'code', p.referral_code,
    'used', p.referred_by is not null,
    'can_apply', p.referred_by is null and p.created_at > now() - interval '3 days',
    'invited', (select count(*) from public.profiles x where x.referred_by = p.id),
    'rewarded', (select count(*) from public.profiles x where x.referred_by = p.id and x.referral_rewarded),
    'bonus_minutes', public.setting_int('referral_bonus_seconds', 1800) / 60)
  from public.profiles p where p.id = auth.uid();
$$;

create or replace function public._grant(p_user uuid, p_seconds int, p_reason text, p_ref text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_seconds <= 0 then return; end if;
  update public.profiles set balance_seconds = balance_seconds + p_seconds where id = p_user;
  insert into public.time_ledger (user_id, delta_seconds, reason, ref) values (p_user, p_seconds, p_reason, p_ref);
end;
$$;

-- ===== التحديات اليومية =====
create or replace function public._challenge_target(p_code text) returns int
language sql immutable as $$
  select case p_code when 'win2' then 2 when 'win3' then 3 when 'play20' then 20 else 1 end;
$$;

create or replace function public._ensure_challenges(u uuid) returns void
language plpgsql security definer set search_path = public as $$
declare d date := public.algiers_today();
begin
  if exists (select 1 from public.daily_challenges where user_id = u and day = d) then return; end if;
  insert into public.daily_challenges (user_id, day, code, target)
  select u, d, c, public._challenge_target(c)
    from unnest(array['win2', 'win3', 'flawless', 'nohint', 'stranger', 'play20']) c
   order by md5(u::text || d::text || c)
   limit 3
  on conflict do nothing;
end;
$$;

create or replace function public.challenges_today() returns jsonb
language plpgsql security definer set search_path = public as $$
declare d date := public.algiers_today();
begin
  perform public._ensure_challenges(auth.uid());
  return (select coalesce(jsonb_agg(jsonb_build_object('code', code, 'progress', least(progress, target), 'target', target,
            'claimed', claimed, 'reward_minutes', public.setting_int('challenge_reward_seconds', 300) / 60) order by code), '[]'::jsonb)
          from public.daily_challenges where user_id = auth.uid() and day = d);
end;
$$;

create or replace function public.challenge_claim(p_code text) returns int
language plpgsql security definer set search_path = public as $$
declare d date := public.algiers_today(); c public.daily_challenges; bal int;
begin
  select * into c from public.daily_challenges where user_id = auth.uid() and day = d and code = p_code for update;
  if c.user_id is null or c.claimed or c.progress < c.target then raise exception 'challenge not ready'; end if;
  update public.daily_challenges set claimed = true where user_id = auth.uid() and day = d and code = p_code;
  perform public._grant(auth.uid(), public.setting_int('challenge_reward_seconds', 300), 'challenge', d::text || ':' || p_code);
  select balance_seconds into bal from public.profiles where id = auth.uid();
  return bal;
end;
$$;

create or replace function public._challenge_bump(u uuid, p_code text, p_by int) returns void
language sql security definer set search_path = public as $$
  update public.daily_challenges set progress = progress + p_by
   where user_id = u and day = public.algiers_today() and code = p_code and not claimed;
$$;

-- ===== نهاية الجلسة: التحديات ومكافأة الدعوة =====
create or replace function public.session_end(p_session uuid, p_status text) returns integer
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  bal int;
  st text := case when p_status in ('won', 'lost', 'abandoned') then p_status else 'abandoned' end;
  s public.play_sessions;
  u uuid;
  was_matched boolean;
  mins int;
  refby uuid;
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
        -- مكافأة الدعوة عند أول فوز للمدعوّ
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

-- ===== العودة للمهمّة =====
create or replace function public.session_resume(p_session uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', s.id, 'stage', s.stage, 'room', s.room_code, 'status', s.status,
                            'host', s.host_id = auth.uid())
    from public.play_sessions s
   where s.id = p_session and auth.uid() = any(s.players)
     and s.status in ('active', 'paused') and s.last_heartbeat > now() - interval '10 minutes';
$$;

-- ===== الإدارة =====
create or replace function public.admin_match_stats() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin();
  return jsonb_build_object(
    'queue_now', (select count(*) from public.match_queue where room_code is null and seen_at > now() - interval '20 seconds'),
    'matches_today', (select count(*) from public.match_log where created_at > now() - interval '24 hours'),
    'avg_wait_today', (select coalesce(round(avg(waited_seconds)), 0) from public.match_log where created_at > now() - interval '24 hours'),
    'matches_week', (select count(*) from public.match_log where created_at > now() - interval '7 days'),
    'friendships', (select count(*) from public.friendships where status = 'accepted'),
    'referrals', (select count(*) from public.profiles where referred_by is not null),
    'referrals_rewarded', (select count(*) from public.profiles where referral_rewarded),
    'open_reports', (select count(*) from public.reports where status = 'open'),
    'challenges_claimed_today', (select count(*) from public.daily_challenges where day = public.algiers_today() and claimed),
    'by_hour', (select coalesce(jsonb_agg(jsonb_build_object('h', h, 'n', n) order by h), '[]'::jsonb) from (
        select extract(hour from created_at at time zone 'Africa/Algiers')::int h, count(*) n
          from public.match_log where created_at > now() - interval '7 days' group by 1) z)
  );
end;
$$;

create or replace function public.admin_reports(p_status text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin();
  return (select coalesce(jsonb_agg(jsonb_build_object(
      'id', r.id, 'reason', r.reason, 'details', r.details, 'status', r.status, 'created_at', r.created_at,
      'reporter', r.reporter, 'reporter_nick', a.nickname,
      'reported', r.reported, 'reported_nick', b.nickname, 'reported_banned', b.banned,
      'against_count', (select count(*) from public.reports x where x.reported = r.reported))
    order by r.created_at desc), '[]'::jsonb)
    from (select * from public.reports where p_status is null or p_status = '' or status = p_status
           order by created_at desc limit 300) r
    join public.profiles a on a.id = r.reporter
    join public.profiles b on b.id = r.reported);
end;
$$;

create or replace function public.admin_resolve_report(p_id bigint, p_status text, p_ban boolean) returns void
language plpgsql security definer set search_path = public as $$
declare who uuid;
begin
  perform public.require_admin();
  if p_status not in ('resolved', 'dismissed', 'open') then raise exception 'invalid status'; end if;
  update public.reports set status = p_status, resolved_at = now(), resolved_by = auth.uid() where id = p_id returning reported into who;
  if p_ban and who is not null then update public.profiles set banned = true where id = who; end if;
end;
$$;

-- الصلاحيات: الدوال الداخلية لا تُستدعى من العميل.
revoke execute on function public._is_blocked(uuid, uuid), public._skill(uuid), public._room_create(uuid),
  public._grant(uuid, int, text, text), public._ensure_challenges(uuid), public._challenge_bump(uuid, text, int)
  from public, anon, authenticated;
