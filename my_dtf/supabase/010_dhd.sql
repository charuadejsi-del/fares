-- 010 : livraison DHD (EcoTrack) — tarifs, communes, suivi des colis
create table if not exists dtf_wilayas (code int primary key, fr text not null, ar text not null);
insert into dtf_wilayas (code, fr, ar) values
(1,'Adrar','أدرار'),
(2,'Chlef','الشلف'),
(3,'Laghouat','الأغواط'),
(4,'Oum El Bouaghi','أم البواقي'),
(5,'Batna','باتنة'),
(6,'Béjaïa','بجاية'),
(7,'Biskra','بسكرة'),
(8,'Béchar','بشار'),
(9,'Blida','البليدة'),
(10,'Bouira','البويرة'),
(11,'Tamanrasset','تمنراست'),
(12,'Tébessa','تبسة'),
(13,'Tlemcen','تلمسان'),
(14,'Tiaret','تيارت'),
(15,'Tizi Ouzou','تيزي وزو'),
(16,'Alger','الجزائر'),
(17,'Djelfa','الجلفة'),
(18,'Jijel','جيجل'),
(19,'Sétif','سطيف'),
(20,'Saïda','سعيدة'),
(21,'Skikda','سكيكدة'),
(22,'Sidi Bel Abbès','سيدي بلعباس'),
(23,'Annaba','عنابة'),
(24,'Guelma','قالمة'),
(25,'Constantine','قسنطينة'),
(26,'Médéa','المدية'),
(27,'Mostaganem','مستغانم'),
(28,'M''Sila','المسيلة'),
(29,'Mascara','معسكر'),
(30,'Ouargla','ورقلة'),
(31,'Oran','وهران'),
(32,'El Bayadh','البيض'),
(33,'Illizi','إليزي'),
(34,'Bordj Bou Arreridj','برج بوعريريج'),
(35,'Boumerdès','بومرداس'),
(36,'El Tarf','الطارف'),
(37,'Tindouf','تندوف'),
(38,'Tissemsilt','تيسمسيلت'),
(39,'El Oued','الوادي'),
(40,'Khenchela','خنشلة'),
(41,'Souk Ahras','سوق أهراس'),
(42,'Tipaza','تيبازة'),
(43,'Mila','ميلة'),
(44,'Aïn Defla','عين الدفلة'),
(45,'Naâma','النعامة'),
(46,'Aïn Témouchent','عين تيموشنت'),
(47,'Ghardaïa','غرداية'),
(48,'Relizane','غليزان'),
(49,'Timimoun','تيميمون'),
(50,'Bordj Badji Mokhtar','برج باجي مختار'),
(51,'Ouled Djellal','أولاد جلال'),
(52,'Béni Abbès','بني عباس'),
(53,'In Salah','عين صالح'),
(54,'In Guezzam','عين قزام'),
(55,'Touggourt','تقرت'),
(56,'Djanet','جانت'),
(57,'El Meghaier','المغير'),
(58,'El Menia','المنيعة')
on conflict (code) do update set fr = excluded.fr, ar = excluded.ar;

create table if not exists dtf_ship_rates (
  wilaya_code int primary key, name text, home numeric, desk numeric, retour numeric, updated_at timestamptz default now());
create table if not exists dtf_ship_communes (
  wilaya_code int not null, name text not null, has_desk boolean default false, code_postal text, primary key (wilaya_code, name));
create table if not exists dtf_ship_config (
  id int primary key default 1 check (id = 1), cron_key text not null default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  origin text default 'عين الدفلى', last_sync timestamptz, last_track timestamptz, last_error text);
insert into dtf_ship_config (id) values (1) on conflict do nothing;

alter table dtf_ship_rates enable row level security;
alter table dtf_ship_communes enable row level security;
alter table dtf_wilayas enable row level security;
alter table dtf_ship_config enable row level security;
create policy "lecture tarifs" on dtf_ship_rates for select to authenticated using (true);
create policy "lecture communes" on dtf_ship_communes for select to authenticated using (true);
create policy "lecture wilayas" on dtf_wilayas for select to authenticated using (true);
-- dtf_ship_config : aucune politique → seul le serveur (service role) y accède

alter table dtf_orders add column if not exists ship_wilaya_code int,
  add column if not exists ship_status text, add column if not exists ship_status_raw text,
  add column if not exists ship_cod numeric, add column if not exists ship_events jsonb,
  add column if not exists shipped_at timestamptz, add column if not exists ship_synced_at timestamptz;

create or replace function dtf_fold(p text) returns text language sql immutable as $$
  select translate(lower(trim(coalesce(p, ''))), 'éèêëàâäîïôöùûüçÉÈ''-', 'eeeeaaaiioouuuceE  ') $$;
create or replace function dtf_wilaya_code(p text) returns int language sql stable set search_path = public as $$
  select code from dtf_wilayas
  where dtf_fold(fr) = dtf_fold(p) or ar = trim(p) or code::text = ltrim(split_part(trim(p), ' ', 1), '0')
  limit 1 $$;

-- Frais de livraison calculés côté serveur depuis les tarifs DHD (le client ne peut plus fixer le prix)
create or replace function dtf_create_order(p_estimated_length_cm numeric, p_delivery_mode dtf_delivery_mode, p_delivery_fee numeric,
  p_ship_name text, p_ship_phone text, p_ship_wilaya text, p_ship_commune text, p_ship_address text, p_note text)
returns dtf_orders language plpgsql security definer set search_path = public as $function$
declare p record; o dtf_orders; wc int; fee numeric := 0; r dtf_ship_rates;
begin
  if dtf_my_role() is distinct from 'client' then raise exception 'Compte client requis'; end if;
  select * into p from dtf_price(p_estimated_length_cm, auth.uid());
  if p_delivery_mode <> 'pickup' then
    wc := dtf_wilaya_code(p_ship_wilaya);
    select * into r from dtf_ship_rates where wilaya_code = wc;
    fee := coalesce(case when p_delivery_mode = 'stopdesk' then r.desk else r.home end, 0);
  end if;
  insert into dtf_orders (client_id, estimated_length_cm, price_per_meter, billed_meters,
    print_amount, delivery_mode, delivery_fee, ship_name, ship_phone, ship_wilaya, ship_commune, ship_address, client_note, ship_wilaya_code)
  values (auth.uid(), p_estimated_length_cm, p.price_per_meter, p.billed_meters, p.print_amount, p_delivery_mode, fee,
    p_ship_name, p_ship_phone, p_ship_wilaya, p_ship_commune, p_ship_address, p_note, wc)
  returning * into o;
  return o;
end $function$;

-- Suivi automatique toutes les 30 minutes + tarifs chaque nuit
create extension if not exists pg_net;
create extension if not exists pg_cron;
create or replace function dtf_dhd_cron(p_action text) returns void language plpgsql security definer set search_path = public as $$
begin
  perform net.http_post(
    url := 'https://pxifieuohgthtqkwasug.supabase.co/functions/v1/dtf-dhd',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-key', (select cron_key from dtf_ship_config where id = 1)),
    body := jsonb_build_object('action', p_action));
end $$;
revoke all on function dtf_dhd_cron(text) from public, anon, authenticated;
select cron.schedule('dtf-dhd-track', '*/30 * * * *', $$select public.dtf_dhd_cron('track')$$);
select cron.schedule('dtf-dhd-rates', '17 3 * * *', $$select public.dtf_dhd_cron('sync')$$);
