package com.mydtf.client.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mydtf.client.ui.theme.Lux
import com.mydtf.client.ui.theme.Tajawal
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay

/**
 * Intro animée : la feuille de film apparaît, les 4 images se posent une à une
 * (comme l'imbrication), une tête d'impression balaie le tout, puis le nom s'affiche.
 */
@Composable
fun Intro(subtitle: String = "طباعة DTF", onDone: () -> Unit) {
    val anim = motionEnabled()
    val sheet = remember { Animatable(0f) }
    val tiles = remember { List(4) { Animatable(0f) } }
    val head = remember { Animatable(0f) }
    val title = remember { Animatable(0f) }
    val out = remember { Animatable(1f) }
    LaunchedEffect(Unit) {
        if (!anim) { onDone(); return@LaunchedEffect }
        sheet.animateTo(1f, spring(dampingRatio = 0.55f, stiffness = Spring.StiffnessLow))
        coroutineScope {
            tiles.mapIndexed { i, a -> async { delay(i * 110L); a.animateTo(1f, spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMediumLow)) } }.awaitAll()
        }
        coroutineScope {
            listOf(async { head.animateTo(1f, tween(520, easing = FastOutSlowInEasing)) }, async { delay(180); title.animateTo(1f, tween(420)) }).awaitAll()
        }
        delay(260)
        out.animateTo(0f, tween(260))
        onDone()
    }
    Box(Modifier.fillMaxSize().background(Lux.nightBrush).graphicsLayer { alpha = out.value }, contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Canvas(Modifier.size(150.dp).graphicsLayer { scaleX = 0.6f + 0.4f * sheet.value; scaleY = scaleX; alpha = sheet.value.coerceIn(0f, 1f) }) {
                val u = size.width / 108f
                // halo
                drawCircle(Brush.radialGradient(listOf(Color(0x558B5CF6), Color.Transparent)), radius = size.width * 0.62f)
                // feuille
                drawRoundRect(Lux.goldBrush, Offset(33 * u, 30 * u), Size(42 * u, 48 * u), CornerRadius(4 * u))
                // les 4 « images » posées sur la feuille (cases sombres)
                val rects = listOf(floatArrayOf(37f, 35f, 15f, 15f), floatArrayOf(55f, 35f, 16f, 10f), floatArrayOf(55f, 48f, 16f, 25f), floatArrayOf(37f, 53f, 15f, 20f))
                rects.forEachIndexed { i, r ->
                    val t = tiles[i].value
                    val dy = (1f - t) * -26f * u
                    drawRoundRect(Lux.Night.copy(alpha = t.coerceIn(0f, 1f)), Offset(r[0] * u, r[1] * u + dy), Size(r[2] * u * (0.7f + 0.3f * t), r[3] * u * (0.7f + 0.3f * t)), CornerRadius(1.5f * u))
                }
                // tête d'impression
                if (head.value in 0.01f..0.99f) {
                    val x = (28 + head.value * 52) * u
                    drawRect(Brush.verticalGradient(listOf(Color.Transparent, Color.White.copy(alpha = 0.85f), Color.Transparent)), Offset(x, 24 * u), Size(2.2f * u, 60 * u))
                    drawRect(Color(0x33FFFFFF), Offset(33 * u, 30 * u), Size(x - 33 * u, 48 * u))
                }
            }
            Spacer(Modifier.height(18.dp))
            Text("My DTF", fontFamily = Tajawal, fontWeight = FontWeight.ExtraBold, fontSize = 34.sp, color = Lux.Ivory,
                modifier = Modifier.graphicsLayer { alpha = title.value; translationY = (1 - title.value) * 30f })
            Text(subtitle, fontFamily = Tajawal, fontSize = 15.sp, color = Lux.GoldLight,
                modifier = Modifier.graphicsLayer { alpha = title.value; translationY = (1 - title.value) * 40f })
        }
    }
}
