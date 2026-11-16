alter table public.stock_modeles_info add column if not exists series jsonb not null default '[]'::jsonb;
