package com.mydtf.client.ui.order

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.mydtf.client.data.Repo
import com.mydtf.client.ui.components.GoldButton
import com.mydtf.client.ui.components.LuxCard
import com.mydtf.client.data.friendlyError
import com.mydtf.client.ui.theme.Lux
import kotlinx.coroutines.launch

private val StarColor = Color(0xFFFBBF24)

/** Note du client après livraison (1 à 5 étoiles + commentaire). */
@Composable
fun RatingCard(orderId: String) {
    var stars by remember { mutableIntStateOf(0) }
    var comment by remember { mutableStateOf("") }
    var saved by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var err by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(orderId) {
        runCatching { Repo.myRating(orderId) }.getOrNull()?.let { stars = it.stars; comment = it.comment.orEmpty(); saved = true }
    }
    LuxCard(Modifier.fillMaxWidth(), highlight = !saved) {
        Text(if (saved) "تقييمك" else "كيف كانت طلبيتك؟", style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            (1..5).forEach { k ->
                Icon(
                    if (k <= stars) Icons.Rounded.Star else Icons.Rounded.StarBorder, "$k",
                    tint = if (k <= stars) StarColor else Lux.Muted,
                    modifier = Modifier.padding(2.dp).clickable { stars = k; saved = false },
                )
            }
        }
        if (!saved) {
            OutlinedTextField(comment, { comment = it }, Modifier.fillMaxWidth().padding(top = 8.dp), placeholder = { Text("ملاحظة (اختياري)") }, minLines = 2)
            err?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
            GoldButton("إرسال التقييم", onClick = {
                scope.launch {
                    busy = true; err = null
                    try { Repo.rateOrder(orderId, stars, comment); saved = true } catch (e: Exception) { err = friendlyError(e) }
                    busy = false
                }
            }, enabled = stars > 0, loading = busy, modifier = Modifier.fillMaxWidth().padding(top = 10.dp))
        } else if (comment.isNotBlank()) {
            Text(comment, style = MaterialTheme.typography.bodySmall, color = Lux.Muted, modifier = Modifier.padding(top = 6.dp))
        }
    }
}

private val celebrated = mutableSetOf<String>()

/** Petite fête quand la commande est prête (une fois par commande). */
@Composable
fun ReadyConfetti(orderId: String, status: String) {
    val ready = status in setOf("printed", "ready_pickup")
    var show by remember(orderId, status) { mutableStateOf(ready && orderId !in celebrated) }
    if (show) {
        LaunchedEffect(Unit) { celebrated += orderId }
        com.mydtf.client.ui.components.Confetti(Modifier.fillMaxWidth().height(220.dp), pieces = 70) { show = false }
    }
}
