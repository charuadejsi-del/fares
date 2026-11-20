-- المستوى ونقاط الخبرة + عدد المتّصلين الحقيقي.
-- لا جدول جديد: نقاط الخبرة تُحسب من سجلّ الجلسات (play_sessions)، فتشمل الجلسات القديمة أيضاً.
--   فوز = 50 + 20 بلا أخطاء + 10 بلا تلميح + رقم المرحلة (حتى 60) · خسارة = 10
-- المتّصلون = من حدّث حضوره خلال آخر دقيقتين (التطبيق يحدّثه كل 12 ثانية).

create or replace function public._xp_of(u uuid) returns int
language sql stable security definer set search_path = public as $$
  select coalesce(sum(
    case when status = 'won' then 50
           + case when errors = 0 then 20 else 0 end
           + case when hints = 0 then 10 else 0 end
           + least(greatest(stage, 0), 60)
         when status = 'lost' then 10
         else 0 end), 0)::int
  from public.play_sessions where u = any(players);
$$;

create or replace function public.player_stats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not signed in'; end if;
  return jsonb_build_object(
    'xp', public._xp_of(me),
    'online', (select count(*) from public.profiles where last_seen > now() - interval '2 minutes' and not banned)
  );
end;
$$;

revoke all on function public._xp_of(uuid) from public, anon, authenticated;
revoke all on function public.player_stats() from public, anon;
grant execute on function public.player_stats() to authenticated;
