-- 015 — Lecture seule de Hosonsoft PrintExp par le programme Windows.
-- Le collecteur observe ; il ne commande jamais la machine. Les métrages relevés sont stockés à part
-- (dtf_print_runs) et NE TOUCHENT PAS au stock : la déduction automatique reste désactivée.

alter table dtf_machines add column if not exists printexp_id text unique;   -- identifiant de la machine côté PrintExp (correspondance explicite)

-- Dernier relevé de chaque imprimante vue par un collecteur.
create table if not exists dtf_machine_live (
  printer_key  text primary key,                 -- identifiant de l'imprimante côté source
  machine_id   uuid references dtf_machines(id) on delete set null,
  printer_name text,
  source       text not null,                    -- 'log' | 'uia' | 'report' …
  connection   text not null check (connection in ('connected','disconnected','unknown')),
  activity     text not null check (activity in ('printing','paused','idle','error','unknown')),
  job_name     text,
  progress     numeric,                          -- 0..100 si la source le donne
  printed_m    numeric,                          -- mètres en cours rapportés par la source
  planned_m    numeric,
  collector    text,                             -- poste Windows qui a envoyé
  read_at      timestamptz not null,             -- heure de la lecture sur le PC
  updated_at   timestamptz not null default now()
);

-- Une ligne = un passage d'impression physique. run_key unique ⇒ jamais compté deux fois.
create table if not exists dtf_print_runs (
  id          uuid primary key default gen_random_uuid(),
  run_key     text not null unique,
  printer_key text not null,
  machine_id  uuid references dtf_machines(id) on delete set null,
  source      text not null,
  source_run_id text,                            -- identifiant fourni par PrintExp s'il existe
  job_name    text,
  planned_m   numeric,                           -- longueur prévue du travail
  reported_m  numeric,                           -- longueur annoncée par PrintExp
  consumed_m  numeric,                           -- film réellement consommé (saisie / validation ultérieure)
  outcome     text not null check (outcome in ('completed','cancelled','failed','unknown')),
  started_at  timestamptz,
  ended_at    timestamptz,
  needs_review boolean not null default false,   -- deux passages impossibles à distinguer, valeur douteuse…
  review_note text,
  order_id    uuid references dtf_orders(id) on delete set null,  -- lien éventuel avec la saisie manuelle
  counted_in_stock boolean not null default false,
  collector   text,
  raw         jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists dtf_print_runs_machine on dtf_print_runs (machine_id, ended_at desc);

-- Interrupteur de déduction automatique : désactivé, et rien ne le lit encore.
alter table dtf_settings add column if not exists printexp_auto_deduct boolean not null default false;

alter table dtf_machine_live enable row level security;
alter table dtf_print_runs enable row level security;
drop policy if exists live_staff_read on dtf_machine_live;
create policy live_staff_read on dtf_machine_live for select using (dtf_my_role() in ('admin','manager','designer','printer'));
drop policy if exists runs_staff_read on dtf_print_runs;
create policy runs_staff_read on dtf_print_runs for select using (dtf_my_role() in ('admin','manager','designer','printer'));
drop policy if exists runs_admin_update on dtf_print_runs;
create policy runs_admin_update on dtf_print_runs for update using (dtf_my_role() in ('admin','manager')) with check (dtf_my_role() in ('admin','manager'));

-- Point d'entrée unique du collecteur (session de l'utilisateur connecté dans le programme Windows).
-- p_live : [{printer_key, printer_name, source, connection, activity, job_name, progress, printed_m, planned_m, read_at}]
-- p_runs : [{run_key, printer_key, source, source_run_id, job_name, planned_m, reported_m, outcome, started_at, ended_at, needs_review, review_note, raw}]
-- Renvoie les run_key enregistrés OU déjà présents (accusé de réception idempotent).
create or replace function dtf_printexp_report(p_collector text, p_live jsonb, p_runs jsonb)
returns text[] language plpgsql security definer set search_path = public as $$
declare r jsonb; mid uuid; acked text[] := '{}';
begin
  if dtf_my_role() is null or dtf_my_role() = 'client' then raise exception 'Réservé à l''équipe'; end if;
  for r in select * from jsonb_array_elements(coalesce(p_live, '[]')) loop
    select id into mid from dtf_machines where printexp_id = r->>'printer_key';
    insert into dtf_machine_live as l (printer_key, machine_id, printer_name, source, connection, activity, job_name, progress, printed_m, planned_m, collector, read_at, updated_at)
    values (r->>'printer_key', mid, r->>'printer_name', coalesce(r->>'source','unknown'), coalesce(r->>'connection','unknown'), coalesce(r->>'activity','unknown'),
            r->>'job_name', (r->>'progress')::numeric, (r->>'printed_m')::numeric, (r->>'planned_m')::numeric, left(p_collector, 80), (r->>'read_at')::timestamptz, now())
    on conflict (printer_key) do update set machine_id = excluded.machine_id, printer_name = excluded.printer_name, source = excluded.source,
      connection = excluded.connection, activity = excluded.activity, job_name = excluded.job_name, progress = excluded.progress,
      printed_m = excluded.printed_m, planned_m = excluded.planned_m, collector = excluded.collector, read_at = excluded.read_at, updated_at = now()
      where excluded.read_at >= l.read_at;   -- une lecture plus ancienne (synchro retardée) n'écrase pas la plus récente
  end loop;
  for r in select * from jsonb_array_elements(coalesce(p_runs, '[]')) loop
    select id into mid from dtf_machines where printexp_id = r->>'printer_key';
    insert into dtf_print_runs (run_key, printer_key, machine_id, source, source_run_id, job_name, planned_m, reported_m, outcome, started_at, ended_at, needs_review, review_note, collector, raw)
    values (r->>'run_key', r->>'printer_key', mid, coalesce(r->>'source','unknown'), r->>'source_run_id', r->>'job_name', (r->>'planned_m')::numeric, (r->>'reported_m')::numeric,
            coalesce(r->>'outcome','unknown'), (r->>'started_at')::timestamptz, (r->>'ended_at')::timestamptz, coalesce((r->>'needs_review')::boolean, false), r->>'review_note', left(p_collector, 80), r->'raw')
    on conflict (run_key) do nothing;
    acked := acked || (r->>'run_key');
  end loop;
  return acked;
end $$;
revoke all on function dtf_printexp_report(text, jsonb, jsonb) from public, anon;
grant execute on function dtf_printexp_report(text, jsonb, jsonb) to authenticated;

-- 016 — Correspondance explicite imprimante PrintExp ↔ machine My DTF (admin / gérant).
create or replace function dtf_set_printexp_id(p_machine uuid, p_key text)
returns void language plpgsql security definer set search_path = public as $$
declare k text := nullif(trim(p_key), '');
begin
  if dtf_my_role() not in ('admin','manager') then raise exception 'Réservé à l''administration'; end if;
  update dtf_machines set printexp_id = null where printexp_id = k and id <> p_machine;
  update dtf_machines set printexp_id = k where id = p_machine;
  update dtf_machine_live set machine_id = null where machine_id = p_machine and printer_key is distinct from k;
  if k is not null then
    update dtf_machine_live set machine_id = p_machine where printer_key = k;
    update dtf_print_runs set machine_id = p_machine where printer_key = k and machine_id is null;
  end if;
end $$;
revoke all on function dtf_set_printexp_id(uuid, text) from public, anon;
grant execute on function dtf_set_printexp_id(uuid, text) to authenticated;

alter publication supabase_realtime add table dtf_machine_live, dtf_print_runs;
