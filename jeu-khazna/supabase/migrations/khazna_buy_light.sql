-- مشتريات أثناء المهمّة: الضوء (للقفل / للجولة) ومورس (إعادة البثّ / الرموز المكتوبة).
-- الأسعار يحدّدها المدير من لوحة الإدارة (جدول settings).
insert into public.settings (key, value) values
  ('light_lock_seconds', to_jsonb(60)),
  ('light_round_seconds', to_jsonb(120)),
  ('morse_replay_seconds', to_jsonb(30)),
  ('morse_text_seconds', to_jsonb(90))
on conflict (key) do nothing;

create or replace function public.session_buy(p_session uuid, p_item text) returns integer
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  k text := case p_item
    when 'light_lock' then 'light_lock_seconds'
    when 'light_round' then 'light_round_seconds'
    when 'morse_replay' then 'morse_replay_seconds'
    when 'morse_text' then 'morse_text_seconds'
  end;
  cost int; bal int;
begin
  if k is null then raise exception 'invalid item'; end if;
  if not exists (select 1 from public.session_players where session_id = p_session and user_id = me) then raise exception 'no session'; end if;
  cost := public.setting_int(k, 60);
  select balance_seconds into bal from public.profiles where id = me;
  if bal < cost then raise exception 'no balance'; end if;
  perform public._charge(me, cost, case when p_item like 'light%' then 'light' else 'morse' end, p_session::text);
  select balance_seconds into bal from public.profiles where id = me;
  return bal;
end;
$$;

revoke all on function public.session_buy(uuid, text) from public, anon;
grant execute on function public.session_buy(uuid, text) to authenticated;

-- أسباب السجلّ: إضافة الضوء ومورس، وإصلاح «الإحالة» و«التحديات» التي كانت مرفوضة.
alter table public.time_ledger drop constraint time_ledger_reason_check;
alter table public.time_ledger add constraint time_ledger_reason_check check (reason = any (array['signup','daily','session','penalty','purchase','gift_in','gift_out','hint','admin','referral','challenge','light','morse']));
