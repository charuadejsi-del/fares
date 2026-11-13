-- =====================================================================
-- Atelier Broderie — schéma Supabase
-- Chaque compte (auth.users) ne voit et ne modifie que SES données (RLS).
-- =====================================================================

create table if not exists public.broderie_ouvriers (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nom         text not null check (length(trim(nom)) > 0),
  telephone   text,
  tarif_1000  numeric(12,2) not null default 0 check (tarif_1000 >= 0), -- DA pour 1000 points
  actif       boolean not null default true,
  created_at  timestamptz not null default now()
);

create table if not exists public.broderie_dessins (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nom         text not null check (length(trim(nom)) > 0),
  points      integer not null check (points > 0),               -- points par robe
  client      text,
  note        text,
  actif       boolean not null default true,
  created_at  timestamptz not null default now()
);

create table if not exists public.broderie_machines (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nom         text not null check (length(trim(nom)) > 0),
  nb_tetes    integer not null default 1 check (nb_tetes > 0),
  actif       boolean not null default true,
  created_at  timestamptz not null default now()
);

create table if not exists public.broderie_production (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date_prod        date not null default current_date,
  ouvrier_id       uuid not null references public.broderie_ouvriers(id) on delete restrict,
  dessin_id        uuid not null references public.broderie_dessins(id)  on delete restrict,
  machine_id       uuid references public.broderie_machines(id) on delete set null,
  nb_robes         integer not null check (nb_robes > 0),
  points_par_robe  integer not null check (points_par_robe > 0),       -- copie au moment de la saisie
  tarif_1000       numeric(12,2) not null default 0 check (tarif_1000 >= 0), -- copie au moment de la saisie
  total_points     bigint generated always as (nb_robes::bigint * points_par_robe) stored,
  montant          numeric(14,2) generated always as (round(nb_robes::numeric * points_par_robe * tarif_1000 / 1000, 2)) stored,
  note             text,
  created_at       timestamptz not null default now()
);

create index if not exists broderie_ouvriers_user_idx   on public.broderie_ouvriers(user_id);
create index if not exists broderie_dessins_user_idx    on public.broderie_dessins(user_id);
create index if not exists broderie_machines_user_idx   on public.broderie_machines(user_id);
create index if not exists broderie_production_user_date_idx on public.broderie_production(user_id, date_prod desc);
create index if not exists broderie_production_ouvrier_idx on public.broderie_production(ouvrier_id);
create index if not exists broderie_production_dessin_idx  on public.broderie_production(dessin_id);
create index if not exists broderie_production_machine_idx on public.broderie_production(machine_id);

-- Sécurité : RLS, accès limité au propriétaire
alter table public.broderie_ouvriers   enable row level security;
alter table public.broderie_dessins    enable row level security;
alter table public.broderie_machines   enable row level security;
alter table public.broderie_production enable row level security;

do $$
declare t text;
begin
  foreach t in array array['broderie_ouvriers','broderie_dessins','broderie_machines','broderie_production'] loop
    execute format('drop policy if exists %I on public.%I', t || '_owner_all', t);
    execute format(
      'create policy %I on public.%I for all to authenticated
         using ((select auth.uid()) = user_id)
         with check ((select auth.uid()) = user_id)', t || '_owner_all', t);
  end loop;
end $$;

-- Une saisie ne peut référencer que des ouvriers/dessins/machines du même compte
create or replace function public.broderie_check_owner()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not exists (select 1 from public.broderie_ouvriers o where o.id = new.ouvrier_id and o.user_id = new.user_id) then
    raise exception 'Ouvrier invalide';
  end if;
  if not exists (select 1 from public.broderie_dessins d where d.id = new.dessin_id and d.user_id = new.user_id) then
    raise exception 'Dessin invalide';
  end if;
  if new.machine_id is not null and not exists (select 1 from public.broderie_machines m where m.id = new.machine_id and m.user_id = new.user_id) then
    raise exception 'Machine invalide';
  end if;
  return new;
end $$;

drop trigger if exists broderie_production_owner_chk on public.broderie_production;
create trigger broderie_production_owner_chk
  before insert or update on public.broderie_production
  for each row execute function public.broderie_check_owner();

-- =====================================================================
-- v2 : photos des dessins (Supabase Storage, bucket privé, dossier = id du compte)
-- =====================================================================
alter table public.broderie_dessins add column if not exists photo_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('broderie-dessins', 'broderie-dessins', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

create policy "broderie_photos_select" on storage.objects for select to authenticated
  using (bucket_id = 'broderie-dessins' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "broderie_photos_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'broderie-dessins' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "broderie_photos_update" on storage.objects for update to authenticated
  using (bucket_id = 'broderie-dessins' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'broderie-dessins' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "broderie_photos_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'broderie-dessins' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- =====================================================================
-- v3 : relevé du compteur de points, types de broderie (tarif / 1000 pts), équipes jour/nuit
--      montant = points du compteur × tarif du type / 1000
-- =====================================================================
create table if not exists public.broderie_types (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nom text not null check (length(trim(nom)) > 0),
  tarif_1000 numeric(12,2) not null default 0 check (tarif_1000 >= 0),
  ordre integer not null default 0,
  actif boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.broderie_types enable row level security;
create policy broderie_types_owner_all on public.broderie_types for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter table public.broderie_production drop column if exists montant;
alter table public.broderie_production drop column if exists total_points;
alter table public.broderie_production
  add column type_id uuid references public.broderie_types(id) on delete restrict,
  add column equipe text not null default 'jour' check (equipe in ('jour','nuit')),
  add column total_points bigint not null check (total_points > 0),
  alter column nb_robes drop not null,
  alter column points_par_robe drop not null,
  alter column dessin_id drop not null;
alter table public.broderie_production
  add column montant numeric(14,2) generated always as (round(total_points::numeric * tarif_1000 / 1000, 2)) stored;
-- (le trigger broderie_check_owner vérifie aussi type_id ; dessin_id devient facultatif)
