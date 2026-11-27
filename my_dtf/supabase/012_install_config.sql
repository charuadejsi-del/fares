-- 012 : l'adresse des fonctions serveur n'est plus écrite dans le code (une installation = un projet Supabase)
alter table dtf_ship_config add column if not exists functions_url text;
create or replace function dtf_dhd_cron(p_action text) returns void language plpgsql security definer set search_path = public as $$
declare u text; k text;
begin
  select coalesce(functions_url, ''), cron_key into u, k from dtf_ship_config where id = 1;
  if u = '' then return; end if;  -- installation pas encore configurée
  perform net.http_post(url := rtrim(u, '/') || '/dtf-dhd',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-key', k),
    body := jsonb_build_object('action', p_action));
end $$;
revoke all on function dtf_dhd_cron(text) from public, anon, authenticated;
-- Installation d'origine :
update dtf_ship_config set functions_url = 'https://pxifieuohgthtqkwasug.supabase.co/functions/v1' where id = 1 and functions_url is null;
