-- =====================================================================
-- v11 : code PIN à 4 chiffres par utilisateur (verrouillage de l'application)
-- =====================================================================
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.membre_pins (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  pin_hash      text not null,
  essais        int not null default 0,
  bloque_jusqu  timestamptz,
  updated_at    timestamptz not null default now()
);
-- Aucun accès direct : uniquement via les fonctions ci-dessous
alter table public.membre_pins enable row level security;

create or replace function public._pin_journal(p_user uuid, p_action text, p_libelle text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_atelier uuid; v_nom text;
begin
  select m.atelier_id, coalesce(nullif(m.nom, ''), u.email) into v_atelier, v_nom
  from auth.users u left join public.atelier_membres m on m.user_id = u.id where u.id = auth.uid();
  if v_atelier is null then return; end if;
  insert into public.journal_actions(atelier_id, user_id, user_nom, table_nom, action, ligne_id, libelle)
  values (v_atelier, auth.uid(), v_nom, 'atelier_membres', p_action, p_user::text, p_libelle);
end $$;
revoke execute on function public._pin_journal(uuid, text, text) from anon, authenticated, public;

create or replace function public.pin_etat()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'defini', exists (select 1 from public.membre_pins p where p.user_id = auth.uid()),
    'bloque_jusqu', (select p.bloque_jusqu from public.membre_pins p where p.user_id = auth.uid() and p.bloque_jusqu > now())
  );
$$;

create or replace function public.pin_definir(p_pin text, p_ancien text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare r public.membre_pins; v_existait boolean;
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  if p_pin !~ '^[0-9]{4}$' then raise exception 'Le code PIN doit contenir 4 chiffres'; end if;
  select * into r from public.membre_pins where user_id = auth.uid();
  v_existait := found;
  if v_existait then
    if p_ancien is null or r.pin_hash <> extensions.crypt(p_ancien, r.pin_hash) then
      raise exception 'Ancien code PIN incorrect';
    end if;
  end if;
  insert into public.membre_pins(user_id, pin_hash) values (auth.uid(), extensions.crypt(p_pin, extensions.gen_salt('bf', 8)))
  on conflict (user_id) do update set pin_hash = excluded.pin_hash, essais = 0, bloque_jusqu = null, updated_at = now();
  perform public._pin_journal(auth.uid(), case when v_existait then 'modification' else 'ajout' end,
                              case when v_existait then 'Code PIN modifié' else 'Code PIN créé' end);
end $$;

create or replace function public.pin_verifier(p_pin text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare r public.membre_pins;
begin
  select * into r from public.membre_pins where user_id = auth.uid() for update;
  if not found then return jsonb_build_object('ok', false, 'defini', false); end if;
  if r.bloque_jusqu is not null and r.bloque_jusqu > now() then
    return jsonb_build_object('ok', false, 'bloque_jusqu', r.bloque_jusqu, 'restants', 0);
  end if;
  if r.pin_hash = extensions.crypt(coalesce(p_pin, ''), r.pin_hash) then
    update public.membre_pins set essais = 0, bloque_jusqu = null where user_id = auth.uid();
    return jsonb_build_object('ok', true);
  end if;
  if r.essais + 1 >= 5 then
    update public.membre_pins set essais = 0, bloque_jusqu = now() + interval '5 minutes' where user_id = auth.uid();
    perform public._pin_journal(auth.uid(), 'modification', 'Code PIN : 5 erreurs, accès bloqué 5 min');
    return jsonb_build_object('ok', false, 'restants', 0, 'bloque_jusqu', now() + interval '5 minutes');
  end if;
  update public.membre_pins set essais = r.essais + 1 where user_id = auth.uid();
  return jsonb_build_object('ok', false, 'restants', 5 - (r.essais + 1));
end $$;

-- L'administrateur réinitialise le PIN d'un membre de son atelier
create or replace function public.pin_reinitialiser(p_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.a_droit('admin') then raise exception 'Réservé à l''administrateur'; end if;
  if not exists (select 1 from public.atelier_membres m where m.user_id = p_user and m.atelier_id = public.atelier_courant()) then
    raise exception 'Membre introuvable';
  end if;
  delete from public.membre_pins where user_id = p_user;
  perform public._pin_journal(p_user, 'suppression', 'Code PIN réinitialisé par l''administrateur');
end $$;

revoke execute on function public.pin_etat(), public.pin_definir(text, text), public.pin_verifier(text), public.pin_reinitialiser(uuid) from anon, public;
grant execute on function public.pin_etat(), public.pin_definir(text, text), public.pin_verifier(text), public.pin_reinitialiser(uuid) to authenticated;
