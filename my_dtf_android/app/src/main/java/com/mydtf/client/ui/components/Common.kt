package com.mydtf.client.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.material.icons.rounded.Check
import androidx.compose.animation.togetherWith
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mydtf.client.ui.statusInfo
import com.mydtf.client.ui.theme.Lux

/** Carte « luxe » : surface sombre, liseré doré discret. */
@Composable
fun LuxCard(
    modifier: Modifier = Modifier,
    highlight: Boolean = false,
    onClick: (() -> Unit)? = null,
    padding: PaddingValues = PaddingValues(18.dp),
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(22.dp)
    val border = if (highlight) BorderStroke(1.2.dp, Lux.goldBrush)
    else BorderStroke(1.dp, Lux.Gold.copy(alpha = 0.16f))
    Surface(
        modifier = modifier.then(if (onClick != null) Modifier.bouncyClick(pressedScale = 0.97f, onClick = onClick) else Modifier),
        shape = shape,
        color = MaterialTheme.colorScheme.surface,
        border = border,
        tonalElevation = 0.dp,
    ) {
        Column(Modifier.padding(padding), content = content)
    }
}

/** Bouton principal en dégradé or, avec léger effet d'enfoncement. */
@Composable
fun GoldButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
    icon: ImageVector? = null,
    height: Dp = 56.dp,
    success: Boolean = false,
    shine: Boolean = true,
) {
    val active = enabled && !loading && !success
    val glow by animateFloatAsState(if (active) 1f else 0f, tween(300), label = "glow")
    Box(
        modifier = modifier
            .height(height)
            .bouncyClick(enabled = active, onClick = onClick)
            .graphicsLayer { shadowElevation = 18f * glow; shape = RoundedCornerShape(18.dp); clip = false; ambientShadowColor = Lux.GoldDeep; spotShadowColor = Lux.GoldDeep }
            .clip(RoundedCornerShape(18.dp))
            .background(
                when {
                    success -> Brush.linearGradient(listOf(Color(0xFF34D399), Color(0xFF10B981)))
                    active || loading -> Lux.goldBrush
                    else -> Brush.linearGradient(listOf(Color(0xFF2A2B33), Color(0xFF22232A)))
                }
            )
            .shine(enabled = shine && active),
        contentAlignment = Alignment.Center,
    ) {
        androidx.compose.animation.AnimatedContent(
            targetState = if (success) 2 else if (loading) 1 else 0,
            transitionSpec = { (androidx.compose.animation.scaleIn(initialScale = 0.6f) + androidx.compose.animation.fadeIn()) togetherWith androidx.compose.animation.fadeOut() },
            label = "btn",
        ) { st ->
        if (st == 2) {
            Icon(androidx.compose.material.icons.Icons.Rounded.Check, null, tint = Color.White, modifier = Modifier.size(28.dp))
        } else if (st == 1) {
            CircularProgressIndicator(Modifier.size(24.dp), color = Lux.OnAccent, strokeWidth = 2.5.dp)
        } else Row(verticalAlignment = Alignment.CenterVertically) {
            if (icon != null) {
                Icon(icon, null, tint = if (active) Lux.OnAccent else Lux.Muted)
                Spacer(Modifier.width(8.dp))
            }
            Text(
                text,
                style = MaterialTheme.typography.labelLarge,
                color = if (active) Lux.OnAccent else Lux.Muted,
                fontWeight = FontWeight.ExtraBold,
            )
        }
        }
    }
}

/** Bouton secondaire : contour doré. */
@Composable
fun GhostButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, icon: ImageVector? = null, enabled: Boolean = true) {
    Row(
        modifier = modifier
            .height(52.dp)
            .clip(RoundedCornerShape(16.dp))
            .bouncyClick(enabled = enabled, onClick = onClick)
            .clip(RoundedCornerShape(16.dp))
            .border(1.dp, Lux.Gold.copy(alpha = if (enabled) 0.6f else 0.2f), RoundedCornerShape(16.dp))
            .padding(horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        if (icon != null) {
            Icon(icon, null, tint = Lux.Gold)
            Spacer(Modifier.width(8.dp))
        }
        Text(text, color = Lux.Gold, style = MaterialTheme.typography.labelLarge)
    }
}

@Composable
fun LuxField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    leading: ImageVector? = null,
    keyboard: KeyboardType = KeyboardType.Text,
    isError: Boolean = false,
    supporting: String? = null,
    singleLine: Boolean = true,
    minLines: Int = 1,
    visual: VisualTransformation = VisualTransformation.None,
    trailing: @Composable (() -> Unit)? = null,
    readOnly: Boolean = false,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier.fillMaxWidth(),
        label = { Text(label, maxLines = 1) },
        leadingIcon = leading?.let { { Icon(it, null, tint = Lux.Gold.copy(alpha = 0.85f)) } },
        trailingIcon = trailing,
        singleLine = singleLine,
        minLines = minLines,
        isError = isError,
        readOnly = readOnly,
        visualTransformation = visual,
        supportingText = supporting?.let { { Text(it) } },
        keyboardOptions = KeyboardOptions(keyboardType = keyboard),
        shape = RoundedCornerShape(16.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = Lux.Gold,
            unfocusedBorderColor = MaterialTheme.colorScheme.outline,
            focusedLabelColor = Lux.Gold,
            cursorColor = Lux.Gold,
            focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerLow,
            unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainerLow,
        ),
    )
}

@Composable
fun StatusChip(status: String, modifier: Modifier = Modifier) {
    val info = statusInfo(status)
    Row(
        modifier
            .clip(CircleShape)
            .background(info.color.copy(alpha = 0.14f))
            .border(1.dp, info.color.copy(alpha = 0.45f), CircleShape)
            .padding(horizontal = 10.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(info.icon, null, tint = info.color, modifier = Modifier.size(15.dp))
        Spacer(Modifier.width(5.dp))
        Text(info.label, color = info.color, style = MaterialTheme.typography.labelMedium)
    }
}

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier, trailing: @Composable RowScope.() -> Unit = {}) {
    Row(modifier.fillMaxWidth().padding(top = 8.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(width = 4.dp, height = 18.dp).clip(CircleShape).background(Lux.goldBrush))
        Spacer(Modifier.width(8.dp))
        Text(text, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
        trailing()
    }
}

@Composable
fun GoldIconBadge(icon: ImageVector, size: Dp = 44.dp) {
    Box(
        Modifier.size(size).clip(CircleShape).background(Lux.goldBrush),
        contentAlignment = Alignment.Center,
    ) { Icon(icon, null, tint = Lux.OnAccent, modifier = Modifier.size(size * 0.5f)) }
}

@Composable
fun KeyValue(label: String, value: String, strong: Boolean = false, valueColor: Color? = null) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
        Text(
            value,
            style = if (strong) MaterialTheme.typography.titleLarge else MaterialTheme.typography.titleSmall,
            color = valueColor ?: if (strong) Lux.Gold else MaterialTheme.colorScheme.onSurface,
        )
    }
}

@Composable
fun EmptyState(icon: ImageVector, title: String, subtitle: String, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            Modifier.size(96.dp).clip(CircleShape).background(Lux.Gold.copy(alpha = 0.08f))
                .border(1.dp, Lux.Gold.copy(alpha = 0.3f), CircleShape),
            contentAlignment = Alignment.Center,
        ) { Icon(icon, null, tint = Lux.Gold, modifier = Modifier.size(44.dp)) }
        Spacer(Modifier.height(16.dp))
        Text(title, style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(6.dp))
        Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
