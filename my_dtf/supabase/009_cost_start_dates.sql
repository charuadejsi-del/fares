-- My DTF — 009 : dates de début (atelier, chaque salaire, chaque charge mensuelle).
alter table dtf_cost_settings add column if not exists start_date date;
-- Chaque élément de wages / fixed_costs peut porter "from": "AAAA-MM-JJ".
