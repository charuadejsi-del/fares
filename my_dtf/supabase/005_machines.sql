-- =====================================================================
-- My DTF — migration 005 : machines DTF, rouleau par machine, journal, activité
-- =====================================================================
create type dtf_machine_status as enum ('idle', 'running', 'maintenance', 'down');
create type dtf_machine_event_kind as enum ('status', 'maintenance', 'roll');

create table dtf_machines (
  id           uuid primary key default gen_random_uuid(),
  code         bigint generated always as identity unique,
  name         text not null,
  width_cm     numeric(6,2) not null default 60,
  model        text,
  status       dtf_machine_status not null default 'idle',
  status_note  text,
  status_since timestamptz not null default now(),
  operator_id  uuid references dtf_profiles(id),
  active       boolean not null default true,
  created_at   timestamptz not null default now()
);
create index on dtf_machines (operator_id);

create table dtf_machine_events (
  id          bigint generated always as identity primary key,
  machine_id  uuid not null references dtf_machines(id) on delete cascade,
  kind        dtf_machine_event_kind not null,
  from_status dtf_machine_status,
  to_status   dtf_machine_status,
  note        text,
  actor_id    uuid references dtf_profiles(id),
  created_at  timestamptz not null default now()
);
create index on dtf_machine_events (machine_id, created_at);
create index on dtf_machine_events (actor_id);

alter table dtf_rolls add column if not exists machine_id uuid references dtf_machines(id);
create index if not exists dtf_rolls_machine_idx on dtf_rolls (machine_id);
drop index if exists dtf_one_active_roll;
create unique index dtf_one_active_roll_per_machine on dtf_rolls (machine_id) where status = 'active';

alter table dtf_orders add column if not exists machine_id uuid references dtf_machines(id);
alter table dtf_orders add column if not exists print_started_at timestamptz;
alter table dtf_orders add column if not exists print_finished_at timestamptz;
create index if not exists dtf_orders_machine_idx on dtf_orders (machine_id);

alter table dtf_film_moves add column if not exists machine_id uuid references dtf_machines(id);
create index if not exists dtf_film_moves_machine_idx on dtf_film_moves (machine_id);

alter table dtf_machines enable row level security;
alter table dtf_machine_events enable row level security;
create policy "dtf machines lecture" on dtf_machines for select to authenticated using (coalesce(dtf_my_role() <> 'client', false));
create policy "dtf machines journal lecture" on dtf_machine_events for select to authenticated using (coalesce(dtf_my_role() <> 'client', false));

-- ---------- Gestion des machines (admin) ----------
create or replace function dtf_save_machine(p_id uuid, p_name text, p_width numeric, p_model text, p_active boolean)
returns dtf_machines language plpgsql security definer set search_path = public as $$
declare m dtf_machines;
begin
  if dtf_my_role() is distinct from 'admin' then raise exception 'إضافة الآلات خاصة بالمدير'; end if;
  if coalesce(trim(p_name), '') = '' then raise exception 'اكتب اسم الآلة'; end if;
  if p_id is null then
    insert into dtf_machines (name, width_cm, model, active) values (trim(p_name), coalesce(p_width, 60), p_model, coalesce(p_active, true)) returning * into m;
  else
    update dtf_machines set name = trim(p_name), width_cm = coalesce(p_width, width_cm), model = p_model, active = coalesce(p_active, active)
    where id = p_id returning * into m;
  end if;
  return m;
end $$;

-- ---------- État d'une machine (journalisé) ----------
create or replace function dtf_set_machine_status(p_machine uuid, p_status dtf_machine_status, p_note text)
returns void language plpgsql security definer set search_path = public as $$
declare m dtf_machines;
begin
  if dtf_my_role() not in ('admin', 'manager', 'printer') then raise exception 'غير مسموح'; end if;
  perform dtf_require_shift();
  select * into m from dtf_machines where id = p_machine for update;
  if m.id is null then raise exception 'الآلة غير موجودة'; end if;
  if p_status in ('maintenance', 'down') and coalesce(trim(p_note), '') = '' then raise exception 'اكتب السبب'; end if;
  if m.status = p_status and coalesce(m.status_note, '') = coalesce(p_note, '') then return; end if;
  update dtf_machines set status = p_status, status_note = nullif(trim(p_note), ''), status_since = now(),
    operator_id = case when p_status = 'running' then coalesce(operator_id, auth.uid()) else operator_id end
  where id = p_machine;
  insert into dtf_machine_events (machine_id, kind, from_status, to_status, note, actor_id)
  values (p_machine, 'status', m.status, p_status, nullif(trim(p_note), ''), auth.uid());
  if p_status = 'down' then
    insert into dtf_notifications (user_id, title, body)
    select id, 'عطل في ' || m.name, p_note from dtf_profiles where role in ('admin', 'manager') and active;
  end if;
end $$;

create or replace function dtf_log_maintenance(p_machine uuid, p_note text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if dtf_my_role() not in ('admin', 'manager', 'printer') then raise exception 'غير مسموح'; end if;
  if coalesce(trim(p_note), '') = '' then raise exception 'اكتب ما تمّ'; end if;
  insert into dtf_machine_events (machine_id, kind, note, actor_id) values (p_machine, 'maintenance', trim(p_note), auth.uid());
end $$;

-- ---------- Rouleaux par machine ----------
drop function if exists dtf_activate_roll(uuid);
create or replace function dtf_activate_roll(p_machine uuid, p_roll uuid default null) returns dtf_rolls
language plpgsql security definer set search_path = public as $$
declare r dtf_rolls; mname text;
begin
  if dtf_my_role() not in ('admin', 'manager', 'printer') then raise exception 'غير مسموح'; end if;
  perform dtf_require_shift();
  select name into mname from dtf_machines where id = p_machine and active;
  if mname is null then raise exception 'اختر الآلة'; end if;
  update dtf_rolls set status = 'finished', finished_at = now() where status = 'active' and machine_id = p_machine;
  update dtf_rolls set status = 'active', activated_at = now(), machine_id = p_machine
  where id = coalesce(p_roll, (select id from dtf_rolls where status = 'stock' order by purchased_at, code limit 1))
    and status = 'stock'
  returning * into r;
  if r.id is null then raise exception 'لا يوجد رولو في المخزون'; end if;
  insert into dtf_machine_events (machine_id, kind, note, actor_id) values (p_machine, 'roll', 'تركيب الرولو رقم ' || r.code, auth.uid());
  return r;
end $$;

drop function if exists dtf_consume_film(numeric, dtf_move_kind, uuid, text);
create or replace function dtf_consume_film(p_meters numeric, p_kind dtf_move_kind, p_order uuid, p_note text, p_machine uuid)
returns void language plpgsql security definer set search_path = public as $$
declare need numeric := p_meters; r dtf_rolls; take numeric; alert numeric; mname text;
begin
  if need <= 0 then return; end if;
  select roll_alert_m into alert from dtf_settings where id = 1;
  select name into mname from dtf_machines where id = p_machine;
  loop
    select * into r from dtf_rolls where status = 'active' and machine_id is not distinct from p_machine for update;
    if r.id is null then
      update dtf_rolls set status = 'active', activated_at = now(), machine_id = p_machine
      where id = (select id from dtf_rolls where status = 'stock' order by purchased_at, code limit 1)
      returning * into r;
      if r.id is not null and p_machine is not null then
        insert into dtf_machine_events (machine_id, kind, note, actor_id) values (p_machine, 'roll', 'تركيب تلقائي للرولو رقم ' || r.code, auth.uid());
      end if;
    end if;
    if r.id is null then
      insert into dtf_film_moves (roll_id, order_id, meters, kind, note, actor_id, machine_id)
      values (null, p_order, need, p_kind, coalesce(p_note, '') || ' [بدون رولو]', auth.uid(), p_machine);
      insert into dtf_notifications (user_id, title, body)
        select id, 'المخزون فارغ', 'خُصم ' || need || ' م دون رولو مسجّل — سجّل شراء الرولوات'
        from dtf_profiles where role in ('admin', 'manager') and active;
      return;
    end if;
    take := least(need, r.remaining_m);
    update dtf_rolls set remaining_m = remaining_m - take,
      status = case when remaining_m - take <= 0.0001 then 'finished'::dtf_roll_status else status end,
      finished_at = case when remaining_m - take <= 0.0001 then now() else finished_at end
    where id = r.id returning * into r;
    insert into dtf_film_moves (roll_id, order_id, meters, kind, note, actor_id, machine_id)
    values (r.id, p_order, take, p_kind, p_note, auth.uid(), p_machine);
    if r.status = 'active' and r.remaining_m <= alert and not r.alerted then
      update dtf_rolls set alerted = true where id = r.id;
      insert into dtf_notifications (user_id, title, body)
        select id, 'الرولو رقم ' || r.code || coalesce(' على ' || mname, '') || ' قارب على الانتهاء', 'بقي ' || r.remaining_m || ' م — جهّز الرولو التالي'
        from dtf_profiles where role in ('admin', 'manager', 'printer') and active;
    end if;
    need := need - take;
    exit when need <= 0.0001;
  end loop;
end $$;

drop function if exists dtf_record_waste(numeric, text);
create or replace function dtf_record_waste(p_meters numeric, p_note text, p_machine uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if dtf_my_role() not in ('admin', 'manager', 'printer') then raise exception 'غير مسموح'; end if;
  perform dtf_require_shift();
  if p_machine is null or not exists (select 1 from dtf_machines where id = p_machine) then raise exception 'اختر الآلة'; end if;
  if p_meters <= 0 or p_meters > 500 then raise exception 'عدد أمتار غير صحيح'; end if;
  perform dtf_consume_film(p_meters, 'waste', null, p_note, p_machine);
end $$;

-- ---------- Impression sur une machine ----------
drop function if exists dtf_start_printing(uuid);
create or replace function dtf_start_printing(p_order uuid, p_machine uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare m numeric; mid uuid := p_machine; ms dtf_machine_status;
begin
  perform dtf_require_shift();
  if dtf_my_role() not in ('admin', 'manager', 'printer') then raise exception 'خاص بالطابع'; end if;
  if mid is null then
    select id into mid from dtf_machines where active and status not in ('down', 'maintenance') order by code limit 1;
    if (select count(*) from dtf_machines where active and status not in ('down', 'maintenance')) > 1 then
      raise exception 'اختر الآلة التي ستطبع عليها';
    end if;
  end if;
  if mid is null then raise exception 'لا توجد آلة جاهزة. أضف آلة من صفحة «الآلات» أو غيّر حالتها.'; end if;
  select status into ms from dtf_machines where id = mid and active;
  if ms is null then raise exception 'الآلة غير موجودة'; end if;
  if ms in ('down', 'maintenance') then raise exception 'هذه الآلة في عطل أو صيانة'; end if;
  update dtf_orders
     set status = 'printing', machine_id = mid, print_started_at = now(),
         printer_id = case when dtf_my_role() = 'printer' then auth.uid() else printer_id end
   where id = p_order and status = 'ready_to_print'
     and (dtf_is_staff_admin() or printer_id is null or printer_id = auth.uid())
  returning billed_meters into m;
  if not found then raise exception 'هذه الطلبية أخذها طابع آخر أو لم تعد جاهزة للطباعة'; end if;
  update dtf_machines set status = 'running', status_note = null,
    status_since = case when status = 'running' then status_since else now() end, operator_id = auth.uid()
  where id = mid;
  if ms <> 'running' then
    insert into dtf_machine_events (machine_id, kind, from_status, to_status, actor_id) values (mid, 'status', ms, 'running', auth.uid());
  end if;
  perform dtf_consume_film(m, 'print', p_order, null, mid);
end $$;

create or replace function dtf_finish_printing(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare mid uuid;
begin
  perform dtf_require_shift();
  update dtf_orders set print_finished_at = now(),
    status = case when delivery_mode = 'pickup' then 'ready_pickup'::dtf_order_status else 'printed'::dtf_order_status end
  where id = p_order and status = 'printing' and (printer_id = auth.uid() or dtf_is_staff_admin())
  returning machine_id into mid;
  if not found then raise exception 'هذه الطلبية ليست في الطباعة باسمك'; end if;
  if mid is not null and not exists (select 1 from dtf_orders where machine_id = mid and status = 'printing') then
    update dtf_machines set status = 'idle', status_since = now() where id = mid and status = 'running';
    insert into dtf_machine_events (machine_id, kind, from_status, to_status, actor_id) values (mid, 'status', 'running', 'idle', auth.uid());
  end if;
end $$;

-- ---------- Tableau des machines (sans prix, pour toute l'équipe) ----------
create or replace function dtf_machine_board()
returns table (
  id uuid, code bigint, name text, width_cm numeric, model text, status dtf_machine_status, status_note text,
  status_since timestamptz, active boolean, operator_name text,
  roll_code bigint, roll_remaining numeric, roll_length numeric, alert_m numeric,
  job_id uuid, job_code bigint, job_meters numeric, job_started timestamptz, jobs_running int,
  meters_today numeric, waste_today numeric, meters_7d numeric
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if dtf_my_role() is null or dtf_my_role() = 'client' then raise exception 'Réservé à l''équipe'; end if;
  return query
  select m.id, m.code, m.name, m.width_cm, m.model, m.status, m.status_note, m.status_since, m.active,
         split_part(op.full_name, ' ', 1),
         r.code, r.remaining_m, r.length_m, (select roll_alert_m from dtf_settings where id = 1),
         j.id, j.code, j.billed_meters, j.print_started_at,
         (select count(*)::int from dtf_orders o where o.machine_id = m.id and o.status = 'printing'),
         coalesce((select sum(f.meters) from dtf_film_moves f where f.machine_id = m.id and f.kind = 'print' and f.created_at >= date_trunc('day', now() at time zone 'Africa/Algiers') at time zone 'Africa/Algiers'), 0),
         coalesce((select sum(f.meters) from dtf_film_moves f where f.machine_id = m.id and f.kind = 'waste' and f.created_at >= date_trunc('day', now() at time zone 'Africa/Algiers') at time zone 'Africa/Algiers'), 0),
         coalesce((select sum(f.meters) from dtf_film_moves f where f.machine_id = m.id and f.kind = 'print' and f.created_at >= now() - interval '7 days'), 0)
  from dtf_machines m
  left join dtf_profiles op on op.id = m.operator_id
  left join dtf_rolls r on r.machine_id = m.id and r.status = 'active'
  left join lateral (select o.id, o.code, o.billed_meters, o.print_started_at from dtf_orders o
                     where o.machine_id = m.id and o.status = 'printing' order by o.print_started_at desc limit 1) j on true
  order by m.active desc, m.code;
end $$;

-- ---------- Fil d'activité (admin / gérant) ----------
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
  ) x order by 1 desc limit greatest(1, least(p_limit, 200));
end $$;

-- dtf_work_orders : ajout de la machine
drop function if exists dtf_work_orders();
create or replace function dtf_work_orders()
returns table (
  id uuid, code bigint, status dtf_order_status, billed_meters numeric, estimated_length_cm numeric,
  final_length_cm numeric, client_note text, delivery_mode dtf_delivery_mode, designer_id uuid,
  printer_id uuid, machine_id uuid, print_started_at timestamptz, created_at timestamptz, updated_at timestamptz, client_name text
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare r dtf_role := dtf_my_role();
begin
  if r is null or r = 'client' then raise exception 'Réservé au personnel'; end if;
  return query
  select o.id, o.code, o.status, o.billed_meters, o.estimated_length_cm, o.final_length_cm, o.client_note,
         o.delivery_mode, o.designer_id, o.printer_id, o.machine_id, o.print_started_at, o.created_at, o.updated_at,
         split_part(p.full_name, ' ', 1)
  from dtf_orders o join dtf_profiles p on p.id = o.client_id
  where (r = 'designer' and o.designer_id = auth.uid() and (o.status in ('in_design', 'ready_to_print', 'printing') or o.updated_at > now() - interval '1 day'))
     or (r = 'printer' and (o.status = 'ready_to_print'
                            or (o.printer_id = auth.uid() and (o.status = 'printing' or o.updated_at > now() - interval '1 day'))))
     or (r in ('admin', 'manager') and o.status in ('in_design', 'ready_to_print', 'printing'))
  order by o.updated_at;
end $$;

revoke execute on function dtf_consume_film(numeric, dtf_move_kind, uuid, text, uuid) from public, anon, authenticated;
revoke execute on function dtf_save_machine(uuid, text, numeric, text, boolean), dtf_set_machine_status(uuid, dtf_machine_status, text),
  dtf_log_maintenance(uuid, text), dtf_activate_roll(uuid, uuid), dtf_record_waste(numeric, text, uuid),
  dtf_start_printing(uuid, uuid), dtf_finish_printing(uuid), dtf_machine_board(), dtf_activity(int), dtf_work_orders() from public, anon;

alter publication supabase_realtime add table dtf_machines, dtf_machine_events;
