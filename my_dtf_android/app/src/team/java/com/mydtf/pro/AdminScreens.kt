package com.mydtf.pro

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.AccessTime
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Inventory
import androidx.compose.material.icons.rounded.Payments
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.mydtf.client.data.PriceTier
import com.mydtf.client.ui.components.AnimatedNumber
import com.mydtf.client.ui.components.EmptyState
import com.mydtf.client.ui.components.GhostButton
import com.mydtf.client.ui.components.GoldButton
import com.mydtf.client.ui.components.LuxCard
import com.mydtf.client.ui.components.LuxField
import com.mydtf.client.ui.components.SectionTitle
import com.mydtf.client.ui.components.Shimmer
import com.mydtf.client.ui.components.bouncyClick
import com.mydtf.client.ui.components.staggerIn
import com.mydtf.client.ui.theme.Lux
import com.mydtf.core.formatDa
import com.mydtf.core.ltr
import java.time.LocalDate
import java.time.YearMonth

private fun d(s: String) = s.replace(',', '.').trim().toDoubleOrNull()
private fun f0(v: Double) = if (v % 1.0 == 0.0) "%.0f".format(java.util.Locale.US, v) else "%.2f".format(java.util.Locale.US, v).trimEnd('0').trimEnd('.')
private val Amber = Color(0xFFFBBF24)

// =========================== Menu « Plus » ===========================
private data class Section(val id: String, val label: String, val icon: ImageVector, val sub: String)
private val SECTIONS = listOf(
    Section("stock", "المخزون", Icons.Rounded.Inventory, "الرولوات، الحبر، البودرة"),
    Section("costs", "التكاليف والأرباح", Icons.Rounded.Payments, "للمتر، اليوم، الشهر"),
    Section("perf", "الأداء", Icons.Rounded.EmojiEvents, "نقطة كل عامل والتقييمات"),
    Section("attendance", "الحضور", Icons.Rounded.AccessTime, "الدخول والخروج والساعات"),
    Section("team", "الفريق", Icons.Rounded.Groups, "الحسابات والرموز"),
    Section("settings", "الإعدادات", Icons.Rounded.Settings, "الأسعار والجملة والورشة"),
)

@Composable
fun AdminMore(vm: ProViewModel) {
    var open by remember { mutableStateOf<String?>(null) }
    AnimatedContent(open, transitionSpec = { (slideInHorizontally { -it / 4 } + fadeIn()) togetherWith fadeOut() }, label = "more") { sec ->
        if (sec == null) {
            LazyVerticalGrid(GridCells.Fixed(2), contentPadding = PaddingValues(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                itemsIndexed(SECTIONS) { i, s ->
                    LuxCard(Modifier.staggerIn(i).aspectRatio(1f), onClick = { open = s.id }) {
                        Box(Modifier.size(52.dp).clip(RoundedCornerShape(16.dp)).background(Lux.goldBrush), contentAlignment = Alignment.Center) { Icon(s.icon, null, tint = Lux.OnAccent) }
                        Spacer(Modifier.weight(1f))
                        Text(s.label, style = MaterialTheme.typography.titleMedium)
                        Text(s.sub, style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
                    }
                }
            }
        } else {
            BackHandler { open = null }
            Column(Modifier.fillMaxSize()) {
                Row(Modifier.padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(42.dp).clip(CircleShape).bouncyClick { open = null }, contentAlignment = Alignment.Center) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "رجوع") }
                    Text(SECTIONS.first { it.id == sec }.label, style = MaterialTheme.typography.titleLarge)
                }
                Box(Modifier.weight(1f)) {
                    when (sec) {
                        "stock" -> StockScreen(vm)
                        "costs" -> CostsScreen(vm)
                        "perf" -> PerfScreen(vm)
                        "attendance" -> AttendanceScreen(vm)
                        "team" -> TeamScreen(vm)
                        "settings" -> SettingsScreen(vm)
                    }
                }
            }
        }
    }
}

@Composable
private fun Page(content: @Composable ColumnScope.() -> Unit) =
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).imePadding().padding(16.dp, 4.dp, 16.dp, 30.dp), verticalArrangement = Arrangement.spacedBy(12.dp), content = content)

@Composable
private fun Note(text: String?) { if (text != null) Text(text, color = if (text.startsWith("✓")) Lux.Success else Lux.Danger, style = MaterialTheme.typography.bodySmall) }

@Composable
private fun Seg(options: List<String>, sel: Int, onSel: (Int) -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        options.forEachIndexed { i, t ->
            val on = i == sel
            Box(Modifier.clip(CircleShape).background(if (on) Lux.Gold.copy(alpha = 0.18f) else Lux.Surface).border(1.dp, if (on) Lux.Gold else Lux.Surface2, CircleShape)
                .bouncyClick { onSel(i) }.padding(horizontal = 14.dp, vertical = 8.dp)) { Text(t, color = if (on) Lux.GoldLight else Lux.Ivory, fontWeight = FontWeight.Bold) }
        }
    }
}

// =========================== Commande : extras administrateur ===========================
@Composable
fun AdminOrderExtras(vm: ProViewModel, o: MgrOrder) {
    var rating by remember { mutableStateOf<OrderRating?>(null) }
    var sp by remember { mutableStateOf("") }
    var msg by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(o.id) {
        rating = Admin.rating(o.id)
        sp = Admin.client(o.clientId)?.specialPrice?.let { f0(it) } ?: ""
    }
    rating?.let { r ->
        LuxCard(Modifier.fillMaxWidth(), highlight = r.stars <= 2) {
            Row { repeat(5) { k -> Icon(Icons.Rounded.Star, null, tint = if (k < r.stars) Amber else Lux.Surface2) } }
            r.comment?.let { Text(it, color = Lux.Muted) }
        }
    }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.weight(1f)) { LuxField(sp, { sp = it }, "سعر خاص لهذا الزبون (فارغ = عادي)", keyboard = KeyboardType.Decimal) }
        Spacer(Modifier.width(8.dp))
        GhostButton("حفظ", { vm.act(onDone = { e -> msg = e ?: "✓ حُفظ السعر الخاص" }) { Admin.setClientPrice(o.clientId, d(sp)) } })
    }
    Note(msg)
}

// =========================== Machine : ajout / modification ===========================
@Composable
fun MachineFormDialog(vm: ProViewModel, m: Machine?, onClose: () -> Unit) {
    var name by remember { mutableStateOf(m?.name ?: "") }
    var width by remember { mutableStateOf(f0(m?.widthCm ?: 60.0)) }
    var model by remember { mutableStateOf(m?.model ?: "") }
    var active by remember { mutableStateOf(m?.active ?: true) }
    var err by remember { mutableStateOf<String?>(null) }
    AlertDialog(
        onDismissRequest = onClose, containerColor = Lux.Surface,
        title = { Text(if (m == null) "إضافة آلة DTF" else "تعديل ${m.name}") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                LuxField(name, { name = it }, "اسم الآلة")
                LuxField(width, { width = it }, "عرض الطباعة (سم)", keyboard = KeyboardType.Decimal)
                LuxField(model, { model = it }, "الموديل")
                if (m != null) Row(verticalAlignment = Alignment.CenterVertically) {
                    Switch(active, { active = it }, colors = SwitchDefaults.colors(checkedTrackColor = Lux.GoldDeep)); Spacer(Modifier.width(8.dp)); Text("في الخدمة")
                }
                Note(err)
            }
        },
        confirmButton = { TextButton(onClick = { vm.act(onDone = { e -> if (e == null) onClose() else err = e }) { Admin.saveMachine(m?.id, name.trim(), d(width) ?: 60.0, model.ifBlank { null }, active) } }, enabled = name.isNotBlank()) { Text("حفظ", color = Lux.GoldLight) } },
        dismissButton = { TextButton(onClick = onClose) { Text("إلغاء") } },
    )
}

// =========================== Stock ===========================
@Composable
private fun StockScreen(vm: ProViewModel) {
    var rolls by remember { mutableStateOf<List<Roll>?>(null) }
    var moves by remember { mutableStateOf<List<FilmMove>>(emptyList()) }
    var sup by remember { mutableStateOf<List<SupplyFull>>(emptyList()) }
    var form by remember { mutableStateOf("") }
    var a by remember { mutableStateOf("") }; var b by remember { mutableStateOf("") }; var c by remember { mutableStateOf("") }; var s by remember { mutableStateOf("") }
    var msg by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(vm.tick) {
        rolls = runCatching { Admin.rolls() }.getOrDefault(emptyList()); moves = runCatching { Admin.filmMoves() }.getOrDefault(emptyList()); sup = runCatching { Admin.supplies() }.getOrDefault(emptyList())
    }
    fun open(f: String, x: String = "", y: String = "", z: String = "") { form = f; a = x; b = y; c = z; s = ""; msg = null }
    Page {
        val r = rolls
        if (r == null) { Shimmer(Modifier.fillMaxWidth().height(140.dp)); return@Page }
        val inStock = r.filter { it.status == "stock" }
        LuxCard(Modifier.fillMaxWidth().staggerIn(0), highlight = true) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                Stat("الفيلم المتبقي", m2(r.filter { it.status != "finished" }.sumOf { it.remainingM }))
                Stat("رولوات احتياطية", "${inStock.size}", color = if (inStock.isEmpty()) Lux.Danger else Lux.Ivory)
                Stat("على الآلات", "${r.count { it.status == "active" }}")
            }
            Spacer(Modifier.height(12.dp))
            GoldButton("تسجيل شراء رولوات", icon = Icons.Rounded.Add, modifier = Modifier.fillMaxWidth(), onClick = { open("rolls", "6", "200", "") })
        }
        if (form == "rolls") LuxCard(Modifier.fillMaxWidth()) {
            LuxField(a, { a = it }, "عدد الرولوات", keyboard = KeyboardType.Number)
            LuxField(b, { b = it }, "طول الرولو (م)", keyboard = KeyboardType.Decimal)
            LuxField(c, { c = it }, "ثمن الرولو الواحد (دج)", keyboard = KeyboardType.Decimal)
            LuxField(s, { s = it }, "المورّد")
            GoldButton("حفظ", modifier = Modifier.fillMaxWidth().padding(top = 8.dp), enabled = (a.toIntOrNull() ?: 0) > 0 && (d(b) ?: 0.0) > 0,
                onClick = { vm.act(onDone = { e -> msg = e ?: "✓ أُضيفت الرولوات للمخزون"; if (e == null) form = "" }) { Admin.addRolls(a.toInt(), d(b)!!, d(c) ?: 0.0, s.ifBlank { null }) } })
        }
        SectionTitle("رولو كل آلة")
        vm.board.filter { it.active }.forEach { m ->
            val low = m.rollCode != null && (m.rollRemaining ?: 0.0) <= (m.alertM ?: 0.0)
            LuxCard(Modifier.fillMaxWidth()) {
                Row { Text(m.name, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f)); Text(if (m.rollCode != null) ltr("%.1f / %.0f م".format(m.rollRemaining, m.rollLength)) else "بدون رولو", color = if (low) Lux.Danger else Lux.Muted) }
                Spacer(Modifier.height(6.dp)); Gauge(if (m.rollCode != null) ((m.rollRemaining ?: 0.0) / (m.rollLength ?: 1.0)).toFloat() else 0f, low)
                Spacer(Modifier.height(8.dp))
                GhostButton(if (m.rollCode != null) "تغيير الرولو" else "تركيب رولو", { vm.act(onDone = { e -> msg = e ?: "✓ رُكّب الرولو على ${m.name}" }) { Pro.mountRoll(m.id) } }, Modifier.fillMaxWidth())
            }
        }
        SectionTitle("الحبر والبودرة")
        sup.forEach { x ->
            val ink = x.kind == "ink"; val u = if (ink) "لتر" else "كغ"; val low = x.stock <= x.alert
            LuxCard(Modifier.fillMaxWidth(), highlight = low) {
                Row { Text(if (ink) "الحبر" else "البودرة", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f)); Text(ltr("%.2f".format(x.stock.coerceAtLeast(0.0) / 1000)) + " $u", color = if (low) Lux.Danger else Lux.GoldLight, fontWeight = FontWeight.ExtraBold) }
                Spacer(Modifier.height(6.dp)); Gauge((x.stock / maxOf(x.alert * 4, x.stock, 1.0)).toFloat(), low)
                Text("التنبيه تحت ${f0(x.alert / 1000)} $u · متوسّط السعر ${formatDa(x.avgPrice)} لل$u", style = MaterialTheme.typography.labelSmall, color = Lux.Muted, modifier = Modifier.padding(top = 6.dp))
                Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    GhostButton("شراء", { open("buy_" + x.kind) }, Modifier.weight(1f))
                    GhostButton("جرد", { open("adj_" + x.kind, f0(x.stock.coerceAtLeast(0.0) / 1000)) }, Modifier.weight(1f))
                    GhostButton("التنبيه", { open("al_" + x.kind, f0(x.alert / 1000)) }, Modifier.weight(1f))
                }
                if (form.endsWith("_" + x.kind)) {
                    Spacer(Modifier.height(8.dp))
                    when {
                        form.startsWith("buy") -> {
                            LuxField(a, { a = it }, "الكمية ($u)", keyboard = KeyboardType.Decimal)
                            LuxField(b, { b = it }, "السعر الإجمالي (دج)", keyboard = KeyboardType.Decimal)
                            LuxField(s, { s = it }, "المورّد")
                            GoldButton("حفظ الشراء", modifier = Modifier.fillMaxWidth().padding(top = 8.dp), enabled = (d(a) ?: 0.0) > 0 && d(b) != null,
                                onClick = { vm.act(onDone = { e -> msg = e ?: "✓ سُجّل الشراء وتحدّث السعر في الحسابات"; if (e == null) form = "" }) { Admin.buySupply(x.kind, d(a)!! * 1000, d(b)!!, s.ifBlank { null }) } })
                        }
                        form.startsWith("adj") -> {
                            LuxField(a, { a = it }, "الكمية الموجودة فعلاً ($u)", keyboard = KeyboardType.Decimal)
                            GoldButton("حفظ الجرد", modifier = Modifier.fillMaxWidth().padding(top = 8.dp), enabled = d(a) != null,
                                onClick = { vm.act(onDone = { e -> msg = e ?: "✓ سُجّل الجرد"; if (e == null) form = "" }) { Admin.adjustSupply(x.kind, d(a)!! * 1000) } })
                        }
                        else -> {
                            LuxField(a, { a = it }, "نبّهني تحت ($u)", keyboard = KeyboardType.Decimal)
                            GoldButton("حفظ", modifier = Modifier.fillMaxWidth().padding(top = 8.dp), enabled = d(a) != null,
                                onClick = { vm.act(onDone = { e -> msg = e ?: "✓ حُفظ حدّ التنبيه"; if (e == null) form = "" }) { Admin.supplyAlert(x.kind, d(a)!! * 1000) } })
                        }
                    }
                }
            }
        }
        Note(msg)
        SectionTitle("الرولوات")
        r.take(40).forEach { x ->
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Lux.Surface).padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("#${x.code}", fontWeight = FontWeight.Bold, modifier = Modifier.width(56.dp))
                Column(Modifier.weight(1f)) {
                    Text(ltr("%.1f / %.0f م".format(x.remainingM, x.lengthM)))
                    Text((x.supplier ?: "") + " · " + formatDa(x.unitPrice), style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
                }
                val (t, col) = when (x.status) { "active" -> "مركّب" to Lux.Success; "stock" -> "مخزون" to Lux.GoldLight; else -> "منتهي" to Lux.Muted }
                Text(t, color = col, fontWeight = FontWeight.Bold)
            }
        }
        SectionTitle("آخر حركات الفيلم")
        moves.take(30).forEach { mv ->
            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                Text(hhmm(mv.createdAt), style = MaterialTheme.typography.labelSmall, color = Lux.Muted, modifier = Modifier.width(54.dp))
                Text(when (mv.kind) { "print" -> "طباعة"; "waste" -> "هدر"; else -> mv.kind }, modifier = Modifier.width(60.dp), color = if (mv.kind == "waste") Amber else Lux.Ivory)
                Text(m2(mv.meters), fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                Text(vm.name(mv.actorId), style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
            }
        }
    }
}

// =========================== Coûts et bénéfices ===========================
data class Period(val meters: Double, val days: Int, val film: Double, val ink: Double, val powder: Double, val wages: Double, val fixed: Double, val waste: Double, val revenue: Double) {
    val cost get() = film + ink + powder + wages + fixed + waste
    val profit get() = revenue - cost
    val margin get() = if (revenue > 0) profit / revenue else null
    fun pm(v: Double) = if (meters > 0) v / meters else null
}

/** Mêmes formules que le site (costs.js) : vérifiées avec l'exemple 50 m/jour → 575,27 / 824,73 دج. */
private fun activeFrom(from: String?, start: String?) = listOfNotNull(from, start).maxOrNull()
fun wagesOn(c: CostSettings, day: String) = c.wages.filter { val f = activeFrom(it.from, c.startDate); f == null || day >= f }.sumOf { it.amount }
fun fixedOn(c: CostSettings, day: String) = c.fixedCosts.filter { val f = activeFrom(it.from, c.startDate); f == null || day >= f }.sumOf { it.amount }
fun fixedForMonth(c: CostSettings, ym: YearMonth): Double {
    val dim = ym.lengthOfMonth()
    return c.fixedCosts.sumOf { f -> val from = activeFrom(f.from, c.startDate); val n = (1..dim).count { d -> from == null || ym.atDay(d).toString() >= from }; f.amount * n / dim }
}
fun costPeriod(c: CostSettings, meters: Double, waste: Double, days: Int, wages: Double, fixed: Double, value: Double): Period {
    val film = c.rollPrice / c.rollLengthM; val ink = c.inkPriceL / 1000 * c.inkMlPerM; val powder = c.powderPriceKg / 1000 * c.powderGPerM
    return Period(meters, days, film * meters, ink * meters, powder * meters, wages, fixed, if (c.wasteInProfit) (film + ink + powder) * waste else 0.0, value)
}

@Composable
private fun CostsScreen(vm: ProViewModel) {
    var tab by remember { mutableIntStateOf(0) }
    var ym by remember { mutableStateOf(YearMonth.now()) }
    var cs by remember { mutableStateOf<CostSettings?>(null) }
    var days by remember { mutableStateOf<List<CostDay>?>(null) }
    var sel by remember { mutableIntStateOf(-1) }
    LaunchedEffect(ym, vm.tick) {
        cs = runCatching { Admin.costSettings() }.getOrNull()
        val ongoing = ym == YearMonth.now()
        days = runCatching { Admin.costDays(ym.atDay(1).toString(), (if (ongoing) LocalDate.now() else ym.atEndOfMonth()).toString()) }.getOrDefault(emptyList())
        sel = (days?.size ?: 0) - 1
    }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) { Seg(listOf("اللوحة", "الإعدادات"), tab) { tab = it } }
        val c = cs; val ds = days
        if (c == null || ds == null) { Box(Modifier.padding(16.dp)) { Shimmer(Modifier.fillMaxWidth().height(160.dp)) }; return@Column }
        if (tab == 1) { CostSettingsForm(vm, c); return@Column }
        val ongoing = ym == YearMonth.now()
        val isOn = { x: CostDay -> (c.startDate == null || x.day >= c.startDate) && (x.meters > 0 || x.wasteM > 0) }
        val workedDays = ds.filter(isOn); val worked = workedDays.size
        val M = ds.sumOf { it.meters }; val W = ds.sumOf { it.wasteM }; val V = ds.sumOf { it.value }
        val fixedM = fixedForMonth(c, ym)
        val actual = costPeriod(c, M, W, worked, workedDays.sumOf { wagesOn(c, it.day) }, fixedM, V)
        val proj = if (ongoing && worked > 0) {
            val dim = ym.lengthOfMonth(); val n = (1..dim).count { d -> c.startDate == null || ym.atDay(d).toString() >= c.startDate }
            val eff = maxOf(worked.toDouble(), c.workDays * n.toDouble() / dim); val k = eff / worked
            costPeriod(c, M * k, W * k, eff.toInt(), wagesOn(c, ym.atEndOfMonth().toString()) * eff, fixedM, V * k)
        } else null
        val ref = proj ?: actual
        val perDay = ds.map { x -> val on = isOn(x); costPeriod(c, x.meters, x.wasteM, if (on) 1 else 0, if (on) wagesOn(c, x.day) else 0.0, if (on) fixedOn(c, x.day) / c.workDays else 0.0, x.value) }
        val maxAbs = (perDay.maxOfOrNull { kotlin.math.abs(it.profit) } ?: 1.0).coerceAtLeast(1.0)
        Page {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(40.dp).clip(CircleShape).bouncyClick { ym = ym.minusMonths(1) }, contentAlignment = Alignment.Center) { Icon(Icons.Rounded.ChevronRight, "السابق") }
                Text("${ym.monthValue} / ${ym.year}".let { ltr(it) }, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                Box(Modifier.size(40.dp).clip(CircleShape).bouncyClick(enabled = !ongoing) { ym = ym.plusMonths(1) }, contentAlignment = Alignment.Center) { Icon(Icons.Rounded.ChevronLeft, "التالي", tint = if (ongoing) Lux.Surface2 else Lux.Ivory) }
            }
            LuxCard(Modifier.fillMaxWidth().staggerIn(0), highlight = true) {
                Text(if (ongoing) "الربح الصافي حتى اليوم" else "الربح الصافي للشهر", color = Lux.Muted, style = MaterialTheme.typography.labelMedium)
                AnimatedNumber(actual.profit, { formatDa(Math.round(it).toDouble()) }, MaterialTheme.typography.headlineMedium, if (actual.profit < 0) Lux.Danger else Lux.Success)
                Text("${m2(M)} في $worked يوم عمل", color = Lux.Muted, style = MaterialTheme.typography.labelSmall)
                if (proj != null) Text("التوقّع لنهاية الشهر: ${formatDa(Math.round(proj.profit).toDouble())}", color = Lux.GoldLight, modifier = Modifier.padding(top = 6.dp))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                LuxCard(Modifier.weight(1f)) { Stat("التكلفة للمتر", ref.pm(ref.cost)?.let { formatDa(Math.round(it).toDouble()) } ?: "—", modifier = Modifier.fillMaxWidth()) }
                LuxCard(Modifier.weight(1f)) { Stat("الربح للمتر", ref.pm(ref.profit)?.let { formatDa(Math.round(it).toDouble()) } ?: "—", ref.margin?.let { "الهامش " + ltr("%.1f%%".format(it * 100)) }, modifier = Modifier.fillMaxWidth()) }
            }
            SectionTitle("الربح اليومي")
            LuxCard(Modifier.fillMaxWidth()) {
                Canvas(Modifier.fillMaxWidth().height(170.dp)) {
                    val n = perDay.size.coerceAtLeast(1); val bw = size.width / n; val mid = size.height / 2
                    drawLine(Color(0x33FFFFFF), Offset(0f, mid), Offset(size.width, mid), 1f)
                    perDay.forEachIndexed { i, p ->
                        val h = (kotlin.math.abs(p.profit) / maxAbs * (mid - 6)).toFloat()
                        // RTL : le 1er jour à droite
                        val x = size.width - (i + 1) * bw + bw * 0.18f
                        val pos = p.profit >= 0
                        drawRoundRect(if (pos) Brush.verticalGradient(listOf(Color(0xFF4ADE80), Color(0x6610B981))) else Brush.verticalGradient(listOf(Color(0x66F87171), Color(0xFFF87171))),
                            Offset(x, if (pos) mid - h else mid), Size(bw * 0.64f, h.coerceAtLeast(1f)), CornerRadius(4f))
                        if (i == sel) drawRoundRect(Color(0x338B5CF6), Offset(x - bw * 0.14f, 0f), Size(bw * 0.92f, size.height), CornerRadius(6f))
                    }
                }
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    ds.forEachIndexed { i, x -> Box(Modifier.clip(CircleShape).background(if (i == sel) Lux.Gold.copy(alpha = 0.2f) else Color.Transparent).bouncyClick { sel = i }.padding(6.dp)) {
                        Text(ltr(x.day.takeLast(2)), style = MaterialTheme.typography.labelSmall, color = if (x.meters > 0) Lux.Ivory else Lux.Muted) } }
                }
            }
            val D = perDay.getOrNull(sel)
            SectionTitle("التفصيل")
            LuxCard(Modifier.fillMaxWidth()) {
                Row { Text("", Modifier.weight(1.3f)); Text("للمتر", Modifier.weight(1f), color = Lux.Muted); Text("اليوم ${ds.getOrNull(sel)?.day?.takeLast(2) ?: ""}", Modifier.weight(1f), color = Lux.Muted); Text("الشهر", Modifier.weight(1.2f), color = Lux.Muted) }
                fun row(t: String, per: Double?, day: Double?, mo: Double, strong: Boolean = false) = @Composable {
                    Row(Modifier.padding(vertical = 5.dp)) {
                        Text(t, Modifier.weight(1.3f), fontWeight = if (strong) FontWeight.Bold else FontWeight.Normal)
                        Text(per?.let { f0(Math.round(it).toDouble()) } ?: "—", Modifier.weight(1f))
                        Text(day?.let { f0(Math.round(it).toDouble()) } ?: "—", Modifier.weight(1f))
                        Text(f0(Math.round(mo).toDouble()), Modifier.weight(1.2f), fontWeight = if (strong) FontWeight.Bold else FontWeight.Normal, color = if (strong && mo < 0) Lux.Danger else Lux.Ivory)
                    }
                }
                val on = D != null && D.days > 0
                row("الفيلم", ref.pm(ref.film), if (on) D!!.film else null, actual.film)()
                row("الحبر", ref.pm(ref.ink), if (on) D!!.ink else null, actual.ink)()
                row("البودرة", ref.pm(ref.powder), if (on) D!!.powder else null, actual.powder)()
                row("الأجور", ref.pm(ref.wages), if (on) D!!.wages else null, actual.wages)()
                row("المصاريف الثابتة", ref.pm(ref.fixed), if (on) D!!.fixed else null, actual.fixed)()
                if (c.wasteInProfit) row("الهدر", ref.pm(ref.waste), if (on) D!!.waste else null, actual.waste)()
                row("مجموع التكاليف", ref.pm(ref.cost), if (on) D!!.cost else null, actual.cost, true)()
                row("المداخيل", ref.pm(ref.revenue), if (on) D!!.revenue else null, actual.revenue)()
                row("الربح الصافي", ref.pm(ref.profit), if (on) D!!.profit else null, actual.profit, true)()
            }
            Text("بالدينار. المصاريف الثابتة في عمود الشهر بقدر أيامها السارية" + (c.startDate?.let { " (منذ ${ltr(it)})" } ?: "") + "، و1/${c.workDays} منها في كل يوم عمل. الأجور من تاريخ كل عامل.", style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
        }
    }
}

private val DATE = Regex("^\\d{4}-\\d{2}-\\d{2}$")

@Composable
private fun AmountList(title: String, list: SnapshotStateList<Triple<String, String, String>>) {
    LuxCard(Modifier.fillMaxWidth()) {
        Row { Text(title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f)); Text(formatDa(list.sumOf { d(it.second) ?: 0.0 }), color = Lux.GoldLight) }
        list.forEachIndexed { i, (n, a, from) ->
            Column(Modifier.padding(top = 8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.weight(1.4f)) { LuxField(n, { list[i] = list[i].copy(first = it) }, "البند") }
                    Spacer(Modifier.width(6.dp))
                    Box(Modifier.weight(1f)) { LuxField(a, { list[i] = list[i].copy(second = it) }, "دج", keyboard = KeyboardType.Decimal) }
                    Box(Modifier.size(40.dp).clip(CircleShape).bouncyClick { list.removeAt(i) }, contentAlignment = Alignment.Center) { Icon(Icons.Rounded.Delete, "حذف", tint = Lux.Muted) }
                }
                LuxField(from, { list[i] = list[i].copy(third = it) }, "يبدأ من (2026-12-10) — فارغ = منذ البداية", isError = from.isNotBlank() && !DATE.matches(from.trim()))
            }
        }
        GhostButton("إضافة", { list.add(Triple("", "", "")) }, Modifier.padding(top = 8.dp), Icons.Rounded.Add)
    }
}

@Composable
private fun CostSettingsForm(vm: ProViewModel, c: CostSettings) {
    val f = remember(c) { mutableStateListOf(f0(c.rollPrice), f0(c.rollLengthM), f0(c.inkPriceL), f0(c.inkMlPerM), f0(c.powderPriceKg), f0(c.powderGPerM), "${c.workDays}") }
    val wages = remember(c) { mutableStateListOf<Triple<String, String, String>>().apply { addAll(c.wages.map { Triple(it.name, f0(it.amount), it.from ?: "") }) } }
    val fixed = remember(c) { mutableStateListOf<Triple<String, String, String>>().apply { addAll(c.fixedCosts.map { Triple(it.name, f0(it.amount), it.from ?: "") }) } }
    var start by remember(c) { mutableStateOf(c.startDate ?: "") }
    var waste by remember(c) { mutableStateOf(c.wasteInProfit) }
    var msg by remember { mutableStateOf<String?>(null) }
    val labels = listOf("ثمن رول الفيلم (دج)", "طول الرول (م)", "ثمن لتر الحبر (دج)", "استهلاك الحبر للمتر (مل)", "ثمن كيلو البودرة (دج)", "استهلاك البودرة للمتر (غ)", "أيام العمل في الشهر")
    val draft = runCatching {
        CostSettings(d(f[0])!!, d(f[1])!!, d(f[2])!!, d(f[3])!!, d(f[4])!!, d(f[5])!!, f[6].toInt(),
            wages.filter { it.first.isNotBlank() }.map { NameAmount(it.first.trim(), d(it.second) ?: 0.0, it.third.trim().takeIf { x -> DATE.matches(x) }) },
            fixed.filter { it.first.isNotBlank() }.map { NameAmount(it.first.trim(), d(it.second) ?: 0.0, it.third.trim().takeIf { x -> DATE.matches(x) }) }, waste,
            start.trim().takeIf { x -> DATE.matches(x) })
    }.getOrNull()
    Page {
        LuxCard(Modifier.fillMaxWidth()) {
            Text("بداية الحساب", style = MaterialTheme.typography.titleMedium)
            LuxField(start, { start = it }, "تاريخ بداية عمل الورشة (2026-11-27)", isError = start.isNotBlank() && !DATE.matches(start.trim()))
            Text("لا يُحسب شيء قبله. لكل أجرة ومصروف تاريخ «يبدأ من» خاص به.", style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
        }
        LuxCard(Modifier.fillMaxWidth()) {
            Text("المواد", style = MaterialTheme.typography.titleMedium)
            labels.forEachIndexed { i, l -> Box(Modifier.padding(top = 6.dp)) { LuxField(f[i], { f[i] = it }, l, keyboard = KeyboardType.Decimal) } }
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                Switch(waste, { waste = it }, colors = SwitchDefaults.colors(checkedTrackColor = Lux.GoldDeep)); Spacer(Modifier.width(8.dp)); Text("خصم تكلفة الهدر من الربح")
            }
        }
        AmountList("الأجور اليومية", wages)
        AmountList("المصاريف الشهرية", fixed)
        if (draft != null && draft.rollLengthM > 0 && draft.workDays > 0) {
            val p = costPeriod(draft, 50.0 * draft.workDays, 0.0, draft.workDays, draft.wages.sumOf { it.amount } * draft.workDays, draft.fixedCosts.sumOf { it.amount }, 50.0 * draft.workDays * vm.shop.pricePerMeter)
            LuxCard(Modifier.fillMaxWidth(), highlight = true) {
                Text("النتيجة بهذه الأرقام (50 م في اليوم)", color = Lux.Muted, style = MaterialTheme.typography.labelMedium)
                Text("التكلفة ${formatDa(Math.round(p.pm(p.cost) ?: 0.0).toDouble())} للمتر · الربح ${formatDa(Math.round(p.pm(p.profit) ?: 0.0).toDouble())}", fontWeight = FontWeight.Bold)
                Text("الربح الشهري ${formatDa(Math.round(p.profit).toDouble())} · الهامش ${ltr("%.1f%%".format((p.margin ?: 0.0) * 100))}", color = Lux.Success)
            }
        }
        Note(msg)
        GoldButton("حفظ الإعدادات", enabled = draft != null, modifier = Modifier.fillMaxWidth(),
            onClick = { vm.act(onDone = { e -> msg = e ?: "✓ حُفظت الإعدادات" }) { Admin.saveCosts(draft!!) } })
    }
}

// =========================== Performance ===========================
private data class Scored(val s: StaffStat, val stars: Double?, val n: Int, val q: Double, val sp: Double, val vol: Double, val disc: Double) {
    val score get() = Math.round(q * 40 + sp * 30 + vol * 20 + disc * 10).toInt()
}

@Composable
private fun PerfScreen(vm: ProViewModel) {
    var range by remember { mutableIntStateOf(1) }
    var rows by remember { mutableStateOf<List<Scored>?>(null) }
    val spans = listOf(1, 7, 30, 90)
    LaunchedEffect(range, vm.tick) {
        val to = LocalDate.now(); val from = to.minusDays((spans[range] - 1).toLong())
        val st = runCatching { Admin.stats(from.toString(), to.toString()) }.getOrDefault(emptyList())
        val rt = Admin.ratings(from.toString(), to.toString())
        rows = st.map { x ->
            val peers = st.filter { it.role == x.role && it.ordersDone > 0 }
            val avgT = if (peers.isEmpty()) 0.0 else peers.sumOf { it.avgMinutes } / peers.size
            val maxN = (st.filter { it.role == x.role }.maxOfOrNull { it.ordersDone } ?: 1).coerceAtLeast(1)
            val k = rt.firstOrNull { it.userId == x.userId }
            val q0 = if (x.ordersDone > 0) (1 - x.issues.toDouble() / x.ordersDone * 3).coerceAtLeast(0.0) else if (x.issues > 0) 0.0 else 1.0
            val q = if (k != null) q0 * 0.5 + (k.avgStars - 1) / 4 * 0.5 else q0
            val sp = if (x.ordersDone > 0 && avgT > 0) (avgT / maxOf(x.avgMinutes, 1.0) * 0.7).coerceIn(0.0, 1.0) else 0.5
            val disc = if (x.daysWorked > 0) (1 - (x.lateDays * 0.5 + x.forgotOut) / x.daysWorked).coerceAtLeast(0.0) else 0.5
            Scored(x, k?.avgStars, k?.n ?: 0, q, sp, x.ordersDone.toDouble() / maxN, disc)
        }.sortedByDescending { it.score }
    }
    Page {
        Seg(listOf("اليوم", "7 أيام", "30 يوماً", "3 أشهر"), range) { range = it }
        Text("النقطة من 100: الدقّة 40 · السرعة 30 · حجم العمل 20 · الانضباط 10", style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
        val r = rows
        if (r == null) { Shimmer(Modifier.fillMaxWidth().height(140.dp)); return@Page }
        if (r.isEmpty()) EmptyState(Icons.Rounded.EmojiEvents, "لا توجد بيانات", "تظهر النقاط بعد أول أيام العمل")
        r.forEachIndexed { i, x ->
            LuxCard(Modifier.fillMaxWidth().staggerIn(i), highlight = i == 0 && x.s.ordersDone > 0) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(34.dp).clip(CircleShape).background(if (i == 0) Lux.goldBrush else androidx.compose.ui.graphics.SolidColor(Lux.Surface2)), contentAlignment = Alignment.Center) { Text("${i + 1}", fontWeight = FontWeight.Bold) }
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) { Text(x.s.fullName, style = MaterialTheme.typography.titleMedium); Text(ROLE[x.s.role] ?: "", style = MaterialTheme.typography.labelSmall, color = Lux.Muted) }
                    AnimatedNumber(x.score.toDouble(), { "${Math.round(it)}" }, MaterialTheme.typography.headlineMedium, Lux.GoldLight)
                }
                listOf("الدقّة" to x.q, "السرعة" to x.sp, "حجم العمل" to x.vol, "الانضباط" to x.disc).forEach { (l, v) ->
                    Row(Modifier.padding(top = 6.dp)) { Text(l, style = MaterialTheme.typography.labelSmall, color = Lux.Muted, modifier = Modifier.weight(1f)); Text(ltr("${Math.round(v * 100)}%"), style = MaterialTheme.typography.labelSmall) }
                    Gauge(v.toFloat(), v < 0.4)
                }
                Text("الملفات ${x.s.ordersDone} · ${m2(x.s.meters)} · مشاكل ${x.s.issues} · أيام ${x.s.daysWorked} · تأخّر ${x.s.lateDays}" + (x.stars?.let { " · ${ltr("%.1f".format(it))}★ (${x.n})" } ?: ""),
                    style = MaterialTheme.typography.labelSmall, color = Lux.Muted, modifier = Modifier.padding(top = 8.dp))
            }
        }
    }
}

// =========================== Présence ===========================
@Composable
private fun AttendanceScreen(vm: ProViewModel) {
    var span by remember { mutableIntStateOf(0) }
    var rows by remember { mutableStateOf<List<AttendanceRow>?>(null) }
    val spans = listOf(1, 7, 30)
    LaunchedEffect(span, vm.tick) { rows = runCatching { Admin.attendance(LocalDate.now().minusDays((spans[span] - 1).toLong()).toString()) }.getOrDefault(emptyList()) }
    Page {
        Seg(listOf("اليوم", "7 أيام", "30 يوماً"), span) { span = it }
        val r = rows
        if (r == null) { Shimmer(Modifier.fillMaxWidth().height(120.dp)); return@Page }
        val today = LocalDate.now().toString()
        val team = vm.staff.filter { it.role != "admin" && it.active }
        LuxCard(Modifier.fillMaxWidth(), highlight = true) {
            Text("اليوم", style = MaterialTheme.typography.titleMedium)
            team.forEach { p ->
                val a = r.firstOrNull { it.userId == p.id && it.workDate == today }
                Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    StatusDot(if (a != null && a.clockOut == null) Lux.Success else if (a != null) Lux.Muted else Lux.Danger, a != null && a.clockOut == null, 6)
                    Text(p.fullName, modifier = Modifier.weight(1f))
                    Text(when { a == null -> "غائب"; a.clockOut == null -> "حاضر منذ ${hhmm(a.clockIn)}"; else -> "${hhmm(a.clockIn)} ← ${hhmm(a.clockOut)}" },
                        style = MaterialTheme.typography.labelMedium, color = if (a == null) Lux.Danger else Lux.Muted)
                }
            }
        }
        r.groupBy { it.workDate }.forEach { (day, list) ->
            SectionTitle(ltr(day))
            list.forEach { a ->
                val mins = parseTs(a.clockIn)?.let { s -> java.time.Duration.between(s, parseTs(a.clockOut) ?: java.time.OffsetDateTime.now()).toMinutes() } ?: 0
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Lux.Surface).padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(vm.name(a.userId), fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                    Text("${hhmm(a.clockIn)} ← ${if (a.clockOut != null) hhmm(a.clockOut) else "…"}", style = MaterialTheme.typography.labelMedium, color = Lux.Muted)
                    Spacer(Modifier.width(10.dp))
                    Text(dur(mins), fontWeight = FontWeight.Bold, color = if (a.autoClosed) Amber else Lux.GoldLight)
                }
                if (a.autoClosed) Text("نسي تسجيل الخروج — أُغلق تلقائياً", color = Amber, style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}

// =========================== Équipe ===========================
@Composable
private fun TeamScreen(vm: ProViewModel) {
    var list by remember { mutableStateOf<List<TeamMember>?>(null) }
    var adding by remember { mutableStateOf(false) }
    var passFor by remember { mutableStateOf<TeamMember?>(null) }
    var msg by remember { mutableStateOf<String?>(null) }
    var reload by remember { mutableIntStateOf(0) }
    LaunchedEffect(reload, vm.tick) { list = runCatching { Admin.team() }.getOrDefault(emptyList()) }
    Page {
        GoldButton("إضافة عضو للفريق", icon = Icons.Rounded.Add, modifier = Modifier.fillMaxWidth(), onClick = { adding = !adding })
        if (adding) {
            var name by remember { mutableStateOf("") }; var phone by remember { mutableStateOf("") }; var email by remember { mutableStateOf("") }; var pass by remember { mutableStateOf("") }
            var role by remember { mutableIntStateOf(0) }
            val roles = listOf("designer", "printer", "manager")
            LuxCard(Modifier.fillMaxWidth()) {
                Seg(listOf("مصمّم", "طابع", "مسيّر"), role) { role = it }
                listOf(Triple("الاسم الكامل", name) { v: String -> name = v }, Triple("الهاتف", phone) { v: String -> phone = v }, Triple("البريد الإلكتروني", email) { v: String -> email = v })
                    .forEach { (l, v, set) -> Box(Modifier.padding(top = 6.dp)) { LuxField(v, set, l) } }
                Box(Modifier.padding(top = 6.dp)) { LuxField(pass, { pass = it }, "كلمة سر مؤقتة (6 أحرف على الأقل)", visual = PasswordVisualTransformation()) }
                GoldButton("إنشاء الحساب", enabled = name.isNotBlank() && email.contains('@') && pass.length >= 6, modifier = Modifier.fillMaxWidth().padding(top = 10.dp),
                    onClick = { vm.act(onDone = { e -> msg = e ?: "✓ أُنشئ الحساب — يختار العامل رمزه السري عند أول دخول"; if (e == null) { adding = false; reload++ } }) {
                        Admin.createStaff(name.trim(), phone.trim(), roles[role], email.trim(), pass) } })
            }
        }
        Note(msg)
        val l = list
        if (l == null) { Shimmer(Modifier.fillMaxWidth().height(120.dp)); return@Page }
        l.forEachIndexed { i, s ->
            LuxCard(Modifier.fillMaxWidth().staggerIn(i)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(40.dp).clip(CircleShape).background(Lux.Gold.copy(alpha = 0.16f)), contentAlignment = Alignment.Center) { Text(s.fullName.firstOrNull()?.toString() ?: "?", color = Lux.GoldLight, fontWeight = FontWeight.Bold) }
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text(s.fullName, style = MaterialTheme.typography.titleMedium)
                        Text((ROLE[s.role] ?: s.role) + (s.phone?.let { " · " + ltr(it) } ?: "") + if (!s.active) " · موقوف" else "", style = MaterialTheme.typography.labelSmall, color = if (s.active) Lux.Muted else Lux.Danger)
                    }
                    if (s.role != "admin") Switch(s.active, { v -> vm.act(onDone = { e -> msg = e ?: if (v) "✓ فُعّل الحساب" else "✓ أُوقف الحساب"; reload++ }) { Admin.setActive(s.id, v) } },
                        colors = SwitchDefaults.colors(checkedTrackColor = Lux.GoldDeep))
                }
                if (s.role != "admin") Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    GhostButton("إعادة الرمز السري", { vm.act(onDone = { e -> msg = e ?: "✓ سيختار ${s.fullName} رمزاً جديداً عند الدخول" }) { Admin.resetPin(s.id) } }, Modifier.weight(1f))
                    GhostButton("كلمة السر", { passFor = s }, Modifier.weight(1f))
                }
            }
        }
    }
    passFor?.let { s ->
        var p by remember { mutableStateOf("") }
        AlertDialog(onDismissRequest = { passFor = null }, containerColor = Lux.Surface, title = { Text("كلمة سر جديدة لـ ${s.fullName}") },
            text = { LuxField(p, { p = it }, "6 أحرف على الأقل", visual = PasswordVisualTransformation()) },
            confirmButton = { TextButton(enabled = p.length >= 6, onClick = { vm.act(onDone = { e -> msg = e ?: "✓ تغيّرت كلمة السر" }) { Admin.setPassword(s.id, p) }; passFor = null }) { Text("حفظ", color = Lux.GoldLight) } },
            dismissButton = { TextButton(onClick = { passFor = null }) { Text("إلغاء") } })
    }
}

// =========================== Réglages ===========================
@Composable
private fun SettingsScreen(vm: ProViewModel) {
    var s by remember { mutableStateOf<FullSettings?>(null) }
    LaunchedEffect(Unit) { s = runCatching { Admin.settings() }.getOrNull() }
    val cur = s
    if (cur == null) { Box(Modifier.padding(16.dp)) { Shimmer(Modifier.fillMaxWidth().height(200.dp)) }; return }
    val f = remember(cur) { mutableStateListOf(f0(cur.pricePerMeter), f0(cur.minOrderAmount), f0(cur.meterRoundingStep), f0(cur.filmWidthCm), f0(cur.gapCm), f0(cur.rollAlertM),
        cur.workEndTime?.take(5) ?: "18:00", cur.workshopName ?: "", cur.workshopPhone ?: "", cur.workshopAddress ?: "") }
    var rot by remember(cur) { mutableStateOf(cur.allowRotation) }
    val tiers = remember(cur) { mutableStateListOf<Pair<String, String>>().apply { addAll(cur.priceTiers.map { f0(it.minM) to f0(it.price) }) } }
    var msg by remember { mutableStateOf<String?>(null) }
    val labels = listOf("سعر المتر (دج)", "الحد الأدنى للطلبية (دج)", "تقريب الأمتار (0 = بدون)", "عرض الفيلم المفيد (سم)", "المسافة بين الصور (سم)", "تنبيه الرولو تحت (م)", "نهاية يوم العمل (HH:MM)", "اسم الورشة", "هاتف الورشة", "عنوان الورشة")
    Page {
        LuxCard(Modifier.fillMaxWidth()) {
            Text("الأسعار والطباعة", style = MaterialTheme.typography.titleMedium)
            labels.forEachIndexed { i, l -> Box(Modifier.padding(top = 6.dp)) { LuxField(f[i], { f[i] = it }, l, keyboard = if (i < 6) KeyboardType.Decimal else KeyboardType.Text) } }
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                Switch(rot, { rot = it }, colors = SwitchDefaults.colors(checkedTrackColor = Lux.GoldDeep)); Spacer(Modifier.width(8.dp)); Text("السماح بتدوير الصور 90°")
            }
        }
        LuxCard(Modifier.fillMaxWidth()) {
            Text("أسعار الجملة (حسب الكمية)", style = MaterialTheme.typography.titleMedium)
            tiers.forEachIndexed { i, (a, b) ->
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 6.dp)) {
                    Box(Modifier.weight(1f)) { LuxField(a, { tiers[i] = it to tiers[i].second }, "من (م)", keyboard = KeyboardType.Decimal) }
                    Spacer(Modifier.width(6.dp))
                    Box(Modifier.weight(1f)) { LuxField(b, { tiers[i] = tiers[i].first to it }, "دج للمتر", keyboard = KeyboardType.Decimal) }
                    Box(Modifier.size(40.dp).clip(CircleShape).bouncyClick { tiers.removeAt(i) }, contentAlignment = Alignment.Center) { Icon(Icons.Rounded.Delete, "حذف", tint = Lux.Muted) }
                }
            }
            GhostButton("+ درجة", { tiers.add("" to "") }, Modifier.padding(top = 8.dp))
            Text("السعر الخاص لزبون معيّن (من صفحة الطلبية) يتقدّم على الدرجات.", style = MaterialTheme.typography.labelSmall, color = Lux.Muted, modifier = Modifier.padding(top = 6.dp))
        }
        Note(msg)
        GoldButton("حفظ الإعدادات", modifier = Modifier.fillMaxWidth(), onClick = {
            val n = runCatching {
                cur.copy(pricePerMeter = d(f[0])!!, minOrderAmount = d(f[1])!!, meterRoundingStep = d(f[2]) ?: 0.0, filmWidthCm = d(f[3])!!, gapCm = d(f[4])!!, rollAlertM = d(f[5])!!,
                    workEndTime = f[6].trim().ifBlank { "18:00" }, workshopName = f[7].ifBlank { null }, workshopPhone = f[8].ifBlank { null }, workshopAddress = f[9].ifBlank { null }, allowRotation = rot,
                    priceTiers = tiers.mapNotNull { (a, b) -> val x = d(a); val y = d(b); if (x != null && y != null && x > 0 && y > 0) PriceTier(x, y) else null }.sortedBy { it.minM })
            }.getOrNull()
            if (n == null) msg = "تحقّق من الأرقام" else vm.act(onDone = { e -> msg = e ?: "✓ حُفظت الإعدادات — تُطبَّق فوراً على التطبيق والموقع" }) { Admin.saveSettings(n); s = n }
        })
    }
}
