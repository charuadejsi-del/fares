-- 014 : tarifs et communes de livraison lisibles avant connexion (inscription dans l'application)
create policy "lecture publique tarifs" on dtf_ship_rates for select to anon using (true);
create policy "lecture publique communes" on dtf_ship_communes for select to anon using (true);
create policy "lecture publique wilayas" on dtf_wilayas for select to anon using (true);
