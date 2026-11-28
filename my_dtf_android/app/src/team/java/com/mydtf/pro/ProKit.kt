package com.mydtf.pro

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Backspace
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.CompositionLocalProvider
import com.mydtf.client.ui.components.bouncyClick
import com.mydtf.client.ui.theme.Lux
import kotlinx.coroutines.delay
import java.time.Duration
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

// ---------------- Temps ----------------
fun parseTs(s: String?): OffsetDateTime? = s?.let { runCatching { OffsetDateTime.parse(it.replace(' ', 'T').let { x -> if (Regex("[+-]\\d\\d$").containsMatchIn(x)) "$x:00" else x }) }.getOrNull() }
fun minsSince(s: String?): Long = parseTs(s)?.let { Duration.between(it, OffsetDateTime.now()).toMinutes().coerceAtLeast(0) } ?: 0
fun hhmm(s: String?): String = parseTs(s)?.atZoneSameInstant(ZoneId.systemDefault())?.format(DateTimeFormatter.ofPattern("HH:mm"))?.let { com.mydtf.core.ltr(it) } ?: "—"
fun dur(m: Long): String = when {
    m < 1 -> "الآن"
    m < 60 -> com.mydtf.core.ltr("$m") + " د"
    m < 1440 -> com.mydtf.core.ltr("${m / 60}:${(m % 60).toString().padStart(2, '0')}") + " س"
    else -> com.mydtf.core.ltr("${m / 1440}") + " يوم"
}
fun m2(v: Double?) = com.mydtf.client.ui.meters(v ?: 0.0)

/** Chrono qui défile à la seconde. */
@Composable
fun LiveClock(since: String?, style: androidx.compose.ui.text.TextStyle = MaterialTheme.typography.titleLarge, color: Color = Lux.Success) {
    val start = remember(since) { parseTs(since) }
    val txt by produceState("00:00", start) {
        while (true) {
            val s = start?.let { Duration.between(it, OffsetDateTime.now()).seconds.coerceAtLeast(0) } ?: 0
            value = com.mydtf.core.ltr(if (s >= 3600) "%d:%02d:%02d".format(s / 3600, s % 3600 / 60, s % 60) else "%02d:%02d".format(s / 60, s % 60))
            delay(1000)
        }
    }
    Text(txt, style = style, color = color, fontWeight = FontWeight.ExtraBold)
}

// ---------------- Libellés ----------------
val ROLE = mapOf("admin" to "المدير", "manager" to "المسيّر", "designer" to "المصمّم", "printer" to "الطابع")
data class MState(val label: String, val color: Color)
fun mstate(s: String) = when (s) {
    "running" -> MState("تطبع", Lux.Success)
    "maintenance" -> MState("صيانة", Color(0xFFFBBF24))
    "down" -> MState("عطل", Lux.Danger)
    else -> MState("متوقفة", Color(0xFF60A5FA))
}

/** Aptitude réelle à imprimer : état déclaré + rouleau monté (même règle que le site). */
data class Ready(val label: String, val color: Color, val block: Boolean = false, val why: String? = null)
fun readiness(m: Machine): Ready {
    val amber = Color(0xFFFBBF24); val left = m.rollRemaining ?: 0.0; val has = m.rollCode != null
    return when {
        !m.active -> Ready("غير مفعّلة", Lux.Muted, true, "الآلة موقوفة من الإعدادات")
        m.status == "down" -> Ready("معطّلة", Lux.Danger, true, m.statusNote ?: "عطل — أصلح الآلة ثم غيّر حالتها")
        m.status == "maintenance" -> Ready("في الصيانة", amber, true, m.statusNote ?: "صيانة جارية")
        m.status == "running" -> if (has) Ready("تطبع", Lux.Success) else Ready("تطبع — دون رولو مسجّل", amber, false, "سجّل الرولو المركّب حتى يُحسب الاستهلاك")
        !has -> Ready("تحتاج رولو", amber, true, "لا يوجد رولو مركّب — ركّب رولو لتبدأ الطباعة")
        left <= 0.0 -> Ready("الرولو انتهى", Lux.Danger, true, "الرولو فارغ — بدّله برولو جديد")
        left <= (m.alertM ?: 0.0) -> Ready("جاهزة — الرولو ينفد", amber, false, "بقي %.1f م فقط — جهّز رولو جديداً".format(left))
        else -> Ready("جاهزة للطباعة", Lux.Success)
    }
}

/** Voyant lumineux (pulse quand la machine imprime ou est en panne). */
@Composable
fun StatusDot(color: Color, pulse: Boolean, size: Int = 10) {
    val t by androidx.compose.animation.core.rememberInfiniteTransition(label = "d").animateFloat(
        1f, if (pulse) 2.2f else 1f, androidx.compose.animation.core.infiniteRepeatable(tween(1200), androidx.compose.animation.core.RepeatMode.Restart), label = "r",
    )
    Box(Modifier.size((size * 2.4).dp), contentAlignment = Alignment.Center) {
        if (pulse) Box(Modifier.size(size.dp).graphicsLayer { scaleX = t; scaleY = t; alpha = (2.2f - t) / 1.2f * 0.5f }.clip(CircleShape).background(color))
        Box(Modifier.size(size.dp).clip(CircleShape).background(color))
    }
}

/** Jauge horizontale animée. */
@Composable
fun Gauge(fraction: Float, low: Boolean, modifier: Modifier = Modifier) {
    val f by animateFloatAsState(fraction.coerceIn(0f, 1f), tween(700), label = "g")
    Box(modifier.fillMaxWidth().height(8.dp).clip(CircleShape).background(Lux.Surface2)) {
        Box(Modifier.fillMaxWidth(f).height(8.dp).clip(CircleShape).background(
            if (low) androidx.compose.ui.graphics.Brush.horizontalGradient(listOf(Lux.Danger, Color(0xFFFB923C))) else Lux.goldBrush))
    }
}

// ---------------- Clavier du code PIN ----------------
@Composable
fun PinScreen(title: String, subtitle: String, initial: String, error: String?, shake: Int, onPin: (String) -> Unit, footer: @Composable () -> Unit = {}) {
    var v by remember { mutableStateOf("") }
    val hf = LocalHapticFeedback.current
    val dx = remember { Animatable(0f) }
    LaunchedEffect(shake) {
        if (shake > 0) {
            v = ""; hf.performHapticFeedback(HapticFeedbackType.LongPress)
            for (x in listOf(22f, -18f, 14f, -10f, 6f, 0f)) dx.animateTo(x, tween(55))
        }
    }
    fun press(k: String) {
        when (k) {
            "del" -> v = v.dropLast(1)
            "ok" -> if (v.length >= 4) { onPin(v) }
            else -> if (v.length < 6) v += k
        }
    }
    Column(Modifier.fillMaxSize().background(Lux.nightBrush).padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Box(Modifier.size(72.dp).clip(CircleShape).background(Lux.goldBrush), contentAlignment = Alignment.Center) {
            Text(initial, color = Lux.OnAccent, fontSize = 30.sp, fontWeight = FontWeight.ExtraBold)
        }
        Spacer(Modifier.height(14.dp))
        Text(title, style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center)
        Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = Lux.Muted, textAlign = TextAlign.Center)
        Spacer(Modifier.height(22.dp))
        Row(Modifier.graphicsLayer { translationX = dx.value }, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            repeat(maxOf(4, v.length)) { i ->
                val filled = i < v.length
                val s by animateFloatAsState(if (filled) 1.25f else 1f, spring(0.4f, Spring.StiffnessMedium), label = "dot")
                Box(Modifier.size(14.dp).graphicsLayer { scaleX = s; scaleY = s }.clip(CircleShape)
                    .background(if (filled) Lux.Gold else Color.Transparent).border(1.5.dp, Lux.Gold.copy(alpha = 0.6f), CircleShape))
            }
        }
        Text(error ?: "", color = Lux.Danger, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 10.dp).height(22.dp))
        // Clavier toujours de gauche à droite : 1 2 3
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            Column(Modifier.width(300.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                listOf(listOf("1", "2", "3"), listOf("4", "5", "6"), listOf("7", "8", "9"), listOf("del", "0", "ok")).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        row.forEach { k ->
                            val enabled = k != "ok" || v.length >= 4
                            Box(
                                Modifier.weight(1f).aspectRatio(1.35f).clip(RoundedCornerShape(22.dp))
                                    .background(when (k) { "ok" -> if (enabled) Lux.goldBrush else androidx.compose.ui.graphics.SolidColor(Lux.Surface2); else -> androidx.compose.ui.graphics.SolidColor(Lux.Surface) })
                                    .border(1.dp, Lux.Gold.copy(alpha = 0.12f), RoundedCornerShape(22.dp))
                                    .bouncyClick(enabled = enabled, pressedScale = 0.86f) { press(k) },
                                contentAlignment = Alignment.Center,
                            ) {
                                when (k) {
                                    "del" -> Icon(Icons.AutoMirrored.Rounded.Backspace, "مسح", tint = Lux.Muted)
                                    "ok" -> Text("تأكيد", color = if (enabled) Lux.OnAccent else Lux.Muted, fontWeight = FontWeight.ExtraBold)
                                    else -> Text(k, fontSize = 28.sp, fontWeight = FontWeight.Bold, color = Lux.Ivory)
                                }
                            }
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(16.dp))
        footer()
    }
}

/** Petite pastille chiffrée. */
@Composable
fun CountPill(n: Int, color: Color = Lux.Gold) {
    if (n <= 0) return
    Box(Modifier.clip(CircleShape).background(color).padding(horizontal = 7.dp, vertical = 1.dp)) {
        Text("$n", color = Lux.OnAccent, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun Stat(label: String, value: String, sub: String? = null, color: Color = Lux.Ivory, modifier: Modifier = Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
        Text(value, style = MaterialTheme.typography.titleLarge, color = color, fontWeight = FontWeight.ExtraBold)
        if (sub != null) Text(sub, style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
    }
}
