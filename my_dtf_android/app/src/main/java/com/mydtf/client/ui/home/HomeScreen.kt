package com.mydtf.client.ui.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AddPhotoAlternate
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChatBubbleOutline
import androidx.compose.material.icons.rounded.NotificationsNone
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Print
import androidx.compose.material.icons.rounded.ReceiptLong
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.mydtf.client.data.Order
import com.mydtf.client.ui.MainViewModel
import com.mydtf.client.ui.components.EmptyState
import com.mydtf.client.ui.components.GoldButton
import com.mydtf.client.ui.components.staggerIn
import com.mydtf.client.ui.components.breathe
import androidx.compose.foundation.lazy.itemsIndexed
import com.mydtf.client.ui.components.LuxCard
import com.mydtf.client.ui.components.ShopStatus
import com.mydtf.client.ui.components.SectionTitle
import com.mydtf.client.ui.components.StatusChip
import com.mydtf.client.ui.components.StepProgress
import com.mydtf.client.ui.formatDate
import com.mydtf.client.ui.meters
import com.mydtf.client.ui.statusInfo
import com.mydtf.client.ui.theme.Lux
import com.mydtf.core.formatDa

private val finished = setOf("delivered", "rejected", "cancelled")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    vm: MainViewModel,
    onNewOrder: () -> Unit,
    onOrder: (String) -> Unit,
    onNotifications: () -> Unit,
    onProfile: () -> Unit,
    onChat: () -> Unit = {},
    onArchive: () -> Unit = {},
) {
    val orders = vm.orders
    val active = orders.filter { it.status !in finished }
    val counted = orders.filter { it.status != "rejected" && it.status != "cancelled" }
    val total = counted.sumOf { it.total }
    val paid = orders.sumOf { it.amountPaid }
    val firstName = vm.profile?.fullName?.split(" ")?.firstOrNull().orEmpty()

    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        PullToRefreshBox(isRefreshing = vm.refreshing, onRefresh = vm::refresh, modifier = Modifier.fillMaxSize()) {
            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = 120.dp),
            ) {
                // ---------- En-tête ----------
                item {
                    Box(
                        Modifier.fillMaxWidth()
                            .clip(RoundedCornerShape(bottomStart = 34.dp, bottomEnd = 34.dp))
                            .background(Lux.nightBrush)
                            .statusBarsPadding().padding(20.dp),
                    ) {
                        Column {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text("مرحباً ${firstName} 👋", style = MaterialTheme.typography.headlineSmall)
                                    Text("${com.mydtf.client.BuildConfig.APP_NAME} · طباعة على الفيلم", style = MaterialTheme.typography.bodySmall, color = Lux.Muted)
                                }
                                IconButton(onClick = onNotifications) {
                                    BadgedBox(badge = { if (vm.unread > 0) Badge(containerColor = Lux.Gold, contentColor = Lux.OnAccent) { Text("${vm.unread}") } }) {
                                        Icon(Icons.Rounded.NotificationsNone, "الإشعارات", tint = Lux.Ivory)
                                    }
                                }
                                IconButton(onClick = onChat) {
                                    BadgedBox(badge = { if (vm.unreadChat > 0) Badge(containerColor = Lux.Gold, contentColor = Lux.OnAccent) { Text("${vm.unreadChat}") } }) {
                                        Icon(Icons.Rounded.ChatBubbleOutline, "الدردشة", tint = Lux.Ivory)
                                    }
                                }
                                IconButton(onClick = onProfile) { Icon(Icons.Rounded.Person, "حسابي", tint = Lux.Ivory) }
                            }
                            Spacer(Modifier.height(18.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Stat("الطلبيات", "${orders.size}", Modifier.weight(1f))
                                Stat("المجموع", formatDa(total), Modifier.weight(1.4f))
                                Stat("المتبقي", formatDa((total - paid).coerceAtLeast(0.0)), Modifier.weight(1.4f))
                            }
                        }
                    }
                }

                // ---------- État de l'atelier ----------
                item { ShopStatus(vm.settings, Modifier.padding(16.dp, 16.dp, 16.dp, 0.dp)) }

                // ---------- Bannière prix ----------
                vm.settings?.let { s ->
                    if (s.pricePerMeter > 0) item {
                        LuxCard(Modifier.fillMaxWidth().padding(16.dp, 16.dp, 16.dp, 0.dp), highlight = true, padding = PaddingValues(16.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Rounded.Print, null, tint = Lux.Gold)
                                Spacer(Modifier.width(10.dp))
                                Column(Modifier.weight(1f)) {
                                    Text("سعر المتر", style = MaterialTheme.typography.bodySmall, color = Lux.Muted)
                                    val sp = vm.profile?.specialPrice
                                    Text(formatDa(sp ?: s.pricePerMeter), style = MaterialTheme.typography.titleLarge, color = Lux.Gold)
                                    if (sp != null) Text("سعر خاص بك", style = MaterialTheme.typography.labelSmall, color = Lux.Success)
                                    else s.priceTiers.sortedBy { it.minM }.forEach { t ->
                                        Text("من ${t.minM.toInt()} م: ${formatDa(t.price)}", style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
                                    }
                                }
                                Text("عرض ${s.filmWidthCm.toInt()} سم", style = MaterialTheme.typography.labelMedium, color = Lux.Muted)
                            }
                        }
                    }
                }

                if (vm.loading) {
                    items(3) { com.mydtf.client.ui.components.Shimmer(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp).height(110.dp)) }
                } else if (orders.isEmpty()) {
                    item {
                        EmptyState(
                            Icons.Rounded.ReceiptLong,
                            "لا توجد طلبيات بعد",
                            "ارفع صورك واكتب مقاساتها، نرتّبها لك على الفيلم ونعطيك السعر فوراً.",
                            Modifier.padding(top = 24.dp),
                        )
                    }
                } else {
                    if (active.isNotEmpty()) {
                        item { SectionTitle("قيد التنفيذ", Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) }
                        itemsIndexed(active, key = { _, it -> "a" + it.id }) { i, o ->
                            Box(Modifier.staggerIn(i)) { ActiveOrderCard(o) { onOrder(o.id) } }
                        }
                    }
                    val past = orders.filter { it.status in finished }
                    if (past.isNotEmpty()) {
                        item {
                            SectionTitle("آخر الطلبيات", Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                                androidx.compose.material3.TextButton(onClick = onArchive) { Text("الأرشيف كاملاً", color = Lux.Gold) }
                            }
                        }
                        itemsIndexed(past.take(5), key = { _, it -> "p" + it.id }) { i, o -> Box(Modifier.staggerIn(i + active.size)) { PastOrderRow(o) { onOrder(o.id) } } }
                    }
                }
                if (vm.offline && orders.isNotEmpty()) item {
                    Text("📴 بدون إنترنت — تعرض آخر نسخة محفوظة", color = Lux.GoldLight, modifier = Modifier.padding(16.dp))
                }
                vm.error?.let { e ->
                    item { Text(e, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(16.dp)) }
                }
            }
        }

        // ---------- Bouton principal ----------
        GoldButton(
            "طلبية جديدة",
            onClick = onNewOrder,
            icon = Icons.Rounded.AddPhotoAlternate,
            modifier = Modifier.breathe().then(Modifier.align(Alignment.BottomCenter).navigationBarsPadding())
                .padding(horizontal = 20.dp, vertical = 16.dp).fillMaxWidth(),
            height = 60.dp,
        )
    }
}

@Composable
private fun Stat(label: String, value: String, modifier: Modifier = Modifier) {
    Column(
        modifier.clip(RoundedCornerShape(18.dp)).background(Lux.Gold.copy(alpha = 0.07f)).padding(12.dp),
    ) {
        Text(value, style = MaterialTheme.typography.titleMedium, color = Lux.GoldLight, maxLines = 1)
        Text(label, style = MaterialTheme.typography.labelSmall, color = Lux.Muted)
    }
}

@Composable
private fun ActiveOrderCard(o: Order, onClick: () -> Unit) {
    val info = statusInfo(o.status)
    LuxCard(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp), highlight = o.status == "printing", onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(46.dp).clip(CircleShape).background(info.color.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
                Icon(info.icon, null, tint = info.color)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text("طلبية #${o.code}", style = MaterialTheme.typography.titleMedium)
                Text(formatDate(o.createdAt), style = MaterialTheme.typography.bodySmall, color = Lux.Muted)
            }
            StatusChip(o.status)
        }
        Spacer(Modifier.height(14.dp))
        StepProgress(o.status, o.deliveryMode)
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(meters(o.billedMeters), style = MaterialTheme.typography.bodyMedium, color = Lux.Muted)
            Spacer(Modifier.weight(1f))
            Text(formatDa(o.total), style = MaterialTheme.typography.titleMedium, color = Lux.Gold)
            Icon(Icons.Rounded.ChevronLeft, null, tint = Lux.Muted)
        }
    }
}

@Composable
private fun PastOrderRow(o: Order, onClick: () -> Unit) {
    LuxCard(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp), onClick = onClick, padding = PaddingValues(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("#${o.code} · ${meters(o.billedMeters)}", style = MaterialTheme.typography.titleSmall)
                Text(formatDate(o.createdAt), style = MaterialTheme.typography.bodySmall, color = Lux.Muted)
            }
            Text(formatDa(o.total), style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.width(10.dp))
            StatusChip(o.status)
        }
    }
}
