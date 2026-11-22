-- Phase 3 : travail des ateliers internes relié aux paquets, dentelle, entrée en stock
alter table public.broderie_pieces add column if not exists lot_id uuid references public.broderie_lots(id) on delete set null;
create index if not exists broderie_pieces_lot_idx on public.broderie_pieces(lot_id);
alter table public.broderie_lots
  add column if not exists dentelle boolean not null default false,
  add column if not exists pieces_stock int check (pieces_stock is null or pieces_stock >= 0),
  add column if not exists date_stock date;
-- tâches par défaut des nouveaux ateliers (si absentes)
insert into public.travail_taches(atelier_id, nom, departement, prix, ordre, actif)
select a.id, t.nom, t.dep, 0, t.ordre, true
from public.ateliers a
cross join (values ('Montage appliqué','Finition',20), ('Appliqué','Appliqué',21), ('Akkach (presse)','Akkach',22)) as t(nom, dep, ordre)
where not exists (select 1 from public.travail_taches x where x.atelier_id = a.id and lower(x.nom) = lower(t.nom) and lower(x.departement) = lower(t.dep));
