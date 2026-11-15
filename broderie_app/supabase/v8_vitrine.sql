-- v8 : site vitrine public (lecture seule) alimenté par le stock
create table if not exists public.stock_modeles_info (
  id          uuid primary key default gen_random_uuid(),
  atelier_id  uuid not null default public.atelier_courant() references public.ateliers(id) on delete cascade,
  modele      text not null,
  description text,
  photos      text[] not null default '{}',
  publie      boolean not null default true,
  vedette     boolean not null default false,
  updated_at  timestamptz not null default now(),
  unique (atelier_id, modele)
);
alter table public.stock_modeles_info enable row level security;
select public._atelier_policies('stock_modeles_info', array['stock'], 'stock');

alter table public.ateliers add column if not exists vitrine_active boolean not null default true;
alter table public.ateliers add column if not exists vitrine_prix boolean not null default false;
alter table public.ateliers add column if not exists vitrine_url text;
alter table public.ateliers add column if not exists vitrine_slogan text;
alter table public.ateliers add column if not exists logo_public text;
alter table public.ateliers add column if not exists whatsapp text;

-- Stockage public des photos du site (dossier = id de l'atelier)
insert into storage.buckets (id, name, public) values ('vitrine', 'vitrine', true) on conflict (id) do update set public = true;
create policy vitrine_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'vitrine' and (storage.foldername(name))[1] = (select public.atelier_courant())::text);
create policy vitrine_update on storage.objects for update to authenticated
  using (bucket_id = 'vitrine' and (storage.foldername(name))[1] = (select public.atelier_courant())::text);
create policy vitrine_remove on storage.objects for delete to authenticated
  using (bucket_id = 'vitrine' and (storage.foldername(name))[1] = (select public.atelier_courant())::text);

-- Catalogue public : uniquement ce qui est publié, jamais les quantités exactes ni les clients.
create or replace function public.vitrine_catalogue(p_atelier uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  with a as (
    select * from public.ateliers where id = p_atelier and vitrine_active
  ), v as (
    select coalesce(p.modele, p.id::text) as cle, p.*,
      coalesce((select sum(m.quantite) from public.stock_mouvements m where m.produit_id = p.id), 0) as stock
    from public.stock_produits p
    where p.atelier_id = p_atelier and p.actif and exists (select 1 from a)
  ), g as (
    select v.cle,
      (array_agg(v.designation order by v.created_at))[1] as designation,
      (array_agg(v.categorie order by v.created_at))[1] as categorie,
      min(v.prix_gros) as prix,
      max(v.created_at) as cree,
      sum(greatest(v.stock, 0)) > 0 as disponible,
      coalesce(jsonb_agg(distinct v.taille) filter (where v.taille is not null), '[]') as tailles,
      coalesce(max(v.modele), (array_agg(v.reference))[1]) as cle_ref
    from v group by v.cle
  )
  select case when not exists (select 1 from a) then null else jsonb_build_object(
    'atelier', (select jsonb_build_object('nom', nom, 'activite', activite, 'telephone', telephone, 'adresse', adresse,
                 'email', email, 'facebook', qr_lien, 'logo', logo_public, 'slogan', vitrine_slogan, 'whatsapp', whatsapp,
                 'prix', vitrine_prix) from a),
    'modeles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'cle', g.cle, 'reference', g.cle_ref, 'designation', g.designation, 'categorie', g.categorie,
        'description', i.description, 'photos', coalesce(to_jsonb(i.photos), '[]'), 'vedette', coalesce(i.vedette, false),
        'prix', case when (select vitrine_prix from a) then g.prix end,
        'disponible', g.disponible, 'nouveau', g.cree > now() - interval '30 days',
        'couleurs', (select coalesce(jsonb_agg(jsonb_build_object('nom', c.couleur, 'disponible', c.dispo) order by c.couleur), '[]')
                     from (select v.couleur, sum(greatest(v.stock, 0)) > 0 as dispo from v where v.cle = g.cle and v.couleur is not null group by v.couleur) c),
        'tailles', g.tailles
      ) order by coalesce(i.vedette, false) desc, g.cree desc)
      from g
      left join public.stock_modeles_info i on i.atelier_id = p_atelier and i.modele = g.cle
      where coalesce(i.publie, true)
    ), '[]')
  ) end;
$$;
revoke execute on function public.vitrine_catalogue(uuid) from public;
grant execute on function public.vitrine_catalogue(uuid) to anon, authenticated;

-- v8c : l'envoi en mode "upsert" exige aussi le droit de lecture
create policy vitrine_select on storage.objects for select to authenticated
  using (bucket_id = 'vitrine' and (storage.foldername(name))[1] = (select public.atelier_courant())::text);

-- v9 : photos associées à une couleur (chemin -> couleur) ; vitrine_catalogue renvoie aussi photos_couleurs et cree
alter table public.stock_modeles_info add column if not exists photos_couleurs jsonb not null default '{}';
