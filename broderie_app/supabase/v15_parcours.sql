alter table public.broderie_lots
  add column if not exists etape text not null default 'broderie'
    check (etape in ('coupe','broderie','applique','akkach','dentelle','couture','finition','stock')),
  add column if not exists parcours text[] not null default array['broderie','couture','finition'],
  add column if not exists modele text,
  add column if not exists couleur text,
  add column if not exists date_coupe date;
update public.broderie_lots set etape = 'couture' where date_livraison is not null and etape = 'broderie';
create table if not exists public.lot_mouvements (
  id uuid primary key default gen_random_uuid(),
  atelier_id uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  lot_id uuid not null references public.broderie_lots(id) on delete cascade,
  de text not null, vers text not null,
  pieces int not null default 0 check (pieces >= 0),
  date_mvt date not null default current_date, note text,
  user_id uuid default auth.uid(), created_at timestamptz not null default now()
);
create index if not exists lot_mouvements_lot_idx on public.lot_mouvements(lot_id, created_at);
alter table public.lot_mouvements enable row level security;
select public._atelier_policies('lot_mouvements', array['broderie','paie','stock'], 'broderie');
drop trigger if exists journal on public.lot_mouvements;
create trigger journal after insert or update or delete on public.lot_mouvements for each row execute function public.journal_enregistrer();
insert into public.lot_mouvements(atelier_id, lot_id, de, vers, pieces, date_mvt)
select l.atelier_id, l.id, 'broderie', 'couture', l.nb_pieces, l.date_livraison from public.broderie_lots l
where l.date_livraison is not null and not exists (select 1 from public.lot_mouvements m where m.lot_id = l.id);
