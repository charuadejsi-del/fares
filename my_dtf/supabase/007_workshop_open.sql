-- My DTF — 007 : état de l'atelier (ouvert / fermé), commandé par l'administrateur ou le gérant, visible des clients.
alter table dtf_settings add column if not exists is_open boolean not null default true;
alter table dtf_settings add column if not exists open_note text;
alter table dtf_settings add column if not exists open_changed_at timestamptz not null default now();
alter table dtf_settings add column if not exists open_changed_by uuid references dtf_profiles(id);

create table if not exists dtf_workshop_log (
  id         bigint generated always as identity primary key,
  is_open    boolean not null,
  note       text,
  actor_id   uuid references dtf_profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists dtf_workshop_log_actor_idx on dtf_workshop_log (actor_id);
alter table dtf_workshop_log enable row level security;
create policy "dtf atelier journal lecture" on dtf_workshop_log for select to authenticated using (coalesce(dtf_my_role() <> 'client', false));

create or replace function dtf_set_open(p_open boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if dtf_my_role() not in ('admin', 'manager') then raise exception 'خاص بالمدير والمسيّر'; end if;
  update dtf_settings set is_open = p_open, open_note = case when p_open then null else nullif(trim(p_note), '') end,
    open_changed_at = now(), open_changed_by = auth.uid() where id = 1;
  insert into dtf_workshop_log (is_open, note, actor_id) values (p_open, nullif(trim(p_note), ''), auth.uid());
end $$;
revoke execute on function dtf_set_open(boolean, text) from public, anon;

create or replace function dtf_activity(p_limit int default 40)
returns table (at timestamptz, actor text, kind text, order_code bigint, to_status text, machine text, note text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not dtf_is_staff_admin() then raise exception 'Réservé à l''administration'; end if;
  return query
  select * from (
    select e.created_at, split_part(coalesce(p.full_name, ''), ' ', 1),
           case when p.role = 'client' then 'client' else 'order' end,
           o.code, e.to_status::text, mm.name, e.note
    from dtf_order_events e join dtf_orders o on o.id = e.order_id
    left join dtf_profiles p on p.id = e.actor_id
    left join dtf_machines mm on mm.id = o.machine_id and e.to_status = 'printing'
    union all
    select me.created_at, split_part(coalesce(p.full_name, ''), ' ', 1), 'machine_' || me.kind::text,
           null::bigint, me.to_status::text, m.name, me.note
    from dtf_machine_events me join dtf_machines m on m.id = me.machine_id
    left join dtf_profiles p on p.id = me.actor_id
    union all
    select w.created_at, split_part(coalesce(p.full_name, ''), ' ', 1), 'workshop',
           null::bigint, case when w.is_open then 'open' else 'closed' end, null::text, w.note
    from dtf_workshop_log w left join dtf_profiles p on p.id = w.actor_id
  ) x order by 1 desc limit greatest(1, least(p_limit, 200));
end $$;
revoke execute on function dtf_activity(int) from public, anon;

alter publication supabase_realtime add table dtf_settings;
