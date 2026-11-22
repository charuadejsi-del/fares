-- Paiement des ateliers de couture par nombre de pièces (lié à un envoi)
alter table public.couture_paiements
  add column if not exists envoi_id uuid references public.couture_envois(id) on delete set null,
  add column if not exists pieces int check (pieces is null or pieces > 0);
create index if not exists couture_paiements_envoi_idx on public.couture_paiements(envoi_id);
