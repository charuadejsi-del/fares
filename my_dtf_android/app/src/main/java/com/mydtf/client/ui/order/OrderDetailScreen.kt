package com.mydtf.client.ui.order

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.ReportProblem
import androidx.compose.material.icons.rounded.Replay
import androidx.compose.material.icons.rounded.ChatBubbleOutline
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.mydtf.client.data.Order
import com.mydtf.client.data.OrderEvent
import com.mydtf.client.data.OrderImage
import com.mydtf.client.data.Repo
import com.mydtf.client.data.friendlyError
import com.mydtf.client.ui.MainViewModel
import com.mydtf.client.ui.components.GhostButton
import com.mydtf.client.ui.components.KeyValue
import com.mydtf.client.ui.components.LuxCard
import com.mydtf.client.ui.components.LuxField
import com.mydtf.client.ui.components.SectionTitle
import com.mydtf.client.ui.components.StatusChip
import com.mydtf.client.ui.components.StatusTimeline
import com.mydtf.client.ui.deliveryLabels
import com.mydtf.client.ui.formatDate
import com.mydtf.client.ui.meters
import com.mydtf.client.ui.theme.Lux
import com.mydtf.core.formatDa
import kotlinx.coroutines.launch

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun OrderDetailScreen(orderId: String, main: MainViewModel, onBack: () -> Unit, onReorder: (String) -> Unit = {}, onChat: (String) -> Unit = {}) {
    var order by remember { mutableStateOf<Order?>(main.orders.firstOrNull { it.id == orderId }) }
    var events by remember { mutableStateOf<List<OrderEvent>>(emptyList()) }
    var images by remember { mutableStateOf<List<Pair<OrderImage, String>>>(emptyList()) }
    var error by remember { mutableStateOf<String?>(null) }
    var showReport by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // Recharge à l'ouverture et à chaque changement en direct.
    LaunchedEffect(orderId, main.liveTick) {
        try {
            order = Repo.order(orderId)
            events = Repo.orderEvents(orderId)
            if (images.isEmpty()) images = Repo.orderImages(orderId).map { it to Repo.signedUrl(it.storagePath) }
        } catch (e: Exception) { error = friendlyError(e) }
    }

    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Row(
            Modifier.fillMaxWidth().background(Lux.nightBrush).statusBarsPadding().padding(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "رجوع", tint = Lux.Ivory) }
            Text(order?.let { "طلبية #${it.code}" } ?: "الطلبية", style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
            order?.let { StatusChip(it.status, Modifier.padding(end = 10.dp)) }
        }
        val o = order
        if (o == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error) else CircularProgressIndicator(color = Lux.Gold)
            }
            return@Column
        }
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            // ---- montant ----
            LuxCard(Modifier.fillMaxWidth(), highlight = true) {
                Text("المبلغ الإجمالي", style = MaterialTheme.typography.bodySmall, color = Lux.Muted)
                Text(formatDa(o.total), style = MaterialTheme.typography.headlineMedium, color = Lux.Gold)
                Spacer(Modifier.height(8.dp))
                KeyValue(if (o.finalLengthCm != null) "الأمتار النهائية" else "الأمتار التقديرية", meters(o.billedMeters))
                KeyValue("الطباعة", formatDa(o.printAmount))
                KeyValue("التوصيل", if (o.deliveryMode == "pickup") "مجاني" else if (o.deliveryFee > 0) formatDa(o.deliveryFee) else "يُحدَّد لاحقاً")
                if (o.amountPaid > 0) KeyValue("المدفوع", formatDa(o.amountPaid), valueColor = Lux.Success)
                if (o.status == "rejected") o.rejectReason?.let { KeyValue("سبب الرفض", it, valueColor = Lux.Danger) }
            }

            // ---- suivi ----
            if (o.status != "rejected" && o.status != "cancelled") {
                SectionTitle("مراحل الطلبية")
                LuxCard(Modifier.fillMaxWidth()) {
                    val dates = events.filter { it.toStatus != null }.associate { it.toStatus!! to formatDate(it.createdAt) }
                    StatusTimeline(o.status, o.deliveryMode, dates)
                }
            }

            // ---- livraison ----
            SectionTitle("الاستلام")
            LuxCard(Modifier.fillMaxWidth()) {
                KeyValue("الطريقة", deliveryLabels[o.deliveryMode] ?: o.deliveryMode)
                o.shipWilaya?.let { KeyValue("الولاية", it) }
                o.shipCommune?.let { KeyValue("البلدية", it) }
                o.trackingNumber?.let { t ->
                    Row(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).clickable { copy(context, t) }.padding(vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("رقم التتبّع ${o.carrier?.uppercase() ?: ""}", color = Lux.Muted, modifier = Modifier.weight(1f))
                        Text(t, style = MaterialTheme.typography.titleSmall, color = Lux.GoldLight)
                        Spacer(Modifier.width(6.dp))
                        Icon(Icons.Rounded.ContentCopy, "نسخ", tint = Lux.Gold, modifier = Modifier.size(18.dp))
                    }
                }
                KeyValue("تاريخ الطلب", formatDate(o.createdAt))
            }

            // ---- images ----
            SectionTitle("الصور (${images.size})")
            FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                images.forEach { (img, url) ->
                    Column(
                        Modifier.width(104.dp).clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surface).padding(6.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        AsyncImage(
                            model = url, contentDescription = null, contentScale = ContentScale.Fit,
                            modifier = Modifier.size(92.dp).clip(RoundedCornerShape(12.dp)).background(Color(0xFF0E0E13)),
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(com.mydtf.client.ui.sizeCm(trim(img.widthCm), trim(img.heightCm)), style = MaterialTheme.typography.labelSmall)
                        Text(com.mydtf.core.ltr("× ${img.quantity}"), style = MaterialTheme.typography.labelSmall, color = Lux.Gold)
                    }
                }
            }

            com.mydtf.client.ui.components.GoldButton("أعِد نفس الطلبية", onClick = { onReorder(o.id) },
                icon = Icons.Rounded.Replay, modifier = Modifier.fillMaxWidth())
            GhostButton("مراسلة الورشة بخصوص هذه الطلبية", onClick = { onChat(o.id) }, icon = Icons.Rounded.ChatBubbleOutline, modifier = Modifier.fillMaxWidth())
            if (o.status !in setOf("new", "rejected", "cancelled")) {
                GhostButton("التبليغ عن مشكل في الطباعة", onClick = { showReport = true }, icon = Icons.Rounded.ReportProblem, modifier = Modifier.fillMaxWidth())
            }
            Spacer(Modifier.height(24.dp))
        }
    }

    if (showReport) {
        var text by remember { mutableStateOf("") }
        var busy by remember { mutableStateOf(false) }
        AlertDialog(
            onDismissRequest = { if (!busy) showReport = false },
            containerColor = MaterialTheme.colorScheme.surface,
            title = { Text("التبليغ عن مشكل") },
            text = { LuxField(text, { text = it }, "صف المشكل (ألوان، مقاس، تقشّر...)", singleLine = false, minLines = 3) },
            confirmButton = {
                TextButton(enabled = text.isNotBlank() && !busy, onClick = {
                    busy = true
                    scope.launch {
                        try {
                            Repo.reportIssue(orderId, text.trim())
                            Toast.makeText(context, "وصل تبليغك إلى الورشة", Toast.LENGTH_LONG).show()
                            showReport = false
                        } catch (e: Exception) {
                            Toast.makeText(context, friendlyError(e), Toast.LENGTH_LONG).show()
                        } finally { busy = false }
                    }
                }) { Text("إرسال", color = Lux.Gold) }
            },
            dismissButton = { TextButton(onClick = { showReport = false }) { Text("إلغاء") } },
        )
    }
}

private fun trim(d: Double) = if (d % 1.0 == 0.0) d.toInt().toString() else d.toString()

private fun copy(context: Context, text: String) {
    val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    cm.setPrimaryClip(ClipData.newPlainText("tracking", text))
    Toast.makeText(context, "تم النسخ", Toast.LENGTH_SHORT).show()
}
