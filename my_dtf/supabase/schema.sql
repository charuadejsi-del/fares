-- =====================================================================
-- My DTF — schéma Supabase (phase 1) — installé sur le projet de l'atelier le 2026-11-27
-- Tables préfixées dtf_ pour cohabiter avec d'autres projets.
-- Rôles : client, admin, manager (gérant), designer, printer.
-- Le token du transporteur (DHD / Ecotrack) n'est JAMAIS stocké ici :
-- il vit dans les secrets d'une Edge Function (phase 5).
-- =====================================================================

-- ---------- Types ----------
create type dtf_role as enum ('client', 'admin', 'manager', 'designer', 'printer');

create type dtf_order_status as enum (
  'new',            -- confirmée par le client
  'rejected',       -- refusée par le gérant
  'in_design',      -- chez le designer
  'ready_to_print', -- envoyée à l'imprimeur
  'printing',       -- impression en cours
  'printed',        -- impression terminée
  'ready_pickup',   -- prête à retirer à l'atelier
  'shipped',        -- remise au transporteur
  'delivered',      -- livrée / retirée
  'cancelled'
);

create type dtf_delivery_mode as enum ('home', 'stopdesk', 'pickup');

-- ---------- Profils ----------
create table dtf_profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        dtf_role not null default 'client',
  full_name   text not null,
  phone       text not null,
  wilaya      text,
  commune     text,
  address     text,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create or replace function dtf_my_role() returns dtf_role
language sql stable security definer set search_path = public as $$
  select role from dtf_profiles where id = auth.uid() and active
$$;

create or replace function dtf_is_staff_admin() returns boolean
language sql stable set search_path = public as $$
  select coalesce(dtf_my_role() in ('admin', 'manager'), false)
$$;

-- Un utilisateur ne peut pas changer son propre rôle (seul l'admin peut).
create or replace function dtf_guard_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role and coalesce(dtf_my_role() <> 'admin', true) then
    raise exception 'Seul l''administrateur peut changer un rôle';
  end if;
  return new;
end $$;

create trigger dtf_profiles_guard_role
before update on dtf_profiles for each row execute function dtf_guard_role();

-- ---------- Paramètres (une seule ligne, modifiée par l'admin) ----------
create table dtf_settings (
  id                    int primary key default 1 check (id = 1),
  price_per_meter       numeric(10,2) not null default 0,
  min_order_amount      numeric(10,2) not null default 0,
  meter_rounding_step   numeric(4,2)  not null default 0.10,
  film_width_cm         numeric(5,2)  not null default 58,
  gap_cm                numeric(4,2)  not null default 0.3,
  allow_rotation        boolean       not null default true,
  workshop_name         text          not null default 'My DTF',
  workshop_phone        text,
  workshop_address      text,
  updated_at            timestamptz   not null default now()
);
insert into dtf_settings (id) values (1);

-- ---------- Commandes ----------
create table dtf_orders (
  id                   uuid primary key default gen_random_uuid(),
  code                 bigint generated always as identity unique, -- n° affiché (#1024)
  client_id            uuid not null references dtf_profiles(id),
  status               dtf_order_status not null default 'new',

  estimated_length_cm  numeric(8,2) not null,   -- calcul automatique (app client)
  final_length_cm      numeric(8,2),            -- saisi par le designer
  price_per_meter      numeric(10,2) not null,  -- figé au moment de la commande
  billed_meters        numeric(8,3) not null,
  print_amount         numeric(10,2) not null,

  delivery_mode        dtf_delivery_mode not null,
  delivery_fee         numeric(10,2) not null default 0,
  ship_name            text,
  ship_phone           text,
  ship_wilaya          text,
  ship_commune         text,
  ship_address         text,
  carrier              text,                     -- 'dhd', ...
  tracking_number      text,

  manager_id           uuid references dtf_profiles(id),
  designer_id          uuid references dtf_profiles(id),
  printer_id           uuid references dtf_profiles(id),

  amount_paid          numeric(10,2) not null default 0,
  client_note          text,
  reject_reason        text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index on dtf_orders (client_id);
create index on dtf_orders (status);
create index on dtf_orders (designer_id);
create index on dtf_orders (printer_id);
create index on dtf_orders (manager_id);

-- Images de la commande (fichiers dans le bucket « dtf-images »)
create table dtf_order_images (
  id            uuid primary key default gen_random_uuid(),
  order_id      uuid not null references dtf_orders(id) on delete cascade,
  storage_path  text not null,      -- <client_id>/<order_id>/<fichier>
  width_cm      numeric(6,2) not null check (width_cm > 0),
  height_cm     numeric(6,2) not null check (height_cm > 0),
  quantity      int not null check (quantity > 0),
  created_at    timestamptz not null default now()
);
create index on dtf_order_images (order_id);

-- Journal : qui a fait quoi et quand (traçabilité)
create table dtf_order_events (
  id          bigint generated always as identity primary key,
  order_id    uuid not null references dtf_orders(id) on delete cascade,
  actor_id    uuid references dtf_profiles(id),
  from_status dtf_order_status,
  to_status   dtf_order_status,
  note        text,
  created_at  timestamptz not null default now()
);
create index on dtf_order_events (order_id);
create index on dtf_order_events (actor_id);

-- Problèmes d'impression, rattachés au designer et à l'imprimeur
create table dtf_issues (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references dtf_orders(id) on delete cascade,
  reported_by  uuid references dtf_profiles(id),
  designer_id  uuid references dtf_profiles(id),
  printer_id   uuid references dtf_profiles(id),
  description  text not null,
  resolved     boolean not null default false,
  created_at   timestamptz not null default now()
);
create index on dtf_issues (order_id);
create index on dtf_issues (designer_id);
create index on dtf_issues (printer_id);
create index on dtf_issues (reported_by);

-- Notifications (client et personnel)
create table dtf_notifications (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references dtf_profiles(id) on delete cascade,
  order_id    uuid references dtf_orders(id) on delete cascade,
  title       text not null,
  body        text,
  read        boolean not null default false,
  created_at  timestamptz not null default now()
);
create index on dtf_notifications (user_id, read);
create index on dtf_notifications (order_id);

-- ---------- Calcul du prix côté serveur ----------
create or replace function dtf_price(p_length_cm numeric)
returns table (billed_meters numeric, print_amount numeric, price_per_meter numeric)
language plpgsql stable set search_path = public as $$
declare s dtf_settings;
declare m numeric;
begin
  select * into s from dtf_settings where id = 1;
  m := p_length_cm / 100;
  if s.meter_rounding_step > 0 then
    m := ceil(m / s.meter_rounding_step - 1e-9) * s.meter_rounding_step;
  end if;
  return query select round(m, 3),
    round(greatest(m * s.price_per_meter, s.min_order_amount)),
    s.price_per_meter;
end $$;

-- ---------- Journal automatique + notification au client ----------
create or replace function dtf_status_label(s dtf_order_status) returns text
language sql immutable set search_path = public as $$
  select case s
    when 'new' then 'طلبيتك مستلمة'
    when 'rejected' then 'طلبيتك مرفوضة'
    when 'in_design' then 'طلبيتك في التصميم'
    when 'ready_to_print' then 'طلبيتك تنتظر الطباعة'
    when 'printing' then 'طلبيتك في الطباعة'
    when 'printed' then 'انتهت طباعة طلبيتك'
    when 'ready_pickup' then 'طلبيتك جاهزة للاستلام من الورشة'
    when 'shipped' then 'طلبيتك عند شركة التوصيل'
    when 'delivered' then 'تم تسليم طلبيتك'
    when 'cancelled' then 'طلبيتك ملغاة'
  end
$$;

create or replace function dtf_touch_order() returns trigger
language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger dtf_orders_touch
before update on dtf_orders for each row execute function dtf_touch_order();

-- AFTER : la ligne existe déjà, les clés étrangères du journal sont valides
create or replace function dtf_on_order_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into dtf_order_events (order_id, actor_id, to_status, note)
    values (new.id, auth.uid(), new.status, 'création');
    return null;
  end if;
  if new.status is distinct from old.status then
    insert into dtf_order_events (order_id, actor_id, from_status, to_status)
    values (new.id, auth.uid(), old.status, new.status);
    insert into dtf_notifications (user_id, order_id, title)
    values (new.client_id, new.id, '#' || new.code || ' — ' || dtf_status_label(new.status));
  end if;
  if new.print_amount is distinct from old.print_amount then
    insert into dtf_notifications (user_id, order_id, title, body)
    values (new.client_id, new.id, '#' || new.code || ' — تم تحديث السعر',
            'الأمتار الحقيقية: ' || new.billed_meters || ' م — السعر: ' || new.print_amount || ' دج');
  end if;
  return null;
end $$;

create trigger dtf_orders_change
after insert or update on dtf_orders for each row execute function dtf_on_order_change();

-- ---------- Actions métier (RPC) : seul chemin pour changer un statut ----------

-- Client : créer une commande (le prix est recalculé ici, pas dans l'app)
create or replace function dtf_create_order(
  p_estimated_length_cm numeric,
  p_delivery_mode dtf_delivery_mode,
  p_delivery_fee numeric,
  p_ship_name text, p_ship_phone text, p_ship_wilaya text,
  p_ship_commune text, p_ship_address text, p_note text
) returns dtf_orders
language plpgsql security definer set search_path = public as $$
declare p record; o dtf_orders;
begin
  if dtf_my_role() is distinct from 'client' then raise exception 'Compte client requis'; end if;
  select * into p from dtf_price(p_estimated_length_cm);
  insert into dtf_orders (client_id, estimated_length_cm, price_per_meter, billed_meters,
    print_amount, delivery_mode, delivery_fee, ship_name, ship_phone, ship_wilaya,
    ship_commune, ship_address, client_note)
  values (auth.uid(), p_estimated_length_cm, p.price_per_meter, p.billed_meters,
    p.print_amount, p_delivery_mode,
    case when p_delivery_mode = 'pickup' then 0 else coalesce(p_delivery_fee, 0) end,
    p_ship_name, p_ship_phone, p_ship_wilaya, p_ship_commune, p_ship_address, p_note)
  returning * into o;
  return o;
end $$;

-- Gérant : accepter et confier à un designer / refuser
create or replace function dtf_assign_designer(p_order uuid, p_designer uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not dtf_is_staff_admin() then raise exception 'Réservé au gérant'; end if;
  if (select role from dtf_profiles where id = p_designer) is distinct from 'designer' then
    raise exception 'Cet utilisateur n''est pas designer'; end if;
  update dtf_orders set status = 'in_design', designer_id = p_designer, manager_id = auth.uid()
  where id = p_order and status in ('new', 'in_design');
  if not found then raise exception 'Commande introuvable ou déjà avancée'; end if;
end $$;

create or replace function dtf_reject_order(p_order uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not dtf_is_staff_admin() then raise exception 'Réservé au gérant'; end if;
  update dtf_orders set status = 'rejected', reject_reason = p_reason, manager_id = auth.uid()
  where id = p_order and status = 'new';
  if not found then raise exception 'Commande introuvable ou déjà traitée'; end if;
end $$;

-- Designer : saisir le métrage réel (prix recalculé, client notifié) et passer à l'imprimeur
create or replace function dtf_design_done(p_order uuid, p_final_length_cm numeric, p_printer uuid)
returns void language plpgsql security definer set search_path = public as $$
declare p record;
begin
  if (select role from dtf_profiles where id = p_printer) is distinct from 'printer' then
    raise exception 'Cet utilisateur n''est pas imprimeur'; end if;
  select * into p from dtf_price(p_final_length_cm);
  update dtf_orders set final_length_cm = p_final_length_cm, billed_meters = p.billed_meters,
    print_amount = p.print_amount, printer_id = p_printer, status = 'ready_to_print'
  where id = p_order and status = 'in_design'
    and (designer_id = auth.uid() or dtf_is_staff_admin());
  if not found then raise exception 'Commande non attribuée à vous ou pas en design'; end if;
end $$;

-- Imprimeur : démarrer / terminer
create or replace function dtf_start_printing(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update dtf_orders set status = 'printing'
  where id = p_order and status = 'ready_to_print'
    and (printer_id = auth.uid() or dtf_is_staff_admin());
  if not found then raise exception 'Commande non attribuée à vous ou pas prête'; end if;
end $$;

create or replace function dtf_finish_printing(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update dtf_orders
  set status = case when delivery_mode = 'pickup' then 'ready_pickup'::dtf_order_status
                    else 'printed'::dtf_order_status end
  where id = p_order and status = 'printing'
    and (printer_id = auth.uid() or dtf_is_staff_admin());
  if not found then raise exception 'Commande non attribuée à vous ou pas en impression'; end if;
end $$;

-- Gérant : remise au transporteur (appelée par l'Edge Function en phase 5) / livrée
create or replace function dtf_mark_shipped(p_order uuid, p_carrier text, p_tracking text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not dtf_is_staff_admin() then raise exception 'Réservé au gérant'; end if;
  update dtf_orders set status = 'shipped', carrier = p_carrier, tracking_number = p_tracking
  where id = p_order and status = 'printed';
  if not found then raise exception 'Commande pas encore imprimée'; end if;
end $$;

create or replace function dtf_mark_delivered(p_order uuid, p_amount_paid numeric)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not dtf_is_staff_admin() then raise exception 'Réservé au gérant'; end if;
  update dtf_orders set status = 'delivered', amount_paid = p_amount_paid
  where id = p_order and status in ('shipped', 'ready_pickup', 'printed');
  if not found then raise exception 'Statut incompatible'; end if;
end $$;

-- Signaler un problème : designer et imprimeur rattachés automatiquement
create or replace function dtf_report_issue(p_order uuid, p_description text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if dtf_my_role() is null then raise exception 'Non connecté'; end if;
  insert into dtf_issues (order_id, reported_by, designer_id, printer_id, description)
  select id, auth.uid(), designer_id, printer_id, p_description
  from dtf_orders where id = p_order
    and (client_id = auth.uid() or dtf_my_role() <> 'client');
  if not found then raise exception 'Commande introuvable'; end if;
end $$;

-- Fonctions internes : pas d'appel direct depuis l'API ; RPC réservées aux connectés
revoke execute on function dtf_guard_role(), dtf_touch_order(), dtf_on_order_change() from public, anon, authenticated;
revoke execute on function dtf_my_role(), dtf_is_staff_admin(), dtf_price(numeric),
  dtf_create_order(numeric, dtf_delivery_mode, numeric, text, text, text, text, text, text),
  dtf_assign_designer(uuid, uuid), dtf_reject_order(uuid, text), dtf_design_done(uuid, numeric, uuid),
  dtf_start_printing(uuid), dtf_finish_printing(uuid), dtf_mark_shipped(uuid, text, text),
  dtf_mark_delivered(uuid, numeric), dtf_report_issue(uuid, text) from public, anon;

-- Statistiques problèmes par personne (lecture admin/gérant)
create or replace view dtf_issue_stats with (security_invoker = true) as
select pr.id, pr.full_name, pr.role,
       count(i.*) filter (where not i.resolved) as open_issues,
       count(i.*) as total_issues
from dtf_profiles pr
left join dtf_issues i on i.designer_id = pr.id or i.printer_id = pr.id
where pr.role in ('designer', 'printer')
group by pr.id;

-- ---------- Sécurité (RLS) ----------
alter table dtf_profiles       enable row level security;
alter table dtf_settings       enable row level security;
alter table dtf_orders         enable row level security;
alter table dtf_order_images   enable row level security;
alter table dtf_order_events   enable row level security;
alter table dtf_issues         enable row level security;
alter table dtf_notifications  enable row level security;

-- Profils
create policy "profil: lire le sien ou personnel" on dtf_profiles for select to authenticated
  using (id = (select auth.uid()) or coalesce(dtf_my_role() <> 'client', false));
create policy "profil: inscription client" on dtf_profiles for insert to authenticated
  with check (id = (select auth.uid()) and role = 'client');
create policy "profil: modifier le sien" on dtf_profiles for update to authenticated
  using (id = (select auth.uid()) or dtf_my_role() = 'admin');

-- Paramètres : lecture pour tous les connectés, écriture admin
create policy "settings: lecture" on dtf_settings for select to authenticated
 using (true);
create policy "settings: admin" on dtf_settings for update to authenticated
 using (dtf_my_role() = 'admin');

-- Commandes : lecture selon le rôle ; écriture uniquement via les RPC ci-dessus
create policy "commandes: lecture" on dtf_orders for select to authenticated
 using (
  client_id = (select auth.uid())
  or dtf_is_staff_admin()
  or (dtf_my_role() = 'designer' and designer_id = (select auth.uid()))
  or (dtf_my_role() = 'printer'  and printer_id  = (select auth.uid()))
);

-- Images : visibles par ceux qui voient la commande ; ajout par le client propriétaire
create policy "images: lecture" on dtf_order_images for select to authenticated
  using (exists (select 1 from dtf_orders o where o.id = order_id));
create policy "images: ajout client" on dtf_order_images for insert to authenticated
  with check (exists (select 1 from dtf_orders o
                      where o.id = order_id and o.client_id = (select auth.uid()) and o.status = 'new'));

create policy "journal: lecture" on dtf_order_events for select to authenticated
  using (exists (select 1 from dtf_orders o where o.id = order_id));

create policy "problèmes: lecture" on dtf_issues for select to authenticated
  using (dtf_is_staff_admin() or designer_id = (select auth.uid()) or printer_id = (select auth.uid())
         or reported_by = (select auth.uid()));
create policy "problèmes: résoudre" on dtf_issues for update to authenticated
 using (dtf_is_staff_admin());

create policy "notifs: les miennes" on dtf_notifications for select to authenticated
 using (user_id = (select auth.uid()));
create policy "notifs: marquer lues" on dtf_notifications for update to authenticated
 using (user_id = (select auth.uid()));

-- ---------- Stockage des images ----------
insert into storage.buckets (id, name, public) values ('dtf-images', 'dtf-images', false)
on conflict (id) do nothing;

create policy "dtf-images: envoi client" on storage.objects for insert to authenticated
  with check (bucket_id = 'dtf-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "dtf-images: lecture" on storage.objects for select to authenticated
  using (bucket_id = 'dtf-images' and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or coalesce(dtf_my_role() <> 'client', false)));

-- ---------- Temps réel (suivi de statut en direct) ----------
alter publication supabase_realtime add table dtf_orders, dtf_notifications;
