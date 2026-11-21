create table if not exists public.broderie_production_lots (
  id uuid primary key default gen_random_uuid(),
  atelier_id uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  production_id uuid not null references public.broderie_production(id) on delete cascade,
  lot_id uuid not null references public.broderie_lots(id) on delete cascade,
  pieces int not null default 0 check (pieces >= 0),
  unique (production_id, lot_id)
);
create index if not exists bpl_lot_idx on public.broderie_production_lots(lot_id);
create index if not exists bpl_prod_idx on public.broderie_production_lots(production_id);
alter table public.broderie_production_lots enable row level security;
select public._atelier_policies('broderie_production_lots', array['broderie','paie'], 'broderie');
insert into public.broderie_production_lots(atelier_id, production_id, lot_id, pieces)
select p.atelier_id, p.id, p.lot_id, coalesce(p.nb_robes, 0) from public.broderie_production p
where p.lot_id is not null on conflict (production_id, lot_id) do nothing;
