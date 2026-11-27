package com.mydtf.client.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mydtf.client.R

// ---------- Palette « Charbon & Violet » (identique aux sites) ----------
// Les noms Gold* sont conservés : ils désignent désormais l'accent violet.
object Lux {
    val Gold = Color(0xFFA78BFA)
    val GoldLight = Color(0xFFC4B5FD)
    val GoldDeep = Color(0xFF7C4DEB)
    val Night = Color(0xFF0B0C0F)
    val Night2 = Color(0xFF101116)
    val Surface = Color(0xFF15161B)
    val Surface2 = Color(0xFF1C1D24)
    val Ivory = Color(0xFFF2F2F3)
    val Muted = Color(0xFF9A9CA6)
    val Danger = Color(0xFFF87171)
    val Success = Color(0xFF4ADE80)
    /** Texte / icône posé sur l'accent. */
    val OnAccent = Color.White

    val goldBrush = Brush.linearGradient(listOf(Color(0xFFB794FF), Color(0xFF8B5CF6), Color(0xFF7C4DEB)))
    val nightBrush = Brush.verticalGradient(listOf(Color(0xFF15131F), Night2, Night))
}

private val DarkLux = darkColorScheme(
    primary = Lux.Gold,
    onPrimary = Lux.OnAccent,
    primaryContainer = Color(0xFF2A2045),
    onPrimaryContainer = Lux.GoldLight,
    secondary = Lux.GoldLight,
    onSecondary = Lux.OnAccent,
    background = Lux.Night,
    onBackground = Lux.Ivory,
    surface = Lux.Surface,
    onSurface = Lux.Ivory,
    surfaceVariant = Lux.Surface2,
    onSurfaceVariant = Lux.Muted,
    surfaceContainer = Lux.Surface,
    surfaceContainerHigh = Lux.Surface2,
    surfaceContainerHighest = Color(0xFF23252D),
    surfaceContainerLow = Lux.Night2,
    outline = Color(0xFF2E3039),
    outlineVariant = Color(0xFF23252B),
    error = Lux.Danger,
)

private val LightLux = lightColorScheme(
    primary = Color(0xFF9C7A1C),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFF6E7B8),
    onPrimaryContainer = Color(0xFF3A2C00),
    secondary = Color(0xFFB08D2E),
    background = Color(0xFFFAF7F0),
    onBackground = Color(0xFF1A1A1A),
    surface = Color.White,
    onSurface = Color(0xFF1A1A1A),
    surfaceVariant = Color(0xFFF1ECDF),
    onSurfaceVariant = Color(0xFF6B655A),
    outline = Color(0xFFD9D1BE),
    error = Color(0xFFC0392B),
)

val Tajawal = FontFamily(
    Font(R.font.tajawal_regular, FontWeight.Normal),
    Font(R.font.tajawal_medium, FontWeight.Medium),
    Font(R.font.tajawal_bold, FontWeight.Bold),
    Font(R.font.tajawal_extrabold, FontWeight.ExtraBold),
)

private fun t(size: Int, w: FontWeight = FontWeight.Normal, lh: Int = (size * 1.45).toInt()) =
    TextStyle(fontFamily = Tajawal, fontWeight = w, fontSize = size.sp, lineHeight = lh.sp)

private val LuxTypography = Typography(
    displaySmall = t(34, FontWeight.ExtraBold),
    headlineMedium = t(28, FontWeight.ExtraBold),
    headlineSmall = t(24, FontWeight.Bold),
    titleLarge = t(21, FontWeight.Bold),
    titleMedium = t(17, FontWeight.Bold),
    titleSmall = t(15, FontWeight.Medium),
    bodyLarge = t(16),
    bodyMedium = t(15),
    bodySmall = t(13),
    labelLarge = t(15, FontWeight.Bold),
    labelMedium = t(13, FontWeight.Medium),
    labelSmall = t(12, FontWeight.Medium),
)

private val LuxShapes = Shapes(
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(18.dp),
    large = RoundedCornerShape(26.dp),
    extraLarge = RoundedCornerShape(32.dp),
)

val LocalIsDark = staticCompositionLocalOf { true }

@Composable
fun MyDtfTheme(dark: Boolean = true, content: @Composable () -> Unit) {
    // Le thème « Nuit & Or » est la signature de l'app : sombre par défaut.
    CompositionLocalProvider(
        LocalLayoutDirection provides LayoutDirection.Rtl,
        LocalIsDark provides dark,
    ) {
        MaterialTheme(
            colorScheme = if (dark) DarkLux else LightLux,
            typography = LuxTypography,
            shapes = LuxShapes,
            content = content,
        )
    }
}
