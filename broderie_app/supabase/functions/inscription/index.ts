// Fonction serveur « inscription » (Warchati) : un nouveau client crée en une seule étape
// son compte et son atelier (période d'essai gratuite). L'email inscrit devient l'administrateur.
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

function slug(nom: string): string {
  const s = nom.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase()
    .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 24).replace(/-+$/g, "");
  return s.length >= 3 ? s : "atelier";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Méthode non autorisée" }, 405);
  try {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
    const body = (await req.json()) as Record<string, unknown>;
    const email = String(body.email ?? "").trim().toLowerCase();
    const motDePasse = String(body.mot_de_passe ?? "");
    const nom = String(body.nom ?? "").trim();

    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return json({ error: "Email invalide" }, 400);
    if (motDePasse.length < 6) return json({ error: "Mot de passe : 6 caractères minimum" }, 400);
    if (!nom) return json({ error: "Le nom de l'atelier est obligatoire" }, 400);

    const { data: reg } = await admin.from("plateforme_reglages").select("jours_essai").eq("id", 1).maybeSingle();
    const joursEssai = Number(reg?.jours_essai ?? 7);

    // code de connexion de l'atelier, fabriqué à partir du nom et rendu unique
    const base = slug(nom);
    let code = base === "atelier" ? `atelier-${crypto.randomUUID().slice(0, 4)}` : base;
    for (let i = 2; i < 100; i++) {
      const { data: pris } = await admin.from("ateliers").select("id").eq("code", code).maybeSingle();
      if (!pris) break;
      code = `${base}-${i}`;
    }

    const { data: created, error: errCreate } = await admin.auth.admin.createUser({ email, password: motDePasse, email_confirm: true, user_metadata: { nom } });
    if (errCreate || !created.user) {
      const msg = (errCreate?.message ?? "").toLowerCase();
      if (msg.includes("already") || msg.includes("registered") || msg.includes("exists")) {
        return json({ error: "Cet email a déjà un compte : connectez-vous" }, 409);
      }
      return json({ error: errCreate?.message ?? "Création impossible" }, 400);
    }
    const uid = created.user.id;
    const annuler = async () => {
      await admin.from("ateliers").delete().eq("id", uid);
      await admin.auth.admin.deleteUser(uid);
    };

    const fin = new Date();
    fin.setDate(fin.getDate() + joursEssai);
    const { error: e1 } = await admin.from("ateliers").insert({ id: uid, nom, code, abonnement: "essai", abonnement_fin: fin.toISOString().slice(0, 10) });
    if (e1) { await annuler(); return json({ error: e1.message }, 400); }
    const { error: e2 } = await admin.from("atelier_membres").insert({ user_id: uid, atelier_id: uid, nom: email.split("@")[0], identifiant: email, role: "admin", actif: true });
    if (e2) { await annuler(); return json({ error: e2.message }, 400); }
    return json({ ok: true, code });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
