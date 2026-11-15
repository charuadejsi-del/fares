-- =====================================================================
-- v6 : commandes & devis (réservation du stock), avoirs (retours), prix spéciaux par client,
--      fournisseurs, matières, achats, paiements fournisseurs, nomenclature (coût de revient), logo
-- =====================================================================

alter table public.ateliers add column if not exists logo_path text;

-- ---------------------------------------------------------------- prix spéciaux par client
create table if not exists public.stock_prix_clients (
  id          uuid primary key default gen_random_uuid(),
  atelier_id  uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  client_id   uuid not null references public.stock_clients(id) on delete cascade,
  produit_id  uuid not null references public.stock_produits(id) on delete cascade,
  prix        numeric(12,2) not null check (prix >= 0),
  unique (client_id, produit_id)
);

-- ---------------------------------------------------------------- devis & commandes
create table if not exists public.stock_commandes (
  id              uuid primary key default gen_random_uuid(),
  atelier_id      uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  type            text not null check (type in ('devis','commande')),
  numero          text not null,
  client_id       uuid references public.stock_clients(id) on delete restrict,
  date_doc        date not null default current_date,
  date_echeance   date,
  statut          text not null default 'en_cours' check (statut in ('en_cours','prete','acceptee','refusee','livree','annulee')),
  remise          numeric(14,2) not null default 0 check (remise >= 0),
  note            text,
  vente_id        uuid references public.stock_ventes(id) on delete set null,
  user_id         uuid default auth.uid() references auth.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  unique (atelier_id, numero)
);

create table if not exists public.stock_commande_lignes (
  id             uuid primary key default gen_random_uuid(),
  atelier_id     uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  commande_id    uuid not null references public.stock_commandes(id) on delete cascade,
  produit_id     uuid not null references public.stock_produits(id) on delete restrict,
  quantite       integer not null check (quantite > 0),
  prix_unitaire  numeric(12,2) not null check (prix_unitaire >= 0),
  montant        numeric(14,2) generated always as (round(quantite * prix_unitaire, 2)) stored
);

-- ---------------------------------------------------------------- avoirs (retours clients)
create table if not exists public.stock_avoirs (
  id              uuid primary key default gen_random_uuid(),
  atelier_id      uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  numero          text not null,
  client_id       uuid not null references public.stock_clients(id) on delete restrict,
  vente_id        uuid references public.stock_ventes(id) on delete set null,
  date_avoir      date not null default current_date,
  total           numeric(14,2) not null default 0,
  remis_en_stock  boolean not null default true,
  motif           text,
  user_id         uuid default auth.uid() references auth.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  unique (atelier_id, numero)
);

create table if not exists public.stock_avoir_lignes (
  id             uuid primary key default gen_random_uuid(),
  atelier_id     uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  avoir_id       uuid not null references public.stock_avoirs(id) on delete cascade,
  produit_id     uuid not null references public.stock_produits(id) on delete restrict,
  quantite       integer not null check (quantite > 0),
  prix_unitaire  numeric(12,2) not null check (prix_unitaire >= 0),
  montant        numeric(14,2) generated always as (round(quantite * prix_unitaire, 2)) stored
);

-- ---------------------------------------------------------------- fournisseurs, matières, achats
create table if not exists public.stock_fournisseurs (
  id          uuid primary key default gen_random_uuid(),
  atelier_id  uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  nom         text not null check (length(trim(nom)) > 0),
  telephone   text,
  adresse     text,
  note        text,
  actif       boolean not null default true,
  created_at  timestamptz not null default now()
);

create table if not exists public.stock_matieres (
  id            uuid primary key default gen_random_uuid(),
  atelier_id    uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  nom           text not null check (length(trim(nom)) > 0),
  unite         text not null default 'm',
  categorie     text,
  seuil_alerte  numeric(12,3) not null default 0 check (seuil_alerte >= 0),
  actif         boolean not null default true,
  created_at    timestamptz not null default now()
);

create table if not exists public.stock_achats (
  id              uuid primary key default gen_random_uuid(),
  atelier_id      uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  numero          text not null,
  fournisseur_id  uuid references public.stock_fournisseurs(id) on delete restrict,
  date_achat      date not null default current_date,
  total           numeric(14,2) not null default 0,
  note            text,
  user_id         uuid default auth.uid() references auth.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  unique (atelier_id, numero)
);

create table if not exists public.stock_achat_lignes (
  id             uuid primary key default gen_random_uuid(),
  atelier_id     uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  achat_id       uuid not null references public.stock_achats(id) on delete cascade,
  matiere_id     uuid not null references public.stock_matieres(id) on delete restrict,
  quantite       numeric(12,3) not null check (quantite > 0),
  prix_unitaire  numeric(12,2) not null check (prix_unitaire >= 0),
  montant        numeric(14,2) generated always as (round(quantite * prix_unitaire, 2)) stored
);

create table if not exists public.stock_matiere_mvts (
  id          uuid primary key default gen_random_uuid(),
  atelier_id  uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  matiere_id  uuid not null references public.stock_matieres(id) on delete restrict,
  type        text not null check (type in ('achat','consommation','ajustement','retour')),
  quantite    numeric(12,3) not null check (quantite <> 0),
  achat_id    uuid references public.stock_achats(id) on delete set null,
  produit_id  uuid references public.stock_produits(id) on delete set null,
  note        text,
  user_id     uuid default auth.uid() references auth.users(id) on delete set null,
  created_at  timestamptz not null default now()
);

create table if not exists public.stock_paiements_fournisseurs (
  id              uuid primary key default gen_random_uuid(),
  atelier_id      uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  fournisseur_id  uuid not null references public.stock_fournisseurs(id) on delete restrict,
  achat_id        uuid references public.stock_achats(id) on delete set null,
  date_paiement   date not null default current_date,
  montant         numeric(14,2) not null check (montant > 0),
  mode            text not null default 'especes' check (mode in ('especes','cheque','virement','ccp','autre')),
  note            text,
  user_id         uuid default auth.uid() references auth.users(id) on delete set null,
  created_at      timestamptz not null default now()
);

create table if not exists public.stock_nomenclature (
  id          uuid primary key default gen_random_uuid(),
  atelier_id  uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  produit_id  uuid not null references public.stock_produits(id) on delete cascade,
  matiere_id  uuid not null references public.stock_matieres(id) on delete restrict,
  quantite    numeric(12,3) not null check (quantite > 0),
  unique (produit_id, matiere_id)
);

-- index
create index if not exists stock_prix_clients_atelier_idx on public.stock_prix_clients(atelier_id);
create index if not exists stock_prix_clients_produit_idx on public.stock_prix_clients(produit_id);
create index if not exists stock_commandes_atelier_idx on public.stock_commandes(atelier_id, date_doc desc);
create index if not exists stock_commandes_client_idx on public.stock_commandes(client_id);
create index if not exists stock_commandes_vente_idx on public.stock_commandes(vente_id);
create index if not exists stock_cmd_lignes_cmd_idx on public.stock_commande_lignes(commande_id);
create index if not exists stock_cmd_lignes_produit_idx on public.stock_commande_lignes(produit_id);
create index if not exists stock_cmd_lignes_atelier_idx on public.stock_commande_lignes(atelier_id);
create index if not exists stock_avoirs_atelier_idx on public.stock_avoirs(atelier_id, date_avoir desc);
create index if not exists stock_avoirs_client_idx on public.stock_avoirs(client_id);
create index if not exists stock_avoirs_vente_idx on public.stock_avoirs(vente_id);
create index if not exists stock_avoir_lignes_avoir_idx on public.stock_avoir_lignes(avoir_id);
create index if not exists stock_avoir_lignes_produit_idx on public.stock_avoir_lignes(produit_id);
create index if not exists stock_avoir_lignes_atelier_idx on public.stock_avoir_lignes(atelier_id);
create index if not exists stock_fournisseurs_atelier_idx on public.stock_fournisseurs(atelier_id);
create index if not exists stock_matieres_atelier_idx on public.stock_matieres(atelier_id);
create index if not exists stock_achats_atelier_idx on public.stock_achats(atelier_id, date_achat desc);
create index if not exists stock_achats_fournisseur_idx on public.stock_achats(fournisseur_id);
create index if not exists stock_achat_lignes_achat_idx on public.stock_achat_lignes(achat_id);
create index if not exists stock_achat_lignes_matiere_idx on public.stock_achat_lignes(matiere_id);
create index if not exists stock_achat_lignes_atelier_idx on public.stock_achat_lignes(atelier_id);
create index if not exists stock_matiere_mvts_matiere_idx on public.stock_matiere_mvts(matiere_id);
create index if not exists stock_matiere_mvts_atelier_idx on public.stock_matiere_mvts(atelier_id, created_at desc);
create index if not exists stock_matiere_mvts_achat_idx on public.stock_matiere_mvts(achat_id);
create index if not exists stock_matiere_mvts_produit_idx on public.stock_matiere_mvts(produit_id);
create index if not exists stock_paiements_f_fourn_idx on public.stock_paiements_fournisseurs(fournisseur_id);
create index if not exists stock_paiements_f_achat_idx on public.stock_paiements_fournisseurs(achat_id);
create index if not exists stock_paiements_f_atelier_idx on public.stock_paiements_fournisseurs(atelier_id, date_paiement desc);
create index if not exists stock_nomenclature_produit_idx on public.stock_nomenclature(produit_id);
create index if not exists stock_nomenclature_matiere_idx on public.stock_nomenclature(matiere_id);
create index if not exists stock_nomenclature_atelier_idx on public.stock_nomenclature(atelier_id);

alter table public.stock_prix_clients enable row level security;
alter table public.stock_commandes enable row level security;
alter table public.stock_commande_lignes enable row level security;
alter table public.stock_avoirs enable row level security;
alter table public.stock_avoir_lignes enable row level security;
alter table public.stock_fournisseurs enable row level security;
alter table public.stock_matieres enable row level security;
alter table public.stock_achats enable row level security;
alter table public.stock_achat_lignes enable row level security;
alter table public.stock_matiere_mvts enable row level security;
alter table public.stock_paiements_fournisseurs enable row level security;
alter table public.stock_nomenclature enable row level security;

select public._atelier_policies('stock_prix_clients', array['stock'], 'stock');
select public._atelier_policies('stock_commandes', array['stock'], 'stock');
select public._atelier_policies('stock_commande_lignes', array['stock'], 'stock');
select public._atelier_policies('stock_avoirs', array['stock'], 'stock');
select public._atelier_policies('stock_avoir_lignes', array['stock'], 'stock');
select public._atelier_policies('stock_fournisseurs', array['stock'], 'stock');
select public._atelier_policies('stock_matieres', array['stock'], 'stock');
select public._atelier_policies('stock_achats', array['stock'], 'stock');
select public._atelier_policies('stock_achat_lignes', array['stock'], 'stock');
select public._atelier_policies('stock_matiere_mvts', array['stock'], 'stock');
select public._atelier_policies('stock_paiements_fournisseurs', array['stock'], 'stock');
select public._atelier_policies('stock_nomenclature', array['stock'], 'stock');

-- ---------------------------------------------------------------- vues (mises à jour : colonnes ajoutées en fin)
create or replace view public.stock_etat with (security_invoker = true) as
select p.*,
  coalesce((select sum(m.quantite) from public.stock_mouvements m where m.produit_id = p.id), 0)::integer as stock,
  coalesce((select sum(l.quantite) from public.stock_vente_lignes l join public.stock_ventes v on v.id = l.vente_id
            where l.produit_id = p.id and v.statut = 'validee'), 0)::integer as vendus,
  coalesce((select sum(cl.quantite) from public.stock_commande_lignes cl join public.stock_commandes c on c.id = cl.commande_id
            where cl.produit_id = p.id and c.type = 'commande' and c.statut in ('en_cours','prete')), 0)::integer as reserve,
  coalesce((select sum(n.quantite * coalesce(mc.cout_moyen, 0)) from public.stock_nomenclature n
            left join lateral (select sum(al.montant) / nullif(sum(al.quantite), 0) as cout_moyen
                               from public.stock_achat_lignes al where al.matiere_id = n.matiere_id) mc on true
            where n.produit_id = p.id), 0)::numeric(14,2) as cout_matieres
from public.stock_produits p;

create or replace view public.stock_ventes_etat with (security_invoker = true) as
select v.*,
  c.nom as client_nom,
  coalesce((select sum(x.montant) from public.stock_versements x where x.vente_id = v.id), 0) as verse,
  case when v.statut = 'annulee' then 0
       else v.total_ttc
          - coalesce((select sum(x.montant) from public.stock_versements x where x.vente_id = v.id), 0)
          - coalesce((select sum(a.total) from public.stock_avoirs a where a.vente_id = v.id), 0) end as reste,
  (select coalesce(sum(l.quantite), 0) from public.stock_vente_lignes l where l.vente_id = v.id)::integer as nb_articles,
  coalesce((select sum(a.total) from public.stock_avoirs a where a.vente_id = v.id), 0) as avoirs
from public.stock_ventes v
left join public.stock_clients c on c.id = v.client_id;

create or replace view public.stock_clients_soldes with (security_invoker = true) as
select c.*,
  coalesce((select sum(v.total_ttc) from public.stock_ventes v where v.client_id = c.id and v.statut = 'validee'), 0) as total_achats,
  coalesce((select sum(x.montant) from public.stock_versements x where x.client_id = c.id), 0) as total_verse,
  coalesce((select sum(v.total_ttc) from public.stock_ventes v where v.client_id = c.id and v.statut = 'validee'), 0)
    - coalesce((select sum(x.montant) from public.stock_versements x where x.client_id = c.id), 0)
    - coalesce((select sum(a.total) from public.stock_avoirs a where a.client_id = c.id), 0) as solde,
  (select count(*) from public.stock_ventes v where v.client_id = c.id and v.statut = 'validee')::integer as nb_ventes,
  (select max(v.date_vente) from public.stock_ventes v where v.client_id = c.id and v.statut = 'validee') as derniere_vente,
  coalesce((select sum(a.total) from public.stock_avoirs a where a.client_id = c.id), 0) as total_avoirs
from public.stock_clients c;

create or replace view public.stock_commandes_etat with (security_invoker = true) as
select c.*,
  cl.nom as client_nom,
  coalesce((select sum(l.montant) from public.stock_commande_lignes l where l.commande_id = c.id), 0) as total_brut,
  greatest(coalesce((select sum(l.montant) from public.stock_commande_lignes l where l.commande_id = c.id), 0) - c.remise, 0) as total,
  (select coalesce(sum(l.quantite), 0) from public.stock_commande_lignes l where l.commande_id = c.id)::integer as nb_articles
from public.stock_commandes c
left join public.stock_clients cl on cl.id = c.client_id;

create or replace view public.stock_avoirs_etat with (security_invoker = true) as
select a.*, c.nom as client_nom, v.numero as vente_numero,
  (select coalesce(sum(l.quantite), 0) from public.stock_avoir_lignes l where l.avoir_id = a.id)::integer as nb_articles
from public.stock_avoirs a
left join public.stock_clients c on c.id = a.client_id
left join public.stock_ventes v on v.id = a.vente_id;

create or replace view public.stock_matieres_etat with (security_invoker = true) as
select m.*,
  coalesce((select sum(x.quantite) from public.stock_matiere_mvts x where x.matiere_id = m.id), 0)::numeric(14,3) as stock,
  coalesce((select sum(al.montant) / nullif(sum(al.quantite), 0) from public.stock_achat_lignes al where al.matiere_id = m.id), 0)::numeric(14,2) as cout_moyen
from public.stock_matieres m;

create or replace view public.stock_fournisseurs_soldes with (security_invoker = true) as
select f.*,
  coalesce((select sum(a.total) from public.stock_achats a where a.fournisseur_id = f.id), 0) as total_achats,
  coalesce((select sum(p.montant) from public.stock_paiements_fournisseurs p where p.fournisseur_id = f.id), 0) as total_paye,
  coalesce((select sum(a.total) from public.stock_achats a where a.fournisseur_id = f.id), 0)
    - coalesce((select sum(p.montant) from public.stock_paiements_fournisseurs p where p.fournisseur_id = f.id), 0) as solde
from public.stock_fournisseurs f;

create or replace view public.stock_achats_etat with (security_invoker = true) as
select a.*, f.nom as fournisseur_nom,
  coalesce((select sum(p.montant) from public.stock_paiements_fournisseurs p where p.achat_id = a.id), 0) as paye,
  a.total - coalesce((select sum(p.montant) from public.stock_paiements_fournisseurs p where p.achat_id = a.id), 0) as reste
from public.stock_achats a
left join public.stock_fournisseurs f on f.id = a.fournisseur_id;

create or replace view public.stock_lignes_detail with (security_invoker = true) as
select l.*, v.date_vente, v.client_id, v.statut, v.numero
from public.stock_vente_lignes l
join public.stock_ventes v on v.id = l.vente_id;

-- ---------------------------------------------------------------- fonctions
-- Crée un devis ou une commande. p_lignes : [{"produit_id","quantite","prix"}]
create or replace function public.stock_creer_commande(
  p_type text, p_client uuid, p_date date, p_echeance date, p_lignes jsonb, p_remise numeric default 0, p_note text default null
) returns uuid language plpgsql security invoker set search_path = '' as $$
declare
  v_atelier uuid := public.atelier_courant();
  v_annee integer := extract(year from coalesce(p_date, current_date))::integer;
  v_id uuid := gen_random_uuid();
  l jsonb;
begin
  if not public.a_droit('stock') then raise exception 'Accès refusé'; end if;
  if p_type not in ('devis','commande') then raise exception 'Type invalide'; end if;
  if p_lignes is null or jsonb_array_length(p_lignes) = 0 then raise exception 'Aucun article'; end if;
  insert into public.stock_commandes(id, atelier_id, type, numero, client_id, date_doc, date_echeance, remise, note)
  values (v_id, v_atelier, p_type,
          case when p_type = 'devis' then 'D-' else 'BC-' end || v_annee || '-' ||
            lpad(public.atelier_prochain_numero(p_type, v_annee)::text, 4, '0'),
          p_client, coalesce(p_date, current_date), p_echeance, coalesce(p_remise, 0), nullif(trim(p_note), ''));
  for l in select * from jsonb_array_elements(p_lignes) loop
    if (l->>'quantite')::integer <= 0 then raise exception 'Quantité invalide'; end if;
    if not exists (select 1 from public.stock_produits p where p.id = (l->>'produit_id')::uuid and p.atelier_id = v_atelier) then
      raise exception 'Produit introuvable';
    end if;
    insert into public.stock_commande_lignes(atelier_id, commande_id, produit_id, quantite, prix_unitaire)
    values (v_atelier, v_id, (l->>'produit_id')::uuid, (l->>'quantite')::integer, (l->>'prix')::numeric);
  end loop;
  return v_id;
end $$;

-- Devis accepté → nouvelle commande (avec les mêmes articles)
create or replace function public.stock_devis_vers_commande(p_devis uuid)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare d record; v_lignes jsonb;
begin
  if not public.a_droit('stock') then raise exception 'Accès refusé'; end if;
  select * into d from public.stock_commandes where id = p_devis and atelier_id = public.atelier_courant() and type = 'devis' for update;
  if not found then raise exception 'Devis introuvable'; end if;
  select jsonb_agg(jsonb_build_object('produit_id', produit_id, 'quantite', quantite, 'prix', prix_unitaire)) into v_lignes
  from public.stock_commande_lignes where commande_id = p_devis;
  update public.stock_commandes set statut = 'acceptee' where id = p_devis;
  return public.stock_creer_commande('commande', d.client_id, current_date, null, v_lignes, d.remise,
                                     trim('Suite au devis ' || d.numero || coalesce(' — ' || d.note, '')));
end $$;

-- Devis ou commande → vente (facture + BL, stock déduit)
create or replace function public.stock_commande_vers_vente(
  p_commande uuid, p_versement numeric default 0, p_mode text default 'especes', p_autoriser_negatif boolean default false
) returns uuid language plpgsql security invoker set search_path = '' as $$
declare c record; v_lignes jsonb; v_vente uuid;
begin
  if not public.a_droit('stock') then raise exception 'Accès refusé'; end if;
  select * into c from public.stock_commandes where id = p_commande and atelier_id = public.atelier_courant() for update;
  if not found then raise exception 'Document introuvable'; end if;
  if c.vente_id is not null then raise exception 'Déjà facturé'; end if;
  if c.statut in ('annulee','refusee') then raise exception 'Document annulé ou refusé'; end if;
  select jsonb_agg(jsonb_build_object('produit_id', produit_id, 'quantite', quantite, 'prix', prix_unitaire)) into v_lignes
  from public.stock_commande_lignes where commande_id = p_commande;
  -- libérer la réservation avant le contrôle du stock
  update public.stock_commandes set statut = case when type = 'devis' then 'acceptee' else 'livree' end where id = p_commande;
  v_vente := public.stock_creer_vente(c.client_id, current_date, v_lignes, c.remise, p_versement, p_mode,
                                      null, null, null, (case when c.type = 'devis' then 'Devis ' else 'Commande ' end) || c.numero,
                                      p_autoriser_negatif);
  update public.stock_commandes set vente_id = v_vente where id = p_commande;
  return v_vente;
end $$;

-- Avoir (retour client). p_lignes : [{"produit_id","quantite","prix"}]
create or replace function public.stock_creer_avoir(
  p_client uuid, p_vente uuid, p_lignes jsonb, p_motif text default null, p_remettre boolean default true
) returns uuid language plpgsql security invoker set search_path = '' as $$
declare
  v_atelier uuid := public.atelier_courant();
  v_annee integer := extract(year from current_date)::integer;
  v_id uuid := gen_random_uuid();
  v_num text;
  v_total numeric := 0;
  l jsonb;
begin
  if not public.a_droit('stock') then raise exception 'Accès refusé'; end if;
  if p_lignes is null or jsonb_array_length(p_lignes) = 0 then raise exception 'Aucun article'; end if;
  if not exists (select 1 from public.stock_clients where id = p_client and atelier_id = v_atelier) then raise exception 'Client introuvable'; end if;
  if p_vente is not null and not exists (select 1 from public.stock_ventes where id = p_vente and client_id = p_client and atelier_id = v_atelier) then
    raise exception 'La vente ne correspond pas au client';
  end if;
  v_num := 'AV-' || v_annee || '-' || lpad(public.atelier_prochain_numero('avoir', v_annee)::text, 4, '0');
  insert into public.stock_avoirs(id, atelier_id, numero, client_id, vente_id, remis_en_stock, motif)
  values (v_id, v_atelier, v_num, p_client, p_vente, coalesce(p_remettre, true), nullif(trim(p_motif), ''));
  for l in select * from jsonb_array_elements(p_lignes) loop
    if (l->>'quantite')::integer <= 0 then raise exception 'Quantité invalide'; end if;
    if not exists (select 1 from public.stock_produits p where p.id = (l->>'produit_id')::uuid and p.atelier_id = v_atelier) then
      raise exception 'Produit introuvable';
    end if;
    insert into public.stock_avoir_lignes(atelier_id, avoir_id, produit_id, quantite, prix_unitaire)
    values (v_atelier, v_id, (l->>'produit_id')::uuid, (l->>'quantite')::integer, (l->>'prix')::numeric);
    v_total := v_total + round((l->>'quantite')::integer * (l->>'prix')::numeric, 2);
    if coalesce(p_remettre, true) then
      insert into public.stock_mouvements(atelier_id, produit_id, type, quantite, note)
      values (v_atelier, (l->>'produit_id')::uuid, 'retour', (l->>'quantite')::integer, 'Avoir ' || v_num);
    end if;
  end loop;
  update public.stock_avoirs set total = v_total where id = v_id;
  return v_id;
end $$;

-- Achat de matières. p_lignes : [{"matiere_id","quantite","prix"}]
create or replace function public.stock_creer_achat(
  p_fournisseur uuid, p_date date, p_lignes jsonb, p_paiement numeric default 0, p_mode text default 'especes', p_note text default null
) returns uuid language plpgsql security invoker set search_path = '' as $$
declare
  v_atelier uuid := public.atelier_courant();
  v_annee integer := extract(year from coalesce(p_date, current_date))::integer;
  v_id uuid := gen_random_uuid();
  v_total numeric := 0;
  l jsonb;
begin
  if not public.a_droit('stock') then raise exception 'Accès refusé'; end if;
  if p_lignes is null or jsonb_array_length(p_lignes) = 0 then raise exception 'Aucune matière'; end if;
  if p_fournisseur is null and coalesce(p_paiement, 0) > 0 then raise exception 'Choisissez le fournisseur pour enregistrer un paiement'; end if;
  insert into public.stock_achats(id, atelier_id, numero, fournisseur_id, date_achat, note)
  values (v_id, v_atelier, 'A-' || v_annee || '-' || lpad(public.atelier_prochain_numero('achat', v_annee)::text, 4, '0'),
          p_fournisseur, coalesce(p_date, current_date), nullif(trim(p_note), ''));
  for l in select * from jsonb_array_elements(p_lignes) loop
    if (l->>'quantite')::numeric <= 0 then raise exception 'Quantité invalide'; end if;
    if not exists (select 1 from public.stock_matieres m where m.id = (l->>'matiere_id')::uuid and m.atelier_id = v_atelier) then
      raise exception 'Matière introuvable';
    end if;
    insert into public.stock_achat_lignes(atelier_id, achat_id, matiere_id, quantite, prix_unitaire)
    values (v_atelier, v_id, (l->>'matiere_id')::uuid, (l->>'quantite')::numeric, (l->>'prix')::numeric);
    insert into public.stock_matiere_mvts(atelier_id, matiere_id, type, quantite, achat_id, note)
    values (v_atelier, (l->>'matiere_id')::uuid, 'achat', (l->>'quantite')::numeric, v_id, 'Achat');
    v_total := v_total + round((l->>'quantite')::numeric * (l->>'prix')::numeric, 2);
  end loop;
  update public.stock_achats set total = v_total where id = v_id;
  if coalesce(p_paiement, 0) > 0 then
    insert into public.stock_paiements_fournisseurs(atelier_id, fournisseur_id, achat_id, date_paiement, montant, mode, note)
    values (v_atelier, p_fournisseur, v_id, coalesce(p_date, current_date), least(p_paiement, v_total), coalesce(p_mode, 'especes'), 'Paiement à l''achat');
  end if;
  return v_id;
end $$;

-- Fabrication : ajoute des robes au stock et consomme les matières de la nomenclature
create or replace function public.stock_fabrication(p_produit uuid, p_quantite integer, p_note text default null)
returns void language plpgsql security invoker set search_path = '' as $$
declare v_atelier uuid := public.atelier_courant(); n record;
begin
  if not public.a_droit('stock') then raise exception 'Accès refusé'; end if;
  if p_quantite is null or p_quantite <= 0 then raise exception 'Quantité invalide'; end if;
  if not exists (select 1 from public.stock_produits where id = p_produit and atelier_id = v_atelier) then raise exception 'Produit introuvable'; end if;
  insert into public.stock_mouvements(atelier_id, produit_id, type, quantite, note)
  values (v_atelier, p_produit, 'entree', p_quantite, coalesce(nullif(trim(p_note), ''), 'Fabrication'));
  for n in select * from public.stock_nomenclature where produit_id = p_produit loop
    insert into public.stock_matiere_mvts(atelier_id, matiere_id, type, quantite, produit_id, note)
    values (v_atelier, n.matiere_id, 'consommation', -(n.quantite * p_quantite), p_produit, 'Fabrication de ' || p_quantite || ' pièce(s)');
  end loop;
end $$;

revoke execute on function public.stock_creer_commande(text, uuid, date, date, jsonb, numeric, text) from anon, public;
revoke execute on function public.stock_devis_vers_commande(uuid) from anon, public;
revoke execute on function public.stock_commande_vers_vente(uuid, numeric, text, boolean) from anon, public;
revoke execute on function public.stock_creer_avoir(uuid, uuid, jsonb, text, boolean) from anon, public;
revoke execute on function public.stock_creer_achat(uuid, date, jsonb, numeric, text, text) from anon, public;
revoke execute on function public.stock_fabrication(uuid, integer, text) from anon, public;
grant execute on function public.stock_creer_commande(text, uuid, date, date, jsonb, numeric, text) to authenticated;
grant execute on function public.stock_devis_vers_commande(uuid) to authenticated;
grant execute on function public.stock_commande_vers_vente(uuid, numeric, text, boolean) to authenticated;
grant execute on function public.stock_creer_avoir(uuid, uuid, jsonb, text, boolean) to authenticated;
grant execute on function public.stock_creer_achat(uuid, date, jsonb, numeric, text, text) to authenticated;
grant execute on function public.stock_fabrication(uuid, integer, text) to authenticated;
