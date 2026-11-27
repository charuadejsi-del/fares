// My DTF — gestion de l'équipe (réservé à l'administrateur).
// Actions : create_staff, set_password. La clé service_role reste côté serveur.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const STAFF_ROLES = ["manager", "designer", "printer"];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST uniquement" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // 1) Qui appelle ?
  const authHeader = req.headers.get("Authorization") ?? "";
  const asUser = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
  const { data: u, error: ue } = await asUser.auth.getUser();
  if (ue || !u?.user) return json({ error: "غير مسجّل" }, 401);

  const admin = createClient(url, service, { auth: { persistSession: false } });
  const { data: me } = await admin.from("dtf_profiles").select("role, active").eq("id", u.user.id).maybeSingle();
  if (!me || me.role !== "admin" || !me.active) return json({ error: "هذه العملية خاصة بالمدير" }, 403);

  let body: Record<string, string>;
  try { body = await req.json(); } catch { return json({ error: "JSON invalide" }, 400); }

  try {
    if (body.action === "create_staff") {
      const email = (body.email ?? "").trim().toLowerCase();
      const password = body.password ?? "";
      const fullName = (body.full_name ?? "").trim();
      const phone = (body.phone ?? "").trim();
      const role = body.role ?? "";
      if (!email.includes("@")) return json({ error: "بريد غير صحيح" }, 400);
      if (password.length < 6) return json({ error: "كلمة السر 6 أحرف على الأقل" }, 400);
      if (!fullName) return json({ error: "الاسم مطلوب" }, 400);
      if (!STAFF_ROLES.includes(role)) return json({ error: "دور غير صحيح" }, 400);

      const { data: created, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
      let userId = created?.user?.id;
      let existing = false;
      if (error || !userId) {
        if (!error?.message?.includes("already")) return json({ error: error?.message ?? "خطأ" }, 400);
        // Compte déjà existant : on cherche son id
        for (let page = 1; page <= 20 && !userId; page++) {
          const { data: list } = await admin.auth.admin.listUsers({ page, perPage: 200 });
          const found = list?.users?.find((x) => (x.email ?? "").toLowerCase() === email);
          if (found) userId = found.id;
          if (!list?.users?.length) break;
        }
        if (!userId) return json({ error: "هذا البريد مستعمل من قبل" }, 400);
        existing = true;
      }
      const { data: prof } = await admin.from("dtf_profiles").select("role").eq("id", userId).maybeSingle();
      if (prof?.role === "client") return json({ error: "هذا البريد حساب زبون. لا يمكن تحويل زبون إلى عضو في الفريق، استعمل بريداً آخر." }, 400);
      if (prof) return json({ error: "هذا البريد عضو في الفريق من قبل" }, 400);
      const { error: pe } = await admin.from("dtf_profiles").insert({ id: userId, role, full_name: fullName, phone: phone || "-" });
      if (pe) {
        if (!existing) await admin.auth.admin.deleteUser(userId);
        return json({ error: pe.message }, 400);
      }
      return json({ ok: true, id: userId, existing });
    }

    if (body.action === "set_password") {
      if ((body.password ?? "").length < 6) return json({ error: "كلمة السر 6 أحرف على الأقل" }, 400);
      const { data: target } = await admin.from("dtf_profiles").select("role").eq("id", body.user_id).maybeSingle();
      if (!target || !STAFF_ROLES.includes(target.role)) return json({ error: "موظف غير موجود" }, 404);
      const { error } = await admin.auth.admin.updateUserById(body.user_id, { password: body.password });
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    return json({ error: "Action inconnue" }, 400);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
