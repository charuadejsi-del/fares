-- Warchati : plateforme multi-ateliers (abonnements, codes d'activation, propriétaire, code atelier)
alter table public.ateliers
  add column if not exists code text,
  add column if not exists abonnement text not null default 'annuel',
  add column if not exists abonnement_fin date,
  add column if not exists suspendu boolean not null default false,
  add column if not exists created_at timestamptz not null default now();
do $$ begin
  alter table public.ateliers add constraint ateliers_code_format check (code is null or code ~ '^[a-z0-9-]{3,30}$');
  alter table public.ateliers add constraint ateliers_code_unique unique (code);
  alter table public.ateliers add constraint ateliers_abonnement_check check (abonnement in ('essai','mensuel','annuel','illimite'));
exception when duplicate_object or duplicate_table then null; end $$;
update public.ateliers set code = 'ghania', abonnement = 'illimite' where id = '61ffe427-40dc-46f0-90c4-5158b63fa456' and code is null;

create table if not exists public.plateforme_proprietaires (user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.plateforme_proprietaires enable row level security;
insert into public.plateforme_proprietaires values ('61ffe427-40dc-46f0-90c4-5158b63fa456') on conflict do nothing;

create table if not exists public.codes_activation (
  code text primary key,
  abonnement text not null check (abonnement in ('essai','mensuel','annuel')),
  duree_mois int not null check (duree_mois between 1 and 60),
  note text,
  utilise_par uuid references public.ateliers(id) on delete set null,
  utilise_le timestamptz,
  created_at timestamptz not null default now()
);
alter table public.codes_activation enable row level security;

create or replace function public.est_proprietaire() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.plateforme_proprietaires where user_id = auth.uid())
$$;

-- Abonnement valide de l'atelier courant (sinon : lecture seule)
create or replace function public.atelier_actif() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select not a.suspendu and (a.abonnement = 'illimite' or a.abonnement_fin is null or a.abonnement_fin >= current_date)
                   from public.ateliers a where a.id = public.atelier_courant()), false)
$$;

-- Plus de création d'atelier sans code d'activation
create or replace function public.atelier_initialiser(p_nom text default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v uuid;
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  select atelier_id into v from public.atelier_membres where user_id = auth.uid();
  if v is not null then return v; end if;
  raise exception 'CODE_ACTIVATION_REQUIS';
end $$;

create or replace function public.atelier_activer(p_nom text, p_code text, p_activation text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare c public.codes_activation; v_code text := lower(trim(p_code));
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  if exists (select 1 from public.atelier_membres where user_id = auth.uid()) then raise exception 'Ce compte appartient déjà à un atelier'; end if;
  if coalesce(trim(p_nom), '') = '' then raise exception 'Le nom de l''atelier est obligatoire'; end if;
  if v_code !~ '^[a-z0-9-]{3,30}$' then raise exception 'Code atelier : 3 à 30 lettres minuscules, chiffres ou tirets'; end if;
  select * into c from public.codes_activation where code = upper(trim(p_activation)) and utilise_par is null for update;
  if not found then raise exception 'Code d''activation invalide ou déjà utilisé'; end if;
  if exists (select 1 from public.ateliers where code = v_code) then raise exception 'Ce code atelier est déjà pris, choisissez-en un autre'; end if;
  insert into public.ateliers(id, nom, code, abonnement, abonnement_fin)
    values (auth.uid(), trim(p_nom), v_code, c.abonnement, current_date + make_interval(months => c.duree_mois));
  insert into public.atelier_membres(user_id, atelier_id, nom, identifiant, role)
    select auth.uid(), auth.uid(), coalesce(split_part(u.email, '@', 1), ''), u.email, 'admin' from auth.users u where u.id = auth.uid();
  update public.codes_activation set utilise_par = auth.uid(), utilise_le = now() where code = c.code;
  return auth.uid();
end $$;

-- ------------------------------------------------------------ espace propriétaire
create or replace function public.proprio_ateliers()
returns table (id uuid, nom text, code text, telephone text, abonnement text, abonnement_fin date, suspendu boolean,
               membres bigint, derniere_activite timestamptz, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.est_proprietaire() then raise exception 'Réservé au propriétaire de la plateforme'; end if;
  return query
    select a.id, a.nom, a.code, a.telephone, a.abonnement, a.abonnement_fin, a.suspendu,
           (select count(*) from public.atelier_membres m where m.atelier_id = a.id),
           (select max(j.created_at) from public.journal_actions j where j.atelier_id = a.id),
           a.created_at
    from public.ateliers a order by a.created_at;
end $$;

create or replace function public.proprio_prolonger(p_atelier uuid, p_mois int, p_abonnement text default null) returns date
language plpgsql security definer set search_path = '' as $$
declare v date;
begin
  if not public.est_proprietaire() then raise exception 'Réservé au propriétaire de la plateforme'; end if;
  update public.ateliers set
    abonnement = coalesce(p_abonnement, case when abonnement in ('essai','illimite') then 'mensuel' else abonnement end),
    abonnement_fin = greatest(coalesce(abonnement_fin, current_date), current_date) + make_interval(months => p_mois)
  where id = p_atelier returning abonnement_fin into v;
  return v;
end $$;

create or replace function public.proprio_illimite(p_atelier uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.est_proprietaire() then raise exception 'Réservé au propriétaire de la plateforme'; end if;
  update public.ateliers set abonnement = 'illimite', abonnement_fin = null where id = p_atelier;
end $$;

create or replace function public.proprio_suspendre(p_atelier uuid, p_suspendu boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.est_proprietaire() then raise exception 'Réservé au propriétaire de la plateforme'; end if;
  update public.ateliers set suspendu = p_suspendu where id = p_atelier;
end $$;

create or replace function public.proprio_codes()
returns table (code text, abonnement text, duree_mois int, note text, atelier text, utilise_le timestamptz, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.est_proprietaire() then raise exception 'Réservé au propriétaire de la plateforme'; end if;
  return query select c.code, c.abonnement, c.duree_mois, c.note, a.nom, c.utilise_le, c.created_at
    from public.codes_activation c left join public.ateliers a on a.id = c.utilise_par order by c.created_at desc;
end $$;

create or replace function public.proprio_creer_code(p_abonnement text, p_mois int, p_note text default null) returns text
language plpgsql security definer set search_path = '' as $$
declare v text;
begin
  if not public.est_proprietaire() then raise exception 'Réservé au propriétaire de la plateforme'; end if;
  loop
    v := 'WAR-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    exit when not exists (select 1 from public.codes_activation where code = v);
  end loop;
  insert into public.codes_activation(code, abonnement, duree_mois, note) values (v, p_abonnement, p_mois, nullif(trim(p_note), ''));
  return v;
end $$;

create or replace function public.proprio_supprimer_code(p_code text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.est_proprietaire() then raise exception 'Réservé au propriétaire de la plateforme'; end if;
  delete from public.codes_activation where code = p_code and utilise_par is null;
end $$;

revoke execute on function public.proprio_ateliers(), public.proprio_prolonger(uuid, int, text), public.proprio_illimite(uuid),
  public.proprio_suspendre(uuid, boolean), public.proprio_codes(), public.proprio_creer_code(text, int, text),
  public.proprio_supprimer_code(text), public.atelier_activer(text, text, text) from anon, public;
grant execute on function public.proprio_ateliers(), public.proprio_prolonger(uuid, int, text), public.proprio_illimite(uuid),
  public.proprio_suspendre(uuid, boolean), public.proprio_codes(), public.proprio_creer_code(text, int, text),
  public.proprio_supprimer_code(text), public.atelier_activer(text, text, text), public.est_proprietaire(), public.atelier_actif() to authenticated;

-- ------------------------------------------------------------ abonnement expiré = lecture seule
do $$
declare p record; cond text := '(select public.atelier_actif())';
begin
  for p in select tablename, policyname, cmd, qual, with_check from pg_policies
           where schemaname = 'public' and policyname ~ '_(ajout|modif|suppr)$' loop
    if p.cmd = 'INSERT' and position('atelier_actif' in coalesce(p.with_check, '')) = 0 then
      execute format('alter policy %I on public.%I with check ((%s) and %s)', p.policyname, p.tablename, p.with_check, cond);
    elsif p.cmd in ('UPDATE', 'DELETE') and position('atelier_actif' in coalesce(p.qual, '')) = 0 then
      execute format('alter policy %I on public.%I using ((%s) and %s)', p.policyname, p.tablename, p.qual, cond);
    end if;
  end loop;
end $$;

-- Les générateurs de règles ajoutent désormais la condition d'abonnement
create or replace function public._atelier_policies(p_table text, p_lecture text[], p_ecriture text)
returns void language plpgsql set search_path = '' as $$
begin
  perform public._atelier_policies2(p_table, p_lecture, array[p_ecriture]);
end $$;

create or replace function public._atelier_policies2(p_table text, p_lecture text[], p_ecriture text[])
returns void language plpgsql set search_path = '' as $$
declare lect text; ecr text;
begin
  select string_agg(format('(select public.a_droit(%L))', e), ' or ') into lect from unnest(p_lecture) e;
  select string_agg(format('(select public.a_droit(%L))', e), ' or ') into ecr from unnest(p_ecriture) e;
  ecr := '(' || ecr || ') and (select public.atelier_actif())';
  execute format('drop policy if exists %I on public.%I', p_table || '_lecture', p_table);
  execute format('drop policy if exists %I on public.%I', p_table || '_ajout', p_table);
  execute format('drop policy if exists %I on public.%I', p_table || '_modif', p_table);
  execute format('drop policy if exists %I on public.%I', p_table || '_suppr', p_table);
  execute format('create policy %I on public.%I for select to authenticated using (atelier_id = (select public.atelier_courant()) and (%s))', p_table || '_lecture', p_table, lect);
  execute format('create policy %I on public.%I for insert to authenticated with check (atelier_id = (select public.atelier_courant()) and %s)', p_table || '_ajout', p_table, ecr);
  execute format('create policy %I on public.%I for update to authenticated using (atelier_id = (select public.atelier_courant()) and %s) with check (atelier_id = (select public.atelier_courant()))', p_table || '_modif', p_table, ecr);
  execute format('create policy %I on public.%I for delete to authenticated using (atelier_id = (select public.atelier_courant()) and %s)', p_table || '_suppr', p_table, ecr);
end $$;
revoke execute on function public._atelier_policies(text, text[], text), public._atelier_policies2(text, text[], text[]) from anon, authenticated, public;

-- ------------------------------------------------------------ vitrine par code d'atelier
create or replace function public.vitrine_catalogue_code(p_code text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v uuid;
begin
  select id into v from public.ateliers where code = lower(trim(p_code)) and not suspendu;
  if v is null then return null; end if;
  return public.vitrine_catalogue(v);
end $$;
grant execute on function public.vitrine_catalogue_code(text) to anon, authenticated;
