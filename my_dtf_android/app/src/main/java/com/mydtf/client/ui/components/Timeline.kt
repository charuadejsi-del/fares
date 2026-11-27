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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mydtf.client.ui.statusInfo
import com.mydtf.client.ui.stepsFor
import com.mydtf.client.ui.theme.Lux

/** Barre de progression segmentée (accueil). */
@Composable
fun StepProgress(status: String, mode: String, modifier: Modifier = Modifier) {
    val steps = stepsFor(mode)
    val idx = steps.indexOf(status)
    Row(modifier.fillMaxWidth()) {
        steps.forEachIndexed { i, _ ->
            Box(
                Modifier.weight(1f).height(6.dp).padding(horizontal = 2.dp).clip(CircleShape)
                    .background(if (i <= idx) Lux.Gold else Lux.Gold.copy(alpha = 0.15f)),
            )
        }
    }
}

/** Frise verticale des étapes ; l'étape en cours pulse doucement. */
@Composable
fun StatusTimeline(status: String, mode: String, dates: Map<String, String>) {
    val steps = stepsFor(mode)
    val current = steps.indexOf(status)
    val pulse by rememberInfiniteTransition(label = "pulse").animateFloat(
        initialValue = 1f, targetValue = 1.18f,
        animationSpec = infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "p",
    )
    val fill = androidx.compose.runtime.remember { androidx.compose.animation.core.Animatable(0f) }
    androidx.compose.runtime.LaunchedEffect(current) { fill.animateTo(current.toFloat().coerceAtLeast(0f), tween(380 * (current.coerceAtLeast(1)))) }
    Column {
        steps.forEachIndexed { i, s ->
            val info = statusInfo(s)
            val reachedT = (fill.value - i + 1).coerceIn(0f, 1f)
            val done = i < current && fill.value >= i
            val now = i == current && fill.value >= i - 0.01f
            Row(verticalAlignment = Alignment.Top) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(
                        Modifier.size(34.dp).scale(if (now) pulse else 1f).clip(CircleShape)
                            .background(
                                when {
                                    now -> info.color
                                    done -> Lux.Gold
                                    else -> MaterialTheme.colorScheme.surfaceContainerHighest
                                },
                            )
                            .border(1.dp, if (done || now) Lux.GoldLight.copy(alpha = 0.6f) else Lux.Gold.copy(alpha = 0.1f), CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(info.icon, null, tint = if (done || now) Lux.OnAccent else Lux.Muted, modifier = Modifier.size(18.dp))
                    }
                    if (i < steps.lastIndex) {
                        Box(Modifier.width(2.dp).height(26.dp).background(Lux.Gold.copy(alpha = 0.15f), RoundedCornerShape(1.dp))) {
                            Box(Modifier.width(2.dp).height(26.dp * (fill.value - i).coerceIn(0f, 1f)).background(Lux.goldBrush, RoundedCornerShape(1.dp)))
                        }
                    }
                }
                Spacer(Modifier.width(14.dp))
                Column(Modifier.padding(top = 5.dp)) {
                    Text(
                        info.label,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = if (now) FontWeight.ExtraBold else FontWeight.Medium,
                        color = if (done || now) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    dates[s]?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                }
            }
        }
    }
}
