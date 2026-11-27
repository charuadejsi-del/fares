package com.mydtf.client.ui

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Brush
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.HourglassTop
import androidx.compose.material.icons.rounded.Inventory2
import androidx.compose.material.icons.rounded.LocalShipping
import androidx.compose.material.icons.rounded.MarkEmailRead
import androidx.compose.material.icons.rounded.Print
import androidx.compose.material.icons.rounded.Storefront
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

data class StatusInfo(val label: String, val color: Color, val icon: ImageVector)

fun statusInfo(s: String): StatusInfo = when (s) {
    "new" -> StatusInfo("مستلمة", Color(0xFF6FA8FF), Icons.Rounded.MarkEmailRead)
    "in_design" -> StatusInfo("في التصميم", Color(0xFFB98CFF), Icons.Rounded.Brush)
    "ready_to_print" -> StatusInfo("تنتظر الطباعة", Color(0xFFFFB25C), Icons.Rounded.HourglassTop)
    "printing" -> StatusInfo("في الطباعة", Color(0xFFFF8C42), Icons.Rounded.Print)
    "printed" -> StatusInfo("انتهت الطباعة", Color(0xFF4FD1C5), Icons.Rounded.Inventory2)
    "ready_pickup" -> StatusInfo("جاهزة للاستلام", Color(0xFF4FD1C5), Icons.Rounded.Storefront)
    "shipped" -> StatusInfo("في التوصيل", Color(0xFF7C8CFF), Icons.Rounded.LocalShipping)
    "delivered" -> StatusInfo("مُسلّمة", Color(0xFF5FC48A), Icons.Rounded.CheckCircle)
    "rejected" -> StatusInfo("مرفوضة", Color(0xFFE5675F), Icons.Rounded.Cancel)
    "cancelled" -> StatusInfo("ملغاة", Color(0xFFE5675F), Icons.Rounded.Cancel)
    else -> StatusInfo(s, Color.Gray, Icons.Rounded.HourglassTop)
}

val deliverySteps = listOf("new", "in_design", "ready_to_print", "printing", "printed", "shipped", "delivered")
val pickupSteps = listOf("new", "in_design", "ready_to_print", "printing", "ready_pickup", "delivered")

fun stepsFor(mode: String) = if (mode == "pickup") pickupSteps else deliverySteps

val deliveryLabels = mapOf(
    "pickup" to "استلام من الورشة",
    "home" to "توصيل إلى المنزل",
    "stopdesk" to "مكتب شركة التوصيل",
)

private val dateFmt = DateTimeFormatter.ofPattern("dd/MM/yyyy · HH:mm")

fun formatDate(iso: String): String = runCatching {
    OffsetDateTime.parse(iso).atZoneSameInstant(ZoneId.systemDefault()).format(dateFmt)
}.getOrDefault(iso.take(16).replace('T', ' '))

fun meters(v: Double) = String.format(java.util.Locale.US, "%.2f م", v)
