create table if not exists public.broderie_lots (
  id uuid primary key default gen_random_uuid(),
  atelier_id uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  numero text not null check (length(trim(numero)) > 0),
  nb_pieces int not null check (nb_pieces > 0),
  dessin_id uuid references public.broderie_dessins(id) on delete set null,
  machine_id uuid references public.broderie_machines(id) on delete set null,
  fil text, note text, date_livraison date,
  user_id uuid default auth.uid(), created_at timestamptz not null default now()
);
create index if not exists broderie_lots_atelier_idx on public.broderie_lots(atelier_id, created_at desc);
alter table public.broderie_lots enable row level security;
select public._atelier_policies('broderie_lots', array['broderie','paie'], 'broderie');
alter table public.broderie_production add column if not exists lot_id uuid references public.broderie_lots(id) on delete set null;
create index if not exists broderie_production_lot_idx on public.broderie_production(lot_id);
drop trigger if exists journal on public.broderie_lots;
create trigger journal after insert or update or delete on public.broderie_lots for each row execute function public.journal_enregistrer();
