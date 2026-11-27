package com.mydtf.client.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CenterFocusStrong
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mydtf.client.ui.theme.Lux
import com.mydtf.core.NestResult

val previewPalette = listOf(
    Color(0xFFD4AF37), Color(0xFF4FD1C5), Color(0xFFB98CFF), Color(0xFFFF8C42), Color(0xFF6FA8FF),
    Color(0xFFFF6B9A), Color(0xFF5FC48A), Color(0xFFE5675F), Color(0xFF9CDCFE), Color(0xFFC6A27A),
)

/**
 * Aperçu du film dans un cadre fixe : pincer pour zoomer, glisser pour parcourir.
 * Règles graduées (tous les 10 cm) en haut et à gauche. Rien ne déborde du cadre.
 */
@Composable
fun FilmPreview(
    result: NestResult,
    colorOf: (String) -> Color,
    labelOf: (String) -> String,
    modifier: Modifier = Modifier,
    height: Dp = 400.dp,
) {
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    var zoom by remember(result) { mutableFloatStateOf(1f) }
    var offset by remember(result) { mutableStateOf(Offset.Zero) }

    BoxWithConstraints(
        modifier
            .fillMaxWidth()
            .height(height)
            .clip(RoundedCornerShape(20.dp))
            .background(Color(0xFF07070A))
            .border(1.dp, Lux.Gold.copy(alpha = 0.25f), RoundedCornerShape(20.dp))
            .clipToBounds(),
    ) {
        val boxW = with(density) { maxWidth.toPx() }
        val boxH = with(density) { maxHeight.toPx() }
        val ruler = with(density) { 22.dp.toPx() }
        val drawW = boxW - ruler
        val base = drawW / result.filmWidthCm.toFloat()
        val filmH = (result.lengthCm.toFloat() * base).coerceAtLeast(1f)

        fun clamp(o: Offset, z: Float): Offset {
            val cw = drawW * z
            val ch = filmH * z
            val minX = minOf(0f, drawW - cw)
            val minY = minOf(0f, (boxH - ruler) - ch)
            return Offset(o.x.coerceIn(minX, 0f), o.y.coerceIn(minY, 0f))
        }

        Canvas(
            Modifier.fillMaxSize().pointerInput(result) {
                detectTransformGestures { _, pan, z, _ ->
                    val nz = (zoom * z).coerceIn(1f, 6f)
                    zoom = nz
                    offset = clamp(offset + pan, nz)
                }
            },
        ) {
            val s = base * zoom
            // ---- zone film (décalée par les règles) ----
            translate(ruler + offset.x, ruler + offset.y) {
                // fond du film + quadrillage 5 cm
                drawRect(Color(0xFF15151C), size = Size(result.filmWidthCm.toFloat() * s, result.lengthCm.toFloat() * s))
                val grid = Color.White.copy(alpha = 0.04f)
                var gx = 0f
                while (gx <= result.filmWidthCm) {
                    drawLine(grid, Offset(gx * s, 0f), Offset(gx * s, result.lengthCm.toFloat() * s))
                    gx += 5f
                }
                var gy = 0f
                while (gy <= result.lengthCm) {
                    drawLine(grid, Offset(0f, gy * s), Offset(result.filmWidthCm.toFloat() * s, gy * s))
                    gy += 5f
                }
                // images
                for (p in result.placements) {
                    val c = colorOf(p.itemId)
                    val tl = Offset(p.x.toFloat() * s, p.y.toFloat() * s)
                    val sz = Size(p.width.toFloat() * s, p.height.toFloat() * s)
                    drawRoundRect(c.copy(alpha = 0.78f), tl, sz, CornerRadius(3f * zoom, 3f * zoom))
                    drawRoundRect(Color.Black.copy(alpha = 0.55f), tl, sz, CornerRadius(3f * zoom, 3f * zoom), style = Stroke(1.2f))
                    if (sz.width > 18f && sz.height > 14f) {
                        val txt = measurer.measure(
                            labelOf(p.itemId),
                            TextStyle(fontSize = (11 * zoom.coerceAtMost(2.5f)).sp, fontWeight = FontWeight.Bold, color = Color.Black.copy(alpha = 0.8f)),
                        )
                        drawText(txt, topLeft = Offset(tl.x + (sz.width - txt.size.width) / 2, tl.y + (sz.height - txt.size.height) / 2))
                    }
                }
                // bords du film
                drawRect(Lux.Gold.copy(alpha = 0.6f), size = Size(result.filmWidthCm.toFloat() * s, result.lengthCm.toFloat() * s), style = Stroke(1.5f))
            }
            // ---- règles ----
            drawRect(Color(0xFF0E0E13), size = Size(size.width, ruler))
            drawRect(Color(0xFF0E0E13), size = Size(ruler, size.height))
            val tick = Lux.Gold.copy(alpha = 0.7f)
            val labelStyle = TextStyle(fontSize = 8.sp, color = Lux.Muted)
            var cm = 0
            while (cm <= result.filmWidthCm) {
                val x = ruler + offset.x + cm * s
                if (x >= ruler - 1 && x <= size.width) {
                    val major = cm % 10 == 0
                    drawLine(tick, Offset(x, ruler), Offset(x, ruler - if (major) ruler * 0.55f else ruler * 0.25f))
                    if (major && cm > 0) drawText(measurer.measure("$cm", labelStyle), topLeft = Offset(x + 2, 1f))
                }
                cm += if (s > 6) 1 else 5
            }
            cm = 0
            while (cm <= result.lengthCm) {
                val y = ruler + offset.y + cm * s
                if (y >= ruler - 1 && y <= size.height) {
                    val major = cm % 10 == 0
                    drawLine(tick, Offset(ruler, y), Offset(ruler - if (major) ruler * 0.55f else ruler * 0.25f, y))
                    if (major && cm > 0) drawText(measurer.measure("$cm", labelStyle), topLeft = Offset(1f, y + 1))
                }
                cm += if (s > 6) 1 else 5
            }
            drawRect(Lux.Gold, topLeft = Offset.Zero, size = Size(ruler, ruler))
        }

        // badge longueur + bouton recentrer
        Box(
            Modifier.align(Alignment.BottomStart).padding(10.dp)
                .clip(CircleShape).background(Lux.Night.copy(alpha = 0.85f))
                .border(1.dp, Lux.Gold.copy(alpha = 0.5f), CircleShape)
                .padding(horizontal = 12.dp, vertical = 6.dp),
        ) {
            Text(
                com.mydtf.core.ltr(String.format(java.util.Locale.US, "%.0f × %.1f", result.filmWidthCm, result.lengthCm)) + " سم",
                color = Lux.GoldLight, style = MaterialTheme.typography.labelMedium,
            )
        }
        if (zoom > 1.01f || offset != Offset.Zero) {
            IconButton(
                onClick = { zoom = 1f; offset = Offset.Zero },
                modifier = Modifier.align(Alignment.BottomEnd).padding(6.dp)
                    .clip(CircleShape).background(Lux.Night.copy(alpha = 0.85f)),
            ) { Icon(Icons.Rounded.CenterFocusStrong, "إعادة الضبط", tint = Lux.Gold) }
        }
    }
}
