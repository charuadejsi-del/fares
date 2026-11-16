-- =====================================================================
-- v10 : tâches & tarifs pour les ouvriers hors broderie (pièce, mois, extra)
-- =====================================================================
create table if not exists public.travail_taches (
  id          uuid primary key default gen_random_uuid(),
  atelier_id  uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  nom         text not null check (length(trim(nom)) > 0),
  departement text not null default 'Couture',
  prix        numeric(12,2) not null default 0 check (prix >= 0),
  ordre       int not null default 0,
  actif       boolean not null default true,
  created_at  timestamptz not null default now()
);
create index if not exists travail_taches_atelier_idx on public.travail_taches(atelier_id);
alter table public.travail_taches enable row level security;
select public._atelier_policies('travail_taches', array['broderie','paie'], 'paie');

alter table public.broderie_pieces add column if not exists tache_id uuid references public.travail_taches(id) on delete set null;
create index if not exists broderie_pieces_tache_idx on public.broderie_pieces(tache_id);

drop trigger if exists journal on public.travail_taches;
create trigger journal after insert or update or delete on public.travail_taches
  for each row execute function public.journal_enregistrer();
