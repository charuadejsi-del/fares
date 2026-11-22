-- Warchati : vitrine réservée, essai gratuit, packs d'abonnement, paiement BaridiMob avec preuve
alter table public.ateliers
  add column if not exists vitrine_autorisee boolean not null default false,
  add column if not exists max_employes int check (max_employes is null or max_employes >= 0);
update public.ateliers set vitrine_autorisee = true where code = 'ghania';

-- vitrine : seuls les ateliers autorisés sont publiés
do $$ begin
  if not exists (select 1 from pg_proc where proname = 'vitrine_catalogue_interne') then
    alter function public.vitrine_catalogue(uuid) rename to vitrine_catalogue_interne;
  end if;
end $$;
revoke execute on function public.vitrine_catalogue_interne(uuid) from anon, authenticated, public;
create or replace function public.vitrine_catalogue(p_atelier uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when exists (select 1 from public.ateliers where id = p_atelier and vitrine_autorisee and not suspendu)
              then public.vitrine_catalogue_interne(p_atelier) end
$$;
create or replace function public.vitrine_catalogue_code(p_code text) returns jsonb
language sql stable security definer set search_path = '' as $$
  select public.vitrine_catalogue((select id from public.ateliers where code = lower(trim(p_code))))
$$;
grant execute on function public.vitrine_catalogue(uuid), public.vitrine_catalogue_code(text) to anon, authenticated;

-- réglages de la plateforme (une seule ligne)
create table if not exists public.plateforme_reglages (
  id int primary key default 1 check (id = 1),
  rip text, titulaire text,
  jours_essai int not null default 7 check (jours_essai between 0 and 90)
);
insert into public.plateforme_reglages(id) values (1) on conflict do nothing;
alter table public.plateforme_reglages enable row level security;
drop policy if exists reglages_lecture on public.plateforme_reglages;
create policy reglages_lecture on public.plateforme_reglages for select to authenticated using (true);

-- packs d'abonnement
create table if not exists public.packs (
  id uuid primary key default gen_random_uuid(),
  nom text not null check (length(trim(nom)) > 0),
  duree_mois int not null check (duree_mois between 1 and 60),
  prix numeric(12,2) not null check (prix >= 0),
  max_employes int check (max_employes is null or max_employes >= 0),
  description text,
  actif boolean not null default true,
  ordre int not null default 0,
  created_at timestamptz not null default now()
);
alter table public.packs enable row level security;
drop policy if exists packs_lecture on public.packs;
create policy packs_lecture on public.packs for select to authenticated using (actif or public.est_proprietaire());

-- demandes d'abonnement (preuve de paiement)
create table if not exists public.demandes_abonnement (
  id uuid primary key default gen_random_uuid(),
  atelier_id uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  pack_id uuid not null references public.packs(id) on delete restrict,
  montant numeric(12,2) not null,
  preuve_path text not null,
  statut text not null default 'attente' check (statut in ('attente','validee','refusee')),
  motif text,
  user_id uuid default auth.uid(),
  created_at timestamptz not null default now(),
  traitee_le timestamptz
);
create index if not exists demandes_atelier_idx on public.demandes_abonnement(atelier_id, created_at desc);
alter table public.demandes_abonnement enable row level security;
drop policy if exists demandes_lecture on public.demandes_abonnement;
drop policy if exists demandes_ajout on public.demandes_abonnement;
create policy demandes_lecture on public.demandes_abonnement for select to authenticated
  using (atelier_id = (select public.atelier_courant()) or (select public.est_proprietaire()));
create policy demandes_ajout on public.demandes_abonnement for insert to authenticated
  with check (atelier_id = (select public.atelier_courant()) and statut = 'attente'
              and exists (select 1 from public.atelier_membres m where m.user_id = auth.uid() and m.role = 'admin' and m.actif));

-- stockage privé des preuves : chaque atelier dans son dossier, le propriétaire voit tout
insert into storage.buckets (id, name, public) values ('preuves', 'preuves', false) on conflict (id) do nothing;
drop policy if exists preuves_ajout on storage.objects;
drop policy if exists preuves_lecture on storage.objects;
create policy preuves_ajout on storage.objects for insert to authenticated
  with check (bucket_id = 'preuves' and (storage.foldername(name))[1] = (select public.atelier_courant())::text);
create policy preuves_lecture on storage.objects for select to authenticated
  using (bucket_id = 'preuves' and ((storage.foldername(name))[1] = (select public.atelier_courant())::text or (select public.est_proprietaire())));

-- création d'atelier en essai (compte déjà connecté sans atelier)
create or replace function public._code_atelier(p_nom text) returns text
language plpgsql security definer set search_path = '' as $$
declare b text; v text; i int := 2;
begin
  b := trim(both '-' from regexp_replace(lower(coalesce(p_nom, '')), '[^a-z0-9]+', '-', 'g'));
  b := left(b, 24);
  if length(b) < 3 then b := 'atelier-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 4); end if;
  v := b;
  while exists (select 1 from public.ateliers where code = v) loop v := b || '-' || i; i := i + 1; end loop;
  return v;
end $$;
revoke execute on function public._code_atelier(text) from anon, authenticated, public;

create or replace function public.atelier_creer(p_nom text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare j int;
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  if exists (select 1 from public.atelier_membres where user_id = auth.uid()) then raise exception 'Ce compte appartient déjà à un atelier'; end if;
  if public.est_proprietaire() then raise exception 'Le compte propriétaire ne peut pas avoir d''atelier'; end if;
  if coalesce(trim(p_nom), '') = '' then raise exception 'Le nom de l''atelier est obligatoire'; end if;
  select jours_essai into j from public.plateforme_reglages where id = 1;
  insert into public.ateliers(id, nom, code, abonnement, abonnement_fin)
    values (auth.uid(), trim(p_nom), public._code_atelier(p_nom), 'essai', current_date + coalesce(j, 7));
  insert into public.atelier_membres(user_id, atelier_id, nom, identifiant, role)
    select auth.uid(), auth.uid(), coalesce(split_part(u.email, '@', 1), ''), u.email, 'admin' from auth.users u where u.id = auth.uid();
  return auth.uid();
end $$;
grant execute on function public.atelier_creer(text) to authenticated;

-- ------------------------------------------------------------ propriétaire : packs, réglages, demandes
create or replace function public.proprio_save_pack(p_id uuid, p_nom text, p_duree int, p_prix numeric, p_max int, p_description text, p_actif boolean)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v uuid;
begin
  if not public.est_proprietaire() then raise exception 'Réservé au propriétaire de la plateforme'; end if;
  if p_id is null then
    insert into public.packs(nom, duree_mois, prix, max_employes, description, actif, ordre)
      values (trim(p_nom), p_duree, p_prix, p_max, nullif(trim(p_description), ''), p_actif, (select count(*) from public.packs)) returning id into v;
  else
    update public.packs set nom = trim(p_nom), duree_mois = p_duree, prix = p_prix, max_employes = p_max,
      description = nullif(trim(p_description), ''), actif = p_actif where id = p_id returning id into v;
  end if;
  return v;
end $$;

create or replace function public.proprio_reglages(p_rip text, p_titulaire text, p_jours int) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.est_proprietaire() then raise exception 'Réservé au propriétaire de la plateforme'; end if;
  update public.plateforme_reglages set rip = nullif(trim(p_rip), ''), titulaire = nullif(trim(p_titulaire), ''), jours_essai = p_jours where id = 1;
end $$;

create or replace function public.proprio_demandes()
returns table (id uuid, atelier_id uuid, atelier text, atelier_code text, pack text, duree_mois int, montant numeric,
               preuve_path text, statut text, motif text, created_at timestamptz, traitee_le timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.est_proprietaire() then raise exception 'Réservé au propriétaire de la plateforme'; end if;
  return query select d.id, d.atelier_id, a.nom, a.code, p.nom, p.duree_mois, d.montant, d.preuve_path, d.statut, d.motif, d.created_at, d.traitee_le
    from public.demandes_abonnement d join public.ateliers a on a.id = d.atelier_id join public.packs p on p.id = d.pack_id
    order by (d.statut = 'attente') desc, d.created_at desc limit 500;
end $$;

create or replace function public.proprio_valider_demande(p_id uuid) returns date
language plpgsql security definer set search_path = '' as $$
declare d public.demandes_abonnement; p public.packs; v date;
begin
  if not public.est_proprietaire() then raise exception 'Réservé au propriétaire de la plateforme'; end if;
  select * into d from public.demandes_abonnement where id = p_id and statut = 'attente' for update;
  if not found then raise exception 'Demande introuvable ou déjà traitée'; end if;
  select * into p from public.packs where id = d.pack_id;
  update public.ateliers set
    abonnement = case when p.duree_mois >= 12 then 'annuel' else 'mensuel' end,
    abonnement_fin = greatest(coalesce(abonnement_fin, current_date), current_date) + make_interval(months => p.duree_mois),
    max_employes = p.max_employes,
    suspendu = false
  where id = d.atelier_id returning abonnement_fin into v;
  update public.demandes_abonnement set statut = 'validee', traitee_le = now() where id = p_id;
  return v;
end $$;

create or replace function public.proprio_refuser_demande(p_id uuid, p_motif text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.est_proprietaire() then raise exception 'Réservé au propriétaire de la plateforme'; end if;
  update public.demandes_abonnement set statut = 'refusee', motif = nullif(trim(p_motif), ''), traitee_le = now() where id = p_id and statut = 'attente';
end $$;

create or replace function public.proprio_max_employes(p_atelier uuid, p_max int) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.est_proprietaire() then raise exception 'Réservé au propriétaire de la plateforme'; end if;
  update public.ateliers set max_employes = p_max where id = p_atelier;
end $$;

revoke execute on function public.proprio_save_pack(uuid, text, int, numeric, int, text, boolean), public.proprio_reglages(text, text, int),
  public.proprio_demandes(), public.proprio_valider_demande(uuid), public.proprio_refuser_demande(uuid, text), public.proprio_max_employes(uuid, int) from anon, public;
grant execute on function public.proprio_save_pack(uuid, text, int, numeric, int, text, boolean), public.proprio_reglages(text, text, int),
  public.proprio_demandes(), public.proprio_valider_demande(uuid), public.proprio_refuser_demande(uuid, text), public.proprio_max_employes(uuid, int) to authenticated;

-- liste des ateliers : ajout du maximum d'employés et des demandes en attente
drop function if exists public.proprio_ateliers();
create function public.proprio_ateliers()
returns table (id uuid, nom text, code text, telephone text, abonnement text, abonnement_fin date, suspendu boolean,
               membres bigint, derniere_activite timestamptz, created_at timestamptz, max_employes int, vitrine boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.est_proprietaire() then raise exception 'Réservé au propriétaire de la plateforme'; end if;
  return query
    select a.id, a.nom, a.code, a.telephone, a.abonnement, a.abonnement_fin, a.suspendu,
           (select count(*) from public.atelier_membres m where m.atelier_id = a.id),
           (select max(j.created_at) from public.journal_actions j where j.atelier_id = a.id),
           a.created_at, a.max_employes, a.vitrine_autorisee
    from public.ateliers a order by a.created_at;
end $$;
revoke execute on function public.proprio_ateliers() from anon, public;
grant execute on function public.proprio_ateliers() to authenticated;

-- fin des codes d'activation
drop function if exists public.atelier_activer(text, text, text);
drop function if exists public.proprio_codes();
drop function if exists public.proprio_creer_code(text, int, text);
drop function if exists public.proprio_supprimer_code(text);
drop table if exists public.codes_activation;
