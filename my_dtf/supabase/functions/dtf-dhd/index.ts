// My DTF — livraison via la plateforme EcoTrack (Expedia Chrono, DHD…).
// Les jetons restent ici, côté serveur (secrets EXPEDIA_TOKEN, DHD_TOKEN). Appelé par le site admin
// (admin / gérant) ou par la tâche planifiée (en-tête x-cron-key).
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

const url = Deno.env.get("SUPABASE_URL")!;
const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
type Carrier = { key: string; name: string; secret: string; token: string; hosts: string[]; host: string };
const CARRIERS: Record<string, Carrier> = {
  expedia: { key: "expedia", name: "Expedia", secret: "EXPEDIA_TOKEN", token: Deno.env.get("EXPEDIA_TOKEN") || "", host: "",
    hosts: [Deno.env.get("EXPEDIA_URL"), "https://expediachrono.ecotrack.dz"].filter(Boolean) as string[] },
  dhd: { key: "dhd", name: "DHD", secret: "DHD_TOKEN", token: Deno.env.get("DHD_TOKEN") || "", host: "",
    hosts: [Deno.env.get("DHD_URL"), "https://platform.dhd-dz.com", "https://dhd.ecotrack.dz"].filter(Boolean) as string[] },
};
const byName = (name: string) => Object.values(CARRIERS).find(c => c.name === name || c.key === name);
function carrierOf(k: string): Carrier { const c = CARRIERS[k] || byName(k); if (!c) throw new Error("شركة توصيل غير معروفة: " + k); return c; }

// ---------- appels EcoTrack ----------
async function eco(c: Carrier, method: string, path: string, params: Record<string, unknown> = {}, raw = false) {
  if (!c.token) throw new Error(`مفتاح ${c.name} غير مضاف بعد في Supabase (${c.secret})`);
  const TOKEN = c.token; let host = c.host; const HOSTS = c.hosts;
  const qs = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v == null || v === "") continue;
    if (Array.isArray(v)) v.forEach(x => qs.append(k + "[]", String(x))); else qs.set(k, String(v));
  }
  const tries = host ? [host] : HOSTS;
  let last: unknown = null;
  for (const h of tries) {
    try {
      const r = await fetch(`${h}/api/v1/${path}${qs.toString() ? "?" + qs.toString() : ""}`, { method, headers: { Authorization: `Bearer ${TOKEN}`, Accept: "application/json" } });
      if (r.status === 404 && !host && tries.length > 1) { last = new Error(`404 ${h}`); continue; }
      host = h; c.host = h;
      if (raw) { if (!r.ok) throw new Error(`${c.name} ${r.status}: ${(await r.text()).slice(0, 200)}`); return new Uint8Array(await r.arrayBuffer()); }
      const t = await r.text(); let b: any; try { b = JSON.parse(t); } catch { b = t; }
      if (typeof b === "string" && b.trim().startsWith("<") && tries.length > 1 && h !== tries[tries.length - 1]) { host = ""; c.host = ""; last = new Error(`HTML ${h}`); continue; }
      if (r.status === 401 || r.status === 403) throw new Error(`مفتاح ${c.name} مرفوض — تحقق منه أو اطلب منهم تفعيل الـ API`);
      if (r.status === 429) throw new Error(`طلبات كثيرة على ${c.name} — أعد المحاولة بعد دقيقة`);
      if (!r.ok) throw new Error(errText(b) || `${c.name} ${r.status}`);
      return b;
    } catch (e) { last = e; if (host) throw e; }
  }
  throw last instanceof Error ? last : new Error("تعذّر الاتصال بـ " + c.name);
}
function errText(b: any): string {
  if (!b || typeof b !== "object") return typeof b === "string" ? b.slice(0, 200) : "";
  if (b.errors && typeof b.errors === "object") return Object.entries(b.errors).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join("، ") : v}`).join(" | ");
  return b.message || b.error || "";
}
const okRes = (b: any) => b && (b.success === true || b.success === 1 || b.success === "true" || b.success === "1");
const rows = (b: any): any[] => Array.isArray(b) ? b : b && typeof b === "object" ? (Array.isArray(b.data) ? b.data : Object.values(b).filter(x => x && typeof x === "object")) : [];
const n = (x: unknown) => { const v = parseFloat(String(x ?? "").replace(",", ".")); return isFinite(v) ? v : null; };

// ---------- statuts ----------
const fold = (s: string) => (s || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[_-]/g, " ").replace(/\s+/g, " ").trim();
const EXACT: Record<string, string> = {
  "order information received by carrier": "created", "notification on order": "created", "en preparation": "created", "en preparation stock": "created",
  "prete a expedier": "pending", "en ramassage": "pending", "picked": "picked", "accepted by carrier": "picked", "vers hub": "transit", "en hub": "hub",
  "vers wilaya": "transit", "dispatched to driver": "out", "en livraison": "out", "attempt delivery": "attempt", "suspendu": "hold",
  "livred": "delivered", "livre": "delivered", "encaissed": "delivered", "payed": "delivered", "livre non encaisse": "delivered",
  "encaisse non paye": "delivered", "paiements prets": "delivered", "paye et archive": "delivered", "return asked": "returned",
  "return in transit": "returned", "return received": "returned", "retour chez livreur": "returned", "retour transit entrepot": "returned",
  "retour en traitement": "returned", "retour recu": "returned", "retour archive": "returned", "annule": "cancelled",
};
function norm(raw: string): string {
  const f = fold(raw); if (!f) return "unknown"; if (EXACT[f]) return EXACT[f];
  const has = (...w: string[]) => w.some(x => f.includes(x));
  if (has("retour", "return", "echec", "failed")) return "returned";
  if (has("annul", "cancel")) return "cancelled";
  if (has("livre", "delivered", "encaiss", "paye", "payed")) return has("en livraison", "sorti") ? "out" : "delivered";
  if (has("tentative", "attempt", "sans reponse")) return "attempt";
  if (has("en livraison", "sorti", "driver")) return "out";
  if (has("suspend", "reporte", "attente", "hold")) return "hold";
  if (has("hub", "centre", "agence", "bureau", "desk")) return "hub";
  if (has("transit", "expedie", "vers")) return "transit";
  if (has("ramass", "picked", "collect")) return "picked";
  return "created";
}

// ---------- actions ----------
async function defaultCarrier(db: any): Promise<Carrier> {
  const { data } = await db.from("dtf_ship_config").select("default_carrier").eq("id", 1).maybeSingle();
  return carrierOf(data?.default_carrier || "expedia");
}
const mapCommunes = (com: any) => rows(com).map((c: any) => ({ wilaya_code: n(c.wilaya_id), name: String(c.nom ?? c.name ?? "").trim(),
  has_desk: +c.has_stop_desk === 1 || c.has_stop_desk === true, code_postal: c.code_postal ? String(c.code_postal) : null }))
  .filter((c: any) => c.wilaya_code && c.name);

async function sync(db: any) {
  const c = await defaultCarrier(db);
  const [wil, fees, com] = await Promise.all([eco(c, "GET", "get/wilayas"), eco(c, "GET", "get/fees"), eco(c, "GET", "get/communes")]);
  const names = new Map<number, string>();
  for (const w of rows(wil)) { const k = n(w.wilaya_id ?? w.id ?? w.code); if (k) names.set(k, w.wilaya_name ?? w.name ?? w.nom ?? ""); }
  // get/fees : { livraison: [{ wilaya_id, tarif, tarif_stopdesk }], retours: [{ wilaya_id, tarif }], ... }
  const liv = rows(fees?.livraison ?? fees?.data?.livraison ?? fees);
  const ret = new Map<number, number | null>(rows(fees?.retours ?? fees?.retour ?? []).map((r: any) => [n(r.wilaya_id) as number, n(r.tarif)]));
  const rates = liv.map((r: any) => ({ wilaya_code: n(r.wilaya_id ?? r.code_wilaya), name: names.get(n(r.wilaya_id) as number) || null,
    home: n(r.tarif ?? r.tarif_livraison ?? r.home), desk: n(r.tarif_stopdesk ?? r.stop_desk ?? r.desk), retour: ret.get(n(r.wilaya_id) as number) ?? null,
    carrier: c.key, updated_at: new Date().toISOString() })).filter((r: any) => r.wilaya_code);
  const uniq = [...new Map(mapCommunes(com).map((x: any) => [x.wilaya_code + "|" + x.name, { ...x, carrier: c.key }])).values()];
  // Les tables gardent seulement la société par défaut : on retire ce qui n'est plus servi.
  if (rates.length) {
    const { error } = await db.from("dtf_ship_rates").upsert(rates); if (error) throw error;
    await db.from("dtf_ship_rates").delete().not("wilaya_code", "in", `(${rates.map((r: any) => r.wilaya_code).join(",")})`);
  }
  if (uniq.length) {
    await db.from("dtf_ship_communes").delete().or(`carrier.is.null,carrier.neq.${c.key}`);
    for (let i = 0; i < uniq.length; i += 500) { const { error } = await db.from("dtf_ship_communes").upsert(uniq.slice(i, i + 500)); if (error) throw error; }
  }
  await db.from("dtf_ship_config").update({ last_sync: new Date().toISOString(), last_error: null }).eq("id", 1);
  return { carrier: c.name, rates: rates.length, communes: uniq.length, host: c.host, sample: rates.length ? undefined : { feesKeys: fees && typeof fees === "object" ? Object.keys(fees) : typeof fees } };
}

async function create(db: any, b: any) {
  const c = b.carrier ? carrierOf(b.carrier) : await defaultCarrier(db);
  const { data: o, error } = await db.from("dtf_orders").select("*").eq("id", b.order_id).maybeSingle();
  if (error) throw error; if (!o) throw new Error("الطلبية غير موجودة");
  if (o.tracking_number) throw new Error("هذه الطلبية أُرسلت من قبل — رقم التتبع " + o.tracking_number);
  const desk = b.stop_desk ? 1 : 0;
  const phone = String(b.phone || "").replace(/\D/g, "").replace(/^213/, "0");
  if (phone.length < 9) throw new Error("رقم الهاتف غير صحيح");
  if (!b.wilaya_code || !b.commune) throw new Error("اختر الولاية والبلدية");
  const params = {
    reference: "MYDTF-" + o.code, nom_client: String(b.name || "").trim(), telephone: phone, telephone_2: b.phone2 || "",
    adresse: String(b.address || b.commune).trim(), code_wilaya: b.wilaya_code, commune: b.commune, montant: Math.round(+b.amount || 0),
    produit: (b.product || `طباعة DTF — طلبية ${o.code}`).slice(0, 255), remarque: b.note || "", type: 1, stop_desk: desk,
    code_postal: desk && b.code_postal ? b.code_postal : "", weight: b.weight || "",
  };
  const r = await eco(c, "POST", "create/order", params);
  const tracking = r?.tracking || r?.data?.tracking;
  if (!okRes(r) && !tracking) throw new Error(errText(r) || `رفضت ${c.name} إنشاء الطرد`);
  // Validation sans demande de ramassage : l'atelier dépose lui-même le colis au bureau.
  let validated = true, vErr = "";
  try { const v = await eco(c, "POST", "valid/order", { tracking, ask_collection: 0 }); if (v && v.success != null && !okRes(v)) { validated = false; vErr = errText(v); } }
  catch (e) { validated = false; vErr = (e as Error).message; }
  const { error: ue } = await db.from("dtf_orders").update({
    carrier: c.name, tracking_number: tracking, status: "shipped", shipped_at: new Date().toISOString(), ship_status: "created",
    ship_status_raw: validated ? "مُرسل" : "أُنشئ دون تأكيد", ship_cod: params.montant, ship_wilaya_code: b.wilaya_code,
    ship_commune: b.commune, ship_name: params.nom_client, ship_phone: phone, ship_address: params.adresse,
    delivery_mode: desk ? "stopdesk" : "home",
  }).eq("id", o.id);
  if (ue) throw ue;
  return { carrier: c.name, tracking, validated, warning: validated ? null : `أُنشئ الطرد لكن لم يُؤكَّد عند ${c.name}: ` + vErr };
}

async function track(db: any) {
  const { data: list, error } = await db.from("dtf_orders").select("id,code,carrier,tracking_number,ship_status,status")
    .in("carrier", Object.values(CARRIERS).map(c => c.name)).not("tracking_number", "is", null).or("ship_status.is.null,ship_status.not.in.(delivered,returned,cancelled)").limit(300);
  if (error) throw error;
  let updated = 0; const errors: string[] = [];
  for (const c of Object.values(CARRIERS)) {
  const mine = (list || []).filter((o: any) => o.carrier === c.name);
  if (!mine.length) continue;
  if (!c.token) { errors.push(`مفتاح ${c.name} غير مضاف`); continue; }
  for (let i = 0; i < mine.length; i += 100) {
    const part = mine.slice(i, i + 100);
    let b: any;
    try { b = await eco(c, "GET", "get/trackings/info", { trackings: part.map((o: any) => o.tracking_number) }); }
    catch (e) { errors.push((e as Error).message); break; }
    const map = new Map<string, any>();
    const src = b?.data ?? b;
    if (Array.isArray(src)) src.forEach((r: any) => r?.tracking && map.set(r.tracking, r));
    else if (src && typeof src === "object") Object.entries(src).forEach(([k, r]) => r && typeof r === "object" && map.set(k, r));
    for (const o of part) {
      const r = map.get(o.tracking_number); if (!r) continue;
      const acts: any[] = Array.isArray(r.activity) ? r.activity : [];
      const lastAct = acts.length ? acts[acts.length - 1] : null;
      const raw = String(lastAct?.status ?? r.status ?? "");
      const st = norm(raw);
      const patch: Record<string, unknown> = { ship_status: st, ship_status_raw: raw || null, ship_synced_at: new Date().toISOString(),
        ship_events: acts.slice(-30).map(a => ({ s: a.status, d: `${a.date ?? ""} ${a.time ?? ""}`.trim(), w: a.station ?? a.scanLocation ?? null })) };
      if (st === "delivered" && o.status !== "delivered") patch.status = "delivered";
      if (st !== o.ship_status) {
        updated++;
        if (st === "returned" || st === "attempt" || st === "hold") {
          const { data: staff } = await db.from("dtf_profiles").select("id").in("role", ["admin", "manager"]).eq("active", true);
          const t = st === "returned" ? "طرد مرتجع" : st === "attempt" ? "محاولة توصيل فاشلة" : "طرد معلّق";
          if (staff?.length) await db.from("dtf_notifications").insert(staff.map((s: any) => ({ user_id: s.id, order_id: o.id, title: `${t} — طلبية #${o.code}`, body: raw })));
        }
      }
      await db.from("dtf_orders").update(patch).eq("id", o.id);
    }
  }
  }
  await db.from("dtf_ship_config").update({ last_track: new Date().toISOString(), last_error: errors.length ? errors.join(" | ").slice(0, 300) : null }).eq("id", 1);
  return { checked: list?.length || 0, updated, errors };
}

async function cancel(db: any, b: any) {
  const { data: o } = await db.from("dtf_orders").select("id,carrier,tracking_number").eq("id", b.order_id).maybeSingle();
  if (!o?.tracking_number) throw new Error("لا يوجد طرد لهذه الطلبية");
  const c = carrierOf(o.carrier);
  const r = await eco(c, "DELETE", "delete/order", { tracking: o.tracking_number });
  if (r && (r.delete === "fail" || r.success === false)) throw new Error(`لا يمكن إلغاء هذا الطرد بعد الآن عند ${c.name}`);
  await db.from("dtf_orders").update({ tracking_number: null, carrier: null, ship_status: null, ship_status_raw: null, ship_events: null, shipped_at: null, status: "printed" }).eq("id", o.id);
  return { cancelled: true };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const db = createClient(url, service, { auth: { persistSession: false } });
  let body: any = {}; try { body = await req.json(); } catch { /* vide */ }
  const action = String(body.action || "");
  // Authentification : tâche planifiée (clé secrète en base) ou membre admin / gérant.
  const cronKey = req.headers.get("x-cron-key");
  let byCron = false;
  if (cronKey) {
    const { data } = await db.from("dtf_ship_config").select("cron_key").eq("id", 1).maybeSingle();
    if (!data || data.cron_key !== cronKey) return json({ error: "clé invalide" }, 401);
    if (!["track", "sync"].includes(action)) return json({ error: "action interdite" }, 403);
    byCron = true;
  } else {
    const auth = req.headers.get("Authorization") || "";
    if (!auth.startsWith("Bearer ")) return json({ error: "غير مسجّل" }, 401);
    const asUser = createClient(url, anon, { global: { headers: { Authorization: auth } }, auth: { persistSession: false } });
    const { data: role, error } = await asUser.rpc("dtf_my_role");
    if (error) return json({ error: "انتهت جلستك — أعد الدخول بحسابك" }, 401);
    if (!["admin", "manager"].includes(role)) return json({ error: "هذه العملية خاصة بالمدير والمسيّر" }, 403);
  }
  try {
    const anyToken = Object.values(CARRIERS).some(c => c.token);
    if (action === "status") {
      const { data } = await db.from("dtf_ship_config").select("origin,last_sync,last_track,last_error,default_carrier").eq("id", 1).maybeSingle();
      const { count } = await db.from("dtf_ship_rates").select("wilaya_code", { count: "exact", head: true });
      return json({ carriers: Object.values(CARRIERS).map(c => ({ key: c.key, name: c.name, secret: c.secret, configured: !!c.token })), rates: count || 0, ...data });
    }
    if (action === "set_default") {
      const c = carrierOf(String(body.carrier || ""));
      await db.from("dtf_ship_config").update({ default_carrier: c.key }).eq("id", 1);
      return json({ default_carrier: c.key });
    }
    if (action === "test") {
      const c = body.carrier ? carrierOf(body.carrier) : await defaultCarrier(db);
      const r = await eco(c, "GET", "validate/token", { api_token: c.token }).catch(async () => ({ fallback: rows(await eco(c, "GET", "get/wilayas")).length }));
      return json({ ok: true, carrier: c.name, host: c.host, r });
    }
    if (action === "communes") {
      const c = carrierOf(String(body.carrier || ""));
      return json({ communes: mapCommunes(await eco(c, "GET", "get/communes", { wilaya_id: body.wilaya_code })).filter((x: any) => !body.wilaya_code || x.wilaya_code === +body.wilaya_code) });
    }
    if (action === "sync") { if (byCron && !(await defaultCarrier(db)).token) return json({ skipped: true }); return json(await sync(db)); }
    if (action === "track") { if (byCron && !anyToken) return json({ skipped: true }); return json(await track(db)); }
    if (action === "create") return json(await create(db, body));
    if (action === "cancel") return json(await cancel(db, body));
    if (action === "label") {
      const { data: o } = await db.from("dtf_orders").select("carrier,tracking_number").eq("id", body.order_id).maybeSingle();
      if (!o?.tracking_number) throw new Error("لا يوجد طرد لهذه الطلبية");
      const pdf = await eco(carrierOf(o.carrier), "GET", "get/order/label", { tracking: o.tracking_number }, true) as Uint8Array;
      let s = ""; for (let i = 0; i < pdf.length; i += 0x8000) s += String.fromCharCode(...pdf.subarray(i, i + 0x8000));
      return json({ pdf: btoa(s), tracking: o.tracking_number });
    }
    return json({ error: "action inconnue" }, 400);
  } catch (e) {
    const msg = (e as Error).message || String(e);
    if (byCron) await db.from("dtf_ship_config").update({ last_error: msg.slice(0, 300) }).eq("id", 1);
    return json({ error: msg }, 400);
  }
});
