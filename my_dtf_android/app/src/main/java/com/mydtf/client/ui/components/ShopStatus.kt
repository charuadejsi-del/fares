package com.mydtf.client.ui.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.mydtf.client.data.Settings
import com.mydtf.client.ui.theme.Lux

private val OpenGreen = Color(0xFF4ADE80)

/** Bandeau « l'atelier travaille / est fermé » (mis à jour en direct). */
@Composable
fun ShopStatus(s: Settings?, modifier: Modifier = Modifier, detail: String? = null) {
    if (s == null) return
    val open = s.isOpen
    val c = if (open) OpenGreen else Lux.Danger
    val pulse by rememberInfiniteTransition(label = "p").animateFloat(0.35f, 1f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "a")
    Row(
        modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(c.copy(alpha = 0.10f))
            .border(1.dp, c.copy(alpha = 0.35f), RoundedCornerShape(16.dp)).padding(horizontal = 14.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(10.dp).alpha(if (open) pulse else 1f).clip(CircleShape).background(c))
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(if (open) "الورشة تعمل الآن" else "الورشة مغلقة حالياً", style = MaterialTheme.typography.titleSmall, color = c)
            val sub = when {
                !open && !s.openNote.isNullOrBlank() -> s.openNote ?: ""
                detail != null -> detail
                open -> "طلبيتك تُعالج مباشرة"
                else -> "يمكنك إرسال طلبيتك، وتُعالج عند الفتح"
            }
            Text(sub, style = MaterialTheme.typography.bodySmall, color = Lux.Muted)
        }
    }
}
