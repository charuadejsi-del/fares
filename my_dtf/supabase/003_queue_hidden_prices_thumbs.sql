-- =====================================================================
-- My DTF — migration 003
-- File d'impression partagée, prix invisibles pour designers/imprimeurs, miniatures
-- =====================================================================

alter table dtf_order_images add column if not exists thumb_path text;

-- Qui peut voir une commande (sans exposer les prix aux ateliers) ?
create or replace function dtf_can_see_order(p_order uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from dtf_orders o
    where o.id = p_order and (
      o.client_id = auth.uid()
      or dtf_is_staff_admin()
      or (dtf_my_role() = 'designer' and o.designer_id = auth.uid())
      or (dtf_my_role() = 'printer' and (o.status = 'ready_to_print' or o.printer_id = auth.uid()))
    )
  )
$$;

-- Table des commandes : clients (les leurs) + admin/gérant uniquement.
drop policy if exists "dtf commandes lecture" on dtf_orders;
create policy "dtf commandes lecture" on dtf_orders for select to authenticated
  using (client_id = (select auth.uid()) or dtf_is_staff_admin());

drop policy if exists "dtf images lecture" on dtf_order_images;
create policy "dtf images lecture" on dtf_order_images for select to authenticated
  using (dtf_can_see_order(order_id));

drop policy if exists "dtf images ajout" on dtf_order_images;
create policy "dtf images ajout" on dtf_order_images for insert to authenticated
  with check (exists (select 1 from dtf_orders o where o.id = order_id and o.client_id = (select auth.uid()) and o.status = 'new'));

drop policy if exists "dtf journal lecture" on dtf_order_events;
create policy "dtf journal lecture" on dtf_order_events for select to authenticated
  using (dtf_can_see_order(order_id));

-- Vue de travail pour designers et imprimeurs : aucune colonne de prix.
create or replace function dtf_work_orders()
returns table (
  id uuid, code bigint, status dtf_order_status, billed_meters numeric, estimated_length_cm numeric,
  final_length_cm numeric, client_note text, delivery_mode dtf_delivery_mode, designer_id uuid,
  printer_id uuid, created_at timestamptz, updated_at timestamptz, client_name text
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare r dtf_role := dtf_my_role();
begin
  if r is null or r = 'client' then raise exception 'Réservé au personnel'; end if;
  return query
  select o.id, o.code, o.status, o.billed_meters, o.estimated_length_cm, o.final_length_cm, o.client_note,
         o.delivery_mode, o.designer_id, o.printer_id, o.created_at, o.updated_at,
         split_part(p.full_name, ' ', 1)
  from dtf_orders o join dtf_profiles p on p.id = o.client_id
  where (r = 'designer' and o.designer_id = auth.uid() and o.status in ('in_design', 'ready_to_print', 'printing'))
     or (r = 'printer' and (o.status = 'ready_to_print'
                            or (o.printer_id = auth.uid() and (o.status = 'printing' or o.updated_at > now() - interval '1 day'))))
     or (r in ('admin', 'manager') and o.status in ('in_design', 'ready_to_print', 'printing'))
  order by o.updated_at;
end $$;

-- Designer : « design prêt » sans choisir d'imprimeur → file partagée.
drop function if exists dtf_design_done(uuid, numeric, uuid);
create or replace function dtf_design_done(p_order uuid, p_final_length_cm numeric)
returns void language plpgsql security definer set search_path = public as $$
declare p record;
begin
  perform dtf_require_shift();
  if p_final_length_cm is null or p_final_length_cm <= 0 then raise exception 'أدخل الطول الحقيقي بالسنتيمتر'; end if;
  select * into p from dtf_price(p_final_length_cm);
  update dtf_orders set final_length_cm = p_final_length_cm, billed_meters = p.billed_meters,
    print_amount = p.print_amount, printer_id = null, status = 'ready_to_print'
  where id = p_order and status = 'in_design' and (designer_id = auth.uid() or dtf_is_staff_admin());
  if not found then raise exception 'هذا الملف ليس عندك أو لم يعد في مرحلة التصميم'; end if;
end $$;

-- Imprimeur : prend la commande dans la file (elle passe à son nom) et débite le rouleau.
create or replace function dtf_start_printing(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare m numeric;
begin
  perform dtf_require_shift();
  if dtf_my_role() not in ('admin', 'manager', 'printer') then raise exception 'خاص بالطابع'; end if;
  update dtf_orders
     set status = 'printing',
         printer_id = case when dtf_my_role() = 'printer' then auth.uid() else printer_id end
   where id = p_order and status = 'ready_to_print'
     and (dtf_is_staff_admin() or printer_id is null or printer_id = auth.uid())
  returning billed_meters into m;
  if not found then raise exception 'هذه الطلبية أخذها طابع آخر أو لم تعد جاهزة للطباعة'; end if;
  perform dtf_consume_film(m, 'print', p_order, null);
end $$;

create or replace function dtf_finish_printing(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform dtf_require_shift();
  update dtf_orders set status = case when delivery_mode = 'pickup' then 'ready_pickup'::dtf_order_status else 'printed'::dtf_order_status end
  where id = p_order and status = 'printing' and (printer_id = auth.uid() or dtf_is_staff_admin());
  if not found then raise exception 'هذه الطلبية ليست في الطباعة باسمك'; end if;
end $$;

-- Notification à tous les imprimeurs quand un fichier arrive dans la file.
create or replace function dtf_notify_queue() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'ready_to_print' and old.status is distinct from 'ready_to_print' then
    insert into dtf_notifications (user_id, order_id, title, body)
    select id, new.id, 'ملف جديد للطباعة #' || new.code, new.billed_meters || ' م'
    from dtf_profiles where role = 'printer' and active;
  end if;
  return null;
end $$;
drop trigger if exists dtf_orders_queue on dtf_orders;
create trigger dtf_orders_queue after update on dtf_orders for each row execute function dtf_notify_queue();

-- Les notifications du personnel doivent être lisibles par lui.
revoke execute on function dtf_can_see_order(uuid), dtf_notify_queue() from public, anon;
revoke execute on function dtf_notify_queue() from authenticated;
revoke execute on function dtf_work_orders(), dtf_design_done(uuid, numeric) from public, anon;
