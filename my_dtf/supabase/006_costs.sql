-- My DTF — 006 : coûts et bénéfices (réglages modifiables par l'administrateur + données réelles par jour).
create table if not exists dtf_cost_settings (
  id              int primary key default 1 check (id = 1),
  roll_price      numeric(12,2) not null default 20000,
  roll_length_m   numeric(8,2)  not null default 100,
  ink_price_l     numeric(12,2) not null default 9000,
  ink_ml_per_m    numeric(8,2)  not null default 11.5,
  powder_price_kg numeric(12,2) not null default 3500,
  powder_g_per_m  numeric(8,2)  not null default 16,
  work_days       int           not null default 26 check (work_days between 1 and 31),
  wages           jsonb         not null default '[{"name":"عامل الطباعة","amount":2000},{"name":"مصمم 1","amount":1500},{"name":"مصمم 2","amount":1500},{"name":"المسيّر","amount":3000}]',
  fixed_costs     jsonb         not null default '[{"name":"كراء","amount":40000},{"name":"كهرباء","amount":30000},{"name":"أنترنت","amount":2500}]',
  waste_in_profit boolean       not null default true,
  updated_at      timestamptz   not null default now()
);
insert into dtf_cost_settings (id) values (1) on conflict do nothing;

alter table dtf_cost_settings enable row level security;
create policy "dtf couts lecture" on dtf_cost_settings for select to authenticated using (dtf_my_role() = 'admin');
create policy "dtf couts modif" on dtf_cost_settings for update to authenticated using (dtf_my_role() = 'admin') with check (dtf_my_role() = 'admin');

-- Données réelles par jour (fuseau Algérie) : mètres réellement imprimés (longueur saisie par le designer),
-- gâche, montants facturés, nombre de commandes. Les formules sont appliquées dans l'interface.
create or replace function dtf_cost_days(p_from date, p_to date)
returns table (day date, meters numeric, waste_m numeric, revenue numeric, orders int)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if dtf_my_role() is distinct from 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  if p_to < p_from or p_to - p_from > 400 then raise exception 'Période invalide'; end if;
  return query
  with o as (
    select (coalesce(o.print_started_at,
                     (select min(e.created_at) from dtf_order_events e where e.order_id = o.id and e.to_status = 'printing'),
                     o.updated_at) at time zone 'Africa/Algiers')::date as d,
           coalesce(o.final_length_cm, o.estimated_length_cm) / 100.0 as m,
           o.print_amount as a
    from dtf_orders o
    where o.status in ('printing', 'printed', 'ready_pickup', 'shipped', 'delivered')
  ), w as (
    select (f.created_at at time zone 'Africa/Algiers')::date as d, sum(f.meters) as m
    from dtf_film_moves f where f.kind = 'waste' group by 1
  )
  select g::date,
         coalesce((select sum(o.m) from o where o.d = g::date), 0)::numeric,
         coalesce((select w.m from w where w.d = g::date), 0)::numeric,
         coalesce((select sum(o.a) from o where o.d = g::date), 0)::numeric,
         (select count(*)::int from o where o.d = g::date)
  from generate_series(p_from, p_to, interval '1 day') g
  order by 1;
end $$;
revoke execute on function dtf_cost_days(date, date) from public, anon;
