-- 013 : images dont la commande n'existe plus (nettoyage via la fonction dtf-dhd, action « cleanup »)
create or replace function dtf_orphan_images() returns setof text language sql stable security definer set search_path = public, storage as $$
  select o.name from storage.objects o
  where o.bucket_id = 'dtf-images' and not exists (select 1 from dtf_orders d where d.id::text = split_part(o.name, '/', 2))
$$;
revoke all on function dtf_orphan_images() from public, anon, authenticated;
grant execute on function dtf_orphan_images() to service_role;
