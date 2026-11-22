-- Phase 2 : couture externe (ateliers, tarifs par modèle, envois, retours, paiements)
create table if not exists public.couture_ateliers (
  id uuid primary key default gen_random_uuid(),
  atelier_id uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  nom text not null check (length(trim(nom)) > 0),
  telephone text, adresse text, note text,
  actif boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.couture_tarifs (
  id uuid primary key default gen_random_uuid(),
  atelier_id uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  modele text not null check (length(trim(modele)) > 0),
  prix numeric(12,2) not null default 0 check (prix >= 0),
  created_at timestamptz not null default now(),
  unique (atelier_id, modele)
);
create table if not exists public.couture_envois (
  id uuid primary key default gen_random_uuid(),
  atelier_id uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  lot_id uuid not null references public.broderie_lots(id) on delete cascade,
  couturier_id uuid not null references public.couture_ateliers(id) on delete restrict,
  pieces int not null check (pieces > 0),
  prix numeric(12,2) not null default 0 check (prix >= 0),
  date_envoi date not null default current_date,
  note text,
  user_id uuid default auth.uid(), created_at timestamptz not null default now()
);
create index if not exists couture_envois_lot_idx on public.couture_envois(lot_id);
create index if not exists couture_envois_couturier_idx on public.couture_envois(couturier_id, date_envoi);
create table if not exists public.couture_retours (
  id uuid primary key default gen_random_uuid(),
  atelier_id uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  envoi_id uuid not null references public.couture_envois(id) on delete cascade,
  date_retour date not null default current_date,
  bonnes int not null default 0 check (bonnes >= 0),
  retouche int not null default 0 check (retouche >= 0),
  abimees int not null default 0 check (abimees >= 0),
  note text,
  user_id uuid default auth.uid(), created_at timestamptz not null default now()
);
create index if not exists couture_retours_envoi_idx on public.couture_retours(envoi_id);
create table if not exists public.couture_paiements (
  id uuid primary key default gen_random_uuid(),
  atelier_id uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  couturier_id uuid not null references public.couture_ateliers(id) on delete restrict,
  date_paie date not null default current_date,
  montant numeric(12,2) not null check (montant > 0),
  note text,
  user_id uuid default auth.uid(), created_at timestamptz not null default now()
);
create index if not exists couture_paiements_couturier_idx on public.couture_paiements(couturier_id, date_paie);

do $$
declare t text;
begin
  foreach t in array array['couture_ateliers','couture_tarifs','couture_envois','couture_retours','couture_paiements'] loop
    execute format('alter table public.%I enable row level security', t);
    perform public._atelier_policies(t, array['broderie','paie','stock'], case when t = 'couture_paiements' then 'paie' else 'broderie' end);
    execute format('drop trigger if exists journal on public.%I', t);
    execute format('create trigger journal after insert or update or delete on public.%I for each row execute function public.journal_enregistrer()', t);
  end loop;
end $$;
