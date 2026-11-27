package com.mydtf.client.ui.order

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.OpenableColumns
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mydtf.client.data.ImageUpload
import com.mydtf.client.data.Order
import com.mydtf.client.data.Profile
import com.mydtf.client.data.Repo
import com.mydtf.client.data.Settings
import com.mydtf.client.data.ShipInfo
import com.mydtf.client.data.friendlyError
import com.mydtf.core.Algeria
import com.mydtf.core.Commune
import com.mydtf.core.ItemTooWideException
import com.mydtf.core.NestItem
import com.mydtf.core.NestResult
import com.mydtf.core.NestingEngine
import com.mydtf.core.PricingSettings
import com.mydtf.core.Quote
import com.mydtf.core.Wilaya
import com.mydtf.core.computeQuote
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale
import kotlin.math.roundToInt

class PickedImage(
    val id: String,
    val uri: Uri,
    val name: String,
    val mime: String,
    val bytes: ByteArray,
    val pxW: Int,
    val pxH: Int,
) {
    var width by mutableStateOf("")
    var height by mutableStateOf("")
    var qty by mutableStateOf("1")
    var lockRatio by mutableStateOf(pxW > 0 && pxH > 0)

    val w: Double? get() = width.replace(',', '.').toDoubleOrNull()
    val h: Double? get() = height.replace(',', '.').toDoubleOrNull()
    val q: Int? get() = qty.toIntOrNull()
    val valid: Boolean get() = (w ?: 0.0) > 0 && (h ?: 0.0) > 0 && (q ?: 0) > 0

    fun updateWidth(v: String) {
        width = clean(v)
        if (lockRatio) w?.let { height = fmt(it * pxH / pxW) }
    }

    fun updateHeight(v: String) {
        height = clean(v)
        if (lockRatio) h?.let { width = fmt(it * pxW / pxH) }
    }

    private fun clean(v: String) = v.filter { it.isDigit() || it == '.' || it == ',' }.take(6)
    private fun fmt(d: Double): String {
        val r = (d * 10).roundToInt() / 10.0
        return if (r % 1.0 == 0.0) r.toInt().toString() else String.format(Locale.US, "%.1f", r)
    }
}

class NewOrderViewModel : ViewModel() {
    val images = mutableStateListOf<PickedImage>()
    private var seq = 0

    var step by mutableStateOf(0)
    var mode by mutableStateOf("pickup")
    var name by mutableStateOf("")
    var phone by mutableStateOf("")
    var wilaya by mutableStateOf<Wilaya?>(null)
    var commune by mutableStateOf<Commune?>(null)
    var address by mutableStateOf("")
    var note by mutableStateOf("")

    var importing by mutableStateOf(false); private set
    var sending by mutableStateOf(false); private set
    var progress by mutableStateOf<String?>(null); private set
    var error by mutableStateOf<String?>(null)
    var created by mutableStateOf<Order?>(null); private set

    var settings by mutableStateOf<Settings?>(null)
    private var prefilled = false

    var special by mutableStateOf<Double?>(null)
    val pricing: PricingSettings? get() = settings?.let { s -> PricingSettings(s.pricePerMeter, s.minOrderAmount, s.meterRoundingStep, s.priceTiers.map { it.minM to it.price }, special) }
    fun prefill(p: Profile?) {
        if (prefilled || p == null) return
        prefilled = true
        special = p.specialPrice
        name = p.fullName
        phone = p.phone
        wilaya = Algeria.wilayaByName(p.wilaya)
        commune = Algeria.communeByName(wilaya, p.commune)
        address = p.address.orEmpty()
    }

    /** Frais de livraison (tarifs de la société, recalculés aussi par le serveur) ; null = inconnu. */
    val deliveryFee: Int? get() = when (mode) { "pickup" -> 0; "stopdesk" -> wilaya?.desk; else -> wilaya?.home }
    /** Pas de bureau dans la wilaya choisie → le retrait au stop desk est impossible. */
    val deskUnavailable: Boolean get() = Algeria.isLive && wilaya != null && wilaya?.hasDesk == false
    fun chooseMode(m: String) {
        if (m == "stopdesk" && deskUnavailable) return
        mode = m
        if (m == "stopdesk" && commune?.desk == false) commune = null
    }

    /** Lecture des images choisies (octets + dimensions en pixels) hors du thread UI. */
    fun addImages(context: Context, uris: List<Uri>) {
        if (uris.isEmpty()) return
        importing = true
        viewModelScope.launch {
            val picked = withContext(Dispatchers.IO) {
                uris.mapNotNull { uri ->
                    runCatching {
                        val cr = context.contentResolver
                        val bytes = cr.openInputStream(uri)!!.use { it.readBytes() }
                        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
                        var display = "image.jpg"
                        cr.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                            if (c.moveToFirst()) display = c.getString(0) ?: display
                        }
                        val mime = cr.getType(uri) ?: "image/jpeg"
                        PickedImage("img${++seq}", uri, display, mime, bytes, opts.outWidth, opts.outHeight)
                    }.getOrNull()
                }
            }
            images.addAll(picked)
            importing = false
        }
    }

    fun remove(img: PickedImage) { images.remove(img) }

    private var reordered = false

    /** « Refaire la même commande » : recharge les images et mesures d'une ancienne commande. */
    fun loadFrom(context: Context, orderId: String) {
        if (reordered) return
        reordered = true
        importing = true
        viewModelScope.launch {
            try {
                val rows = Repo.orderImages(orderId)
                val picked = withContext(Dispatchers.IO) {
                    rows.mapIndexed { i, r ->
                        val bytes = Repo.downloadImage(r.storagePath)
                        val name = r.storagePath.substringAfterLast('/').substringAfter('_')
                        val f = java.io.File(context.cacheDir, "reorder_${i}_$name").apply { writeBytes(bytes) }
                        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
                        val mime = if (name.lowercase().endsWith(".png")) "image/png" else "image/jpeg"
                        PickedImage("img${++seq}", Uri.fromFile(f), name, mime, bytes, opts.outWidth, opts.outHeight).apply {
                            lockRatio = false
                            width = fmtNum(r.widthCm); height = fmtNum(r.heightCm); qty = r.quantity.toString()
                            lockRatio = pxW > 0
                        }
                    }
                }
                images.addAll(picked)
            } catch (e: Exception) {
                error = friendlyError(e)
            } finally { importing = false }
        }
    }

    private fun fmtNum(d: Double) = if (d % 1.0 == 0.0) d.toInt().toString() else d.toString()

    val nestState by derivedStateOf {
        val s = settings ?: return@derivedStateOf NestOutcome(null, null)
        val items = images.filter { it.valid }.map { NestItem(it.id, it.w!!, it.h!!, it.q!!) }
        try {
            val r = NestingEngine(s.filmWidthCm, s.gapCm, s.allowRotation).nest(items)
            NestOutcome(r, null)
        } catch (e: ItemTooWideException) {
            val idx = images.indexOfFirst { it.id == e.itemId } + 1
            NestOutcome(null, "الصورة رقم $idx أعرض من الفيلم (${s.filmWidthCm.toInt()} سم) حتى بعد تدويرها")
        }
    }

    val quote: Quote? by derivedStateOf {
        val s = settings ?: return@derivedStateOf null
        val r = nestState.result ?: return@derivedStateOf null
        if (r.placements.isEmpty()) null
        else computeQuote(r.lengthCm, PricingSettings(s.pricePerMeter, s.minOrderAmount, s.meterRoundingStep, s.priceTiers.map { it.minM to it.price }, special))
    }

    val copies: Int get() = images.sumOf { if (it.valid) it.q!! else 0 }

    fun stepValid(i: Int): Boolean = when (i) {
        0 -> images.isNotEmpty() && images.all { it.valid } && nestState.error == null && nestState.result != null
        1 -> quote != null
        2 -> mode == "pickup" || (
            name.isNotBlank() && phone.replace(" ", "").length >= 9 && wilaya != null && commune != null &&
                !(mode == "stopdesk" && (deskUnavailable || commune?.desk == false)) &&
                (mode == "stopdesk" || address.isNotBlank())
            )
        else -> true
    }

    fun send() {
        val r = nestState.result ?: return
        sending = true; error = null
        progress = "إنشاء الطلبية..."
        viewModelScope.launch {
            try {
                val ship = if (mode == "pickup") ShipInfo(name.trim(), phone.replace(" ", ""))
                else ShipInfo(name.trim(), phone.replace(" ", ""), wilaya?.fr, commune?.fr, address.trim().ifEmpty { null })
                created = Repo.createOrder(
                    estimatedLengthCm = r.lengthCm,
                    deliveryMode = mode,
                    ship = ship,
                    note = note.trim().ifEmpty { null },
                    images = images.map { ImageUpload(it.name, it.bytes, it.mime, it.w!!, it.h!!, it.q!!) },
                ) { done, total -> progress = "رفع الصور $done / $total" }
            } catch (e: Exception) {
                error = friendlyError(e)
            } finally {
                sending = false
                progress = null
            }
        }
    }
}

data class NestOutcome(val result: NestResult?, val error: String?)
