-- «فريقي»: كل الشركاء الذين لعبت معهم، مع آخر مرحلة ومجموع النجوم وآخر لعب.
create or replace function public.my_teams()
returns table(partner uuid, nickname text, top int, stars int, last_played timestamptz, friend boolean)
language sql stable security definer set search_path = public as $$
  select p.id, p.nickname,
         coalesce((select max(tp.stage) from public.team_progress tp where tp.team_id = t.id), 0)::int,
         coalesce((select sum(tp.stars) from public.team_progress tp where tp.team_id = t.id), 0)::int,
         (select max(s.started_at) from public.play_sessions s where s.team_id = t.id),
         exists (select 1 from public.friendships f
                  where f.a = least(auth.uid(), p.id) and f.b = greatest(auth.uid(), p.id) and f.status = 'accepted')
  from public.teams t
  join public.profiles p on p.id = case when t.player_a = auth.uid() then t.player_b else t.player_a end
  where auth.uid() is not null and t.player_b is not null and auth.uid() in (t.player_a, t.player_b)
    and exists (select 1 from public.play_sessions s where s.team_id = t.id)
  order by 5 desc nulls last
  limit 30;
$$;
revoke all on function public.my_teams() from public, anon;
grant execute on function public.my_teams() to authenticated;
