package com.mydtf.client.ui.order

import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AddPhotoAlternate
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Link
import androidx.compose.material.icons.rounded.LinkOff
import androidx.compose.material.icons.rounded.LocalShipping
import androidx.compose.material.icons.rounded.Notes
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Phone
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Send
import androidx.compose.material.icons.rounded.Storefront
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.mydtf.client.ui.MainViewModel
import com.mydtf.client.ui.components.CommunePicker
import com.mydtf.client.ui.components.FilmPreview
import com.mydtf.client.ui.components.GhostButton
import com.mydtf.client.ui.components.GoldButton
import com.mydtf.client.ui.components.KeyValue
import com.mydtf.client.ui.components.LuxCard
import com.mydtf.client.ui.components.LuxField
import com.mydtf.client.ui.components.SectionTitle
import com.mydtf.client.ui.components.WilayaPicker
import com.mydtf.client.ui.components.previewPalette
import com.mydtf.client.ui.deliveryLabels
import com.mydtf.client.ui.meters
import com.mydtf.client.ui.theme.Lux
import com.mydtf.core.formatDa

private val stepTitles = listOf("الصور", "المعاينة", "الاستلام", "التأكيد")

@Composable
fun NewOrderScreen(main: MainViewModel, onClose: () -> Unit, onCreated: (String) -> Unit, fromOrder: String? = null) {
    val vm: NewOrderViewModel = viewModel()
    val context = LocalContext.current
    LaunchedEffect(main.settings, main.profile) {
        if (vm.settings == null) vm.settings = main.settings
        vm.prefill(main.profile)
        if (main.settings == null) main.reloadSettings()
    }
    LaunchedEffect(vm.created) { vm.created?.let { onCreated(it.id) } }
    LaunchedEffect(fromOrder) { fromOrder?.let { vm.loadFrom(context, it) } }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(30)) { uris ->
        vm.addImages(context, uris)
    }
    fun pick() = picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))

    BackHandler(enabled = vm.step > 0 && !vm.sending) { vm.step-- }

    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        // ---------- Barre du haut + étapes ----------
        Column(
            Modifier.fillMaxWidth().background(Lux.nightBrush)
                .statusBarsPadding()
                .padding(top = 8.dp, bottom = 14.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(horizontal = 6.dp)) {
                IconButton(onClick = { if (vm.step > 0 && !vm.sending) vm.step-- else if (!vm.sending) onClose() }) {
                    Icon(Icons.AutoMirrored.Rounded.ArrowBack, "رجوع", tint = Lux.Ivory)
                }
                Text("طلبية جديدة", style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
                if (!vm.sending) IconButton(onClick = onClose) { Icon(Icons.Rounded.Close, "إغلاق", tint = Lux.Muted) }
            }
            StepHeader(vm.step) { target -> if (target < vm.step && !vm.sending) vm.step = target }
        }

        // ---------- Contenu ----------
        AnimatedContent(
            vm.step,
            modifier = Modifier.weight(1f),
            transitionSpec = {
                val dir = if (targetState > initialState) -1 else 1 // RTL : on avance vers la gauche
                slideInHorizontally { it * dir } togetherWith slideOutHorizontally { -it * dir }
            },
            label = "step",
        ) { step ->
            when (step) {
                0 -> ImagesStep(vm, ::pick)
                1 -> PreviewStep(vm)
                2 -> DeliveryStep(vm)
                else -> ConfirmStep(vm)
            }
        }

        // ---------- Barre du bas : devis en direct + action ----------
        Surface(color = MaterialTheme.colorScheme.surface, border = BorderStroke(1.dp, Lux.Gold.copy(alpha = 0.18f)), shape = RoundedCornerShape(topStart = 26.dp, topEnd = 26.dp)) {
            Column(Modifier.navigationBarsPadding().imePadding().padding(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        val q = vm.quote
                        Text(
                            if (q != null) "${meters(q.billedMeters)} · ${vm.copies} نسخة" else "أضف صورك ومقاساتها",
                            style = MaterialTheme.typography.bodySmall, color = Lux.Muted,
                        )
                        Text(
                            if (q != null) formatDa(q.printAmount) else "—",
                            style = MaterialTheme.typography.headlineSmall, color = Lux.Gold,
                        )
                    }
                    if (vm.step < 3) {
                        GoldButton(
                            if (vm.step == 2) "مراجعة" else "التالي",
                            onClick = { vm.step++ },
                            enabled = vm.stepValid(vm.step) && !vm.importing,
                            modifier = Modifier.width(150.dp),
                        )
                    } else {
                        GoldButton(
                            "تأكيد الإرسال",
                            onClick = vm::send,
                            loading = vm.sending,
                            icon = Icons.Rounded.Send,
                            modifier = Modifier.width(190.dp),
                        )
                    }
                }
                if (vm.step == 3 && main.settings?.isOpen == false) {
                    com.mydtf.client.ui.components.ShopStatus(main.settings, Modifier.padding(top = 8.dp), detail = "الورشة مغلقة الآن، ستُعالَج طلبيتك عند الفتح")
                }
                vm.progress?.let { Text(it, color = Lux.GoldLight, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 6.dp)) }
                vm.error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 6.dp)) }
            }
        }
    }
}

@Composable
private fun StepHeader(current: Int, onTap: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        stepTitles.forEachIndexed { i, t ->
            val done = i < current
            val now = i == current
            Column(Modifier.weight(1f).clickable(enabled = done) { onTap(i) }, horizontalAlignment = Alignment.CenterHorizontally) {
                Box(
                    Modifier.size(30.dp).clip(CircleShape)
                        .background(if (done || now) Lux.goldBrush else androidx.compose.ui.graphics.SolidColor(Lux.Surface2)),
                    contentAlignment = Alignment.Center,
                ) {
                    if (done) Icon(Icons.Rounded.CheckCircle, null, tint = Lux.Night, modifier = Modifier.size(18.dp))
                    else Text("${i + 1}", color = if (now) Lux.Night else Lux.Muted, fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.height(4.dp))
                Text(t, style = MaterialTheme.typography.labelSmall, color = if (now) Lux.GoldLight else Lux.Muted)
            }
        }
    }
}

// =====================================================================
// Étape 1 : images et mesures
// =====================================================================
@Composable
private fun ImagesStep(vm: NewOrderViewModel, pick: () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        Text(
            "ارفع صورك واكتب مقاس كل صورة بالسنتيمتر وعدد النسخ. القفل 🔗 يحافظ على أبعاد الصورة تلقائياً.",
            style = MaterialTheme.typography.bodyMedium, color = Lux.Muted,
        )
        Spacer(Modifier.height(12.dp))
        vm.images.forEachIndexed { i, img -> ImageCard(i, img, onRemove = { vm.remove(img) }) }
        // zone d'ajout
        Box(
            Modifier.fillMaxWidth().height(if (vm.images.isEmpty()) 190.dp else 84.dp)
                .clip(RoundedCornerShape(22.dp))
                .background(Lux.Gold.copy(alpha = 0.05f))
                .border(1.5.dp, Lux.Gold.copy(alpha = 0.45f), RoundedCornerShape(22.dp))
                .clickable(enabled = !vm.importing, onClick = pick),
            contentAlignment = Alignment.Center,
        ) {
            if (vm.importing) CircularProgressIndicator(color = Lux.Gold)
            else Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Rounded.AddPhotoAlternate, null, tint = Lux.Gold, modifier = Modifier.size(if (vm.images.isEmpty()) 52.dp else 28.dp))
                Text(if (vm.images.isEmpty()) "اختر صورك من المعرض" else "إضافة صور أخرى", color = Lux.Gold, style = MaterialTheme.typography.titleSmall)
                if (vm.images.isEmpty()) Text("PNG بخلفية شفافة أفضل للطباعة", color = Lux.Muted, style = MaterialTheme.typography.bodySmall)
            }
        }
        vm.nestState.error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(top = 10.dp)) }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun ImageCard(index: Int, img: PickedImage, onRemove: () -> Unit) {
    val color = previewPalette[index % previewPalette.size]
    LuxCard(Modifier.fillMaxWidth().padding(bottom = 12.dp), padding = PaddingValues(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box {
                AsyncImage(
                    model = img.uri, contentDescription = null, contentScale = ContentScale.Fit,
                    modifier = Modifier.size(74.dp).clip(RoundedCornerShape(14.dp)).background(Color(0xFF0E0E13)),
                )
                Box(
                    Modifier.align(Alignment.TopStart).padding(4.dp).size(24.dp).clip(CircleShape).background(color),
                    contentAlignment = Alignment.Center,
                ) { Text("${index + 1}", color = Lux.Night, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelMedium) }
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(img.name, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleSmall)
                if (img.pxW > 0) Text(com.mydtf.core.ltr("${img.pxW} × ${img.pxH} px"), style = MaterialTheme.typography.bodySmall, color = Lux.Muted)
            }
            IconButton(onClick = onRemove) { Icon(Icons.Rounded.DeleteOutline, "حذف", tint = Lux.Muted) }
        }
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            NumberBox("العرض (سم)", img.width, img::updateWidth, Modifier.weight(1f))
            IconButton(onClick = { img.lockRatio = !img.lockRatio }, enabled = img.pxW > 0, modifier = Modifier.padding(bottom = 4.dp)) {
                Icon(if (img.lockRatio) Icons.Rounded.Link else Icons.Rounded.LinkOff, "قفل الأبعاد",
                    tint = if (img.lockRatio) Lux.Gold else Lux.Muted)
            }
            NumberBox("الطول (سم)", img.height, img::updateHeight, Modifier.weight(1f))
        }
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("عدد النسخ", style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f))
            Stepper(img.qty, onChange = { img.qty = it })
        }
    }
}

@Composable
private fun NumberBox(label: String, value: String, onChange: (String) -> Unit, modifier: Modifier = Modifier) {
    Column(modifier) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = Lux.Muted, modifier = Modifier.padding(start = 4.dp, bottom = 4.dp))
        OutlinedTextField(
            value = value, onValueChange = onChange, singleLine = true,
            placeholder = { Text("0", color = Lux.Muted) },
            textStyle = MaterialTheme.typography.titleMedium.copy(textAlign = TextAlign.Center),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            shape = RoundedCornerShape(14.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Lux.Gold, cursorColor = Lux.Gold,
                focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerLow,
                unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainerLow,
            ),
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun Stepper(value: String, onChange: (String) -> Unit) {
    val n = value.toIntOrNull() ?: 0
    Row(
        Modifier.clip(RoundedCornerShape(14.dp)).border(1.dp, Lux.Gold.copy(alpha = 0.35f), RoundedCornerShape(14.dp)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = { if (n > 1) onChange("${n - 1}") }) { Icon(Icons.Rounded.Remove, "ناقص", tint = Lux.Gold) }
        OutlinedTextField(
            value = value,
            onValueChange = { v -> onChange(v.filter { it.isDigit() }.take(4)) },
            singleLine = true,
            textStyle = MaterialTheme.typography.titleMedium.copy(textAlign = TextAlign.Center),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Color.Transparent, unfocusedBorderColor = Color.Transparent, cursorColor = Lux.Gold,
            ),
            modifier = Modifier.width(76.dp),
        )
        IconButton(onClick = { onChange("${n + 1}") }) { Icon(Icons.Rounded.Add, "زائد", tint = Lux.Gold) }
    }
}

// =====================================================================
// Étape 2 : aperçu du film
// =====================================================================
@Composable
private fun PreviewStep(vm: NewOrderViewModel) {
    val r = vm.nestState.result
    val indexOf = vm.images.mapIndexed { i, it -> it.id to i }.toMap()
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        if (r == null) { Text("أكمل مقاسات الصور أولاً", color = Lux.Muted); return@Column }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.TouchApp, null, tint = Lux.Muted, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
            Text("كبّر بإصبعين واسحب لتتصفّح الفيلم", style = MaterialTheme.typography.bodySmall, color = Lux.Muted)
        }
        Spacer(Modifier.height(8.dp))
        FilmPreview(
            result = r,
            colorOf = { id -> previewPalette[(indexOf[id] ?: 0) % previewPalette.size] },
            labelOf = { id -> "${(indexOf[id] ?: 0) + 1}" },
            height = 420.dp,
        )
        Spacer(Modifier.height(14.dp))
        LuxCard(Modifier.fillMaxWidth(), highlight = true) {
            KeyValue("الطول المستعمل", com.mydtf.core.ltr(String.format(java.util.Locale.US, "%.1f", r.lengthCm)) + " سم")
            vm.quote?.let { q ->
                KeyValue("الأمتار المحسوبة", meters(q.billedMeters))
                KeyValue("نسبة استغلال الفيلم", com.mydtf.core.ltr("${(r.fillRatio * 100).toInt()}%"))
                KeyValue("سعر الطباعة", formatDa(q.printAmount), strong = true)
            }
            vm.settings?.let { s ->
                if (s.minOrderAmount > 0) Text("الحد الأدنى للطلبية: ${formatDa(s.minOrderAmount)}", style = MaterialTheme.typography.bodySmall, color = Lux.Muted)
            }
        }
        Spacer(Modifier.height(10.dp))
        SectionTitle("الصور")
        vm.images.forEachIndexed { i, img ->
            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(14.dp).clip(CircleShape).background(previewPalette[i % previewPalette.size]))
                Spacer(Modifier.width(10.dp))
                Text("${i + 1}. " + com.mydtf.client.ui.sizeCm(img.width, img.height), modifier = Modifier.weight(1f))
                Text(com.mydtf.core.ltr("× ${img.qty}"), color = Lux.Gold)
            }
        }
        Spacer(Modifier.height(10.dp))
        Text(
            "هذا ترتيب تقديري. المصمّم يرتّب الصور نهائياً، وإن تغيّر عدد الأمتار تصلك رسالة بالسعر النهائي.",
            style = MaterialTheme.typography.bodySmall, color = Lux.Muted,
        )
        Spacer(Modifier.height(20.dp))
    }
}

// =====================================================================
// Étape 3 : retrait ou livraison
// =====================================================================
@Composable
private fun DeliveryStep(vm: NewOrderViewModel) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionTitle("طريقة الاستلام")
        ModeCard("pickup", Icons.Rounded.Storefront, "مجاناً — تستلمها من الورشة", vm)
        ModeCard("home", Icons.Rounded.Home, "يوصلها لك عامل التوصيل إلى بابك", vm)
        ModeCard("stopdesk", Icons.Rounded.LocalShipping, "تستلمها من مكتب شركة التوصيل في ولايتك", vm)
        if (vm.mode == "pickup") {
            vm.settings?.workshopAddress?.let { Text("عنوان الورشة: $it", color = Lux.GoldLight) }
        }
        AnimatedVisibility(vm.mode != "pickup") {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionTitle("معلومات المستلم")
                LuxField(vm.name, { vm.name = it }, "اسم المستلم", leading = Icons.Rounded.Person)
                LuxField(vm.phone, { vm.phone = it.filter { c -> c.isDigit() || c == ' ' }.take(12) }, "هاتف المستلم",
                    leading = Icons.Rounded.Phone, keyboard = KeyboardType.Phone)
                WilayaPicker(vm.wilaya, { vm.wilaya = it; vm.commune = null })
                CommunePicker(vm.wilaya, vm.commune, { vm.commune = it })
                if (vm.mode == "home") LuxField(vm.address, { vm.address = it }, "العنوان الكامل", leading = Icons.Rounded.Home)
                Text("سعر التوصيل يُحسب حسب الولاية وشركة التوصيل.", style = MaterialTheme.typography.bodySmall, color = Lux.Muted)
            }
        }
        LuxField(vm.note, { vm.note = it }, "ملاحظة للورشة (اختياري)", leading = Icons.Rounded.Notes, singleLine = false, minLines = 2)
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun ModeCard(mode: String, icon: androidx.compose.ui.graphics.vector.ImageVector, desc: String, vm: NewOrderViewModel) {
    val sel = vm.mode == mode
    LuxCard(Modifier.fillMaxWidth(), highlight = sel, onClick = { vm.mode = mode }, padding = PaddingValues(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(46.dp).clip(RoundedCornerShape(14.dp))
                    .background(if (sel) Lux.goldBrush else androidx.compose.ui.graphics.SolidColor(Lux.Gold.copy(alpha = 0.08f))),
                contentAlignment = Alignment.Center,
            ) { Icon(icon, null, tint = if (sel) Lux.Night else Lux.Gold) }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(deliveryLabels[mode]!!, style = MaterialTheme.typography.titleMedium)
                Text(desc, style = MaterialTheme.typography.bodySmall, color = Lux.Muted)
            }
            if (sel) Icon(Icons.Rounded.CheckCircle, null, tint = Lux.Gold)
        }
    }
}

// =====================================================================
// Étape 4 : récapitulatif
// =====================================================================
@Composable
private fun ConfirmStep(vm: NewOrderViewModel) {
    val q = vm.quote
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionTitle("ملخّص الطلبية")
        LuxCard(Modifier.fillMaxWidth(), highlight = true) {
            KeyValue("عدد الصور", "${vm.images.size}")
            KeyValue("عدد النسخ", "${vm.copies}")
            q?.let {
                KeyValue("الأمتار التقديرية", meters(it.billedMeters))
                KeyValue("سعر الطباعة", formatDa(it.printAmount), strong = true)
            }
        }
        LuxCard(Modifier.fillMaxWidth()) {
            KeyValue("الاستلام", deliveryLabels[vm.mode]!!)
            if (vm.mode != "pickup") {
                KeyValue("المستلم", vm.name)
                KeyValue("الهاتف", vm.phone)
                KeyValue("الولاية", vm.wilaya?.let { "${it.code} - ${it.ar}" } ?: "")
                KeyValue("البلدية", vm.commune?.ar ?: "")
                if (vm.mode == "home") KeyValue("العنوان", vm.address)
                KeyValue("التوصيل", "يُضاف حسب الشركة")
            }
            if (vm.note.isNotBlank()) KeyValue("ملاحظة", vm.note)
        }
        Text(
            "بالضغط على «تأكيد الإرسال» تصل طلبيتك إلى الورشة مباشرة، وتتابع مراحلها من التطبيق.",
            style = MaterialTheme.typography.bodySmall, color = Lux.Muted,
        )
        Spacer(Modifier.height(16.dp))
    }
}
