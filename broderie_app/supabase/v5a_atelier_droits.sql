-- =====================================================================
-- v5a : atelier partagé, membres (admin / employés) et droits par espace
--   Espaces : broderie (saisie des points), paie (ouvriers, avances, paiements),
--             stock (produits, ventes, clients). L'admin a tous les droits.
--   L'id d'un atelier = id du compte qui l'a créé (les données existantes restent valables).
-- =====================================================================

create table if not exists public.ateliers (
  id          uuid primary key,
  nom         text not null default 'Mon atelier',
  activite    text default 'Atelier de broderie et confection',
  adresse     text,
  telephone   text,
  email       text,
  rc          text,
  nif         text,
  nis         text,
  art         text,
  rib         text,
  tva         numeric(5,2) not null default 0 check (tva >= 0 and tva <= 100),
  mentions    text,
  created_at  timestamptz not null default now()
);

create table if not exists public.atelier_membres (
  user_id        uuid primary key references auth.users(id) on delete cascade,
  atelier_id     uuid not null references public.ateliers(id) on delete cascade,
  nom            text not null default '',
  identifiant    text,
  role           text not null default 'employe' check (role in ('admin','employe')),
  perm_broderie  boolean not null default false,
  perm_paie      boolean not null default false,
  perm_stock     boolean not null default false,
  actif          boolean not null default true,
  created_at     timestamptz not null default now()
);
create index if not exists atelier_membres_atelier_idx on public.atelier_membres(atelier_id);

-- ---------------------------------------------------------------- fonctions d'accès
create or replace function public.atelier_courant()
returns uuid language sql stable security definer set search_path = '' as $$
  select m.atelier_id from public.atelier_membres m where m.user_id = auth.uid() and m.actif
$$;

create or replace function public.a_droit(p_espace text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.atelier_membres m
    where m.user_id = auth.uid() and m.actif
      and (m.role = 'admin'
        or (p_espace = 'broderie' and m.perm_broderie)
        or (p_espace = 'paie' and m.perm_paie)
        or (p_espace = 'stock' and m.perm_stock))
  )
$$;

-- Premier lancement d'un nouveau compte : il crée son atelier et en devient l'admin
create or replace function public.atelier_initialiser(p_nom text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v uuid;
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  select atelier_id into v from public.atelier_membres where user_id = auth.uid();
  if v is not null then return v; end if;
  insert into public.ateliers(id, nom) values (auth.uid(), coalesce(nullif(trim(p_nom), ''), 'Mon atelier'))
    on conflict (id) do nothing;
  insert into public.atelier_membres(user_id, atelier_id, nom, identifiant, role)
    select auth.uid(), auth.uid(), coalesce(split_part(u.email, '@', 1), ''), u.email, 'admin'
    from auth.users u where u.id = auth.uid();
  return auth.uid();
end $$;

revoke execute on function public.atelier_courant() from anon, public;
revoke execute on function public.a_droit(text) from anon, public;
revoke execute on function public.atelier_initialiser(text) from anon, public;
grant execute on function public.atelier_courant() to authenticated;
grant execute on function public.a_droit(text) to authenticated;
grant execute on function public.atelier_initialiser(text) to authenticated;

alter table public.ateliers enable row level security;
alter table public.atelier_membres enable row level security;

drop policy if exists ateliers_select on public.ateliers;
drop policy if exists ateliers_update on public.ateliers;
create policy ateliers_select on public.ateliers for select to authenticated
  using (id = (select public.atelier_courant()));
create policy ateliers_update on public.ateliers for update to authenticated
  using (id = (select public.atelier_courant()) and (select public.a_droit('admin')))
  with check (id = (select public.atelier_courant()));

drop policy if exists membres_select on public.atelier_membres;
create policy membres_select on public.atelier_membres for select to authenticated
  using (user_id = (select auth.uid())
         or (atelier_id = (select public.atelier_courant()) and (select public.a_droit('admin'))));
-- (création / modification des membres : uniquement via la fonction serveur « atelier-employes »)

-- ---------------------------------------------------------------- migration des comptes existants
insert into public.ateliers(id)
  select distinct u.id from auth.users u
  where exists (select 1 from public.broderie_ouvriers o where o.user_id = u.id)
     or exists (select 1 from public.broderie_types t where t.user_id = u.id)
on conflict (id) do nothing;

insert into public.atelier_membres(user_id, atelier_id, nom, identifiant, role)
  select a.id, a.id, coalesce(split_part(u.email, '@', 1), ''), u.email, 'admin'
  from public.ateliers a join auth.users u on u.id = a.id
on conflict (user_id) do nothing;

-- ---------------------------------------------------------------- atelier_id sur les tables broderie
do $$
declare t text;
begin
  foreach t in array array['broderie_ouvriers','broderie_dessins','broderie_machines','broderie_types',
                           'broderie_production','broderie_pieces','broderie_mouvements'] loop
    execute format('alter table public.%I add column if not exists atelier_id uuid references public.ateliers(id) on delete cascade', t);
    execute format('update public.%I set atelier_id = user_id where atelier_id is null', t);
    execute format('alter table public.%I alter column atelier_id set not null', t);
    execute format('alter table public.%I alter column atelier_id set default public.atelier_courant()', t);
    -- user_id = auteur de la saisie : supprimer un employé ne doit pas effacer ses saisies
    execute format('alter table public.%I drop constraint if exists %I', t, t || '_user_id_fkey');
    execute format('alter table public.%I alter column user_id drop not null', t);
    execute format('alter table public.%I add constraint %I foreign key (user_id) references auth.users(id) on delete set null', t, t || '_user_id_fkey');
    execute format('create index if not exists %I on public.%I(atelier_id)', t || '_atelier_idx', t);
    execute format('drop policy if exists %I on public.%I', t || '_owner_all', t);
  end loop;
end $$;

-- ---------------------------------------------------------------- règles d'accès par espace
-- Génère : lecture si un des espaces « lecture », écriture si l'espace « écriture »
create or replace function public._atelier_policies(p_table text, p_lecture text[], p_ecriture text)
returns void language plpgsql set search_path = '' as $$
declare lect text;
begin
  select string_agg(format('(select public.a_droit(%L))', e), ' or ') into lect from unnest(p_lecture) e;
  execute format('drop policy if exists %I on public.%I', p_table || '_lecture', p_table);
  execute format('drop policy if exists %I on public.%I', p_table || '_ajout', p_table);
  execute format('drop policy if exists %I on public.%I', p_table || '_modif', p_table);
  execute format('drop policy if exists %I on public.%I', p_table || '_suppr', p_table);
  execute format('create policy %I on public.%I for select to authenticated using (atelier_id = (select public.atelier_courant()) and (%s))',
                 p_table || '_lecture', p_table, lect);
  execute format('create policy %I on public.%I for insert to authenticated with check (atelier_id = (select public.atelier_courant()) and (select public.a_droit(%L)))',
                 p_table || '_ajout', p_table, p_ecriture);
  execute format('create policy %I on public.%I for update to authenticated using (atelier_id = (select public.atelier_courant()) and (select public.a_droit(%L))) with check (atelier_id = (select public.atelier_courant()))',
                 p_table || '_modif', p_table, p_ecriture);
  execute format('create policy %I on public.%I for delete to authenticated using (atelier_id = (select public.atelier_courant()) and (select public.a_droit(%L)))',
                 p_table || '_suppr', p_table, p_ecriture);
end $$;
revoke execute on function public._atelier_policies(text, text[], text) from anon, authenticated, public;

select public._atelier_policies('broderie_ouvriers',   array['broderie','paie'], 'paie');
select public._atelier_policies('broderie_dessins',    array['broderie','paie'], 'broderie');
select public._atelier_policies('broderie_machines',   array['broderie','paie'], 'broderie');
select public._atelier_policies('broderie_types',      array['broderie','paie'], 'admin');
select public._atelier_policies('broderie_production', array['broderie','paie'], 'broderie');
select public._atelier_policies('broderie_pieces',     array['paie'], 'paie');
select public._atelier_policies('broderie_mouvements', array['paie'], 'paie');

-- ---------------------------------------------------------------- contrôles de cohérence (même atelier)
create or replace function public.broderie_check_owner()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if not exists (select 1 from public.broderie_ouvriers o where o.id = new.ouvrier_id and o.atelier_id = new.atelier_id) then
    raise exception 'Ouvrier invalide';
  end if;
  if new.dessin_id is not null and not exists (select 1 from public.broderie_dessins d where d.id = new.dessin_id and d.atelier_id = new.atelier_id) then
    raise exception 'Dessin invalide';
  end if;
  if new.machine_id is not null and not exists (select 1 from public.broderie_machines m where m.id = new.machine_id and m.atelier_id = new.atelier_id) then
    raise exception 'Machine invalide';
  end if;
  if new.type_id is not null and not exists (select 1 from public.broderie_types t where t.id = new.type_id and t.atelier_id = new.atelier_id) then
    raise exception 'Type de broderie invalide';
  end if;
  return new;
end $$;

create or replace function public.broderie_check_ouvrier_owner()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if not exists (select 1 from public.broderie_ouvriers o where o.id = new.ouvrier_id and o.atelier_id = new.atelier_id) then
    raise exception 'Ouvrier invalide';
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------- photos (Storage) : dossier = id de l'atelier
drop policy if exists "broderie_photos_select" on storage.objects;
drop policy if exists "broderie_photos_insert" on storage.objects;
drop policy if exists "broderie_photos_update" on storage.objects;
drop policy if exists "broderie_photos_delete" on storage.objects;
create policy "broderie_photos_select" on storage.objects for select to authenticated
  using (bucket_id = 'broderie-dessins' and (storage.foldername(name))[1] = (select public.atelier_courant())::text);
create policy "broderie_photos_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'broderie-dessins' and (storage.foldername(name))[1] = (select public.atelier_courant())::text);
create policy "broderie_photos_update" on storage.objects for update to authenticated
  using (bucket_id = 'broderie-dessins' and (storage.foldername(name))[1] = (select public.atelier_courant())::text)
  with check (bucket_id = 'broderie-dessins' and (storage.foldername(name))[1] = (select public.atelier_courant())::text);
create policy "broderie_photos_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'broderie-dessins' and (storage.foldername(name))[1] = (select public.atelier_courant())::text);
