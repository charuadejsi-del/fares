package com.mydtf.client.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material.icons.rounded.LocationCity
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.runtime.LaunchedEffect
import com.mydtf.core.Algeria
import com.mydtf.core.Commune
import com.mydtf.core.Wilaya
import com.mydtf.client.ui.theme.Lux

/**
 * Champ de sélection avec recherche instantanée dans une feuille en bas d'écran.
 * La recherche ignore accents, majuscules et variantes d'alef.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun <T> SearchPickerField(
    label: String,
    value: String?,
    icon: ImageVector,
    sheetTitle: String,
    search: (String) -> List<T>,
    itemTitle: (T) -> String,
    itemSubtitle: (T) -> String?,
    itemBadge: ((T) -> String)? = null,
    isSelected: (T) -> Boolean,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    placeholderWhenDisabled: String? = null,
) {
    var open by rememberSaveable { mutableStateOf(false) }
    Box(modifier.fillMaxWidth()) {
        LuxField(
            value = value ?: "",
            onValueChange = {},
            label = if (!enabled && placeholderWhenDisabled != null) placeholderWhenDisabled else label,
            leading = icon,
            readOnly = true,
            trailing = { Icon(Icons.Rounded.ExpandMore, null) },
        )
        // couche cliquable au-dessus du champ en lecture seule
        Box(
            Modifier.matchParentSize().clip(RoundedCornerShape(16.dp))
                .clickable(
                    enabled = enabled,
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) { open = true },
        )
    }
    if (open) {
        val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(
            onDismissRequest = { open = false },
            sheetState = sheet,
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
        ) {
            var q by remember { mutableStateOf("") }
            val results = remember(q) { search(q) }
            val focus = remember { FocusRequester() }
            LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
            Column(Modifier.fillMaxWidth().fillMaxHeight(0.9f).imePadding()) {
                Row(Modifier.padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(sheetTitle, style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
                    Text("${results.size}", color = Lux.Gold, style = MaterialTheme.typography.labelLarge)
                }
                Spacer(Modifier.height(10.dp))
                Box(Modifier.padding(horizontal = 16.dp)) {
                    LuxField(
                        value = q,
                        onValueChange = { q = it },
                        label = "ابحث بالعربية أو الفرنسية أو بالرقم",
                        leading = Icons.Rounded.Search,
                        modifier = Modifier.focusRequester(focus),
                        trailing = if (q.isNotEmpty()) {
                            { IconButton(onClick = { q = "" }) { Icon(Icons.Rounded.Close, null) } }
                        } else null,
                    )
                }
                Spacer(Modifier.height(8.dp))
                if (results.isEmpty()) {
                    Text(
                        "لا توجد نتيجة لـ «$q»",
                        modifier = Modifier.padding(24.dp),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                LazyColumn(Modifier.fillMaxWidth()) {
                    items(results) { item ->
                        val selected = isSelected(item)
                        Row(
                            Modifier.fillMaxWidth()
                                .clickable { onSelect(item); open = false }
                                .background(if (selected) Lux.Gold.copy(alpha = 0.10f) else MaterialTheme.colorScheme.surfaceContainerLow)
                                .padding(horizontal = 20.dp, vertical = 14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            if (itemBadge != null) {
                                Box(
                                    Modifier.size(38.dp).clip(RoundedCornerShape(10.dp))
                                        .background(Lux.Gold.copy(alpha = if (selected) 0.9f else 0.12f)),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Text(
                                        itemBadge(item),
                                        color = if (selected) Lux.OnAccent else Lux.Gold,
                                        fontWeight = FontWeight.Bold,
                                        style = MaterialTheme.typography.labelLarge,
                                    )
                                }
                                Spacer(Modifier.width(14.dp))
                            }
                            Column(Modifier.weight(1f)) {
                                Text(itemTitle(item), style = MaterialTheme.typography.titleSmall)
                                itemSubtitle(item)?.let {
                                    Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                            if (selected) Icon(Icons.Rounded.Check, null, tint = Lux.Gold)
                        }
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                    }
                }
            }
        }
    }
}

/** Montant arrondi avec espace des milliers : « 1 500 دج ». */
private fun dzd(v: Int) = v.toString().reversed().chunked(3).joinToString("\u202F").reversed() + " دج"

@Composable
fun WilayaPicker(selected: Wilaya?, onSelect: (Wilaya) -> Unit, modifier: Modifier = Modifier) {
    SearchPickerField(
        label = "الولاية",
        value = selected?.let { "${it.code} - ${it.ar} · ${it.fr}" },
        icon = Icons.Rounded.Map,
        sheetTitle = if (Algeria.isLive) "الولايات التي تصلها شركة التوصيل" else "اختر الولاية",
        search = { Algeria.searchWilayas(it) },
        itemTitle = { it.ar + "  ·  " + it.fr },
        itemSubtitle = { w ->
            if (!Algeria.isLive) null
            else listOfNotNull(w.desk?.let { "المكتب ${dzd(it)}" }, w.home?.let { "المنزل ${dzd(it)}" }).joinToString(" · ")
                .ifEmpty { null }?.let { it + if (w.hasDesk) "" else " — منزل فقط" }
        },
        itemBadge = { it.code },
        isSelected = { it.c == selected?.c },
        onSelect = onSelect,
        modifier = modifier,
    )
}

/** [deskOnly] : seulement les communes où la société a un bureau (retrait au stop desk). */
@Composable
fun CommunePicker(wilaya: Wilaya?, selected: Commune?, onSelect: (Commune) -> Unit, modifier: Modifier = Modifier, deskOnly: Boolean = false) {
    SearchPickerField(
        label = if (deskOnly) "مكتب الاستلام (البلدية)" else "البلدية",
        value = selected?.let { "${it.ar} · ${it.fr}" },
        icon = Icons.Rounded.LocationCity,
        sheetTitle = (if (deskOnly) "مكاتب " else "بلديات ") + (wilaya?.ar ?: ""),
        search = { q -> wilaya?.let { w -> Algeria.searchCommunes(w.c, q).filter { !deskOnly || it.desk != false } } ?: emptyList() },
        itemTitle = { it.ar },
        itemSubtitle = { c -> c.fr + when (c.desk) { true -> "  ·  فيها مكتب"; false -> "  ·  منزل فقط"; null -> "" } },
        isSelected = { c -> selected?.let { s -> c.fr == s.fr && c.w == s.w } ?: false },
        onSelect = onSelect,
        modifier = modifier,
        enabled = wilaya != null,
        placeholderWhenDisabled = "اختر الولاية أولاً",
    )
}
