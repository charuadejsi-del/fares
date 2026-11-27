package com.mydtf.client.ui.more

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.ChatBubbleOutline
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Inventory2
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Phone
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.mydtf.client.data.NewProfileInput
import com.mydtf.client.data.friendlyError
import com.mydtf.client.ui.MainViewModel
import com.mydtf.client.ui.components.CommunePicker
import com.mydtf.client.ui.components.EmptyState
import com.mydtf.client.ui.components.GoldButton
import com.mydtf.client.ui.components.LuxCard
import com.mydtf.client.ui.components.LuxField
import com.mydtf.client.ui.components.StatusChip
import com.mydtf.client.ui.components.WilayaPicker
import com.mydtf.client.ui.formatDate
import com.mydtf.client.ui.meters
import com.mydtf.client.ui.theme.Lux
import com.mydtf.core.Commune
import com.mydtf.core.Wilaya
import com.mydtf.core.formatDa
import kotlinx.coroutines.launch

@Composable
private fun Bar(title: String, onBack: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().background(Lux.nightBrush).statusBarsPadding().padding(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "رجوع", tint = Lux.Ivory) }
        Text(title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
    }
}

// =====================================================================
// Chat avec l'atelier
// =====================================================================
@Composable
fun ChatScreen(main: MainViewModel, onBack: () -> Unit, presetOrder: String? = null) {
    var text by remember { mutableStateOf("") }
    var orderId by remember { mutableStateOf(presetOrder) }
    var sending by remember { mutableStateOf(false) }
    var err by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val list = rememberLazyListState()
    val codes = main.orders.associate { it.id to it.code }
    LaunchedEffect(main.messages.size) {
        main.markChatRead()
        if (main.messages.isNotEmpty()) list.animateScrollToItem(main.messages.size - 1)
    }

    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background).imePadding()) {
        Bar("الدردشة مع الورشة", onBack)
        if (main.settings?.isOpen == false) {
            com.mydtf.client.ui.components.ShopStatus(main.settings, Modifier.padding(12.dp, 4.dp, 12.dp, 0.dp), detail = "قد يتأخر الرد حتى فتح الورشة")
        }
        Box(Modifier.weight(1f)) {
            if (main.messages.isEmpty()) {
                EmptyState(Icons.Rounded.ChatBubbleOutline, "مرحباً بك 👋", "اكتب لنا أي سؤال أو مشكل، ونردّ عليك هنا.")
            }
            LazyColumn(state = list, contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxSize()) {
                items(main.messages, key = { it.id }) { m ->
                    val mine = !m.fromStaff
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (mine) Arrangement.Start else Arrangement.End) {
                        Column(
                            Modifier.widthIn(max = 290.dp)
                                .clip(RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp, bottomStart = if (mine) 18.dp else 4.dp, bottomEnd = if (mine) 4.dp else 18.dp))
                                .background(if (mine) Lux.goldBrush else androidx.compose.ui.graphics.SolidColor(MaterialTheme.colorScheme.surfaceContainerHighest))
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                        ) {
                            m.orderId?.let { codes[it] }?.let {
                                Text("طلبية #$it", style = MaterialTheme.typography.labelSmall, color = if (mine) Lux.Night else Lux.Gold)
                            }
                            Text(m.body, color = if (mine) Lux.Night else MaterialTheme.colorScheme.onSurface, style = MaterialTheme.typography.bodyLarge)
                            Text(
                                (if (mine) "" else "الورشة · ") + formatDate(m.createdAt),
                                style = MaterialTheme.typography.labelSmall,
                                color = if (mine) Lux.Night.copy(alpha = 0.6f) else Lux.Muted,
                            )
                        }
                    }
                }
            }
        }
        // choix de la commande liée
        if (main.orders.isNotEmpty()) {
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 12.dp, vertical = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                OrderPill("بدون طلبية", orderId == null) { orderId = null }
                main.orders.take(15).forEach { o -> OrderPill("#${o.code}", orderId == o.id) { orderId = o.id } }
            }
        }
        err?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 16.dp)) }
        Row(Modifier.fillMaxWidth().navigationBarsPadding().padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = text, onValueChange = { text = it.take(2000) },
                placeholder = { Text("اكتب رسالتك...") }, maxLines = 4,
                shape = RoundedCornerShape(22.dp), modifier = Modifier.weight(1f),
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Lux.Gold, cursorColor = Lux.Gold,
                    focusedContainerColor = MaterialTheme.colorScheme.surface, unfocusedContainerColor = MaterialTheme.colorScheme.surface),
            )
            Spacer(Modifier.width(8.dp))
            Box(
                Modifier.size(52.dp).clip(CircleShape).background(if (text.isBlank() || sending) androidx.compose.ui.graphics.SolidColor(Lux.Surface2) else Lux.goldBrush)
                    .clickable(enabled = text.isNotBlank() && !sending) {
                        val body = text.trim(); sending = true; err = null
                        scope.launch {
                            try { main.send(body, orderId); text = "" } catch (e: Exception) { err = friendlyError(e) }
                            sending = false
                        }
                    },
                contentAlignment = Alignment.Center,
            ) {
                if (sending) CircularProgressIndicator(Modifier.size(22.dp), color = Lux.Night, strokeWidth = 2.dp)
                else Icon(Icons.AutoMirrored.Rounded.Send, "إرسال", tint = if (text.isBlank()) Lux.Muted else Lux.Night)
            }
        }
    }
}

@Composable
private fun OrderPill(label: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        Modifier.clip(CircleShape)
            .background(if (selected) Lux.Gold.copy(alpha = 0.18f) else Color.Transparent)
            .border(1.dp, if (selected) Lux.Gold else Lux.Gold.copy(alpha = 0.25f), CircleShape)
            .clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 6.dp),
    ) { Text(label, color = if (selected) Lux.GoldLight else Lux.Muted, style = MaterialTheme.typography.labelMedium) }
}

// =====================================================================
// Archive des commandes (consultable hors ligne)
// =====================================================================
@Composable
fun ArchiveScreen(main: MainViewModel, onBack: () -> Unit, onOrder: (String) -> Unit) {
    var q by remember { mutableStateOf("") }
    var filter by remember { mutableStateOf("all") }
    val list = main.orders.filter { o ->
        (filter == "all" || (filter == "done" && o.status == "delivered") || (filter == "open" && o.status !in setOf("delivered", "rejected", "cancelled")) ||
            (filter == "rejected" && o.status in setOf("rejected", "cancelled"))) &&
            (q.isBlank() || o.code.toString().contains(q.trim()))
    }
    val delivered = main.orders.filter { it.status == "delivered" }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Bar("أرشيف طلبياتي", onBack)
        LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.navigationBarsPadding()) {
            item {
                LuxCard(Modifier.fillMaxWidth(), highlight = true) {
                    Row {
                        Column(Modifier.weight(1f)) {
                            Text("${main.orders.size}", style = MaterialTheme.typography.headlineSmall, color = Lux.Gold)
                            Text("طلبية", color = Lux.Muted, style = MaterialTheme.typography.bodySmall)
                        }
                        Column(Modifier.weight(1f)) {
                            Text(String.format(java.util.Locale.US, "%.1f", delivered.sumOf { it.billedMeters }), style = MaterialTheme.typography.headlineSmall, color = Lux.Gold)
                            Text("متر مطبوع", color = Lux.Muted, style = MaterialTheme.typography.bodySmall)
                        }
                        Column(Modifier.weight(1.4f)) {
                            Text(formatDa(delivered.sumOf { it.total }), style = MaterialTheme.typography.titleLarge, color = Lux.Gold)
                            Text("مجموع ما صرفته", color = Lux.Muted, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                    if (main.offline) Text("📴 بدون إنترنت — تعرض آخر نسخة محفوظة", color = Lux.GoldLight, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp))
                }
            }
            item { LuxField(q, { q = it.filter(Char::isDigit) }, "ابحث برقم الطلبية", leading = Icons.Rounded.Search, keyboard = KeyboardType.Number) }
            item {
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    listOf("all" to "الكل", "open" to "الجارية", "done" to "المُسلّمة", "rejected" to "المرفوضة").forEach { (k, l) -> OrderPill(l, filter == k) { filter = k } }
                }
            }
            if (list.isEmpty()) item { EmptyState(Icons.Rounded.Inventory2, "لا شيء هنا", "لا توجد طلبيات بهذا البحث.") }
            items(list, key = { it.id }) { o ->
                LuxCard(Modifier.fillMaxWidth(), onClick = { onOrder(o.id) }, padding = PaddingValues(14.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("#${o.code} · ${meters(o.billedMeters)}", style = MaterialTheme.typography.titleSmall)
                            Text(formatDate(o.createdAt), style = MaterialTheme.typography.bodySmall, color = Lux.Muted)
                        }
                        Text(formatDa(o.total), style = MaterialTheme.typography.titleSmall, color = Lux.Gold)
                        Spacer(Modifier.width(8.dp))
                        StatusChip(o.status)
                    }
                }
            }
        }
    }
}

// =====================================================================
// Compte existant sans profil DTF : compléter les informations
// =====================================================================
@Composable
fun CompleteProfileScreen(main: MainViewModel) {
    var name by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var wilaya by remember { mutableStateOf<Wilaya?>(null) }
    var commune by remember { mutableStateOf<Commune?>(null) }
    var address by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var err by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val ok = name.isNotBlank() && Regex("^0[5-7]\\d{8}$").matches(phone.replace(" ", "")) && wilaya != null && commune != null
    Column(
        Modifier.fillMaxSize().background(Lux.nightBrush).statusBarsPadding().navigationBarsPadding().imePadding()
            .verticalScroll(rememberScrollState()).padding(22.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Spacer(Modifier.height(20.dp))
        Text("أكمل معلوماتك", style = MaterialTheme.typography.headlineMedium, color = Lux.Gold)
        Text("مرّة واحدة فقط، لنعرف أين نوصل طلبياتك.", color = Lux.Muted)
        LuxCard(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                LuxField(name, { name = it }, "الاسم الكامل", leading = Icons.Rounded.Person)
                LuxField(phone, { phone = it.filter { c -> c.isDigit() || c == ' ' }.take(12) }, "رقم الهاتف", leading = Icons.Rounded.Phone, keyboard = KeyboardType.Phone)
                WilayaPicker(wilaya, { wilaya = it; commune = null })
                CommunePicker(wilaya, commune, { commune = it })
                LuxField(address, { address = it }, "العنوان (اختياري)", leading = Icons.Rounded.Home)
            }
        }
        err?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        GoldButton("متابعة", enabled = ok, loading = busy, modifier = Modifier.fillMaxWidth(), onClick = {
            busy = true; err = null
            scope.launch {
                try { main.completeProfile(NewProfileInput(name.trim(), phone.replace(" ", ""), wilaya?.fr, commune?.fr, address.trim().ifEmpty { null })) }
                catch (e: Exception) { err = friendlyError(e) }
                busy = false
            }
        })
    }
}
