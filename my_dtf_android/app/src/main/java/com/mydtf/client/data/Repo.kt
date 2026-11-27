package com.mydtf.client.data

import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order as SortOrder
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import io.github.jan.supabase.storage.Storage
import io.github.jan.supabase.storage.storage
import io.ktor.http.ContentType
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.merge
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlin.time.Duration.Companion.hours

object Supa {
    private const val URL = "https://pxifieuohgthtqkwasug.supabase.co"
    // Clé publique « anon » : sans danger côté client, la sécurité est assurée par RLS.
    private const val ANON_KEY =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB4aWZpZXVvaGd0aHRxa3dhc3VnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxMzI3NDUsImV4cCI6MjEwODcwODc0NX0.pXYktWDzEcjzcwEFspJnul1zzdSkmiWlMra2ukQkG8k"
    const val BUCKET = "dtf-images"

    val client by lazy {
        createSupabaseClient(supabaseUrl = URL, supabaseKey = ANON_KEY) {
            install(Auth)
            install(Postgrest)
            install(Storage)
            install(Realtime)
        }
    }
}

class ImageUpload(
    val fileName: String,
    val bytes: ByteArray,
    val mime: String,
    val widthCm: Double,
    val heightCm: Double,
    val quantity: Int,
)

data class ShipInfo(
    val name: String,
    val phone: String,
    val wilaya: String? = null,
    val commune: String? = null,
    val address: String? = null,
)

object Repo {
    private val sb get() = Supa.client

    val uid: String? get() = sb.auth.currentUserOrNull()?.id

    // ---------------- Compte ----------------

    /** @return true si une session est ouverte, false si l'e-mail doit être confirmé. */
    suspend fun signUp(email: String, password: String, p: NewProfileInput): Boolean {
        sb.auth.signUpWith(Email) {
            this.email = email
            this.password = password
            data = buildJsonObject {
                put("dtf", buildJsonObject {
                    put("full_name", p.fullName)
                    put("phone", p.phone)
                    put("wilaya", p.wilaya)
                    put("commune", p.commune)
                    put("address", p.address)
                })
            }
        }
        val logged = sb.auth.currentSessionOrNull() != null
        if (logged) ensureProfile()
        return logged
    }

    suspend fun signIn(email: String, password: String) {
        sb.auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
        val p = ensureProfile()
        if (p != null && p.role != "client") {
            sb.auth.signOut()
            throw IllegalStateException(STAFF_ONLY)
        }
    }

    const val STAFF_ONLY = "هذا الحساب خاص بفريق الورشة، ادخل من موقع الإدارة mydtf-admin.pages.dev"

    suspend fun signOut() = sb.auth.signOut()

    suspend fun myProfile(): Profile? {
        val id = uid ?: return null
        return sb.from("dtf_profiles").select { filter { eq("id", id) } }.decodeSingleOrNull<Profile>()
    }

    /** Crée le profil client depuis les métadonnées d'inscription s'il n'existe pas encore. */
    suspend fun ensureProfile(): Profile? {
        myProfile()?.let { return it }
        val user = sb.auth.currentUserOrNull() ?: return null
        val meta = user.userMetadata?.get("dtf")?.jsonObject ?: return null
        fun s(k: String) = meta[k]?.jsonPrimitive?.contentOrNull
        sb.from("dtf_profiles").insert(
            NewProfile(user.id, "client", s("full_name") ?: "", s("phone") ?: "", s("wilaya"), s("commune"), s("address"))
        )
        return myProfile()
    }

    suspend fun updateProfile(fullName: String, phone: String, wilaya: String?, commune: String?, address: String?) {
        val id = uid ?: return
        sb.from("dtf_profiles").update({
            set("full_name", fullName)
            set("phone", phone)
            set("wilaya", wilaya)
            set("commune", commune)
            set("address", address)
        }) { filter { eq("id", id) } }
    }

    // ---------------- Paramètres ----------------
    suspend fun settings(): Settings = sb.from("dtf_settings").select().decodeSingle()

    // ---------------- Commandes ----------------
    suspend fun myOrders(): List<Order> {
        val id = uid ?: return emptyList()
        return sb.from("dtf_orders").select {
            filter { eq("client_id", id) }
            order("created_at", SortOrder.DESCENDING)
        }.decodeList()
    }

    suspend fun order(id: String): Order? =
        sb.from("dtf_orders").select { filter { eq("id", id) } }.decodeSingleOrNull()

    suspend fun orderEvents(id: String): List<OrderEvent> =
        sb.from("dtf_order_events").select {
            filter { eq("order_id", id) }
            order("created_at", SortOrder.ASCENDING)
        }.decodeList()

    suspend fun orderImages(id: String): List<OrderImage> =
        sb.from("dtf_order_images").select { filter { eq("order_id", id) } }.decodeList()

    suspend fun signedUrl(path: String): String =
        sb.storage.from(Supa.BUCKET).createSignedUrl(path, 1.hours)

    /** Crée la commande (prix recalculé côté serveur) puis envoie les images. */
    suspend fun createOrder(
        estimatedLengthCm: Double,
        deliveryMode: String,
        ship: ShipInfo,
        note: String?,
        images: List<ImageUpload>,
        onProgress: (done: Int, total: Int) -> Unit,
    ): Order {
        val params: JsonObject = buildJsonObject {
            put("p_estimated_length_cm", estimatedLengthCm)
            put("p_delivery_mode", deliveryMode)
            put("p_delivery_fee", 0.0) // calculé par le transporteur (phase 5)
            put("p_ship_name", ship.name)
            put("p_ship_phone", ship.phone)
            put("p_ship_wilaya", ship.wilaya)
            put("p_ship_commune", ship.commune)
            put("p_ship_address", ship.address)
            put("p_note", note)
        }
        val order = sb.postgrest.rpc("dtf_create_order", params).decodeAs<Order>()
        val me = uid!!
        images.forEachIndexed { i, img ->
            val safe = img.fileName.replace(Regex("[^A-Za-z0-9._-]"), "_")
            val path = "$me/${order.id}/${i + 1}_$safe"
            sb.storage.from(Supa.BUCKET).upload(path, img.bytes) {
                upsert = true
                contentType = ContentType.parse(img.mime)
            }
            val thumb = makeThumb(img.bytes)?.let { t ->
                val tp = "$me/${order.id}/thumb_${i + 1}.webp"
                runCatching {
                    sb.storage.from(Supa.BUCKET).upload(tp, t) { upsert = true; contentType = ContentType.parse("image/webp") }
                    tp
                }.getOrNull()
            }
            sb.from("dtf_order_images").insert(NewOrderImage(order.id, path, img.widthCm, img.heightCm, img.quantity, thumb))
            onProgress(i + 1, images.size)
        }
        return order
    }

    suspend fun rateOrder(orderId: String, stars: Int, comment: String) {
        sb.postgrest.rpc("dtf_rate_order", buildJsonObject {
            put("p_order", orderId); put("p_stars", stars); put("p_comment", comment)
        })
    }

    suspend fun myRating(orderId: String): Rating? =
        sb.from("dtf_ratings").select { filter { eq("order_id", orderId) } }.decodeList<Rating>().firstOrNull()

    suspend fun reportIssue(orderId: String, text: String) {
        sb.postgrest.rpc("dtf_report_issue", buildJsonObject {
            put("p_order", orderId)
            put("p_description", text)
        })
    }

    /** Compte existant sans profil DTF (ex. ancien compte) : on le complète. */
    suspend fun createProfile(p: NewProfileInput) {
        val id = uid ?: return
        sb.from("dtf_profiles").insert(NewProfile(id, "client", p.fullName, p.phone, p.wilaya, p.commune, p.address))
    }

    /** Octets d'une image déjà envoyée (pour « refaire la commande »). */
    suspend fun downloadImage(path: String): ByteArray =
        sb.storage.from(Supa.BUCKET).downloadAuthenticated(path)

    // ---------------- Chat ----------------
    suspend fun messages(): List<ChatMessage> {
        val id = uid ?: return emptyList()
        return sb.from("dtf_messages").select {
            filter { eq("client_id", id) }
            order("created_at", SortOrder.ASCENDING)
            limit(500)
        }.decodeList()
    }

    suspend fun sendMessage(body: String, orderId: String?) {
        val id = uid ?: return
        sb.from("dtf_messages").insert(NewChatMessage(id, id, false, orderId, body))
    }

    suspend fun markChatRead() {
        sb.postgrest.rpc("dtf_chat_mark_read", buildJsonObject { })
    }

    // ---------------- Notifications ----------------
    suspend fun notifications(): List<AppNotification> {
        val id = uid ?: return emptyList()
        return sb.from("dtf_notifications").select {
            filter { eq("user_id", id) }
            order("created_at", SortOrder.DESCENDING)
            limit(100)
        }.decodeList()
    }

    suspend fun markRead(id: Long) {
        sb.from("dtf_notifications").update({ set("read", true) }) { filter { eq("id", id) } }
    }

    suspend fun markAllRead() {
        val me = uid ?: return
        sb.from("dtf_notifications").update({ set("read", true) }) {
            filter { eq("user_id", me); eq("read", false) }
        }
    }

    // ---------------- Temps réel ----------------
    /** Émet à chaque changement sur les commandes ou notifications visibles (RLS). */
    suspend fun liveChanges(): Flow<PostgresAction> {
        val ch = sb.channel("dtf-live-${uid ?: "anon"}-${System.currentTimeMillis()}")
        val orders = ch.postgresChangeFlow<PostgresAction>(schema = "public") { table = "dtf_orders" }
        val notifs = ch.postgresChangeFlow<PostgresAction>(schema = "public") { table = "dtf_notifications" }
        val msgs = ch.postgresChangeFlow<PostgresAction>(schema = "public") { table = "dtf_messages" }
        val shop = ch.postgresChangeFlow<PostgresAction>(schema = "public") { table = "dtf_settings" }
        ch.subscribe()
        return merge(orders, notifs, msgs, shop)
    }

    suspend fun stopLive() {
        runCatching { sb.realtime.removeAllChannels() }
    }
}

/** Miniature 400 px (WebP, transparence conservée) pour un affichage rapide côté atelier. */
fun makeThumb(bytes: ByteArray, max: Int = 400): ByteArray? = runCatching {
    val bounds = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
    android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
    var sample = 1
    while (bounds.outWidth / (sample * 2) >= max && bounds.outHeight / (sample * 2) >= max) sample *= 2
    val bmp = android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size,
        android.graphics.BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
    val scale = minOf(1f, max.toFloat() / maxOf(bmp.width, bmp.height))
    val small = if (scale < 1f) android.graphics.Bitmap.createScaledBitmap(bmp, (bmp.width * scale).toInt().coerceAtLeast(1), (bmp.height * scale).toInt().coerceAtLeast(1), true) else bmp
    val out = java.io.ByteArrayOutputStream()
    @Suppress("DEPRECATION")
    val fmt = if (android.os.Build.VERSION.SDK_INT >= 30) android.graphics.Bitmap.CompressFormat.WEBP_LOSSY else android.graphics.Bitmap.CompressFormat.WEBP
    small.compress(fmt, 78, out)
    out.toByteArray()
}.getOrNull()

data class NewProfileInput(
    val fullName: String,
    val phone: String,
    val wilaya: String?,
    val commune: String?,
    val address: String?,
)

/** Traduit les erreurs fréquentes en arabe. */
fun friendlyError(e: Throwable): String {
    val m = e.message ?: return "حدث خطأ غير متوقع"
    return when {
        m.contains("Invalid login credentials", true) -> "البريد أو كلمة السر غير صحيحة"
        m.contains("Email not confirmed", true) -> "أكّد بريدك الإلكتروني أولاً (تحقق من رسائلك)"
        m.contains("already registered", true) || m.contains("already been registered", true) -> "هذا البريد مسجّل من قبل"
        m.contains("Password should be", true) -> "كلمة السر قصيرة (6 أحرف على الأقل)"
        m.contains("Unable to resolve host", true) || m.contains("timeout", true) || m.contains("Failed to connect", true) ->
            "لا يوجد اتصال بالإنترنت"
        m.contains("Compte client requis") -> "هذا الحساب خاص بالورشة، استعمل حساب زبون"
        else -> m.lineSequence().first().take(160)
    }
}
