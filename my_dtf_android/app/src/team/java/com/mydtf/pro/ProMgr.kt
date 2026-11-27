package com.mydtf.pro

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.Chat
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Inbox
import androidx.compose.material.icons.rounded.LocalShipping
import androidx.compose.material.icons.rounded.Warning
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.mydtf.client.ui.components.AnimatedNumber
import com.mydtf.client.ui.components.EmptyState
import com.mydtf.client.ui.components.GhostButton
import com.mydtf.client.ui.components.GoldButton
import com.mydtf.client.ui.components.LuxCard
import com.mydtf.client.ui.components.LuxField
import com.mydtf.client.ui.components.SectionTitle
import com.mydtf.client.ui.components.StatusChip
import com.mydtf.client.ui.components.bouncyClick
import com.mydtf.client.ui.components.staggerIn
import com.mydtf.client.ui.theme.Lux
import com.mydtf.core.formatDa
import kotlinx.coroutines.launch

private val STAGES = listOf(
    listOf("new") to "جديدة", listOf("in_design") to "التصميم", listOf("ready_to_print") to "الطابور",
    listOf("printing") to "تُطبع", listOf("printed", "ready_pickup") to "جاهزة", listOf("shipped") to "التوصيل",
)
private val LIMITS = listOf(60L, 240L, 180L, 90L, 1440L, 4320L)

// =========================== Centre de contrôle ===========================
@Composable
fun Cockpit(vm: ProViewModel) {
    val active = vm.board.filter { it.active }
    val running = active.count { it.status == "running" }
    val today = java.time.LocalDate.now()
    val todayOrders = vm.orders.filter { parseTs(it.createdAt)?.toLocalDate() == today }
    val alerts = buildList {
        active.filter { it.status == "down" }.forEach { add("${it.name} معطّلة: ${it.statusNote ?: ""}" to true) }
        active.filter { it.rollCode != null && (it.rollRemaining ?: 0.0) <= (it.alertM ?: 0.0) }.forEach { add("رولو ${it.name} قارب على الانتهاء" to false) }
        active.filter { it.rollCode == null }.forEach { add("لا يوجد رولو على ${it.name}" to false) }
        vm.supplies.filter { it.stock <= it.alert }.forEach { add((if (it.kind == "ink") "الحبر" else "البودرة") + " قارب على النفاد" to true) }
        vm.orders.count { it.status == "new" }.takeIf { it > 0 }?.let { add("$it طلبية تنتظر القبول" to false) }
        vm.convs.sumOf { it.unread }.takeIf { it > 0 }?.let { add("$it رسالة زبون غير مقروءة" to false) }
    }
    LazyColumn(contentPadding = PaddingValues(16.dp, 4.dp, 16.dp, 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            LuxCard(Modifier.fillMaxWidth().staggerIn(0), highlight = true) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("طلبيات اليوم", style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
                        AnimatedNumber(todayOrders.sumOf { it.printAmount }, { formatDa(Math.round(it).toDouble()) }, MaterialTheme.typography.titleLarge, Lux.GoldLight)
                        Text("${todayOrders.size} طلبية", style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("أمتار اليوم", style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
                        AnimatedNumber(active.sumOf { it.metersToday }, { m2(it) }, MaterialTheme.typography.titleLarge, Lux.Ivory)
                        Text("هدر ${m2(active.sumOf { it.wasteToday })}", style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
                    }
                    Box(Modifier.size(70.dp), contentAlignment = Alignment.Center) {
                        androidx.compose.material3.CircularProgressIndicator(progress = { if (active.isEmpty()) 0f else running.toFloat() / active.size }, Modifier.size(70.dp), color = Lux.Success, trackColor = Lux.Surface2, strokeWidth = 7.dp)
                        Text("$running/${active.size}", fontWeight = FontWeight.ExtraBold)
                    }
                }
            }
        }
        item { SectionTitle("سلسلة الإنتاج") }
        item {
            val loads = STAGES.mapIndexed { i, (k, _) -> val l = vm.orders.filter { it.status in k }; Triple(l.size, l.maxOfOrNull { minsSince(it.updatedAt) } ?: 0L, i) }
            val worst = loads.take(4).maxByOrNull { it.second.toFloat() / LIMITS[it.third] }?.takeIf { it.second.toFloat() / LIMITS[it.third] > 0.5f }?.third
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                STAGES.forEachIndexed { i, (_, t) ->
                    val (n, oldest, _) = loads[i]
                    val hot = i == worst
                    Column(Modifier.width(118.dp).staggerIn(i).clip(RoundedCornerShape(18.dp)).background(if (hot) Color(0xFF2A1618) else Lux.Surface)
                        .border(1.dp, if (hot) Lux.Danger else Lux.Surface2, RoundedCornerShape(18.dp)).padding(12.dp)) {
                        AnimatedNumber(n.toDouble(), { "${Math.round(it)}" }, MaterialTheme.typography.headlineMedium, if (hot) Lux.Danger else Lux.Ivory)
                        Text(t, fontWeight = FontWeight.Bold)
                        Text(if (n > 0) "أقدم ${dur(oldest)}" else "فارغة", style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
                    }
                }
            }
        }
        if (alerts.isNotEmpty()) {
            item { SectionTitle("تنبيهات") }
            itemsIndexed(alerts) { i, (t, bad) ->
                val c = if (bad) Lux.Danger else Color(0xFFFBBF24)
                Row(Modifier.fillMaxWidth().staggerIn(i).clip(RoundedCornerShape(14.dp)).background(c.copy(alpha = 0.1f)).border(1.dp, c.copy(alpha = 0.35f), RoundedCornerShape(14.dp)).padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Warning, null, tint = c); Spacer(Modifier.width(10.dp)); Text(t)
                }
            }
        }
        item { SectionTitle("الآلات") }
        itemsIndexed(active, key = { _, m -> "c" + m.id }) { i, m -> Box(Modifier.staggerIn(i)) { MachineCard(m) {} } }
    }
}

// =========================== Commandes (gérant) ===========================
@Composable
fun OrdersMgr(vm: ProViewModel) {
    var tab by remember { mutableStateOf(0) }
    var open by remember { mutableStateOf<MgrOrder?>(null) }
    val groups = listOf("جديدة" to listOf("new"), "قيد العمل" to listOf("in_design", "ready_to_print", "printing"), "جاهزة" to listOf("printed", "ready_pickup"), "التوصيل" to listOf("shipped")) +
        (if (com.mydtf.client.BuildConfig.ADMIN) listOf("الأرشيف" to listOf("delivered", "rejected", "cancelled")) else emptyList())
    var archive by remember { mutableStateOf<List<MgrOrder>>(emptyList()) }
    LaunchedEffect(tab, vm.tick) { if (tab == 4) archive = runCatching { Admin.archive() }.getOrDefault(emptyList()) }
    val list = if (tab == 4) archive else vm.orders.filter { it.status in groups[tab].second }
    LaunchedEffect(vm.tick, tab) { Thumbs.load(list.map { it.id }) }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 6.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            groups.forEachIndexed { i, (t, st) ->
                val on = i == tab
                val n = if (i == 4) 0 else vm.orders.count { it.status in st }
                Row(Modifier.clip(CircleShape).background(if (on) Lux.Gold.copy(alpha = 0.18f) else Lux.Surface).border(1.dp, if (on) Lux.Gold else Lux.Surface2, CircleShape)
                    .bouncyClick { tab = i }.padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(t, color = if (on) Lux.GoldLight else Lux.Ivory, fontWeight = FontWeight.Bold); Spacer(Modifier.width(6.dp)); CountPill(n, if (i == 0) Lux.Danger else Lux.GoldDeep)
                }
            }
        }
        LazyColumn(contentPadding = PaddingValues(16.dp, 4.dp, 16.dp, 24.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (list.isEmpty()) item { EmptyState(Icons.Rounded.Inbox, "لا شيء هنا", "تظهر الطلبيات مباشرة عند وصولها") }
            itemsIndexed(list, key = { _, o -> o.id }) { i, o ->
                LuxCard(Modifier.fillMaxWidth().staggerIn(i), highlight = o.status == "new", onClick = { open = o }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("طلبية ${o.code}", style = MaterialTheme.typography.titleMedium)
                            Text("${o.shipName ?: ""} · ${m2(o.billedMeters)} · منذ ${dur(minsSince(o.updatedAt))}", color = Lux.Muted, style = MaterialTheme.typography.bodySmall)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text(formatDa(o.printAmount + o.deliveryFee), color = Lux.GoldLight, fontWeight = FontWeight.ExtraBold)
                            StatusChip(o.status)
                        }
                    }
                    if (o.status in setOf("new", "in_design")) { Spacer(Modifier.height(8.dp)); ThumbStrip(o.id, 48) }
                }
            }
        }
    }
    open?.let { o -> OrderMgrSheet(vm, o) { open = null } }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun OrderMgrSheet(vm: ProViewModel, o: MgrOrder, onClose: () -> Unit) {
    val designers = vm.staff.filter { it.role == "designer" && it.active }
    val loadOf = { id: String -> vm.orders.count { it.status == "in_design" && it.designerId == id } }
    var pick by remember { mutableStateOf(designers.minByOrNull { loadOf(it.id) }?.id) }
    var reason by remember { mutableStateOf("") }
    var carrier by remember { mutableStateOf("DHD") }
    var tracking by remember { mutableStateOf("") }
    var paid by remember { mutableStateOf("%.0f".format(o.printAmount + o.deliveryFee)) }
    var err by remember { mutableStateOf<String?>(null) }
    var ok by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    fun run(block: suspend () -> Unit) = vm.act(onDone = { e -> err = e; if (e == null) { ok = true; scope.launch { kotlinx.coroutines.delay(800); onClose() } } }, block = block)
    ModalBottomSheet(onDismissRequest = onClose, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Lux.Night2) {
        Column(Modifier.verticalScroll(rememberScrollState()).padding(16.dp).navigationBarsPadding().imePadding(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) { Text("طلبية ${o.code}", style = MaterialTheme.typography.headlineSmall, modifier = Modifier.weight(1f)); StatusChip(o.status) }
            Text(formatDa(o.printAmount + o.deliveryFee) + " · " + m2(o.billedMeters), color = Lux.GoldLight, style = MaterialTheme.typography.titleLarge)
            Text(listOfNotNull(o.shipName, o.shipPhone, o.shipWilaya, o.shipCommune).joinToString(" · "), color = Lux.Muted)
            o.clientNote?.let { Text("ملاحظة: $it", color = Lux.GoldLight) }
            ThumbStrip(o.id, 70, 5)
            if (com.mydtf.client.BuildConfig.ADMIN) AdminOrderExtras(vm, o)
            when (o.status) {
                "new" -> {
                    SectionTitle("تحويل إلى مصمّم")
                    designers.forEach { d ->
                        val on = pick == d.id
                        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(if (on) Lux.Gold.copy(alpha = 0.14f) else Lux.Surface)
                            .border(1.dp, if (on) Lux.Gold else Lux.Surface2, RoundedCornerShape(14.dp)).bouncyClick { pick = d.id }.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(d.fullName, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                            Text("${loadOf(d.id)} ملف", color = Lux.Muted, style = MaterialTheme.typography.labelMedium)
                        }
                    }
                    GoldButton("قبول وتحويل", icon = Icons.Rounded.CheckCircle, success = ok, enabled = pick != null, modifier = Modifier.fillMaxWidth(), onClick = { run { Pro.assign(o.id, pick!!) } })
                    LuxField(reason, { reason = it }, "أو سبب الرفض (يظهر للزبون)")
                    GhostButton("رفض الطلبية", { if (reason.isNotBlank()) run { Pro.reject(o.id, reason.trim()) } else err = "اكتب سبب الرفض" }, Modifier.fillMaxWidth(), Icons.Rounded.Close)
                }
                "printed" -> if (o.deliveryMode != "pickup") {
                    LuxField(carrier, { carrier = it }, "شركة التوصيل")
                    LuxField(tracking, { tracking = it }, "رقم التتبّع")
                    GoldButton("سُلّمت لشركة التوصيل", icon = Icons.Rounded.LocalShipping, success = ok, modifier = Modifier.fillMaxWidth(), onClick = { run { Pro.shipped(o.id, carrier.ifBlank { "DHD" }, tracking.trim()) } })
                }
                "ready_pickup", "shipped" -> {
                    LuxField(paid, { paid = it }, "المبلغ المقبوض (دج)", keyboard = KeyboardType.Number)
                    GoldButton("سُلّمت للزبون", icon = Icons.Rounded.CheckCircle, success = ok, modifier = Modifier.fillMaxWidth(),
                        onClick = { run { Pro.delivered(o.id, paid.replace(',', '.').toDoubleOrNull() ?: 0.0) } })
                }
                else -> Text("الطلبية عند ${if (o.status == "in_design") "المصمّم " + vm.name(o.designerId) else "الطابعين"}", color = Lux.Muted)
            }
            err?.let { Text(it, color = Lux.Danger) }
            Spacer(Modifier.height(20.dp))
        }
    }
}

// =========================== Discussions ===========================
@Composable
fun ChatMgr(vm: ProViewModel) {
    var open by remember { mutableStateOf<Conversation?>(null) }
    val c = open
    if (c == null) {
        LazyColumn(contentPadding = PaddingValues(16.dp, 4.dp, 16.dp, 24.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (vm.convs.isEmpty()) item { EmptyState(Icons.Rounded.Chat, "لا توجد رسائل", "تظهر رسائل الزبائن هنا مباشرة") }
            itemsIndexed(vm.convs, key = { _, x -> x.clientId }) { i, x ->
                LuxCard(Modifier.fillMaxWidth().staggerIn(i), highlight = x.unread > 0, onClick = { open = x }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(40.dp).clip(CircleShape).background(Lux.Gold.copy(alpha = 0.16f)), contentAlignment = Alignment.Center) { Text(x.fullName?.firstOrNull()?.toString() ?: "?", color = Lux.GoldLight, fontWeight = FontWeight.Bold) }
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text(x.fullName ?: "زبون", fontWeight = FontWeight.Bold)
                            Text(x.lastBody ?: "", color = Lux.Muted, style = MaterialTheme.typography.bodySmall, maxLines = 1)
                        }
                        Column(horizontalAlignment = Alignment.End) { Text(hhmm(x.lastAt), style = MaterialTheme.typography.labelSmall, color = Lux.Muted); CountPill(x.unread, Lux.Danger) }
                    }
                }
            }
        }
    } else Thread(vm, c) { open = null }
}

@Composable
private fun Thread(vm: ProViewModel, c: Conversation, onBack: () -> Unit) {
    var msgs by remember { mutableStateOf<List<Msg>>(emptyList()) }
    var text by remember { mutableStateOf("") }
    val state = rememberLazyListState()
    val scope = rememberCoroutineScope()
    LaunchedEffect(c.clientId, vm.tick) { runCatching { msgs = Pro.messages(c.clientId); Pro.markRead(c.clientId) }; if (msgs.isNotEmpty()) state.animateScrollToItem(msgs.lastIndex) }
    androidx.activity.compose.BackHandler(onBack = onBack)
    Column(Modifier.fillMaxSize().imePadding()) {
        Row(Modifier.padding(horizontal = 12.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(40.dp).clip(CircleShape).bouncyClick(onClick = onBack), contentAlignment = Alignment.Center) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "رجوع") }
            Column { Text(c.fullName ?: "زبون", fontWeight = FontWeight.Bold); c.phone?.let { Text(com.mydtf.core.ltr(it), style = MaterialTheme.typography.labelSmall, color = Lux.Muted) } }
        }
        LazyColumn(Modifier.weight(1f), state = state, contentPadding = PaddingValues(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(msgs, key = { it.id }) { m ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = if (m.fromStaff) Arrangement.Start else Arrangement.End) {
                    Column(Modifier.widthIn(max = 300.dp).clip(RoundedCornerShape(18.dp)).background(if (m.fromStaff) Lux.goldBrush else androidx.compose.ui.graphics.SolidColor(Lux.Surface2)).padding(12.dp)) {
                        Text(m.body, color = if (m.fromStaff) Lux.OnAccent else Lux.Ivory)
                        Text(hhmm(m.createdAt), style = MaterialTheme.typography.labelSmall, color = if (m.fromStaff) Lux.OnAccent.copy(alpha = 0.7f) else Lux.Muted)
                    }
                }
            }
        }
        Row(Modifier.padding(12.dp).navigationBarsPadding(), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f)) { LuxField(text, { text = it }, "اكتب ردّك...") }
            Spacer(Modifier.width(8.dp))
            Box(Modifier.size(54.dp).clip(CircleShape).background(Lux.goldBrush).bouncyClick(enabled = text.isNotBlank()) {
                val t = text.trim(); text = ""
                scope.launch { runCatching { Pro.reply(c.clientId, t); msgs = Pro.messages(c.clientId); state.animateScrollToItem(msgs.lastIndex.coerceAtLeast(0)) } }
            }, contentAlignment = Alignment.Center) { Icon(Icons.AutoMirrored.Rounded.Send, "إرسال", tint = Lux.OnAccent) }
        }
    }
}
