package com.mydtf.client.ui.components

import android.provider.Settings
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.unit.dp
import com.mydtf.client.ui.theme.Lux
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/** Respecte « supprimer les animations » du téléphone. */
@Composable
fun motionEnabled(): Boolean {
    val ctx = LocalContext.current
    return remember { runCatching { Settings.Global.getFloat(ctx.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) }.getOrDefault(1f) > 0f }
}

/** Clic « vivant » : s'enfonce avec un ressort + petite vibration. */
fun Modifier.bouncyClick(enabled: Boolean = true, haptic: Boolean = true, pressedScale: Float = 0.94f, onClick: () -> Unit): Modifier = composed {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val hf = LocalHapticFeedback.current
    val s by animateFloatAsState(if (pressed && enabled) pressedScale else 1f, spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessMediumLow), label = "bounce")
    this.graphicsLayer { scaleX = s; scaleY = s }
        .clickable(interactionSource = source, indication = null, enabled = enabled) {
            if (haptic) hf.performHapticFeedback(HapticFeedbackType.TextHandleMove)
            onClick()
        }
}

/** Reflet lumineux qui balaie un élément (boutons principaux). */
fun Modifier.shine(enabled: Boolean = true, shape: Shape = RoundedCornerShape(18.dp)): Modifier = composed {
    if (!enabled || !motionEnabled()) return@composed this
    val t by rememberInfiniteTransition(label = "shine").animateFloat(-1f, 2.2f, infiniteRepeatable(tween(2600, delayMillis = 1400, easing = LinearEasing)), label = "x")
    this.clip(shape).drawWithContentShine(t)
}
private fun Modifier.drawWithContentShine(t: Float) = this.drawWithContent {
    drawContent()
    val w = size.width
    drawRect(Brush.linearGradient(listOf(Color.Transparent, Color.White.copy(alpha = 0.28f), Color.Transparent),
        start = Offset(w * t - w * 0.3f, 0f), end = Offset(w * t, size.height)))
}

/** Entrée en cascade : chaque élément glisse et apparaît avec un léger décalage. */
fun Modifier.staggerIn(index: Int): Modifier = composed {
    if (!motionEnabled()) return@composed this
    val a = remember { Animatable(0f) }
    LaunchedEffect(Unit) { kotlinx.coroutines.delay((index.coerceAtMost(8) * 55).toLong()); a.animateTo(1f, tween(420, easing = FastOutSlowInEasing)) }
    this.graphicsLayer { alpha = a.value; translationY = (1f - a.value) * 42f; scaleX = 0.96f + 0.04f * a.value; scaleY = scaleX }
}

/** Effet « respiration » (bouton flottant). */
fun Modifier.breathe(): Modifier = composed {
    if (!motionEnabled()) return@composed this
    val s by rememberInfiniteTransition(label = "br").animateFloat(1f, 1.06f, infiniteRepeatable(tween(1400, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "s")
    this.graphicsLayer { scaleX = s; scaleY = s }
}

/** Squelette lumineux pendant le chargement. */
@Composable
fun Shimmer(modifier: Modifier, shape: Shape = RoundedCornerShape(18.dp)) {
    val x by rememberInfiniteTransition(label = "sh").animateFloat(-400f, 1400f, infiniteRepeatable(tween(1300, easing = LinearEasing)), label = "x")
    Box(modifier.clip(shape).background(Brush.linearGradient(listOf(Lux.Surface, Lux.Surface2, Lux.Surface), start = Offset(x, 0f), end = Offset(x + 400f, 200f))))
}

/** Nombre qui défile jusqu'à sa nouvelle valeur. */
@Composable
fun AnimatedNumber(value: Double, format: (Double) -> String, style: TextStyle, color: Color, modifier: Modifier = Modifier) {
    val v by animateFloatAsState(value.toFloat(), tween(if (motionEnabled()) 650 else 0, easing = FastOutSlowInEasing), label = "num")
    Text(format(v.toDouble()), style = style, color = color, modifier = modifier)
}

/** Explosion de confettis (envoi réussi, commande prête). */
@Composable
fun Confetti(modifier: Modifier = Modifier.fillMaxSize(), pieces: Int = 90, onEnd: () -> Unit = {}) {
    val colors = listOf(Lux.Gold, Lux.GoldLight, Color(0xFF2DD4BF), Color(0xFFF472B6), Color(0xFFFBBF24), Color(0xFF4ADE80))
    val parts = remember { List(pieces) { Triple(Random.nextFloat() * 6.283f, 0.4f + Random.nextFloat(), Random.nextInt(colors.size)) } }
    val p = remember { Animatable(0f) }
    LaunchedEffect(Unit) { p.animateTo(1f, tween(1700, easing = LinearEasing)); onEnd() }
    Canvas(modifier) {
        val c = Offset(size.width / 2, size.height * 0.42f)
        val t = p.value
        parts.forEachIndexed { i, (ang, sp, ci) ->
            val dist = size.minDimension * 0.55f * sp * (1 - (1 - t) * (1 - t))
            val pos = Offset(c.x + cos(ang) * dist, c.y + sin(ang) * dist + 900f * t * t * 0.6f)
            rotate(t * 720f * sp + i * 17f, pos) {
                drawRect(colors[ci].copy(alpha = (1f - t).coerceIn(0f, 1f)), topLeft = Offset(pos.x - 6f, pos.y - 3f), size = Size(12f, 6f))
            }
        }
    }
}
