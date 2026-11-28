package com.mydtf.pro

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Build
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ContentCut
import androidx.compose.material.icons.rounded.Download
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Refresh
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
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.mydtf.client.ui.components.EmptyState
import com.mydtf.client.ui.components.FilmPreview
import com.mydtf.client.ui.components.GhostButton
import com.mydtf.client.ui.components.GoldButton
import com.mydtf.client.ui.components.LuxCard
import com.mydtf.client.ui.components.LuxField
import com.mydtf.client.ui.components.SectionTitle
import com.mydtf.client.ui.components.Shimmer
import com.mydtf.client.ui.components.bouncyClick
import com.mydtf.client.ui.components.previewPalette
import com.mydtf.client.ui.components.staggerIn
import com.mydtf.client.ui.theme.Lux
import com.mydtf.core.NestItem
import com.mydtf.core.NestingEngine
import kotlinx.coroutines.launch

// ---------------- Miniatures (cache mémoire) ----------------
object Thumbs {
    val imgs = mutableStateMapOf<String, List<Img>>()
    val urls = mutableStateMapOf<String, String>()
    suspend fun load(ids: List<String>) {
        for (id in ids.filter { it !in imgs }) {
            val l = runCatching { Pro.images(id) }.getOrNull() ?: continue
            imgs[id] = l
            urls.putAll(Pro.signed(l.map { it.thumbPath ?: it.storagePath }.filter { it !in urls }))
        }
    }
}

@Composable
fun ThumbStrip(orderId: String, size: Int = 56, max: Int = 4) {
    val list = Thumbs.imgs[orderId].orEmpty()
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        list.take(max).forEach { im ->
            Box(Modifier.size(size.dp).clip(RoundedCornerShape(12.dp)).background(Lux.Surface2).border(1.dp, Lux.Gold.copy(alpha = 0.12f), RoundedCornerShape(12.dp))) {
                AsyncImage(Thumbs.urls[im.thumbPath ?: im.storagePath], null, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize().padding(3.dp))
                Text("×${im.quantity}", style = MaterialTheme.typography.labelSmall, color = Color.White,
                    modifier = Modifier.align(Alignment.BottomStart).clip(RoundedCornerShape(6.dp)).background(Color(0xAA000000)).padding(horizontal = 4.dp))
            }
        }
        if (list.size > max) Box(Modifier.size(size.dp).clip(RoundedCornerShape(12.dp)).background(Lux.Surface2), contentAlignment = Alignment.Center) { Text("+${list.size - max}", color = Lux.Muted) }
        if (list.isEmpty()) Shimmer(Modifier.size(size.dp), RoundedCornerShape(12.dp))
    }
}

/** Message éphémère simple. */
@Composable
fun rememberSnack(): Pair<String?, (String?) -> Unit> {
    var msg by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(msg) { if (msg != null) { kotlinx.coroutines.delay(3200); msg = null } }
    return msg to { m: String? -> msg = m }
}

@Composable
fun Snack(msg: String?, modifier: Modifier = Modifier) {
    androidx.compose.animation.AnimatedVisibility(msg != null, modifier, enter = androidx.compose.animation.slideInVertically { it } + androidx.compose.animation.fadeIn(),
        exit = androidx.compose.animation.fadeOut()) {
        Box(Modifier.padding(16.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Lux.Surface2).border(1.dp, Lux.Gold.copy(alpha = 0.4f), RoundedCornerShape(16.dp)).padding(14.dp)) {
            Text(msg ?: "", color = Lux.Ivory)
        }
    }
}

// =========================== Poste d'impression ===========================
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PrinterStation(vm: ProViewModel) {
    val ctx = LocalContext.current
    val prefs = remember { ctx.getSharedPreferences("pro", 0) }
    var myMachine by remember { mutableStateOf(prefs.getString("machine", null)) }
    val machines = vm.board.filter { it.active }
    val cur = machines.firstOrNull { it.id == myMachine } ?: machines.firstOrNull()
    val queue = vm.work.filter { it.status == "ready_to_print" }
    val mine = vm.work.filter { it.status == "printing" && it.printerId == Pro.uid }
    val today = java.time.LocalDate.now()
    val done = vm.work.filter { it.status in setOf("printed", "ready_pickup") && it.printerId == Pro.uid && parseTs(it.updatedAt)?.toLocalDate() == today }
    val (snack, show) = rememberSnack()
    var sheetMachine by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(vm.tick) { Thumbs.load((queue + mine).map { it.id }) }

    Box(Modifier.fillMaxSize()) {
        LazyColumn(contentPadding = PaddingValues(16.dp, 4.dp, 16.dp, 90.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (machines.isEmpty()) { item { EmptyState(Icons.Rounded.Build, "لا توجد آلة", "اطلب من المدير إضافة الآلات من الموقع") }; return@LazyColumn }
            item {
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    machines.forEach { m ->
                        val on = m.id == cur?.id
                        Row(Modifier.clip(CircleShape).background(if (on) Lux.Gold.copy(alpha = 0.16f) else Lux.Surface).border(1.dp, if (on) Lux.Gold else Lux.Surface2, CircleShape)
                            .bouncyClick { myMachine = m.id; prefs.edit().putString("machine", m.id).apply() }.padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                            StatusDot(mstate(m.status).color, m.status == "running" || m.status == "down", 6)
                            Text(m.name, fontWeight = FontWeight.Bold, color = if (on) Lux.GoldLight else Lux.Ivory)
                        }
                    }
                }
            }
            cur?.let { m -> item { MachineCard(m, big = true) { sheetMachine = m.id } } }
            item {
                LuxCard(Modifier.fillMaxWidth()) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                        Stat("طبعت اليوم", "${done.size}", m2(done.sumOf { it.billedMeters }))
                        Stat("في الطابور", "${queue.size}", m2(queue.sumOf { it.billedMeters }))
                        Stat("عندي الآن", "${mine.size}", null, Lux.Success)
                    }
                    vm.supplies.forEach { s ->
                        val low = s.stock <= s.alert
                        Spacer(Modifier.height(8.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(if (s.kind == "ink") "الحبر" else "البودرة", style = MaterialTheme.typography.labelMedium, modifier = Modifier.width(56.dp))
                            Gauge((s.stock / maxOf(s.alert * 4, s.stock, 1.0)).toFloat(), low, Modifier.weight(1f))
                            Text(com.mydtf.core.ltr("%.2f".format(s.stock.coerceAtLeast(0.0) / 1000)) + if (s.kind == "ink") " ل" else " كغ",
                                style = MaterialTheme.typography.labelMedium, color = if (low) Lux.Danger else Lux.Muted, modifier = Modifier.padding(start = 8.dp))
                        }
                    }
                }
            }
            if (mine.isNotEmpty()) {
                item { SectionTitle("قيد الطباعة عندي") }
                itemsIndexed(mine, key = { _, o -> "m" + o.id }) { i, o ->
                    LuxCard(Modifier.fillMaxWidth().staggerIn(i), highlight = true) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text("طلبية ${o.code}", style = MaterialTheme.typography.titleMedium)
                                Text(m2(o.billedMeters) + " · " + (machines.firstOrNull { it.id == o.machineId }?.name ?: ""), color = Lux.Muted, style = MaterialTheme.typography.bodySmall)
                            }
                            LiveClock(o.printStartedAt ?: o.updatedAt, MaterialTheme.typography.headlineSmall)
                        }
                        Spacer(Modifier.height(10.dp)); ThumbStrip(o.id)
                        Spacer(Modifier.height(12.dp))
                        var ok by remember { mutableStateOf(false) }
                        GoldButton("انتهت الطباعة", icon = Icons.Rounded.CheckCircle, success = ok, loading = vm.busy && !ok, modifier = Modifier.fillMaxWidth(),
                            onClick = { vm.act(onDone = { e -> if (e == null) ok = true else show(e) }) { Pro.finishPrinting(o.id) } })
                    }
                }
            }
            item { SectionTitle("طابور الطباعة") }
            if (queue.isEmpty()) item { EmptyState(Icons.Rounded.CheckCircle, "الطابور فارغ", "ستظهر هنا الملفات الجاهزة للطباعة مباشرة") }
            itemsIndexed(queue, key = { _, o -> "q" + o.id }) { i, o ->
                val blocked = cur == null || cur.status == "down" || cur.status == "maintenance"
                LuxCard(Modifier.fillMaxWidth().staggerIn(i), highlight = i == 0) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("طلبية ${o.code}", style = MaterialTheme.typography.titleMedium)
                            Text("${o.clientName ?: ""} · ينتظر ${dur(minsSince(o.updatedAt))}", color = Lux.Muted, style = MaterialTheme.typography.bodySmall)
                        }
                        Text(m2(o.billedMeters), color = Lux.GoldLight, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.ExtraBold)
                    }
                    Spacer(Modifier.height(10.dp)); ThumbStrip(o.id)
                    o.clientNote?.let { Text(it, color = Lux.Muted, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 6.dp)) }
                    Spacer(Modifier.height(12.dp))
                    GoldButton("اطبع على ${cur?.name ?: "..."}", icon = Icons.Rounded.PlayArrow, enabled = !blocked && !vm.busy, modifier = Modifier.fillMaxWidth(),
                        onClick = { vm.act(onDone = { e -> show(e ?: "بدأت الطباعة وخُصم ${"%.2f".format(o.billedMeters)} م") }) { Pro.startPrinting(o.id, cur?.id) } })
                }
            }
        }
        Snack(snack, Modifier.align(Alignment.BottomCenter))
    }
    sheetMachine?.let { id -> MachineSheet(vm, id) { sheetMachine = null } }
}

/** Carte vivante d'une machine. */
@Composable
fun MachineCard(m: Machine, big: Boolean = false, onClick: () -> Unit) {
    val st = mstate(m.status); val rd = readiness(m)
    LuxCard(Modifier.fillMaxWidth(), highlight = m.status == "running", onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            StatusDot(st.color, m.status == "running" || m.status == "down")
            Column(Modifier.weight(1f)) {
                Text(m.name, style = MaterialTheme.typography.titleMedium)
                Text("${m.model ?: "DTF"} · الحالة: ${st.label}", style = MaterialTheme.typography.labelMedium, color = Lux.Muted)
            }
            Text(rd.label, color = rd.color, fontWeight = FontWeight.Bold,
                modifier = Modifier.clip(RoundedCornerShape(50)).background(rd.color.copy(alpha = .14f)).padding(horizontal = 10.dp, vertical = 4.dp))
        }
        Spacer(Modifier.height(10.dp))
        Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Lux.Night2).padding(12.dp)) {
            when {
                m.status == "running" && m.jobCode != null -> Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("يطبع الآن", style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
                        Text("طلبية ${m.jobCode} · ${m2(m.jobMeters)}", fontWeight = FontWeight.Bold)
                    }
                    LiveClock(m.jobStarted, if (big) MaterialTheme.typography.headlineMedium else MaterialTheme.typography.titleLarge)
                }
                rd.why != null -> Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Warning, null, tint = rd.color); Spacer(Modifier.width(8.dp))
                    Text(rd.why, color = rd.color, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                    if (rd.block) Text("منذ ${dur(minsSince(m.statusSince))}", color = Lux.Muted, style = MaterialTheme.typography.labelMedium)
                }
                else -> Text("جاهزة — في انتظار ملف · منذ ${dur(minsSince(m.statusSince))}", color = Lux.Ivory, style = MaterialTheme.typography.bodyMedium)
            }
        }
        Spacer(Modifier.height(10.dp))
        val low = m.rollCode != null && (m.rollRemaining ?: 0.0) <= (m.alertM ?: 0.0)
        Row {
            Text(if (m.rollCode != null) "الرولو ${m.rollCode}" else "لا يوجد رولو مركّب", style = MaterialTheme.typography.labelMedium, color = Lux.Muted, modifier = Modifier.weight(1f))
            if (m.rollCode != null) Text(com.mydtf.core.ltr("%.1f / %.0f م".format(m.rollRemaining ?: 0.0, m.rollLength ?: 0.0)), style = MaterialTheme.typography.labelMedium, color = if (low) Lux.Danger else Lux.Ivory)
        }
        Spacer(Modifier.height(4.dp))
        Gauge(if (m.rollCode != null) ((m.rollRemaining ?: 0.0) / (m.rollLength ?: 1.0)).toFloat() else 0f, low)
        Spacer(Modifier.height(8.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("اليوم ${m2(m.metersToday)}", style = MaterialTheme.typography.labelMedium, color = Lux.Muted)
            Text("هدر ${m2(m.wasteToday)}", style = MaterialTheme.typography.labelMedium, color = if (m.wasteToday > 0) Color(0xFFFBBF24) else Lux.Muted)
            Text(m.operatorName ?: "—", style = MaterialTheme.typography.labelMedium, color = Lux.Muted)
        }
    }
}

/** Fiche machine : état, rouleau, gâche. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MachineSheet(vm: ProViewModel, id: String, onEdit: ((Machine) -> Unit)? = null, onClose: () -> Unit) {
    val m = vm.board.firstOrNull { it.id == id } ?: return
    var mode by remember { mutableStateOf("") }
    var note by remember { mutableStateOf("") }
    var meters by remember { mutableStateOf("") }
    var err by remember { mutableStateOf<String?>(null) }
    ModalBottomSheet(onDismissRequest = onClose, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Lux.Night2) {
        Column(Modifier.verticalScroll(rememberScrollState()).padding(16.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            MachineCard(m, big = true) {}
            if (com.mydtf.client.BuildConfig.ADMIN && onEdit != null) GhostButton("تعديل الآلة (الاسم، العرض، الموديل)", { onEdit(m) }, Modifier.fillMaxWidth())
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (m.status == "down" || m.status == "maintenance")
                    GoldButton("عادت للعمل", modifier = Modifier.weight(1f), onClick = { vm.act(onDone = { err = it }) { Pro.machineStatus(id, "idle", null) } })
                else GhostButton("صيانة", { mode = "maintenance" }, Modifier.weight(1f), Icons.Rounded.Build)
                GhostButton("عطل", { mode = "down" }, Modifier.weight(1f), Icons.Rounded.Warning)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                GhostButton("تركيب رولو", { mode = "roll" }, Modifier.weight(1f), Icons.Rounded.Refresh)
                GhostButton("هدر", { mode = "waste" }, Modifier.weight(1f), Icons.Rounded.ContentCut)
            }
            when (mode) {
                "maintenance", "down" -> {
                    LuxField(note, { note = it }, "السبب")
                    GoldButton("تأكيد", enabled = note.isNotBlank(), modifier = Modifier.fillMaxWidth(),
                        onClick = { vm.act(onDone = { e -> err = e; if (e == null) { mode = ""; note = "" } }) { Pro.machineStatus(id, mode, note) } })
                }
                "roll" -> {
                    Text(if (m.rollCode != null) "الرولو ${m.rollCode} الحالي سيُعتبر منتهياً، ويُركَّب أقدم رولو من المخزون." else "يُركَّب أقدم رولو من المخزون.", color = Lux.Muted)
                    GoldButton("تركيب الرولو التالي", modifier = Modifier.fillMaxWidth(), onClick = { vm.act(onDone = { e -> err = e; if (e == null) mode = "" }) { Pro.mountRoll(id) } })
                }
                "waste" -> {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf("0.5", "1", "2").forEach { v -> GhostButton("$v م", { meters = v }, Modifier.weight(1f)) }
                    }
                    LuxField(meters, { meters = it }, "الأمتار", keyboard = KeyboardType.Decimal)
                    LuxField(note, { note = it }, "السبب (تجربة، خطأ، تنظيف...)")
                    val v = meters.replace(',', '.').toDoubleOrNull() ?: 0.0
                    GoldButton("خصم من رولو ${m.name}", enabled = v > 0, modifier = Modifier.fillMaxWidth(),
                        onClick = { vm.act(onDone = { e -> err = e; if (e == null) { mode = ""; meters = ""; note = "" } }) { Pro.waste(v, note.ifBlank { null }, id) } })
                }
            }
            err?.let { Text(it, color = Lux.Danger) }
            Spacer(Modifier.height(20.dp))
        }
    }
}

@Composable
fun MachinesScreen(vm: ProViewModel) {
    var sheet by remember { mutableStateOf<String?>(null) }
    var form by remember { mutableStateOf<Machine?>(null) }
    var adding by remember { mutableStateOf(false) }
    LazyColumn(contentPadding = PaddingValues(16.dp, 4.dp, 16.dp, 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (com.mydtf.client.BuildConfig.ADMIN) item { GoldButton("إضافة آلة", onClick = { adding = true }, modifier = Modifier.fillMaxWidth()) }
        if (vm.board.isEmpty()) item { EmptyState(Icons.Rounded.Build, "لا توجد آلات", if (com.mydtf.client.BuildConfig.ADMIN) "أضف أول آلة بالزر أعلاه" else "تُضاف الآلات من الموقع الإداري") }
        itemsIndexed(vm.board, key = { _, m -> m.id }) { i, m -> Box(Modifier.staggerIn(i)) { MachineCard(m) { sheet = m.id } } }
    }
    sheet?.let { MachineSheet(vm, it, onEdit = { m -> sheet = null; form = m }) { sheet = null } }
    if (adding || form != null) MachineFormDialog(vm, form) { adding = false; form = null }
}

// =========================== Bureau du designer ===========================
@Composable
fun DesignerDesk(vm: ProViewModel) {
    val todo = vm.work.filter { it.status == "in_design" }.sortedBy { it.updatedAt }
    val today = java.time.LocalDate.now()
    val sent = vm.work.filter { it.status != "in_design" && parseTs(it.updatedAt)?.toLocalDate() == today }
    var open by remember { mutableStateOf<WorkOrder?>(null) }
    LaunchedEffect(vm.tick) { Thumbs.load(todo.map { it.id }) }
    LazyColumn(contentPadding = PaddingValues(16.dp, 4.dp, 16.dp, 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            LuxCard(Modifier.fillMaxWidth(), highlight = true) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    val total = sent.size + todo.size
                    Box(Modifier.size(84.dp), contentAlignment = Alignment.Center) {
                        androidx.compose.material3.CircularProgressIndicator(
                            progress = { if (total == 0) 0f else sent.size.toFloat() / total }, modifier = Modifier.size(84.dp), color = Lux.Gold, trackColor = Lux.Surface2, strokeWidth = 8.dp)
                        Text("${sent.size}/$total", fontWeight = FontWeight.ExtraBold)
                    }
                    Spacer(Modifier.width(14.dp))
                    Column {
                        Text("تقدّم اليوم", style = MaterialTheme.typography.titleLarge)
                        Text("أرسلت ${sent.size} ملف (${m2(sent.sumOf { it.billedMeters })}) · بقي ${todo.size}", color = Lux.Muted, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
        item { SectionTitle("ملفات تنتظر التصميم") }
        if (todo.isEmpty()) item { EmptyState(Icons.Rounded.CheckCircle, "لا توجد ملفات", "عمل ممتاز — ستظهر الملفات الجديدة هنا مباشرة") }
        itemsIndexed(todo, key = { _, o -> o.id }) { i, o ->
            val w = minsSince(o.updatedAt)
            val c = when { w > 240 -> Lux.Danger; w > 120 -> Color(0xFFFBBF24); else -> Lux.Success }
            LuxCard(Modifier.fillMaxWidth().staggerIn(i), onClick = { open = o }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("طلبية ${o.code}", style = MaterialTheme.typography.titleMedium)
                        Text("${o.clientName ?: ""} · تقديري ${com.mydtf.core.ltr("%.1f".format(o.estimatedLengthCm))} سم", color = Lux.Muted, style = MaterialTheme.typography.bodySmall)
                    }
                    Box(Modifier.size(52.dp), contentAlignment = Alignment.Center) {
                        androidx.compose.material3.CircularProgressIndicator(progress = { (w / 240f).coerceIn(0f, 1f) }, modifier = Modifier.size(52.dp), color = c, trackColor = Lux.Surface2, strokeWidth = 5.dp)
                        Text(dur(w), style = MaterialTheme.typography.labelSmall, color = c)
                    }
                }
                Spacer(Modifier.height(10.dp)); ThumbStrip(o.id, 62)
                o.clientNote?.let { Text(it, color = Lux.GoldLight, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 6.dp)) }
            }
        }
    }
    open?.let { DesignSheet(vm, it) { open = null } }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DesignSheet(vm: ProViewModel, o: WorkOrder, onClose: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val imgs = Thumbs.imgs[o.id].orEmpty()
    var len by remember { mutableStateOf("") }
    var err by remember { mutableStateOf<String?>(null) }
    var dl by remember { mutableStateOf<String?>(null) }
    var ok by remember { mutableStateOf(false) }
    val result = remember(imgs) {
        if (imgs.isEmpty()) null else runCatching { NestingEngine(58.0, 0.3, true).nest(imgs.mapIndexed { i, im -> NestItem("$i", im.widthCm, im.heightCm, im.quantity) }) }.getOrNull()
    }
    LaunchedEffect(result) { if (len.isEmpty() && result != null) len = "%.1f".format(java.util.Locale.US, result.lengthCm) }
    ModalBottomSheet(onDismissRequest = onClose, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Lux.Night2) {
        Column(Modifier.verticalScroll(rememberScrollState()).padding(16.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("طلبية ${o.code}", style = MaterialTheme.typography.headlineSmall)
            o.clientNote?.let { Text("ملاحظة الزبون: $it", color = Lux.GoldLight) }
            result?.let { r ->
                Text("ترتيب مقترح · ${com.mydtf.core.ltr("%.1f".format(r.lengthCm))} سم · امتلاء ${com.mydtf.core.ltr("${(r.fillRatio * 100).toInt()}%")}", color = Lux.Muted, style = MaterialTheme.typography.bodySmall)
                FilmPreview(r, { previewPalette[(it.toIntOrNull() ?: 0) % previewPalette.size] }, { "${(it.toIntOrNull() ?: 0) + 1}" }, height = 300.dp)
            }
            imgs.forEachIndexed { i, im ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(70.dp).clip(RoundedCornerShape(12.dp)).background(Lux.Surface2)) {
                        AsyncImage(Thumbs.urls[im.thumbPath ?: im.storagePath], null, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize().padding(3.dp))
                    }
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text("صورة ${i + 1}", fontWeight = FontWeight.Bold)
                        Text(com.mydtf.client.ui.sizeCm("%.1f".format(im.widthCm), "%.1f".format(im.heightCm)) + " × ${im.quantity}", color = Lux.Muted, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
            GhostButton(dl ?: "تحميل كل الصور الأصلية", {
                scope.launch {
                    var n = 0
                    imgs.forEachIndexed { i, im ->
                        dl = "تحميل ${i + 1}/${imgs.size}..."
                        runCatching {
                            val bytes = Pro.download(im.storagePath)
                            val name = "DTF_${o.code}_${i + 1}_" + im.storagePath.substringAfterLast('/').substringAfter('_')
                            val cv = ContentValues().apply {
                                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                                put(MediaStore.MediaColumns.MIME_TYPE, if (name.endsWith(".png", true)) "image/png" else "image/jpeg")
                                if (Build.VERSION.SDK_INT >= 29) put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/MyDTF")
                            }
                            ctx.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, cv)?.let { uri -> ctx.contentResolver.openOutputStream(uri)?.use { it.write(bytes) }; n++ }
                        }
                    }
                    dl = "حُفظت $n صورة في Pictures/MyDTF"
                }
            }, Modifier.fillMaxWidth(), Icons.Rounded.Download)
            LuxField(len, { len = it }, "الطول الحقيقي بعد فوتوشوب (سم)", keyboard = KeyboardType.Decimal)
            val L = len.replace(',', '.').toDoubleOrNull() ?: 0.0
            err?.let { Text(it, color = Lux.Danger) }
            GoldButton("جاهز للطباعة", icon = Icons.Rounded.CheckCircle, success = ok, enabled = L > 0, loading = vm.busy && !ok, modifier = Modifier.fillMaxWidth(),
                onClick = { vm.act(onDone = { e -> err = e; if (e == null) { ok = true; scope.launch { kotlinx.coroutines.delay(900); onClose() } } }) { Pro.designDone(o.id, L) } })
            Spacer(Modifier.height(20.dp))
        }
    }
}
