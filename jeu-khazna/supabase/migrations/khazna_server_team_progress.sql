-- الخادم يحفظ تقدّم الفريق بنفسه عند نهاية كل مهمّة فائزة (لا يعتمد على التطبيق).

create or replace function public._record_team_win(p_team uuid, p_stage int, p_stars int, p_time int) returns void
language plpgsql security definer set search_path = public as $$
declare top int;
begin
  if p_team is null or p_stage < 1 then return; end if;
  select coalesce(max(stage), 0) into top from public.team_progress where team_id = p_team;
  if p_stage > top + 1 then return; end if; -- لا قفز فوق المراحل
  insert into public.team_progress (team_id, stage, stars, best_time_seconds)
  values (p_team, p_stage, greatest(1, least(3, p_stars)), greatest(0, p_time))
  on conflict (team_id, stage) do update
    set stars = greatest(team_progress.stars, excluded.stars),
        best_time_seconds = least(coalesce(team_progress.best_time_seconds, excluded.best_time_seconds), excluded.best_time_seconds),
        completed_at = now();
end;
$$;
revoke all on function public._record_team_win(uuid, int, int, int) from public, anon, authenticated;

create or replace function public.session_end(p_session uuid, p_status text) returns integer
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid(); bal int;
  st text := case when p_status in ('won', 'lost', 'abandoned') then p_status else 'abandoned' end;
  s public.play_sessions; u uuid; was_matched boolean; mins int; refby uuid; pts int; secs int;
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
    -- حفظ المرحلة للفريق (النجوم تقريبية؛ التطبيق يرفعها إن كانت أعلى)
    if st = 'won' and s.stage > 0 then
      secs := greatest(0, extract(epoch from (now() - s.started_at))::int);
      perform public._record_team_win(s.team_id, s.stage,
        case when s.errors = 0 and secs <= 300 then 3 when s.errors <= 2 then 2 else 1 end, secs);
    end if;
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

-- الاستعادة طُبّقت يدوياً لفريق واحد فقط (المراحل 5–9) بموافقة صاحب اللعبة.
