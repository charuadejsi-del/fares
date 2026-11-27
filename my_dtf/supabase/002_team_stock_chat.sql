-- =====================================================================
-- My DTF — migration 002 : pointage PIN, rouleaux de film, chat, stats
-- =====================================================================

-- ---------- Paramètres supplémentaires ----------
alter table dtf_settings
  add column if not exists roll_alert_m numeric(8,2) not null default 20,
  add column if not exists work_end_time time not null default '18:00';

-- =====================================================================
-- 1. POINTAGE PAR CODE PIN
-- =====================================================================
create table dtf_staff_pins (
  user_id    uuid primary key references dtf_profiles(id) on delete cascade,
  pin_hash   text not null,
  updated_at timestamptz not null default now()
);
alter table dtf_staff_pins enable row level security;  -- aucune politique : accès via RPC uniquement

create table dtf_attendance (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references dtf_profiles(id) on delete cascade,
  work_date   date not null default (now() at time zone 'Africa/Algiers')::date,
  clock_in    timestamptz not null default now(),
  clock_out   timestamptz,
  auto_closed boolean not null default false
);
create index on dtf_attendance (user_id, work_date);
alter table dtf_attendance enable row level security;
create policy "dtf pointage lecture" on dtf_attendance for select to authenticated
  using (user_id = (select auth.uid()) or dtf_is_staff_admin());

create or replace function dtf_today() returns date
language sql stable set search_path = public as $$ select (now() at time zone 'Africa/Algiers')::date $$;

-- Ferme les journées oubliées (sortie non pointée) à 23:59 et prévient l'admin.
create or replace function dtf_close_forgotten() returns void
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  for r in select a.id, a.user_id, a.work_date, p.full_name from dtf_attendance a join dtf_profiles p on p.id = a.user_id
           where a.clock_out is null and a.work_date < dtf_today() loop
    update dtf_attendance
      set clock_out = ((r.work_date + time '23:59') at time zone 'Africa/Algiers'), auto_closed = true
      where id = r.id;
    insert into dtf_notifications (user_id, title, body)
      select id, 'نسي تسجيل الخروج: ' || r.full_name, 'يوم ' || r.work_date || ' أُغلق تلقائياً على 23:59'
      from dtf_profiles where role = 'admin' and active;
  end loop;
end $$;

create or replace function dtf_open_shift(p_user uuid) returns dtf_attendance
language sql stable security definer set search_path = public as $$
  select * from dtf_attendance where user_id = p_user and clock_out is null and work_date = dtf_today()
  order by clock_in desc limit 1
$$;

-- Le personnel (hors admin) doit avoir pointé son entrée pour travailler.
create or replace function dtf_require_shift() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if dtf_my_role() in ('manager', 'designer', 'printer') and dtf_open_shift(auth.uid()) is null then
    raise exception 'سجّل دخولك بالرمز السري أولاً';
  end if;
end $$;

create or replace function dtf_pin_status()
returns table (has_pin boolean, clocked_in boolean, since timestamptz, work_end time)
language plpgsql security definer set search_path = public as $$
declare s dtf_attendance;
begin
  perform dtf_close_forgotten();
  s := dtf_open_shift(auth.uid());
  return query select exists (select 1 from dtf_staff_pins where user_id = auth.uid()),
                      s.id is not null, s.clock_in,
                      (select work_end_time from dtf_settings where id = 1);
end $$;

-- Le salarié choisit son code (4 à 6 chiffres). Pour le changer : ancien code requis.
create or replace function dtf_pin_set(p_new text, p_old text default null) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare h text;
begin
  if dtf_my_role() is null or dtf_my_role() = 'client' then raise exception 'Réservé au personnel'; end if;
  if p_new !~ '^\d{4,6}$' then raise exception 'الرمز يجب أن يكون من 4 إلى 6 أرقام'; end if;
  select pin_hash into h from dtf_staff_pins where user_id = auth.uid();
  if h is not null and (p_old is null or crypt(p_old, h) <> h) then raise exception 'الرمز القديم غير صحيح'; end if;
  insert into dtf_staff_pins (user_id, pin_hash) values (auth.uid(), crypt(p_new, gen_salt('bf')))
  on conflict (user_id) do update set pin_hash = excluded.pin_hash, updated_at = now();
end $$;

create or replace function dtf_pin_reset(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if dtf_my_role() is distinct from 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  delete from dtf_staff_pins where user_id = p_user;
end $$;

create or replace function dtf_check_pin(p_pin text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare h text;
begin
  select pin_hash into h from dtf_staff_pins where user_id = auth.uid();
  if h is null then raise exception 'اختر رمزك السري أولاً'; end if;
  if crypt(p_pin, h) <> h then raise exception 'الرمز السري غير صحيح'; end if;
end $$;

create or replace function dtf_clock_in(p_pin text) returns dtf_attendance
language plpgsql security definer set search_path = public as $$
declare a dtf_attendance;
begin
  perform dtf_check_pin(p_pin);
  perform dtf_close_forgotten();
  a := dtf_open_shift(auth.uid());
  if a.id is not null then return a; end if;
  insert into dtf_attendance (user_id) values (auth.uid()) returning * into a;
  return a;
end $$;

create or replace function dtf_clock_out(p_pin text) returns dtf_attendance
language plpgsql security definer set search_path = public as $$
declare a dtf_attendance;
begin
  perform dtf_check_pin(p_pin);
  update dtf_attendance set clock_out = now()
  where id = (dtf_open_shift(auth.uid())).id returning * into a;
  if a.id is null then raise exception 'لم تسجّل دخولك اليوم'; end if;
  return a;
end $$;

-- =====================================================================
-- 2. ROULEAUX DE FILM
-- =====================================================================
create type dtf_roll_status as enum ('stock', 'active', 'finished');
create type dtf_move_kind as enum ('print', 'waste', 'adjust');

create table dtf_rolls (
  id            uuid primary key default gen_random_uuid(),
  code          bigint generated always as identity unique,
  length_m      numeric(8,2) not null check (length_m > 0),
  remaining_m   numeric(8,2) not null,
  status        dtf_roll_status not null default 'stock',
  unit_price    numeric(10,2) not null default 0,     -- prix d'achat du rouleau
  supplier      text,
  note          text,
  alerted       boolean not null default false,
  purchased_at  timestamptz not null default now(),
  activated_at  timestamptz,
  finished_at   timestamptz,
  created_by    uuid references dtf_profiles(id)
);
create index on dtf_rolls (status);
create index on dtf_rolls (created_by);
create unique index dtf_one_active_roll on dtf_rolls (status) where status = 'active';

create table dtf_film_moves (
  id         bigint generated always as identity primary key,
  roll_id    uuid references dtf_rolls(id),
  order_id   uuid references dtf_orders(id) on delete set null,
  meters     numeric(8,3) not null,
  kind       dtf_move_kind not null,
  note       text,
  actor_id   uuid references dtf_profiles(id),
  created_at timestamptz not null default now()
);
create index on dtf_film_moves (roll_id);
create index on dtf_film_moves (order_id);
create index on dtf_film_moves (actor_id);
create index on dtf_film_moves (created_at);

alter table dtf_rolls enable row level security;
alter table dtf_film_moves enable row level security;
create policy "dtf rouleaux lecture" on dtf_rolls for select to authenticated
  using (coalesce(dtf_my_role() <> 'client', false));
create policy "dtf mouvements lecture" on dtf_film_moves for select to authenticated
  using (coalesce(dtf_my_role() <> 'client', false));

create or replace view dtf_stock_summary with (security_invoker = true) as
select
  coalesce(sum(remaining_m) filter (where status in ('stock', 'active')), 0) as total_remaining_m,
  coalesce(sum(remaining_m) filter (where status = 'active'), 0)            as active_remaining_m,
  (select length_m from dtf_rolls where status = 'active' limit 1)          as active_length_m,
  (select code from dtf_rolls where status = 'active' limit 1)              as active_code,
  count(*) filter (where status = 'stock')                                   as rolls_in_stock,
  (select roll_alert_m from dtf_settings where id = 1)                       as alert_m
from dtf_rolls;

-- Achat : n rouleaux identiques en stock.
create or replace function dtf_add_rolls(p_count int, p_length_m numeric, p_unit_price numeric, p_supplier text, p_note text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not dtf_is_staff_admin() then raise exception 'Réservé à l''administration'; end if;
  if p_count < 1 or p_count > 200 then raise exception 'Nombre de rouleaux invalide'; end if;
  insert into dtf_rolls (length_m, remaining_m, unit_price, supplier, note, created_by)
  select p_length_m, p_length_m, coalesce(p_unit_price, 0), p_supplier, p_note, auth.uid()
  from generate_series(1, p_count);
end $$;

-- Monter un rouleau : l'ancien rouleau actif passe en « terminé ».
create or replace function dtf_activate_roll(p_roll uuid default null) returns dtf_rolls
language plpgsql security definer set search_path = public as $$
declare r dtf_rolls;
begin
  if dtf_my_role() not in ('admin', 'manager', 'printer') then raise exception 'Non autorisé'; end if;
  perform dtf_require_shift();
  update dtf_rolls set status = 'finished', finished_at = now() where status = 'active';
  update dtf_rolls set status = 'active', activated_at = now()
  where id = coalesce(p_roll, (select id from dtf_rolls where status = 'stock' order by purchased_at, code limit 1))
    and status = 'stock'
  returning * into r;
  if r.id is null then raise exception 'لا يوجد رولو في المخزون'; end if;
  return r;
end $$;

-- Débit du film (impression ou chute), avec passage automatique au rouleau suivant.
create or replace function dtf_consume_film(p_meters numeric, p_kind dtf_move_kind, p_order uuid, p_note text)
returns void language plpgsql security definer set search_path = public as $$
declare need numeric := p_meters; r dtf_rolls; take numeric; alert numeric;
begin
  if need <= 0 then return; end if;
  select roll_alert_m into alert from dtf_settings where id = 1;
  loop
    select * into r from dtf_rolls where status = 'active' for update;
    if r.id is null then
      update dtf_rolls set status = 'active', activated_at = now()
      where id = (select id from dtf_rolls where status = 'stock' order by purchased_at, code limit 1)
      returning * into r;
    end if;
    if r.id is null then
      -- plus de film enregistré : on trace quand même le débit (stock à régulariser)
      insert into dtf_film_moves (roll_id, order_id, meters, kind, note, actor_id)
      values (null, p_order, need, p_kind, coalesce(p_note, '') || ' [sans rouleau]', auth.uid());
      insert into dtf_notifications (user_id, title, body)
        select id, 'المخزون فارغ', 'تم خصم ' || need || ' م بدون رولو مسجّل — أضف شراء الرولوات'
        from dtf_profiles where role in ('admin', 'manager') and active;
      return;
    end if;
    take := least(need, r.remaining_m);
    update dtf_rolls set remaining_m = remaining_m - take,
      status = case when remaining_m - take <= 0.0001 then 'finished'::dtf_roll_status else status end,
      finished_at = case when remaining_m - take <= 0.0001 then now() else finished_at end
    where id = r.id returning * into r;
    insert into dtf_film_moves (roll_id, order_id, meters, kind, note, actor_id)
    values (r.id, p_order, take, p_kind, p_note, auth.uid());
    if r.status = 'active' and r.remaining_m <= alert and not r.alerted then
      update dtf_rolls set alerted = true where id = r.id;
      insert into dtf_notifications (user_id, title, body)
        select id, 'الرولو #' || r.code || ' قريب يخلاص', 'بقي ' || r.remaining_m || ' م فقط — حضّر الرولو التالي'
        from dtf_profiles where role in ('admin', 'manager', 'printer') and active;
    end if;
    need := need - take;
    exit when need <= 0.0001;
  end loop;
end $$;

create or replace function dtf_record_waste(p_meters numeric, p_note text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if dtf_my_role() not in ('admin', 'manager', 'printer') then raise exception 'Non autorisé'; end if;
  perform dtf_require_shift();
  if p_meters <= 0 or p_meters > 500 then raise exception 'Métrage invalide'; end if;
  perform dtf_consume_film(p_meters, 'waste', null, p_note);
end $$;

-- =====================================================================
-- 3. ACTIONS COMMANDE : pointage obligatoire + débit du rouleau
-- =====================================================================
create or replace function dtf_assign_designer(p_order uuid, p_designer uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not dtf_is_staff_admin() then raise exception 'Réservé au gérant'; end if;
  perform dtf_require_shift();
  if (select role from dtf_profiles where id = p_designer and active) is distinct from 'designer' then
    raise exception 'Cet utilisateur n''est pas designer'; end if;
  update dtf_orders set status = 'in_design', designer_id = p_designer, manager_id = auth.uid()
  where id = p_order and status in ('new', 'in_design');
  if not found then raise exception 'Commande introuvable ou déjà avancée'; end if;
end $$;

create or replace function dtf_reject_order(p_order uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not dtf_is_staff_admin() then raise exception 'Réservé au gérant'; end if;
  perform dtf_require_shift();
  update dtf_orders set status = 'rejected', reject_reason = p_reason, manager_id = auth.uid() where id = p_order and status = 'new';
  if not found then raise exception 'Commande introuvable ou déjà traitée'; end if;
end $$;

create or replace function dtf_design_done(p_order uuid, p_final_length_cm numeric, p_printer uuid)
returns void language plpgsql security definer set search_path = public as $$
declare p record;
begin
  perform dtf_require_shift();
  if (select role from dtf_profiles where id = p_printer and active) is distinct from 'printer' then
    raise exception 'Cet utilisateur n''est pas imprimeur'; end if;
  select * into p from dtf_price(p_final_length_cm);
  update dtf_orders set final_length_cm = p_final_length_cm, billed_meters = p.billed_meters,
    print_amount = p.print_amount, printer_id = p_printer, status = 'ready_to_print'
  where id = p_order and status = 'in_design' and (designer_id = auth.uid() or dtf_is_staff_admin());
  if not found then raise exception 'Commande non attribuée à vous ou pas en design'; end if;
end $$;

create or replace function dtf_start_printing(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare m numeric;
begin
  perform dtf_require_shift();
  update dtf_orders set status = 'printing'
  where id = p_order and status = 'ready_to_print' and (printer_id = auth.uid() or dtf_is_staff_admin())
  returning billed_meters into m;
  if not found then raise exception 'Commande non attribuée à vous ou pas prête'; end if;
  perform dtf_consume_film(m, 'print', p_order, null);  -- mêmes mètres que la facture
end $$;

create or replace function dtf_finish_printing(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform dtf_require_shift();
  update dtf_orders set status = case when delivery_mode = 'pickup' then 'ready_pickup'::dtf_order_status else 'printed'::dtf_order_status end
  where id = p_order and status = 'printing' and (printer_id = auth.uid() or dtf_is_staff_admin());
  if not found then raise exception 'Commande non attribuée à vous ou pas en impression'; end if;
end $$;

create or replace function dtf_mark_shipped(p_order uuid, p_carrier text, p_tracking text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not dtf_is_staff_admin() then raise exception 'Réservé au gérant'; end if;
  perform dtf_require_shift();
  update dtf_orders set status = 'shipped', carrier = p_carrier, tracking_number = p_tracking where id = p_order and status = 'printed';
  if not found then raise exception 'Commande pas encore imprimée'; end if;
end $$;

create or replace function dtf_mark_delivered(p_order uuid, p_amount_paid numeric)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not dtf_is_staff_admin() then raise exception 'Réservé au gérant'; end if;
  perform dtf_require_shift();
  update dtf_orders set status = 'delivered', amount_paid = p_amount_paid where id = p_order and status in ('shipped', 'ready_pickup', 'printed');
  if not found then raise exception 'Statut incompatible'; end if;
end $$;

-- =====================================================================
-- 4. CHAT CLIENT ↔ ATELIER
-- =====================================================================
create table dtf_messages (
  id             bigint generated always as identity primary key,
  client_id      uuid not null references dtf_profiles(id) on delete cascade,  -- clé de la conversation
  sender_id      uuid not null references dtf_profiles(id),
  from_staff     boolean not null,
  order_id       uuid references dtf_orders(id) on delete set null,
  body           text not null check (length(body) between 1 and 2000),
  read_by_client boolean not null default false,
  read_by_staff  boolean not null default false,
  created_at     timestamptz not null default now()
);
create index on dtf_messages (client_id, created_at);
create index on dtf_messages (sender_id);
create index on dtf_messages (order_id);
alter table dtf_messages enable row level security;

create policy "dtf chat lecture" on dtf_messages for select to authenticated
  using (client_id = (select auth.uid()) or dtf_is_staff_admin());
create policy "dtf chat client envoie" on dtf_messages for insert to authenticated
  with check (client_id = (select auth.uid()) and sender_id = (select auth.uid()) and not from_staff
              and (order_id is null or exists (select 1 from dtf_orders o where o.id = order_id and o.client_id = (select auth.uid()))));
create policy "dtf chat atelier envoie" on dtf_messages for insert to authenticated
  with check (dtf_is_staff_admin() and sender_id = (select auth.uid()) and from_staff);

-- L'expéditeur a lu son propre message ; l'autre côté non.
create or replace function dtf_message_flags() returns trigger
language plpgsql set search_path = public as $$
begin
  new.read_by_client := not new.from_staff;
  new.read_by_staff := new.from_staff;
  new.created_at := now();
  return new;
end $$;
create trigger dtf_messages_flags before insert on dtf_messages for each row execute function dtf_message_flags();

create or replace function dtf_chat_mark_read(p_client uuid default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if dtf_my_role() = 'client' then
    update dtf_messages set read_by_client = true where client_id = auth.uid() and not read_by_client;
  elsif dtf_is_staff_admin() then
    update dtf_messages set read_by_staff = true where client_id = p_client and not read_by_staff;
  end if;
end $$;

-- Réponse de l'atelier → notification au client.
create or replace function dtf_on_message() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.from_staff then
    insert into dtf_notifications (user_id, order_id, title, body)
    values (new.client_id, new.order_id, 'رسالة جديدة من الورشة', left(new.body, 120));
  end if;
  return null;
end $$;
create trigger dtf_messages_notify after insert on dtf_messages for each row execute function dtf_on_message();

-- Liste des conversations pour l'atelier.
create or replace view dtf_conversations with (security_invoker = true) as
select m.client_id, p.full_name, p.phone, p.wilaya,
       max(m.created_at) as last_at,
       (array_agg(m.body order by m.created_at desc))[1] as last_body,
       count(*) filter (where not m.from_staff and not m.read_by_staff) as unread
from dtf_messages m join dtf_profiles p on p.id = m.client_id
group by m.client_id, p.full_name, p.phone, p.wilaya;

-- =====================================================================
-- 5. STATISTIQUES DU PERSONNEL (mesures brutes, score calculé côté site)
-- =====================================================================
create or replace function dtf_staff_stats(p_from date, p_to date)
returns table (
  user_id uuid, full_name text, role dtf_role, active boolean,
  orders_done int, meters numeric, avg_minutes numeric, issues int,
  days_worked int, hours_worked numeric, late_days int, forgot_out int
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not dtf_is_staff_admin() then raise exception 'Réservé à l''administration'; end if;
  return query
  with ev as (
    select e.order_id, e.to_status, min(e.created_at) as at
    from dtf_order_events e
    where e.created_at >= p_from and e.created_at < p_to + 1
    group by e.order_id, e.to_status
  ),
  design as (
    select o.designer_id as uid, count(*)::int as n, sum(o.billed_meters) as m,
           avg(extract(epoch from (b.at - a.at)) / 60) as mins
    from dtf_orders o join ev a on a.order_id = o.id and a.to_status = 'in_design'
                      join ev b on b.order_id = o.id and b.to_status = 'ready_to_print'
    group by o.designer_id
  ),
  print as (
    select o.printer_id as uid, count(*)::int as n, sum(o.billed_meters) as m,
           avg(extract(epoch from (b.at - a.at)) / 60) as mins
    from dtf_orders o join ev a on a.order_id = o.id and a.to_status = 'printing'
                      join ev b on b.order_id = o.id and b.to_status in ('printed', 'ready_pickup')
    group by o.printer_id
  ),
  manage as (
    select o.manager_id as uid, count(*)::int as n, sum(o.billed_meters) as m,
           avg(extract(epoch from (b.at - o.created_at)) / 60) as mins
    from dtf_orders o join ev b on b.order_id = o.id and b.to_status in ('in_design', 'rejected')
    group by o.manager_id
  ),
  iss as (
    select x.uid, count(*)::int as n from (
      select designer_id as uid from dtf_issues where created_at >= p_from and created_at < p_to + 1
      union all
      select printer_id from dtf_issues where created_at >= p_from and created_at < p_to + 1
    ) x where x.uid is not null group by x.uid
  ),
  att as (
    select a.user_id as uid, count(distinct a.work_date)::int as d,
           sum(extract(epoch from (coalesce(a.clock_out, now()) - a.clock_in)) / 3600) as h,
           count(*) filter (where (a.clock_in at time zone 'Africa/Algiers')::time > time '08:15')::int as late,
           count(*) filter (where a.auto_closed)::int as forgot
    from dtf_attendance a where a.work_date between p_from and p_to group by a.user_id
  )
  select pr.id, pr.full_name, pr.role, pr.active,
         coalesce(case pr.role when 'designer' then d.n when 'printer' then pt.n else mg.n end, 0),
         coalesce(case pr.role when 'designer' then d.m when 'printer' then pt.m else mg.m end, 0),
         round(coalesce(case pr.role when 'designer' then d.mins when 'printer' then pt.mins else mg.mins end, 0)::numeric, 1),
         coalesce(i.n, 0), coalesce(at.d, 0), round(coalesce(at.h, 0)::numeric, 1),
         coalesce(at.late, 0), coalesce(at.forgot, 0)
  from dtf_profiles pr
  left join design d on d.uid = pr.id
  left join print pt on pt.uid = pr.id
  left join manage mg on mg.uid = pr.id
  left join iss i on i.uid = pr.id
  left join att at on at.uid = pr.id
  where pr.role in ('manager', 'designer', 'printer');
end $$;

-- ---------- Droits d'exécution ----------
revoke execute on function dtf_close_forgotten(), dtf_open_shift(uuid), dtf_check_pin(text),
  dtf_consume_film(numeric, dtf_move_kind, uuid, text), dtf_on_message(), dtf_message_flags() from public, anon, authenticated;
revoke execute on function dtf_today(), dtf_require_shift(), dtf_pin_status(), dtf_pin_set(text, text),
  dtf_pin_reset(uuid), dtf_clock_in(text), dtf_clock_out(text), dtf_add_rolls(int, numeric, numeric, text, text),
  dtf_activate_roll(uuid), dtf_record_waste(numeric, text), dtf_chat_mark_read(uuid),
  dtf_staff_stats(date, date), dtf_assign_designer(uuid, uuid), dtf_reject_order(uuid, text),
  dtf_design_done(uuid, numeric, uuid), dtf_start_printing(uuid), dtf_finish_printing(uuid),
  dtf_mark_shipped(uuid, text, text), dtf_mark_delivered(uuid, numeric) from public, anon;

-- ---------- Temps réel ----------
alter publication supabase_realtime add table dtf_messages, dtf_rolls, dtf_attendance;
