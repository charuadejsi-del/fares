// Fonction serveur « atelier-employes » : gestion des comptes employés par l'administrateur de l'atelier.
// Actions : creer, modifier, supprimer. Seul un membre « admin » actif peut l'appeler.
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const DOMAINE = "atelier-broderie.app";

// Connexion employé : identifiant + code de l'atelier (un même identifiant peut exister dans deux ateliers)
function emailDepuisIdentifiant(identifiant: string, code?: string | null): string {
  const id = identifiant.trim().toLowerCase();
  if (id.includes("@")) return id;
  const c = (code ?? "").trim().toLowerCase();
  return c ? `${id}.${c}@${DOMAINE}` : `${id}@${DOMAINE}`;
}

function droits(body: Record<string, unknown>) {
  return {
    perm_broderie: body.perm_broderie === true,
    perm_paie: body.perm_paie === true,
    perm_stock: body.perm_stock === true,
    perm_coupe: body.perm_coupe === true,
    perm_applique: body.perm_applique === true,
    perm_finition: body.perm_finition === true,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Méthode non autorisée" }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Qui appelle ?
    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
      auth: { persistSession: false },
    });
    const { data: userData } = await userClient.auth.getUser();
    const caller = userData?.user;
    if (!caller) return json({ error: "Non connecté" }, 401);

    const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
    const { data: me } = await admin.from("atelier_membres").select("*").eq("user_id", caller.id).maybeSingle();
    if (!me || me.role !== "admin" || !me.actif) return json({ error: "Réservé à l'administrateur de l'atelier" }, 403);

    const body = (await req.json()) as Record<string, unknown>;
    const action = String(body.action ?? "");

    // ------------------------------------------------------------------ créer
    if (action === "creer") {
      const nom = String(body.nom ?? "").trim();
      const identifiant = String(body.identifiant ?? "").trim().toLowerCase();
      const motDePasse = String(body.mot_de_passe ?? "");
      if (!nom) return json({ error: "Le nom est obligatoire" }, 400);
      if (!/^[a-z0-9._@-]{3,60}$/.test(identifiant)) {
        return json({ error: "Identifiant invalide : 3 caractères minimum, lettres, chiffres, point, tiret" }, 400);
      }
      if (motDePasse.length < 6) return json({ error: "Mot de passe : 6 caractères minimum" }, 400);

      const { data: at } = await admin.from("ateliers").select("code").eq("id", me.atelier_id).maybeSingle();
      const { data: created, error: errCreate } = await admin.auth.admin.createUser({
        email: emailDepuisIdentifiant(identifiant, at?.code),
        password: motDePasse,
        email_confirm: true,
        user_metadata: { nom, atelier_id: me.atelier_id },
      });
      if (errCreate || !created.user) {
        const msg = (errCreate?.message ?? "").toLowerCase();
        if (msg.includes("already") || msg.includes("registered") || msg.includes("exists")) {
          return json({ error: "Cet identifiant est déjà utilisé, choisissez-en un autre" }, 409);
        }
        return json({ error: errCreate?.message ?? "Création impossible" }, 400);
      }

      const { error: errInsert } = await admin.from("atelier_membres").insert({
        user_id: created.user.id,
        atelier_id: me.atelier_id,
        nom,
        identifiant,
        role: body.role === "admin" ? "admin" : "employe",
        ...droits(body),
        actif: true,
      });
      if (errInsert) {
        await admin.auth.admin.deleteUser(created.user.id);
        return json({ error: errInsert.message }, 400);
      }
      return json({ ok: true, user_id: created.user.id });
    }

    // Les autres actions visent un membre existant du même atelier
    const cible = String(body.user_id ?? "");
    const { data: membre } = await admin.from("atelier_membres").select("*").eq("user_id", cible).maybeSingle();
    if (!membre || membre.atelier_id !== me.atelier_id) return json({ error: "Employé introuvable" }, 404);
    const soiMeme = cible === caller.id;
    // Administrateur principal = créateur de l'atelier (id du compte = id de l'atelier) : intouchable par les autres
    const principal = membre.user_id === membre.atelier_id;
    if (principal && !soiMeme && (action === "supprimer" || action === "modifier")) {
      return json({ error: "L'administrateur principal ne peut être modifié que par lui-même" }, 403);
    }

    // ------------------------------------------------------------------ modifier
    if (action === "modifier") {
      const maj: Record<string, unknown> = {};
      if (typeof body.nom === "string" && body.nom.trim()) maj.nom = body.nom.trim();
      if (!soiMeme) {
        if (body.role === "admin" || body.role === "employe") maj.role = body.role;
        if (typeof body.actif === "boolean") maj.actif = body.actif;
        Object.assign(maj, droits(body));
      }
      if (Object.keys(maj).length) {
        const { error } = await admin.from("atelier_membres").update(maj).eq("user_id", cible);
        if (error) return json({ error: error.message }, 400);
      }
      const motDePasse = typeof body.mot_de_passe === "string" ? body.mot_de_passe : "";
      const authMaj: Record<string, unknown> = {};
      if (motDePasse) {
        if (motDePasse.length < 6) return json({ error: "Mot de passe : 6 caractères minimum" }, 400);
        authMaj.password = motDePasse;
      }
      if (!soiMeme && typeof body.actif === "boolean") authMaj.ban_duration = body.actif ? "none" : "876000h";
      if (Object.keys(authMaj).length) {
        const { error } = await admin.auth.admin.updateUserById(cible, authMaj);
        if (error) return json({ error: error.message }, 400);
      }
      return json({ ok: true });
    }

    // ------------------------------------------------------------------ supprimer
    if (action === "supprimer") {
      if (soiMeme) return json({ error: "Vous ne pouvez pas supprimer votre propre compte" }, 400);
      const { error } = await admin.auth.admin.deleteUser(cible);
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    return json({ error: "Action inconnue" }, 400);
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
