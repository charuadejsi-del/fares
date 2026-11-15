-- =====================================================================
-- v9 : clôture mensuelle de la paie + journal des actions
-- =====================================================================

-- ---------------------------------------------------------------- 1. Clôtures de paie
create table if not exists public.paie_clotures (
  id               uuid primary key default gen_random_uuid(),
  atelier_id       uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  mois             date not null check (extract(day from mois) = 1),
  nb_ouvriers      int not null default 0,
  total_gains      numeric(14,2) not null default 0,
  total_deductions numeric(14,2) not null default 0,
  total_net        numeric(14,2) not null default 0,
  detail           jsonb not null default '[]'::jsonb,
  note             text,
  user_id          uuid default auth.uid() references auth.users(id) on delete set null,
  created_at       timestamptz not null default now(),
  unique (atelier_id, mois)
);
alter table public.paie_clotures enable row level security;

drop policy if exists paie_clotures_select on public.paie_clotures;
drop policy if exists paie_clotures_insert on public.paie_clotures;
drop policy if exists paie_clotures_delete on public.paie_clotures;
create policy paie_clotures_select on public.paie_clotures for select to authenticated
  using (atelier_id = (select public.atelier_courant()) and (select public.a_droit('paie')));
create policy paie_clotures_insert on public.paie_clotures for insert to authenticated
  with check (atelier_id = (select public.atelier_courant()) and (select public.a_droit('paie')));
-- Réouvrir un mois : réservé à l'administrateur
create policy paie_clotures_delete on public.paie_clotures for delete to authenticated
  using (atelier_id = (select public.atelier_courant()) and (select public.a_droit('admin')));

-- Un mois clôturé est verrouillé : plus d'ajout, de modification ni de suppression
create or replace function public.paie_verrou_mois()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_col text := tg_argv[0];
  r jsonb;
  d date;
begin
  foreach r in array array[case when tg_op <> 'INSERT' then to_jsonb(old) end,
                           case when tg_op <> 'DELETE' then to_jsonb(new) end] loop
    continue when r is null;
    d := (r->>v_col)::date;
    if exists (select 1 from public.paie_clotures c
               where c.atelier_id = (r->>'atelier_id')::uuid and c.mois = date_trunc('month', d)::date) then
      raise exception 'Le mois %/% est clôturé : réouvrez-le pour le modifier', to_char(d, 'MM'), to_char(d, 'YYYY');
    end if;
  end loop;
  return coalesce(new, old);
end $$;
revoke execute on function public.paie_verrou_mois() from anon, authenticated, public;

drop trigger if exists paie_verrou on public.broderie_production;
create trigger paie_verrou before insert or update or delete on public.broderie_production
  for each row execute function public.paie_verrou_mois('date_prod');
drop trigger if exists paie_verrou on public.broderie_pieces;
create trigger paie_verrou before insert or update or delete on public.broderie_pieces
  for each row execute function public.paie_verrou_mois('date_travail');
drop trigger if exists paie_verrou on public.broderie_mouvements;
create trigger paie_verrou before insert or update or delete on public.broderie_mouvements
  for each row execute function public.paie_verrou_mois('date_mvt');

-- ---------------------------------------------------------------- 2. Journal des actions
create table if not exists public.journal_actions (
  id          bigint generated always as identity primary key,
  atelier_id  uuid not null,
  user_id     uuid,
  user_nom    text,
  table_nom   text not null,
  action      text not null check (action in ('ajout','modification','suppression')),
  ligne_id    text,
  libelle     text,
  montant     numeric,
  changements jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists journal_actions_atelier_date_idx on public.journal_actions(atelier_id, created_at desc);
alter table public.journal_actions enable row level security;

-- Lecture seule, administrateur uniquement. Aucune règle d'écriture : le journal est infalsifiable.
drop policy if exists journal_actions_select on public.journal_actions;
create policy journal_actions_select on public.journal_actions for select to authenticated
  using (atelier_id = (select public.atelier_courant()) and (select public.a_droit('admin')));

create or replace function public.journal_enregistrer()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  o jsonb := case when tg_op <> 'INSERT' then to_jsonb(old) end;
  n jsonb := case when tg_op <> 'DELETE' then to_jsonb(new) end;
  r jsonb := coalesce(n, o);
  v_atelier uuid;
  v_diff jsonb := '{}'::jsonb;
  k text;
  v_nom text;
begin
  -- mouvements de stock générés par une vente : déjà tracés par la vente
  if tg_table_name = 'stock_mouvements' and r->>'vente_id' is not null then
    return null;
  end if;

  v_atelier := coalesce((r->>'atelier_id')::uuid, case when tg_table_name = 'ateliers' then (r->>'id')::uuid end);
  if v_atelier is null then return null; end if;

  if tg_op = 'UPDATE' then
    for k in select jsonb_object_keys(n) loop
      if k not in ('updated_at','created_at') and (o->k) is distinct from (n->k) then
        v_diff := v_diff || jsonb_build_object(k, jsonb_build_array(o->k, n->k));
      end if;
    end loop;
    if v_diff = '{}'::jsonb then return null; end if;
  end if;

  select coalesce(nullif(m.nom, ''), u.email) into v_nom
  from auth.users u left join public.atelier_membres m on m.user_id = u.id
  where u.id = auth.uid();

  insert into public.journal_actions(atelier_id, user_id, user_nom, table_nom, action, ligne_id, libelle, montant, changements)
  values (
    v_atelier, auth.uid(), coalesce(v_nom, 'Système'), tg_table_name,
    case tg_op when 'INSERT' then 'ajout' when 'UPDATE' then 'modification' else 'suppression' end,
    coalesce(r->>'id', r->>'user_id'),
    left(concat_ws(' · ',
      coalesce(r->>'numero', r->>'reference', r->>'nom', r->>'libelle', r->>'designation'),
      case when r ? 'couleur' then r->>'couleur' end,
      case when r ? 'taille' then r->>'taille' end,
      case when tg_table_name in ('broderie_mouvements','stock_mouvements','stock_matiere_mvts','stock_commandes') then r->>'type' end,
      case when tg_table_name = 'paie_clotures' then to_char((r->>'mois')::date, 'MM/YYYY') end,
      case when r ? 'quantite' and tg_table_name <> 'broderie_pieces' then 'qté ' || (r->>'quantite') end,
      case when r ? 'nb_robes' then (r->>'nb_robes') || ' robes' end
    ), 200),
    coalesce((r->>'montant')::numeric, (r->>'total_ttc')::numeric, (r->>'total')::numeric, (r->>'total_net')::numeric),
    case when tg_op = 'UPDATE' then v_diff end
  );
  return null;
end $$;
revoke execute on function public.journal_enregistrer() from anon, authenticated, public;

do $$
declare t text;
begin
  foreach t in array array[
    'ateliers','atelier_membres',
    'broderie_ouvriers','broderie_dessins','broderie_machines','broderie_types',
    'broderie_production','broderie_pieces','broderie_mouvements','paie_clotures',
    'stock_produits','stock_mouvements','stock_clients','stock_ventes','stock_versements',
    'stock_commandes','stock_avoirs','stock_achats','stock_fournisseurs','stock_matieres',
    'stock_matiere_mvts','stock_paiements_fournisseurs','stock_prix_clients'] loop
    execute format('drop trigger if exists journal on public.%I', t);
    execute format('create trigger journal after insert or update or delete on public.%I
                    for each row execute function public.journal_enregistrer()', t);
  end loop;
end $$;
