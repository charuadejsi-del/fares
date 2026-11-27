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

// ---------- Palette « Nuit & Or » (identique aux sites) ----------
// Bleu nuit profond, or pour l'action ; le violet reste réservé aux graphiques.
object Lux {
    val Gold = Color(0xFFF2C94C)
    val GoldLight = Color(0xFFF7DC8A)
    val GoldDeep = Color(0xFFDCA414)
    val Night = Color(0xFF090B11)
    val Night2 = Color(0xFF0C0F17)
    val Surface = Color(0xFF11141D)
    val Surface2 = Color(0xFF171B26)
    val Ivory = Color(0xFFEEF0F5)
    val Muted = Color(0xFF8E95A8)
    val Danger = Color(0xFFF05A5A)
    val Success = Color(0xFF34D399)
    val Chart = Color(0xFF7C6CF0)
    /** Texte / icône posé sur l'accent (or) : sombre pour rester lisible. */
    val OnAccent = Color(0xFF17120A)

    val goldBrush = Brush.linearGradient(listOf(Color(0xFFF7D45E), Color(0xFFE6B325), Color(0xFFD99F10)))
    val nightBrush = Brush.verticalGradient(listOf(Color(0xFF14182A), Night2, Night))
}

private val DarkLux = darkColorScheme(
    primary = Lux.Gold,
    onPrimary = Lux.OnAccent,
    primaryContainer = Color(0xFF2A2410),
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
    surfaceContainerHighest = Color(0xFF1E2330),
    surfaceContainerLow = Lux.Night2,
    outline = Color(0xFF272D3E),
    outlineVariant = Color(0xFF1B2030),
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
