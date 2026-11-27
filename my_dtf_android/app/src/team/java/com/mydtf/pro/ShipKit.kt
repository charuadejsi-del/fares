package com.mydtf.pro

// Livraison (Expedia, DHD… via la fonction serveur « dtf-dhd ») : envoi d'un colis, étiquette PDF,
// suivi, annulation, et réglages de la société par défaut (application Admin).
import android.content.Context
import android.content.Intent
import android.util.Base64
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.LocalShipping
import androidx.compose.material.icons.rounded.Notes
import androidx.compose.material.icons.rounded.Payments
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Phone
import androidx.compose.material.icons.rounded.PictureAsPdf
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.mydtf.client.data.Supa
import com.mydtf.client.ui.components.CommunePicker
import com.mydtf.client.ui.components.GhostButton
import com.mydtf.client.ui.components.GoldButton
import com.mydtf.client.ui.components.LuxCard
import com.mydtf.client.ui.components.LuxField
import com.mydtf.client.ui.components.SectionTitle
import com.mydtf.client.ui.components.WilayaPicker
import com.mydtf.client.ui.components.bouncyClick
import com.mydtf.client.ui.theme.Lux
import com.mydtf.core.Algeria
import com.mydtf.core.Commune
import com.mydtf.core.Wilaya
import com.mydtf.core.formatDa
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.io.File

/** Sociétés gérées par l'API (les autres noms = saisie manuelle, pas de suivi automatique). */
val API_CARRIERS = setOf("Expedia", "DHD")

data class CarrierInfo(val key: String, val name: String, val secret: String, val configured: Boolean)
data class ShipStatus(val carriers: List<CarrierInfo>, val defaultCarrier: String, val rates: Int, val lastSync: String?, val lastTrack: String?, val lastError: String?)

object Ship {
    private suspend fun call(body: JsonObject): JsonObject {
        val r = Supa.client.functions.invoke("dtf-dhd", body)
        val obj = runCatching { Json.parseToJsonElement(r.bodyAsText()).jsonObject }.getOrNull() ?: JsonObject(emptyMap())
        obj["error"]?.jsonPrimitive?.contentOrNull?.let { throw IllegalStateException(it) }
        return obj
    }
    private fun JsonObject.str(k: String) = this[k]?.let { if (it is JsonPrimitive) it.contentOrNull else null }

    suspend fun status(): ShipStatus {
        val o = call(buildJsonObject { put("action", "status") })
        val cs = o["carriers"]?.jsonArray?.map { e -> val c = e.jsonObject
            CarrierInfo(c.str("key") ?: "", c.str("name") ?: "", c.str("secret") ?: "", c["configured"]?.jsonPrimitive?.booleanOrNull == true) } ?: emptyList()
        return ShipStatus(cs, o.str("default_carrier") ?: "expedia", o["rates"]?.jsonPrimitive?.intOrNull ?: 0, o.str("last_sync"), o.str("last_track"), o.str("last_error"))
    }
    suspend fun create(order: String, carrier: String, name: String, phone: String, wilaya: Int, commune: String, desk: Boolean, codePostal: String?, address: String, amount: Double, note: String): String {
        val o = call(buildJsonObject {
            put("action", "create"); put("order_id", order); put("carrier", carrier); put("name", name); put("phone", phone)
            put("wilaya_code", wilaya); put("commune", commune); put("stop_desk", desk); put("code_postal", codePostal)
            put("address", address); put("amount", amount); put("note", note)
        })
        return listOfNotNull(o.str("tracking"), o.str("warning")).joinToString(" — ")
    }
    suspend fun track(): String { val o = call(buildJsonObject { put("action", "track") }); return "فُحص ${o.str("checked")} طرد — ${o.str("updated")} تغيير" }
    suspend fun cancel(order: String) { call(buildJsonObject { put("action", "cancel"); put("order_id", order) }) }
    suspend fun setDefault(key: String) { call(buildJsonObject { put("action", "set_default"); put("carrier", key) }) }
    suspend fun sync(): String { val o = call(buildJsonObject { put("action", "sync") }); return "${o.str("carrier")}: ${o.str("rates")} ولاية و${o.str("communes")} بلدية" }
    suspend fun test(): String { val o = call(buildJsonObject { put("action", "test") }); return "الاتصال بـ ${o.str("carrier")} يعمل" }

    /** Télécharge l'étiquette officielle et l'ouvre (ou propose une application PDF / le partage). */
    suspend fun openLabel(ctx: Context, order: String) {
        val o = call(buildJsonObject { put("action", "label"); put("order_id", order) })
        val bytes = Base64.decode(o.str("pdf") ?: throw IllegalStateException("لا يوجد ملصق"), Base64.DEFAULT)
        val dir = File(ctx.cacheDir, "labels").apply { mkdirs() }
        val f = File(dir, "label-${o.str("tracking") ?: order}.pdf").apply { writeBytes(bytes) }
        val uri = FileProvider.getUriForFile(ctx, ctx.packageName + ".files", f)
        val view = Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/pdf").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { ctx.startActivity(view) }.onFailure {
            val share = Intent(Intent.ACTION_SEND).setType("application/pdf").putExtra(Intent.EXTRA_STREAM, uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            ctx.startActivity(Intent.createChooser(share, "الملصق").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
}

private val SHIP_LABELS = mapOf(
    "created" to "أُنشئ الطرد", "pending" to "جاهز للإرسال", "picked" to "استلمته الشركة", "transit" to "في الطريق",
    "hub" to "في المركز / المكتب", "out" to "خرج للتوصيل", "attempt" to "محاولة فاشلة", "hold" to "معلّق",
    "delivered" to "سُلّم", "returned" to "مرتجع", "cancelled" to "ملغى",
)

/** Bloc « livraison » d'une commande envoyée : n° de suivi, état, étiquette, suivi, annulation. */
@Composable
fun ShipBox(vm: ProViewModel, o: MgrOrder, onChanged: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var msg by remember { mutableStateOf<String?>(null) }
    fun go(block: suspend () -> String?) = scope.launch { busy = true; msg = runCatching { block() }.getOrElse { it.message }; busy = false }
    val t = o.trackingNumber ?: return
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Lux.Surface).border(1.dp, Lux.Gold.copy(alpha = 0.18f), RoundedCornerShape(16.dp)).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.LocalShipping, null, tint = Lux.Gold)
            Spacer(Modifier.padding(4.dp))
            Text(o.carrier ?: "", fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            o.shipStatus?.let { Text(SHIP_LABELS[it] ?: it, color = when (it) { "delivered" -> Lux.Success; "returned", "attempt" -> Lux.Danger; else -> Lux.GoldLight }, style = MaterialTheme.typography.labelLarge) }
        }
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Lux.Night2).bouncyClick {
            (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager).setPrimaryClip(android.content.ClipData.newPlainText("tracking", t))
            Toast.makeText(ctx, "نُسخ رقم التتبّع", Toast.LENGTH_SHORT).show()
        }.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(com.mydtf.core.ltr(t), style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f))
            Icon(Icons.Rounded.ContentCopy, "نسخ", tint = Lux.Gold)
        }
        o.shipCod?.let { Text("يُحصَّل من الزبون: ${formatDa(it)}", color = Lux.GoldLight) }
        o.shipStatusRaw?.let { Text(it, color = Lux.Muted, style = MaterialTheme.typography.bodySmall) }
        if (o.carrier in API_CARRIERS) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                GhostButton("الملصق", { go { Ship.openLabel(ctx, o.id); null } }, Modifier.weight(1f), Icons.Rounded.PictureAsPdf, enabled = !busy)
                GhostButton("تحديث", { go { Ship.track().also { onChanged() } } }, Modifier.weight(1f), Icons.Rounded.Refresh, enabled = !busy)
            }
            if (o.shipStatus == null || o.shipStatus == "created")
                GhostButton("إلغاء الطرد", { go { Ship.cancel(o.id); onChanged(); "أُلغي الطرد" } }, Modifier.fillMaxWidth(), Icons.Rounded.Cancel, enabled = !busy)
        }
        msg?.let { Text(it, color = Lux.Muted, style = MaterialTheme.typography.bodySmall) }
    }
}

/** Formulaire d'envoi d'un colis, pré-rempli depuis la commande. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShipFormSheet(o: MgrOrder, onClose: () -> Unit, onDone: (String) -> Unit) {
    val scope = rememberCoroutineScope()
    var st by remember { mutableStateOf<ShipStatus?>(null) }
    var err by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { runCatching { st = Ship.status() }.onFailure { err = it.message } }
    val carriers = st?.carriers?.filter { it.configured } ?: emptyList()
    var carrier by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(st) { if (carrier == null) carrier = carriers.firstOrNull { it.key == st?.defaultCarrier }?.key ?: carriers.firstOrNull()?.key }
    val isDefault = carrier != null && carrier == st?.defaultCarrier
    var desk by remember { mutableStateOf(o.deliveryMode == "stopdesk") }
    var name by remember { mutableStateOf(o.shipName.orEmpty()) }
    var phone by remember { mutableStateOf(o.shipPhone.orEmpty()) }
    var wilaya by remember { mutableStateOf<Wilaya?>(o.shipWilayaCode?.let { c -> Algeria.wilayas.firstOrNull { it.c == c } } ?: Algeria.wilayaByName(o.shipWilaya)) }
    var commune by remember { mutableStateOf<Commune?>(Algeria.communeByName(wilaya, o.shipCommune)) }
    var communeText by remember { mutableStateOf(o.shipCommune.orEmpty()) }
    var address by remember { mutableStateOf(o.shipAddress.orEmpty()) }
    var amount by remember { mutableStateOf("%.0f".format(o.printAmount + o.deliveryFee - o.amountPaid)) }
    var note by remember { mutableStateOf("") }
    val fee = wilaya?.let { if (desk) it.desk else it.home }
    ModalBottomSheet(onDismissRequest = onClose, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Lux.Night2) {
        Column(Modifier.verticalScroll(rememberScrollState()).padding(16.dp).navigationBarsPadding().imePadding(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("إرسال الطرد — طلبية ${o.code}", style = MaterialTheme.typography.headlineSmall)
            if (st != null && carriers.isEmpty()) Text("لا توجد شركة توصيل مفعّلة — أضف مفتاحها في Supabase.", color = Lux.Danger)
            if (carriers.size > 1) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                carriers.forEach { c -> ShipChip(c.name, carrier == c.key, Modifier.weight(1f)) { carrier = c.key } }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ShipChip("إلى المنزل", !desk, Modifier.weight(1f)) { desk = false }
                ShipChip("مكتب الشركة", desk, Modifier.weight(1f)) { desk = true; if (commune?.desk == false) commune = null }
            }
            LuxField(name, { name = it }, "اسم المستلم", leading = Icons.Rounded.Person)
            LuxField(phone, { phone = it.filter { c -> c.isDigit() || c == ' ' || c == '+' }.take(14) }, "الهاتف", leading = Icons.Rounded.Phone, keyboard = KeyboardType.Phone)
            WilayaPicker(wilaya, { wilaya = it; commune = null })
            if (isDefault && Algeria.isLive) CommunePicker(wilaya, commune, { commune = it }, deskOnly = desk)
            else LuxField(communeText, { communeText = it }, "البلدية (كما تُكتب عند الشركة)")
            if (!desk) LuxField(address, { address = it }, "العنوان", leading = Icons.Rounded.Home)
            LuxField(amount, { amount = it.filter { c -> c.isDigit() || c == '.' } }, "المبلغ الذي يدفعه الزبون للموزّع (دج)", leading = Icons.Rounded.Payments, keyboard = KeyboardType.Number)
            LuxField(note, { note = it }, "ملاحظة للموزّع", leading = Icons.Rounded.Notes)
            LuxCard(Modifier.fillMaxWidth()) {
                Text("الطباعة ${formatDa(o.printAmount)} + التوصيل ${formatDa(o.deliveryFee)}" + if (o.amountPaid > 0) " − المدفوع ${formatDa(o.amountPaid)}" else "", style = MaterialTheme.typography.bodySmall)
                if (isDefault && fee != null) Text("سعر الشركة لهذه الولاية: ${formatDa(fee.toDouble())}" + if (fee.toDouble() != o.deliveryFee) " — يختلف عن المسجّل" else "",
                    color = if (fee.toDouble() != o.deliveryFee) Lux.Danger else Lux.GoldLight, style = MaterialTheme.typography.bodySmall)
                Text("بعد الإرسال: اطبع الملصق وخذ الطرد إلى مكتب الشركة.", color = Lux.Muted, style = MaterialTheme.typography.bodySmall)
            }
            err?.let { Text(it, color = Lux.Danger) }
            val comm = if (isDefault && Algeria.isLive) commune?.fr else communeText.trim().ifEmpty { null }
            GoldButton("إنشاء الطرد عند ${carriers.firstOrNull { it.key == carrier }?.name ?: ""}", icon = Icons.Rounded.LocalShipping, loading = busy,
                enabled = carrier != null && name.isNotBlank() && wilaya != null && comm != null, modifier = Modifier.fillMaxWidth(), onClick = {
                    scope.launch {
                        busy = true; err = null
                        runCatching {
                            Ship.create(o.id, carrier!!, name.trim(), phone, wilaya!!.c, comm!!, desk, commune?.code, address.trim(), amount.toDoubleOrNull() ?: 0.0, note.trim())
                        }.onSuccess { onDone("أُرسل الطرد — $it") }.onFailure { err = it.message }
                        busy = false
                    }
                })
            Spacer(Modifier.height(16.dp))
        }
    }
}

@Composable
private fun ShipChip(text: String, on: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Text(text, modifier.clip(RoundedCornerShape(50)).background(if (on) Lux.Gold else Lux.Surface)
        .border(1.dp, if (on) Lux.Gold else Lux.Surface2, RoundedCornerShape(50)).bouncyClick(onClick = onClick).padding(vertical = 10.dp),
        color = if (on) Lux.OnAccent else Lux.Ivory, fontWeight = FontWeight.Bold, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
}

/** Réglages de livraison (application Admin) : société par défaut, synchronisation, test, suivi. */
@Composable
fun DeliverySettingsCard() {
    val scope = rememberCoroutineScope()
    var st by remember { mutableStateOf<ShipStatus?>(null) }
    var msg by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    suspend fun reload() { st = runCatching { Ship.status() }.onFailure { msg = it.message }.getOrNull() }
    LaunchedEffect(Unit) { reload() }
    fun go(block: suspend () -> String) = scope.launch { busy = true; msg = runCatching { block() }.getOrElse { it.message }; reload(); busy = false }
    LuxCard(Modifier.fillMaxWidth()) {
        SectionTitle("التوصيل")
        val s = st
        if (s == null) { Text(msg ?: "...", color = Lux.Muted); return@LuxCard }
        Text("الشركة الافتراضية — منها أسعار التوصيل وإليها تُرسل الطرود", color = Lux.Muted, style = MaterialTheme.typography.bodySmall)
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            s.carriers.forEach { c -> ShipChip(c.name + if (c.configured) " ✓" else "", c.key == s.defaultCarrier, Modifier.weight(1f)) {
                if (c.key != s.defaultCarrier) go { Ship.setDefault(c.key); if (c.configured) Ship.sync() else "أُضيفت ${c.name} كشركة افتراضية — أضف مفتاحها ${c.secret}" }
            } }
        }
        val def = s.carriers.firstOrNull { it.key == s.defaultCarrier }
        if (def != null && !def.configured) Text("أضف مفتاح ${def.name} في Supabase ← Edge Functions ← Secrets باسم ${def.secret}.", color = Lux.Danger, style = MaterialTheme.typography.bodySmall)
        Spacer(Modifier.height(6.dp))
        Text("${s.rates} ولاية لها سعر · آخر مزامنة ${s.lastSync?.take(16)?.replace('T', ' ') ?: "—"} · آخر تتبّع ${s.lastTrack?.take(16)?.replace('T', ' ') ?: "—"}",
            color = Lux.Muted, style = MaterialTheme.typography.bodySmall)
        s.lastError?.let { Text("آخر خطأ: $it", color = Lux.Danger, style = MaterialTheme.typography.bodySmall) }
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GhostButton("اختبار", { go { Ship.test() } }, Modifier.weight(1f), enabled = !busy && def?.configured == true)
            GhostButton("مزامنة", { go { Ship.sync() } }, Modifier.weight(1f), Icons.Rounded.Sync, enabled = !busy && def?.configured == true)
            GhostButton("التتبّع", { go { Ship.track() } }, Modifier.weight(1f), Icons.Rounded.Refresh, enabled = !busy)
        }
        msg?.let { Text(it, color = Lux.GoldLight, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 6.dp)) }
    }
}
