-- =====================================================================
-- v4 : départements, modes de paie (points / mois / pièce), travaux à la pièce,
--      mouvements d'argent (avances, paiements, salaires, primes, retenues), soldes
-- Règle : reste à payer = gains (broderie + pièces + salaires + primes)
--                         − (avances + paiements + retenues)
-- =====================================================================

alter table public.broderie_ouvriers
  add column if not exists departement text not null default 'Broderie',
  add column if not exists mode_paie text not null default 'points',
  add column if not exists salaire_mensuel numeric(12,2) not null default 0,
  add column if not exists prix_piece numeric(12,2) not null default 0;

do $$ begin
  alter table public.broderie_ouvriers add constraint broderie_ouvriers_mode_paie_chk check (mode_paie in ('points','mois','piece'));
  alter table public.broderie_ouvriers add constraint broderie_ouvriers_salaire_chk check (salaire_mensuel >= 0 and prix_piece >= 0);
exception when duplicate_object then null; end $$;

-- Travaux payés à la pièce
create table if not exists public.broderie_pieces (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  ouvrier_id     uuid not null references public.broderie_ouvriers(id) on delete restrict,
  date_travail   date not null default current_date,
  libelle        text not null check (length(trim(libelle)) > 0),
  quantite       numeric(12,2) not null check (quantite > 0),
  prix_unitaire  numeric(12,2) not null check (prix_unitaire >= 0),
  montant        numeric(14,2) generated always as (round(quantite * prix_unitaire, 2)) stored,
  note           text,
  created_at     timestamptz not null default now()
);

-- Mouvements d'argent
create table if not exists public.broderie_mouvements (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  ouvrier_id  uuid not null references public.broderie_ouvriers(id) on delete restrict,
  date_mvt    date not null default current_date,
  type        text not null check (type in ('avance','paiement','salaire','prime','retenue')),
  montant     numeric(14,2) not null check (montant > 0),
  note        text,
  created_at  timestamptz not null default now()
);

create index if not exists broderie_pieces_user_date_idx    on public.broderie_pieces(user_id, date_travail desc);
create index if not exists broderie_pieces_ouvrier_idx      on public.broderie_pieces(ouvrier_id);
create index if not exists broderie_mouvements_user_date_idx on public.broderie_mouvements(user_id, date_mvt desc);
create index if not exists broderie_mouvements_ouvrier_idx   on public.broderie_mouvements(ouvrier_id);

alter table public.broderie_pieces     enable row level security;
alter table public.broderie_mouvements enable row level security;

do $$
declare t text;
begin
  foreach t in array array['broderie_pieces','broderie_mouvements'] loop
    execute format('drop policy if exists %I on public.%I', t || '_owner_all', t);
    execute format(
      'create policy %I on public.%I for all to authenticated
         using ((select auth.uid()) = user_id)
         with check ((select auth.uid()) = user_id)', t || '_owner_all', t);
  end loop;
end $$;

-- L'ouvrier référencé doit appartenir au même compte
create or replace function public.broderie_check_ouvrier_owner()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not exists (select 1 from public.broderie_ouvriers o where o.id = new.ouvrier_id and o.user_id = new.user_id) then
    raise exception 'Ouvrier invalide';
  end if;
  return new;
end $$;

drop trigger if exists broderie_pieces_owner_chk on public.broderie_pieces;
create trigger broderie_pieces_owner_chk before insert or update on public.broderie_pieces
  for each row execute function public.broderie_check_ouvrier_owner();
drop trigger if exists broderie_mouvements_owner_chk on public.broderie_mouvements;
create trigger broderie_mouvements_owner_chk before insert or update on public.broderie_mouvements
  for each row execute function public.broderie_check_ouvrier_owner();

-- Solde de chaque ouvrier (toutes dates)
create or replace view public.broderie_soldes with (security_invoker = true) as
select
  o.id as ouvrier_id,
  coalesce(p.m, 0)            as gains_broderie,
  coalesce(pc.m, 0)           as gains_pieces,
  coalesce(mv.salaires, 0)    as salaires,
  coalesce(mv.primes, 0)      as primes,
  coalesce(mv.avances, 0)     as avances,
  coalesce(mv.paiements, 0)   as paiements,
  coalesce(mv.retenues, 0)    as retenues,
  coalesce(p.m, 0) + coalesce(pc.m, 0) + coalesce(mv.salaires, 0) + coalesce(mv.primes, 0)
    - coalesce(mv.avances, 0) - coalesce(mv.paiements, 0) - coalesce(mv.retenues, 0) as solde
from public.broderie_ouvriers o
left join (select ouvrier_id, sum(montant) m from public.broderie_production group by ouvrier_id) p on p.ouvrier_id = o.id
left join (select ouvrier_id, sum(montant) m from public.broderie_pieces group by ouvrier_id) pc on pc.ouvrier_id = o.id
left join (
  select ouvrier_id,
    sum(montant) filter (where type = 'salaire')  as salaires,
    sum(montant) filter (where type = 'prime')    as primes,
    sum(montant) filter (where type = 'avance')   as avances,
    sum(montant) filter (where type = 'paiement') as paiements,
    sum(montant) filter (where type = 'retenue')  as retenues
  from public.broderie_mouvements group by ouvrier_id
) mv on mv.ouvrier_id = o.id;

-- Bilan d'un ouvrier sur une période, avec le solde reporté d'avant la période
create or replace function public.broderie_bilan(p_ouvrier uuid, p_debut date, p_fin date)
returns table (
  anterieur numeric, gains_broderie numeric, gains_pieces numeric, salaires numeric, primes numeric,
  avances numeric, paiements numeric, retenues numeric, reste numeric
)
language sql
stable
security invoker
set search_path = ''
as $$
  with
  prod as (
    select
      coalesce(sum(montant) filter (where date_prod < p_debut), 0) as avant,
      coalesce(sum(montant) filter (where date_prod between p_debut and p_fin), 0) as periode
    from public.broderie_production where ouvrier_id = p_ouvrier
  ),
  pcs as (
    select
      coalesce(sum(montant) filter (where date_travail < p_debut), 0) as avant,
      coalesce(sum(montant) filter (where date_travail between p_debut and p_fin), 0) as periode
    from public.broderie_pieces where ouvrier_id = p_ouvrier
  ),
  mv as (
    select
      coalesce(sum(case when type in ('salaire','prime') then montant else -montant end) filter (where date_mvt < p_debut), 0) as avant,
      coalesce(sum(montant) filter (where type = 'salaire'  and date_mvt between p_debut and p_fin), 0) as salaires,
      coalesce(sum(montant) filter (where type = 'prime'    and date_mvt between p_debut and p_fin), 0) as primes,
      coalesce(sum(montant) filter (where type = 'avance'   and date_mvt between p_debut and p_fin), 0) as avances,
      coalesce(sum(montant) filter (where type = 'paiement' and date_mvt between p_debut and p_fin), 0) as paiements,
      coalesce(sum(montant) filter (where type = 'retenue'  and date_mvt between p_debut and p_fin), 0) as retenues
    from public.broderie_mouvements where ouvrier_id = p_ouvrier
  )
  select
    prod.avant + pcs.avant + mv.avant,
    prod.periode, pcs.periode, mv.salaires, mv.primes, mv.avances, mv.paiements, mv.retenues,
    prod.avant + pcs.avant + mv.avant + prod.periode + pcs.periode + mv.salaires + mv.primes
      - mv.avances - mv.paiements - mv.retenues
  from prod, pcs, mv;
$$;

revoke execute on function public.broderie_bilan(uuid, date, date) from anon, public;
grant execute on function public.broderie_bilan(uuid, date, date) to authenticated;
