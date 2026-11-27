-- My DTF — 008 : stock encre/poudre, prix de gros, notes des clients.

-- ===================== 1. Encre et poudre =====================
create table if not exists dtf_supplies (
  kind       text primary key check (kind in ('ink', 'powder')),
  stock      numeric(14,2) not null default 0,     -- ml pour l'encre, g pour la poudre
  alert      numeric(14,2) not null,               -- seuil d'alerte (même unité)
  avg_price  numeric(12,2) not null default 0,     -- prix moyen par litre / par kilo
  alerted    boolean not null default false,
  updated_at timestamptz not null default now()
);
insert into dtf_supplies (kind, alert, avg_price) values ('ink', 1000, 9000), ('powder', 2000, 3500) on conflict do nothing;

create table if not exists dtf_supply_moves (
  id         bigint generated always as identity primary key,
  kind       text not null references dtf_supplies(kind),
  move       text not null check (move in ('purchase', 'print', 'waste', 'adjust')),
  qty        numeric(14,2) not null,               -- + entrée / − sortie
  total_price numeric(12,2),
  supplier   text,
  note       text,
  order_id   uuid references dtf_orders(id),
  actor_id   uuid references dtf_profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists dtf_supply_moves_kind_idx on dtf_supply_moves (kind, created_at);
create index if not exists dtf_supply_moves_order_idx on dtf_supply_moves (order_id);
create index if not exists dtf_supply_moves_actor_idx on dtf_supply_moves (actor_id);

alter table dtf_supplies enable row level security;
alter table dtf_supply_moves enable row level security;
create policy "dtf matieres lecture" on dtf_supplies for select to authenticated using (coalesce(dtf_my_role() <> 'client', false));
create policy "dtf matieres journal" on dtf_supply_moves for select to authenticated using (coalesce(dtf_my_role() <> 'client', false));

-- Mouvement interne : met à jour le stock et prévient sous le seuil.
create or replace function dtf_supply_apply(p_kind text, p_move text, p_qty numeric, p_order uuid, p_note text)
returns void language plpgsql security definer set search_path = public as $$
declare s dtf_supplies; lbl text;
begin
  if p_qty = 0 then return; end if;
  update dtf_supplies set stock = stock + p_qty, updated_at = now() where kind = p_kind returning * into s;
  insert into dtf_supply_moves (kind, move, qty, order_id, note, actor_id) values (p_kind, p_move, p_qty, p_order, p_note, auth.uid());
  if s.stock <= s.alert and not s.alerted then
    update dtf_supplies set alerted = true where kind = p_kind;
    lbl := case p_kind when 'ink' then 'الحبر' else 'البودرة' end;
    insert into dtf_notifications (user_id, title, body)
    select id, lbl || ' قارب على النفاد',
           'بقي ' || case p_kind when 'ink' then round(s.stock / 1000, 2) || ' لتر' else round(s.stock / 1000, 2) || ' كغ' end || ' — سجّل شراءً جديداً'
    from dtf_profiles where role in ('admin', 'manager', 'printer') and active;
  elsif s.stock > s.alert and s.alerted then
    update dtf_supplies set alerted = false where kind = p_kind;
  end if;
end $$;

-- Chaque mètre de film imprimé ou gâché consomme encre et poudre (mêmes mètres que le film).
create or replace function dtf_film_to_supplies() returns trigger
language plpgsql security definer set search_path = public as $$
declare c dtf_cost_settings;
begin
  if new.kind not in ('print', 'waste') or new.meters <= 0 then return new; end if;
  select * into c from dtf_cost_settings where id = 1;
  perform dtf_supply_apply('ink', new.kind::text, -round(new.meters * c.ink_ml_per_m, 2), new.order_id, null);
  perform dtf_supply_apply('powder', new.kind::text, -round(new.meters * c.powder_g_per_m, 2), new.order_id, null);
  return new;
end $$;
drop trigger if exists dtf_film_supplies on dtf_film_moves;
create trigger dtf_film_supplies after insert on dtf_film_moves for each row execute function dtf_film_to_supplies();

-- Achat : quantité en ml / g, prix total. Le prix moyen alimente automatiquement le calcul des coûts.
create or replace function dtf_add_supply(p_kind text, p_qty numeric, p_total numeric, p_supplier text, p_note text)
returns dtf_supplies language plpgsql security definer set search_path = public as $$
declare s dtf_supplies; val numeric; newavg numeric;
begin
  if not dtf_is_staff_admin() then raise exception 'خاص بالمدير والمسيّر'; end if;
  if p_qty is null or p_qty <= 0 or p_total is null or p_total < 0 then raise exception 'الكمية أو السعر غير صحيح'; end if;
  select * into s from dtf_supplies where kind = p_kind for update;
  if s.kind is null then raise exception 'مادة غير معروفة'; end if;
  val := greatest(s.stock, 0) / 1000 * s.avg_price;
  newavg := round((val + p_total) / ((greatest(s.stock, 0) + p_qty) / 1000), 2);
  update dtf_supplies set stock = stock + p_qty, avg_price = newavg, alerted = (stock + p_qty) <= alert, updated_at = now()
  where kind = p_kind returning * into s;
  insert into dtf_supply_moves (kind, move, qty, total_price, supplier, note, actor_id)
  values (p_kind, 'purchase', p_qty, p_total, nullif(trim(p_supplier), ''), nullif(trim(p_note), ''), auth.uid());
  if p_kind = 'ink' then update dtf_cost_settings set ink_price_l = newavg, updated_at = now() where id = 1;
  else update dtf_cost_settings set powder_price_kg = newavg, updated_at = now() where id = 1; end if;
  return s;
end $$;

-- Inventaire : quantité réelle constatée.
create or replace function dtf_adjust_supply(p_kind text, p_real numeric, p_note text)
returns void language plpgsql security definer set search_path = public as $$
declare cur numeric;
begin
  if not dtf_is_staff_admin() then raise exception 'خاص بالمدير والمسيّر'; end if;
  if p_real is null or p_real < 0 then raise exception 'الكمية غير صحيحة'; end if;
  select stock into cur from dtf_supplies where kind = p_kind for update;
  perform dtf_supply_apply(p_kind, 'adjust', round(p_real - cur, 2), null, coalesce(nullif(trim(p_note), ''), 'جرد'));
end $$;

create or replace function dtf_set_supply_alert(p_kind text, p_alert numeric)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not dtf_is_staff_admin() then raise exception 'خاص بالمدير والمسيّر'; end if;
  update dtf_supplies set alert = greatest(p_alert, 0), alerted = stock <= greatest(p_alert, 0) where kind = p_kind;
end $$;

-- ===================== 2. Prix de gros =====================
alter table dtf_settings add column if not exists price_tiers jsonb not null default '[]';   -- [{"min_m":20,"price":1300}]
alter table dtf_profiles add column if not exists special_price numeric(10,2);

create or replace function dtf_price(p_length_cm numeric, p_client uuid)
returns table (billed_meters numeric, print_amount numeric, price_per_meter numeric)
language plpgsql stable security definer set search_path = public as $$
declare s dtf_settings; m numeric; ppm numeric; sp numeric;
begin
  select * into s from dtf_settings where id = 1;
  m := p_length_cm / 100;
  if s.meter_rounding_step > 0 then m := ceil(m / s.meter_rounding_step - 1e-9) * s.meter_rounding_step; end if;
  if p_client is not null and (p_client = auth.uid() or dtf_my_role() <> 'client') then
    select special_price into sp from dtf_profiles where id = p_client;
  end if;
  ppm := coalesce(sp,
    (select (t->>'price')::numeric from jsonb_array_elements(s.price_tiers) t
      where (t->>'min_m')::numeric <= m + 1e-9 order by (t->>'min_m')::numeric desc limit 1),
    s.price_per_meter);
  return query select round(m, 3), round(greatest(m * ppm, s.min_order_amount)), ppm;
end $$;

create or replace function dtf_price(p_length_cm numeric)
returns table (billed_meters numeric, print_amount numeric, price_per_meter numeric)
language sql stable set search_path = public as $$ select * from dtf_price(p_length_cm, null::uuid) $$;

-- Tarifs vus par le client connecté (prix spécial + paliers).
create or replace function dtf_my_price() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('base', s.price_per_meter, 'special', p.special_price, 'tiers', s.price_tiers,
                            'min_order', s.min_order_amount, 'step', s.meter_rounding_step)
  from dtf_settings s left join dtf_profiles p on p.id = auth.uid() where s.id = 1
$$;

create or replace function dtf_set_client_price(p_client uuid, p_price numeric)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not dtf_is_staff_admin() then raise exception 'خاص بالمدير والمسيّر'; end if;
  if p_price is not null and p_price <= 0 then raise exception 'سعر غير صحيح'; end if;
  update dtf_profiles set special_price = p_price where id = p_client and role = 'client';
  if not found then raise exception 'الزبون غير موجود'; end if;
end $$;

create or replace function dtf_create_order(
  p_estimated_length_cm numeric, p_delivery_mode dtf_delivery_mode, p_delivery_fee numeric,
  p_ship_name text, p_ship_phone text, p_ship_wilaya text, p_ship_commune text, p_ship_address text, p_note text
) returns dtf_orders
language plpgsql security definer set search_path = public as $$
declare p record; o dtf_orders;
begin
  if dtf_my_role() is distinct from 'client' then raise exception 'Compte client requis'; end if;
  select * into p from dtf_price(p_estimated_length_cm, auth.uid());
  insert into dtf_orders (client_id, estimated_length_cm, price_per_meter, billed_meters,
    print_amount, delivery_mode, delivery_fee, ship_name, ship_phone, ship_wilaya, ship_commune, ship_address, client_note)
  values (auth.uid(), p_estimated_length_cm, p.price_per_meter, p.billed_meters, p.print_amount, p_delivery_mode,
    case when p_delivery_mode = 'pickup' then 0 else coalesce(p_delivery_fee, 0) end,
    p_ship_name, p_ship_phone, p_ship_wilaya, p_ship_commune, p_ship_address, p_note)
  returning * into o;
  return o;
end $$;

create or replace function dtf_design_done(p_order uuid, p_final_length_cm numeric)
returns void language plpgsql security definer set search_path = public as $$
declare p record; cl uuid;
begin
  perform dtf_require_shift();
  if p_final_length_cm is null or p_final_length_cm <= 0 then raise exception 'أدخل الطول الحقيقي بالسنتيمتر'; end if;
  select client_id into cl from dtf_orders where id = p_order;
  select * into p from dtf_price(p_final_length_cm, cl);
  update dtf_orders set final_length_cm = p_final_length_cm, billed_meters = p.billed_meters,
    print_amount = p.print_amount, price_per_meter = p.price_per_meter, printer_id = null, status = 'ready_to_print'
  where id = p_order and status = 'in_design' and (designer_id = auth.uid() or dtf_is_staff_admin());
  if not found then raise exception 'هذا الملف ليس عندك أو لم يعد في مرحلة التصميم'; end if;
end $$;

-- Données de coûts v2 : + valeur au prix réel de chaque commande (gros / prix spéciaux).
create or replace function dtf_cost_days2(p_from date, p_to date)
returns table (day date, meters numeric, waste_m numeric, revenue numeric, value numeric, orders int)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if dtf_my_role() is distinct from 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  if p_to < p_from or p_to - p_from > 400 then raise exception 'Période invalide'; end if;
  return query
  with o as (
    select (coalesce(o.print_started_at,
                     (select min(e.created_at) from dtf_order_events e where e.order_id = o.id and e.to_status = 'printing'),
                     o.updated_at) at time zone 'Africa/Algiers')::date as d,
           coalesce(o.final_length_cm, o.estimated_length_cm) / 100.0 as m,
           o.price_per_meter as ppm, o.print_amount as a
    from dtf_orders o
    where o.status in ('printing', 'printed', 'ready_pickup', 'shipped', 'delivered')
  ), w as (
    select (f.created_at at time zone 'Africa/Algiers')::date as d, sum(f.meters) as m
    from dtf_film_moves f where f.kind = 'waste' group by 1
  )
  select g::date,
         coalesce((select sum(o.m) from o where o.d = g::date), 0)::numeric,
         coalesce((select w.m from w where w.d = g::date), 0)::numeric,
         coalesce((select sum(o.a) from o where o.d = g::date), 0)::numeric,
         coalesce((select sum(o.m * o.ppm) from o where o.d = g::date), 0)::numeric,
         (select count(*)::int from o where o.d = g::date)
  from generate_series(p_from, p_to, interval '1 day') g
  order by 1;
end $$;

-- ===================== 3. Notes des clients =====================
create table if not exists dtf_ratings (
  order_id   uuid primary key references dtf_orders(id) on delete cascade,
  client_id  uuid not null references dtf_profiles(id),
  stars      int not null check (stars between 1 and 5),
  comment    text,
  created_at timestamptz not null default now()
);
create index if not exists dtf_ratings_client_idx on dtf_ratings (client_id);
alter table dtf_ratings enable row level security;
create policy "dtf notes lecture" on dtf_ratings for select to authenticated using (client_id = auth.uid() or dtf_is_staff_admin());

create or replace function dtf_rate_order(p_order uuid, p_stars int, p_comment text)
returns void language plpgsql security definer set search_path = public as $$
declare o dtf_orders;
begin
  select * into o from dtf_orders where id = p_order;
  if o.id is null or o.client_id is distinct from auth.uid() then raise exception 'الطلبية غير موجودة'; end if;
  if o.status <> 'delivered' then raise exception 'يمكنك التقييم بعد استلام الطلبية'; end if;
  if p_stars is null or p_stars not between 1 and 5 then raise exception 'اختر من 1 إلى 5 نجوم'; end if;
  insert into dtf_ratings (order_id, client_id, stars, comment) values (p_order, auth.uid(), p_stars, nullif(trim(p_comment), ''))
  on conflict (order_id) do update set stars = excluded.stars, comment = excluded.comment, created_at = now();
  if p_stars <= 2 then
    insert into dtf_notifications (user_id, title, body)
    select id, 'تقييم ضعيف للطلبية رقم ' || o.code, p_stars || ' نجمة' || coalesce(' — ' || nullif(trim(p_comment), ''), '')
    from dtf_profiles where role in ('admin', 'manager') and active;
  end if;
end $$;

-- Moyenne des notes par designer / imprimeur sur une période.
create or replace function dtf_staff_ratings(p_from date, p_to date)
returns table (user_id uuid, avg_stars numeric, n int)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not dtf_is_staff_admin() then raise exception 'Réservé à l''administration'; end if;
  return query
  select x.uid, round(avg(x.stars)::numeric, 2), count(*)::int from (
    select o.designer_id as uid, r.stars from dtf_ratings r join dtf_orders o on o.id = r.order_id
      where r.created_at >= p_from and r.created_at < p_to + 1
    union all
    select o.printer_id, r.stars from dtf_ratings r join dtf_orders o on o.id = r.order_id
      where r.created_at >= p_from and r.created_at < p_to + 1
  ) x where x.uid is not null group by x.uid;
end $$;

revoke execute on function dtf_supply_apply(text, text, numeric, uuid, text), dtf_film_to_supplies() from public, anon, authenticated;
revoke execute on function dtf_add_supply(text, numeric, numeric, text, text), dtf_adjust_supply(text, numeric, text),
  dtf_set_supply_alert(text, numeric), dtf_price(numeric, uuid), dtf_my_price(), dtf_set_client_price(uuid, numeric),
  dtf_cost_days2(date, date), dtf_rate_order(uuid, int, text), dtf_staff_ratings(date, date) from public, anon;

alter publication supabase_realtime add table dtf_supplies;
