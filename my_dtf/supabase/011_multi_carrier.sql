-- 011 : plusieurs sociétés EcoTrack (Expedia Chrono, DHD) — société par défaut dans dtf_ship_config
alter table dtf_ship_config add column if not exists default_carrier text not null default 'expedia';
alter table dtf_ship_rates add column if not exists carrier text;
alter table dtf_ship_communes add column if not exists carrier text;
