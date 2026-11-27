package com.mydtf.pro

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Logout
import androidx.compose.material.icons.rounded.Brush
import androidx.compose.material.icons.rounded.Chat
import androidx.compose.material.icons.rounded.Dashboard
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.Inventory2
import androidx.compose.material.icons.rounded.Print
import androidx.compose.material.icons.rounded.ReceiptLong
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.mydtf.client.ui.components.LuxField
import com.mydtf.client.ui.components.bouncyClick
import com.mydtf.client.ui.theme.Lux

data class Tab(val id: String, val label: String, val icon: ImageVector)

@Composable
fun ProShell(vm: ProViewModel) {
    val tabs = if (com.mydtf.client.BuildConfig.ADMIN) listOf(
        Tab("control", "التحكّم", Icons.Rounded.Dashboard), Tab("orders", "الطلبيات", Icons.Rounded.ReceiptLong),
        Tab("machines", "الآلات", Icons.Rounded.Inventory2), Tab("chat", "الدردشة", Icons.Rounded.Chat),
        Tab("more", "المزيد", Icons.Rounded.GridView),
    ) else when (vm.role) {
        "printer" -> listOf(Tab("station", "المحطة", Icons.Rounded.Print), Tab("machines", "الآلات", Icons.Rounded.Inventory2))
        "designer" -> listOf(Tab("desk", "مكتب التصميم", Icons.Rounded.Brush))
        else -> listOf(Tab("control", "التحكّم", Icons.Rounded.Dashboard), Tab("orders", "الطلبيات", Icons.Rounded.ReceiptLong),
            Tab("machines", "الآلات", Icons.Rounded.Inventory2), Tab("chat", "الدردشة", Icons.Rounded.Chat))
    }
    var sel by remember { mutableIntStateOf(0) }
    var askOut by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().background(Lux.nightBrush)) {
        TopBar(vm, onOut = { askOut = true })
        Box(Modifier.weight(1f)) {
            AnimatedContent(sel, transitionSpec = { (slideInHorizontally { if (targetState > initialState) -it / 5 else it / 5 } + fadeIn()) togetherWith fadeOut() }, label = "tab") { i ->
                when (tabs.getOrNull(i)?.id) {
                    "station" -> PrinterStation(vm)
                    "desk" -> DesignerDesk(vm)
                    "control" -> Cockpit(vm)
                    "orders" -> OrdersMgr(vm)
                    "machines" -> MachinesScreen(vm)
                    "chat" -> ChatMgr(vm)
                    "more" -> AdminMore(vm)
                    else -> {}
                }
            }
        }
        if (tabs.size > 1) BottomBar(tabs, sel, badges = mapOf("orders" to vm.orders.count { it.status == "new" }, "chat" to vm.convs.sumOf { it.unread })) { sel = it }
    }
    if (askOut) {
        Dialog(onDismissRequest = { askOut = false }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
            if (vm.role == "admin") Box(Modifier.fillMaxSize().background(Lux.nightBrush), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("الخروج من الحساب؟", style = MaterialTheme.typography.titleLarge)
                    Row { TextButton(onClick = { askOut = false; vm.logout() }) { Text("خروج", color = Lux.Danger) }; TextButton(onClick = { askOut = false }) { Text("إلغاء") } }
                }
            } else PinScreen("تسجيل الخروج", "أدخل رمزك السري لإنهاء يوم العمل", vm.me?.fullName?.firstOrNull()?.toString() ?: "?", vm.pinError, vm.pinShake,
                { vm.clockOut(it) { askOut = false } }) { TextButton(onClick = { askOut = false }) { Text("إلغاء", color = Lux.Muted) } }
        }
    }
}

@Composable
private fun TopBar(vm: ProViewModel, onOut: () -> Unit) {
    var closing by remember { mutableStateOf(false) }
    var note by remember { mutableStateOf("") }
    Row(Modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = 16.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(42.dp).clip(CircleShape).background(Lux.goldBrush), contentAlignment = Alignment.Center) {
            Text(vm.me?.fullName?.firstOrNull()?.toString() ?: "?", color = Lux.OnAccent, fontWeight = FontWeight.ExtraBold)
        }
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(vm.me?.fullName ?: "", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(ROLE[vm.role] ?: "", style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
                if (vm.since != null) { Text("  ·  ", color = Lux.Muted); LiveClock(vm.since, MaterialTheme.typography.labelMedium, Lux.Success) }
            }
        }
        if (vm.isMgr) {
            val open = vm.shop.isOpen
            val c = if (open) Lux.Success else Lux.Danger
            Row(
                Modifier.clip(CircleShape).background(c.copy(alpha = 0.12f)).border(1.dp, c.copy(alpha = 0.4f), CircleShape)
                    .bouncyClick { if (open) closing = true else vm.act { Pro.setOpen(true, null) } }.padding(horizontal = 10.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                StatusDot(c, pulse = open, size = 7)
                Text(if (open) "تعمل" else "مغلقة", color = c, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.width(6.dp))
        }
        Box(Modifier.size(40.dp).clip(CircleShape).background(Lux.Surface).bouncyClick(onClick = onOut), contentAlignment = Alignment.Center) {
            Icon(Icons.AutoMirrored.Rounded.Logout, "خروج", tint = Lux.Danger)
        }
    }
    if (closing) AlertDialog(
        onDismissRequest = { closing = false },
        title = { Text("إغلاق الورشة؟") },
        text = { Column { Text("يرى الزبائن أن الورشة مغلقة، وتُعالج طلبياتهم عند الفتح.", color = Lux.Muted); Spacer(Modifier.height(10.dp)); LuxField(note, { note = it }, "رسالة للزبائن (اختياري)") } },
        confirmButton = { TextButton(onClick = { closing = false; vm.act { Pro.setOpen(false, note.ifBlank { null }) }; note = "" }) { Text("إغلاق", color = Lux.Danger) } },
        dismissButton = { TextButton(onClick = { closing = false }) { Text("إلغاء") } },
        containerColor = Lux.Surface,
    )
}

/** Barre du bas avec pastille qui glisse sous l'onglet actif. */
@Composable
private fun BottomBar(tabs: List<Tab>, sel: Int, badges: Map<String, Int>, onSel: (Int) -> Unit) {
    BoxWithConstraints(Modifier.fillMaxWidth().background(Lux.Night2).navigationBarsPadding().padding(horizontal = 8.dp, vertical = 8.dp)) {
        val w = maxWidth / tabs.size
        val x by animateDpAsState(w * sel, spring(dampingRatio = 0.7f, stiffness = 400f), label = "pill")
        // offset suit le sens RTL : l onglet 0 est au début (à droite)
        Box(Modifier.align(Alignment.CenterStart).offset(x = x).width(w).height(54.dp).padding(horizontal = 6.dp).clip(RoundedCornerShape(18.dp)).background(Lux.Gold.copy(alpha = 0.14f)))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
            tabs.forEachIndexed { i, t ->
                val on = i == sel
                Column(Modifier.weight(1f).height(54.dp).bouncyClick { onSel(i) }, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                    Box {
                        Icon(t.icon, t.label, tint = if (on) Lux.GoldLight else Lux.Muted)
                        val b = badges[t.id] ?: 0
                        if (b > 0) Box(Modifier.align(Alignment.TopEnd).offset(x = 8.dp, y = (-6).dp)) { CountPill(b, Lux.Danger) }
                    }
                    Text(t.label, style = MaterialTheme.typography.labelSmall, color = if (on) Lux.GoldLight else Lux.Muted, fontWeight = if (on) FontWeight.Bold else FontWeight.Normal)
                }
            }
        }
    }
}

val Transparent = Color.Transparent
