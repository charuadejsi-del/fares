-- Phase 4 : droits par atelier, comptable seul à voir/fixer les montants, délais de suivi
alter table public.atelier_membres
  add column if not exists perm_coupe boolean not null default false,
  add column if not exists perm_applique boolean not null default false,
  add column if not exists perm_finition boolean not null default false;
-- les responsables broderie gardent pour l'instant l'accès aux nouveaux ateliers
update public.atelier_membres set perm_coupe = true, perm_applique = true, perm_finition = true
where perm_broderie and role <> 'admin' and not (perm_coupe or perm_applique or perm_finition);

alter table public.ateliers add column if not exists delais jsonb not null
  default '{"coupe":3,"broderie":10,"applique":5,"akkach":5,"couture":15,"finition":5}'::jsonb;

create or replace function public.a_droit(p_espace text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.atelier_membres m
    where m.user_id = auth.uid() and m.actif
      and (m.role = 'admin'
        or (p_espace = 'broderie' and m.perm_broderie)
        or (p_espace = 'paie' and m.perm_paie)
        or (p_espace = 'stock' and m.perm_stock)
        or (p_espace = 'coupe' and m.perm_coupe)
        or (p_espace = 'applique' and m.perm_applique)
        or (p_espace = 'finition' and m.perm_finition))
  )
$$;

-- Variante : écriture autorisée pour plusieurs espaces
create or replace function public._atelier_policies2(p_table text, p_lecture text[], p_ecriture text[])
returns void language plpgsql set search_path = '' as $$
declare lect text; ecr text;
begin
  select string_agg(format('(select public.a_droit(%L))', e), ' or ') into lect from unnest(p_lecture) e;
  select string_agg(format('(select public.a_droit(%L))', e), ' or ') into ecr from unnest(p_ecriture) e;
  execute format('drop policy if exists %I on public.%I', p_table || '_lecture', p_table);
  execute format('drop policy if exists %I on public.%I', p_table || '_ajout', p_table);
  execute format('drop policy if exists %I on public.%I', p_table || '_modif', p_table);
  execute format('drop policy if exists %I on public.%I', p_table || '_suppr', p_table);
  execute format('create policy %I on public.%I for select to authenticated using (atelier_id = (select public.atelier_courant()) and (%s))', p_table || '_lecture', p_table, lect);
  execute format('create policy %I on public.%I for insert to authenticated with check (atelier_id = (select public.atelier_courant()) and (%s))', p_table || '_ajout', p_table, ecr);
  execute format('create policy %I on public.%I for update to authenticated using (atelier_id = (select public.atelier_courant()) and (%s)) with check (atelier_id = (select public.atelier_courant()))', p_table || '_modif', p_table, ecr);
  execute format('create policy %I on public.%I for delete to authenticated using (atelier_id = (select public.atelier_courant()) and (%s))', p_table || '_suppr', p_table, ecr);
end $$;
revoke execute on function public._atelier_policies2(text, text[], text[]) from anon, authenticated, public;

select public._atelier_policies2('broderie_lots', array['broderie','coupe','applique','finition','paie','stock'], array['coupe','broderie','applique','finition','paie']);
select public._atelier_policies2('lot_mouvements', array['broderie','coupe','applique','finition','paie','stock'], array['coupe','broderie','applique','finition','paie']);
select public._atelier_policies2('broderie_pieces', array['paie','coupe','applique','finition'], array['paie','coupe','applique','finition']);
select public._atelier_policies2('broderie_ouvriers', array['broderie','paie','coupe','applique','finition'], array['paie','broderie','coupe','applique','finition']);
select public._atelier_policies2('travail_taches', array['broderie','paie','coupe','applique','finition'], array['paie']);
select public._atelier_policies2('couture_ateliers', array['paie','coupe','broderie','applique','finition'], array['paie']);
select public._atelier_policies2('couture_envois', array['paie','coupe','broderie','applique','finition'], array['paie']);
select public._atelier_policies2('couture_retours', array['paie','coupe','broderie','applique','finition'], array['paie']);
select public._atelier_policies2('couture_tarifs', array['paie'], array['paie']);
select public._atelier_policies2('couture_paiements', array['paie'], array['paie']);

-- Seuls l'administrateur et le comptable fixent les salaires et prix des ouvriers
create or replace function public.ouvrier_proteger_montants()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if public.a_droit('paie') then return new; end if;
  if tg_op = 'INSERT' then
    new.salaire_mensuel := 0; new.prix_piece := 0; new.tarif_1000 := 0;
  else
    new.salaire_mensuel := old.salaire_mensuel; new.prix_piece := old.prix_piece; new.tarif_1000 := old.tarif_1000;
  end if;
  return new;
end $$;
drop trigger if exists proteger_montants on public.broderie_ouvriers;
create trigger proteger_montants before insert or update on public.broderie_ouvriers
  for each row execute function public.ouvrier_proteger_montants();

-- Travail saisi par un responsable d'atelier : prix calculé par le serveur
create or replace function public.piece_prix_serveur()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_mode text; v_prix numeric; v_tache numeric;
begin
  if public.a_droit('paie') then return new; end if;
  select mode_paie, prix_piece into v_mode, v_prix from public.broderie_ouvriers where id = new.ouvrier_id;
  if v_mode = 'mois' then
    new.prix_unitaire := 0;
  else
    select prix into v_tache from public.travail_taches where id = new.tache_id;
    new.prix_unitaire := coalesce(nullif(v_tache, 0), v_prix, 0);
  end if;
  return new;
end $$;
drop trigger if exists prix_serveur on public.broderie_pieces;
create trigger prix_serveur before insert or update on public.broderie_pieces
  for each row execute function public.piece_prix_serveur();

-- L'akkach se fait à la presse à chaud de la finition
update public.travail_taches set departement = 'Finition', nom = 'Presse à chaud (akkach)' where nom = 'Akkach (presse)' and departement = 'Akkach';
update public.broderie_ouvriers set departement = 'Finition' where departement = 'Akkach';
