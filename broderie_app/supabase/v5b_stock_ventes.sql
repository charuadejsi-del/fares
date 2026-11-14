-- =====================================================================
-- v5b : stock des produits (robes), QR = référence, ventes en gros,
--       clients, versements, numérotation des factures et bons de livraison
-- =====================================================================

-- Compteurs (numéros de facture, BL, références produits)
create table if not exists public.atelier_compteurs (
  atelier_id uuid not null references public.ateliers(id) on delete cascade,
  cle        text not null,
  annee      integer not null default 0,
  valeur     integer not null default 0,
  primary key (atelier_id, cle, annee)
);
alter table public.atelier_compteurs enable row level security;
drop policy if exists compteurs_all on public.atelier_compteurs;
create policy compteurs_all on public.atelier_compteurs for all to authenticated
  using (atelier_id = (select public.atelier_courant()))
  with check (atelier_id = (select public.atelier_courant()));

create or replace function public.atelier_prochain_numero(p_cle text, p_annee integer default 0)
returns integer language plpgsql security invoker set search_path = '' as $$
declare v integer;
begin
  insert into public.atelier_compteurs(atelier_id, cle, annee, valeur)
  values (public.atelier_courant(), p_cle, p_annee, 1)
  on conflict (atelier_id, cle, annee) do update set valeur = public.atelier_compteurs.valeur + 1
  returning valeur into v;
  return v;
end $$;

-- Produits
create table if not exists public.stock_produits (
  id            uuid primary key default gen_random_uuid(),
  atelier_id    uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  reference     text not null check (length(trim(reference)) > 0),
  designation   text not null check (length(trim(designation)) > 0),
  categorie     text,
  taille        text,
  couleur       text,
  prix_gros     numeric(12,2) not null default 0 check (prix_gros >= 0),
  prix_detail   numeric(12,2) not null default 0 check (prix_detail >= 0),
  cout_revient  numeric(12,2) not null default 0 check (cout_revient >= 0),
  seuil_alerte  integer not null default 0 check (seuil_alerte >= 0),
  photo_path    text,
  actif         boolean not null default true,
  created_at    timestamptz not null default now(),
  unique (atelier_id, reference)
);

-- Clients (gros)
create table if not exists public.stock_clients (
  id          uuid primary key default gen_random_uuid(),
  atelier_id  uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  nom         text not null check (length(trim(nom)) > 0),
  telephone   text,
  adresse     text,
  wilaya      text,
  rc          text,
  nif         text,
  note        text,
  actif       boolean not null default true,
  created_at  timestamptz not null default now()
);

-- Ventes
create table if not exists public.stock_ventes (
  id                 uuid primary key default gen_random_uuid(),
  atelier_id         uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  numero             text not null,
  numero_bl          text not null,
  client_id          uuid references public.stock_clients(id) on delete restrict,
  date_vente         date not null default current_date,
  remise             numeric(14,2) not null default 0 check (remise >= 0),
  tva_taux           numeric(5,2) not null default 0,
  total_brut         numeric(14,2) not null default 0,
  total_ht           numeric(14,2) not null default 0,
  total_tva          numeric(14,2) not null default 0,
  total_ttc          numeric(14,2) not null default 0,
  statut             text not null default 'validee' check (statut in ('validee','annulee')),
  chauffeur          text,
  vehicule           text,
  adresse_livraison  text,
  note               text,
  user_id            uuid default auth.uid() references auth.users(id) on delete set null,
  created_at         timestamptz not null default now(),
  unique (atelier_id, numero)
);

create table if not exists public.stock_vente_lignes (
  id             uuid primary key default gen_random_uuid(),
  atelier_id     uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  vente_id       uuid not null references public.stock_ventes(id) on delete cascade,
  produit_id     uuid not null references public.stock_produits(id) on delete restrict,
  reference      text not null,
  designation    text not null,
  quantite       integer not null check (quantite > 0),
  prix_unitaire  numeric(12,2) not null check (prix_unitaire >= 0),
  montant        numeric(14,2) generated always as (round(quantite * prix_unitaire, 2)) stored
);

-- Mouvements de stock (quantité signée : + entrée, − sortie)
create table if not exists public.stock_mouvements (
  id          uuid primary key default gen_random_uuid(),
  atelier_id  uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  produit_id  uuid not null references public.stock_produits(id) on delete restrict,
  type        text not null check (type in ('entree','sortie','vente','retour','ajustement','annulation')),
  quantite    integer not null check (quantite <> 0),
  vente_id    uuid references public.stock_ventes(id) on delete set null,
  note        text,
  user_id     uuid default auth.uid() references auth.users(id) on delete set null,
  created_at  timestamptz not null default now()
);

-- Versements des clients
create table if not exists public.stock_versements (
  id               uuid primary key default gen_random_uuid(),
  atelier_id       uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  client_id        uuid not null references public.stock_clients(id) on delete restrict,
  vente_id         uuid references public.stock_ventes(id) on delete set null,
  date_versement   date not null default current_date,
  montant          numeric(14,2) not null check (montant > 0),
  mode             text not null default 'especes' check (mode in ('especes','cheque','virement','ccp','autre')),
  note             text,
  user_id          uuid default auth.uid() references auth.users(id) on delete set null,
  created_at       timestamptz not null default now()
);

create index if not exists stock_produits_atelier_idx on public.stock_produits(atelier_id);
create index if not exists stock_clients_atelier_idx on public.stock_clients(atelier_id);
create index if not exists stock_ventes_atelier_date_idx on public.stock_ventes(atelier_id, date_vente desc);
create index if not exists stock_ventes_client_idx on public.stock_ventes(client_id);
create index if not exists stock_lignes_vente_idx on public.stock_vente_lignes(vente_id);
create index if not exists stock_lignes_produit_idx on public.stock_vente_lignes(produit_id);
create index if not exists stock_lignes_atelier_idx on public.stock_vente_lignes(atelier_id);
create index if not exists stock_mvts_produit_idx on public.stock_mouvements(produit_id);
create index if not exists stock_mvts_atelier_date_idx on public.stock_mouvements(atelier_id, created_at desc);
create index if not exists stock_mvts_vente_idx on public.stock_mouvements(vente_id);
create index if not exists stock_versements_client_idx on public.stock_versements(client_id);
create index if not exists stock_versements_vente_idx on public.stock_versements(vente_id);
create index if not exists stock_versements_atelier_idx on public.stock_versements(atelier_id, date_versement desc);

do $$
declare t text;
begin
  foreach t in array array['stock_produits','stock_clients','stock_ventes','stock_vente_lignes','stock_mouvements','stock_versements'] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

select public._atelier_policies('stock_produits',     array['stock'], 'stock');
select public._atelier_policies('stock_clients',      array['stock'], 'stock');
select public._atelier_policies('stock_ventes',       array['stock'], 'stock');
select public._atelier_policies('stock_vente_lignes', array['stock'], 'stock');
select public._atelier_policies('stock_mouvements',   array['stock'], 'stock');
select public._atelier_policies('stock_versements',   array['stock'], 'stock');

-- Cohérence : client / produit / vente du même atelier
create or replace function public.stock_check_refs()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_table_name in ('stock_mouvements','stock_vente_lignes') then
    if not exists (select 1 from public.stock_produits p where p.id = new.produit_id and p.atelier_id = new.atelier_id) then
      raise exception 'Produit invalide';
    end if;
  end if;
  if tg_table_name in ('stock_versements','stock_ventes') and new.client_id is not null then
    if not exists (select 1 from public.stock_clients c where c.id = new.client_id and c.atelier_id = new.atelier_id) then
      raise exception 'Client invalide';
    end if;
  end if;
  if tg_table_name in ('stock_versements','stock_mouvements','stock_vente_lignes') and new.vente_id is not null then
    if not exists (select 1 from public.stock_ventes v where v.id = new.vente_id and v.atelier_id = new.atelier_id) then
      raise exception 'Vente invalide';
    end if;
  end if;
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['stock_mouvements','stock_vente_lignes','stock_versements','stock_ventes'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_refs_chk', t);
    execute format('create trigger %I before insert or update on public.%I for each row execute function public.stock_check_refs()', t || '_refs_chk', t);
  end loop;
end $$;

-- ---------------------------------------------------------------- vues
create or replace view public.stock_etat with (security_invoker = true) as
select p.*,
  coalesce((select sum(m.quantite) from public.stock_mouvements m where m.produit_id = p.id), 0)::integer as stock,
  coalesce((select sum(l.quantite) from public.stock_vente_lignes l join public.stock_ventes v on v.id = l.vente_id
            where l.produit_id = p.id and v.statut = 'validee'), 0)::integer as vendus
from public.stock_produits p;

create or replace view public.stock_ventes_etat with (security_invoker = true) as
select v.*,
  c.nom as client_nom,
  coalesce((select sum(x.montant) from public.stock_versements x where x.vente_id = v.id), 0) as verse,
  case when v.statut = 'annulee' then 0
       else v.total_ttc - coalesce((select sum(x.montant) from public.stock_versements x where x.vente_id = v.id), 0) end as reste,
  (select coalesce(sum(l.quantite), 0) from public.stock_vente_lignes l where l.vente_id = v.id)::integer as nb_articles
from public.stock_ventes v
left join public.stock_clients c on c.id = v.client_id;

create or replace view public.stock_clients_soldes with (security_invoker = true) as
select c.*,
  coalesce((select sum(v.total_ttc) from public.stock_ventes v where v.client_id = c.id and v.statut = 'validee'), 0) as total_achats,
  coalesce((select sum(x.montant) from public.stock_versements x where x.client_id = c.id), 0) as total_verse,
  coalesce((select sum(v.total_ttc) from public.stock_ventes v where v.client_id = c.id and v.statut = 'validee'), 0)
    - coalesce((select sum(x.montant) from public.stock_versements x where x.client_id = c.id), 0) as solde,
  (select count(*) from public.stock_ventes v where v.client_id = c.id and v.statut = 'validee')::integer as nb_ventes,
  (select max(v.date_vente) from public.stock_ventes v where v.client_id = c.id and v.statut = 'validee') as derniere_vente
from public.stock_clients c;

-- ---------------------------------------------------------------- vente (transaction complète)
-- p_lignes : [{"produit_id": "...", "quantite": 10, "prix": 1500}, ...]
create or replace function public.stock_creer_vente(
  p_client uuid,
  p_date date,
  p_lignes jsonb,
  p_remise numeric default 0,
  p_versement numeric default 0,
  p_mode text default 'especes',
  p_chauffeur text default null,
  p_vehicule text default null,
  p_adresse text default null,
  p_note text default null,
  p_autoriser_negatif boolean default false
) returns uuid
language plpgsql security invoker set search_path = '' as $$
declare
  v_atelier uuid := public.atelier_courant();
  v_annee integer := extract(year from coalesce(p_date, current_date))::integer;
  v_id uuid := gen_random_uuid();
  v_tva numeric;
  v_brut numeric := 0;
  v_ht numeric;
  v_tva_mt numeric;
  v_ttc numeric;
  l jsonb;
  p record;
  v_dispo integer;
  v_qte integer;
  v_prix numeric;
begin
  if not public.a_droit('stock') then raise exception 'Accès refusé'; end if;
  if p_lignes is null or jsonb_array_length(p_lignes) = 0 then raise exception 'La vente ne contient aucun article'; end if;
  if p_client is null and coalesce(p_versement, 0) > 0 then raise exception 'Choisissez un client pour enregistrer un versement'; end if;

  select tva into v_tva from public.ateliers where id = v_atelier;

  -- contrôle des lignes et du stock
  for l in select * from jsonb_array_elements(p_lignes) loop
    v_qte := (l->>'quantite')::integer;
    v_prix := (l->>'prix')::numeric;
    if v_qte is null or v_qte <= 0 then raise exception 'Quantité invalide'; end if;
    if v_prix is null or v_prix < 0 then raise exception 'Prix invalide'; end if;
    select * into p from public.stock_produits where id = (l->>'produit_id')::uuid and atelier_id = v_atelier for update;
    if not found then raise exception 'Produit introuvable'; end if;
    select coalesce(sum(quantite), 0) into v_dispo from public.stock_mouvements where produit_id = p.id;
    if not p_autoriser_negatif and v_dispo < v_qte then
      raise exception 'Stock insuffisant pour % (disponible : %, demandé : %)', p.reference, v_dispo, v_qte;
    end if;
    v_brut := v_brut + round(v_qte * v_prix, 2);
  end loop;

  v_ht := greatest(v_brut - coalesce(p_remise, 0), 0);
  v_tva_mt := round(v_ht * coalesce(v_tva, 0) / 100, 2);
  v_ttc := v_ht + v_tva_mt;

  insert into public.stock_ventes(id, atelier_id, numero, numero_bl, client_id, date_vente, remise, tva_taux,
                                  total_brut, total_ht, total_tva, total_ttc, chauffeur, vehicule, adresse_livraison, note)
  values (v_id, v_atelier,
          'F-' || v_annee || '-' || lpad(public.atelier_prochain_numero('facture', v_annee)::text, 4, '0'),
          'BL-' || v_annee || '-' || lpad(public.atelier_prochain_numero('bl', v_annee)::text, 4, '0'),
          p_client, coalesce(p_date, current_date), coalesce(p_remise, 0), coalesce(v_tva, 0),
          v_brut, v_ht, v_tva_mt, v_ttc,
          nullif(trim(p_chauffeur), ''), nullif(trim(p_vehicule), ''), nullif(trim(p_adresse), ''), nullif(trim(p_note), ''));

  for l in select * from jsonb_array_elements(p_lignes) loop
    select * into p from public.stock_produits where id = (l->>'produit_id')::uuid;
    insert into public.stock_vente_lignes(atelier_id, vente_id, produit_id, reference, designation, quantite, prix_unitaire)
    values (v_atelier, v_id, p.id, p.reference,
            p.designation || coalesce(' — ' || nullif(p.taille, ''), '') || coalesce(' — ' || nullif(p.couleur, ''), ''),
            (l->>'quantite')::integer, (l->>'prix')::numeric);
    insert into public.stock_mouvements(atelier_id, produit_id, type, quantite, vente_id, note)
    values (v_atelier, p.id, 'vente', -((l->>'quantite')::integer), v_id, 'Vente');
  end loop;

  if coalesce(p_versement, 0) > 0 then
    insert into public.stock_versements(atelier_id, client_id, vente_id, date_versement, montant, mode, note)
    values (v_atelier, p_client, v_id, coalesce(p_date, current_date), least(p_versement, v_ttc), coalesce(p_mode, 'especes'), 'Versement à la vente');
  end if;

  return v_id;
end $$;

-- Annulation : remet les articles en stock ; les versements restent comme avance du client
create or replace function public.stock_annuler_vente(p_vente uuid, p_motif text default null)
returns void language plpgsql security invoker set search_path = '' as $$
declare v record; l record;
begin
  if not public.a_droit('stock') then raise exception 'Accès refusé'; end if;
  select * into v from public.stock_ventes where id = p_vente and atelier_id = public.atelier_courant() for update;
  if not found then raise exception 'Vente introuvable'; end if;
  if v.statut = 'annulee' then raise exception 'Vente déjà annulée'; end if;
  update public.stock_ventes set statut = 'annulee',
    note = trim(coalesce(note, '') || ' [Annulée' || coalesce(' : ' || nullif(trim(p_motif), ''), '') || ']')
  where id = p_vente;
  for l in select * from public.stock_vente_lignes where vente_id = p_vente loop
    insert into public.stock_mouvements(atelier_id, produit_id, type, quantite, vente_id, note)
    values (v.atelier_id, l.produit_id, 'annulation', l.quantite, p_vente, 'Annulation ' || v.numero);
  end loop;
  update public.stock_versements set vente_id = null, note = coalesce(note, '') || ' (vente ' || v.numero || ' annulée)'
  where vente_id = p_vente;
end $$;

revoke execute on function public.atelier_prochain_numero(text, integer) from anon, public;
revoke execute on function public.stock_creer_vente(uuid, date, jsonb, numeric, numeric, text, text, text, text, text, boolean) from anon, public;
revoke execute on function public.stock_annuler_vente(uuid, text) from anon, public;
grant execute on function public.atelier_prochain_numero(text, integer) to authenticated;
grant execute on function public.stock_creer_vente(uuid, date, jsonb, numeric, numeric, text, text, text, text, text, boolean) to authenticated;
grant execute on function public.stock_annuler_vente(uuid, text) to authenticated;

-- v5c : correctif — conditions imbriquées (PL/pgSQL n'évalue pas « and » en court-circuit sur les champs de NEW)
create or replace function public.stock_check_refs()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_table_name in ('stock_mouvements','stock_vente_lignes') then
    if not exists (select 1 from public.stock_produits p where p.id = new.produit_id and p.atelier_id = new.atelier_id) then
      raise exception 'Produit invalide';
    end if;
  end if;
  if tg_table_name in ('stock_versements','stock_ventes') then
    if new.client_id is not null then
      if not exists (select 1 from public.stock_clients c where c.id = new.client_id and c.atelier_id = new.atelier_id) then
        raise exception 'Client invalide';
      end if;
    end if;
  end if;
  if tg_table_name in ('stock_versements','stock_mouvements','stock_vente_lignes') then
    if new.vente_id is not null then
      if not exists (select 1 from public.stock_ventes v where v.id = new.vente_id and v.atelier_id = new.atelier_id) then
        raise exception 'Vente invalide';
      end if;
    end if;
  end if;
  return new;
end $$;
