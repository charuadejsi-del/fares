package com.mydtf.pro

import com.mydtf.client.data.Supa
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order as SortOrder
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import io.github.jan.supabase.storage.storage
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.merge
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.time.Duration.Companion.hours

// ---------------- Modèles (équipe) ----------------

@Serializable
data class StaffMe(
    val id: String,
    val role: String,
    @SerialName("full_name") val fullName: String = "",
    val active: Boolean = true,
)

@Serializable
data class StaffLite(val id: String, val role: String, @SerialName("full_name") val fullName: String = "", val active: Boolean = true)

@Serializable
data class PinStatus(
    @SerialName("has_pin") val hasPin: Boolean,
    @SerialName("clocked_in") val clockedIn: Boolean,
    val since: String? = null,
    @SerialName("work_end") val workEnd: String? = null,
)

@Serializable
data class Attendance(@SerialName("clock_in") val clockIn: String? = null, @SerialName("clock_out") val clockOut: String? = null, val minutes: Int? = null)

@Serializable
data class WorkOrder(
    val id: String,
    val code: Long,
    val status: String,
    @SerialName("billed_meters") val billedMeters: Double = 0.0,
    @SerialName("estimated_length_cm") val estimatedLengthCm: Double = 0.0,
    @SerialName("final_length_cm") val finalLengthCm: Double? = null,
    @SerialName("client_note") val clientNote: String? = null,
    @SerialName("delivery_mode") val deliveryMode: String = "pickup",
    @SerialName("designer_id") val designerId: String? = null,
    @SerialName("printer_id") val printerId: String? = null,
    @SerialName("machine_id") val machineId: String? = null,
    @SerialName("print_started_at") val printStartedAt: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
    @SerialName("client_name") val clientName: String? = null,
)

/** Commande complète (gérant / administrateur — prix visibles). */
@Serializable
data class MgrOrder(
    val id: String,
    val code: Long,
    val status: String,
    @SerialName("client_id") val clientId: String,
    @SerialName("billed_meters") val billedMeters: Double = 0.0,
    @SerialName("print_amount") val printAmount: Double = 0.0,
    @SerialName("delivery_fee") val deliveryFee: Double = 0.0,
    @SerialName("delivery_mode") val deliveryMode: String = "pickup",
    @SerialName("estimated_length_cm") val estimatedLengthCm: Double = 0.0,
    @SerialName("client_note") val clientNote: String? = null,
    @SerialName("ship_name") val shipName: String? = null,
    @SerialName("ship_phone") val shipPhone: String? = null,
    @SerialName("ship_wilaya") val shipWilaya: String? = null,
    @SerialName("ship_commune") val shipCommune: String? = null,
    @SerialName("designer_id") val designerId: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
)

@Serializable
data class Img(
    @SerialName("storage_path") val storagePath: String,
    @SerialName("thumb_path") val thumbPath: String? = null,
    @SerialName("width_cm") val widthCm: Double,
    @SerialName("height_cm") val heightCm: Double,
    val quantity: Int,
)

@Serializable
data class Machine(
    val id: String,
    val code: Long = 0,
    val name: String,
    @SerialName("width_cm") val widthCm: Double = 60.0,
    val model: String? = null,
    val status: String = "idle",
    @SerialName("status_note") val statusNote: String? = null,
    @SerialName("status_since") val statusSince: String? = null,
    val active: Boolean = true,
    @SerialName("operator_name") val operatorName: String? = null,
    @SerialName("roll_code") val rollCode: Long? = null,
    @SerialName("roll_remaining") val rollRemaining: Double? = null,
    @SerialName("roll_length") val rollLength: Double? = null,
    @SerialName("alert_m") val alertM: Double? = null,
    @SerialName("job_id") val jobId: String? = null,
    @SerialName("job_code") val jobCode: Long? = null,
    @SerialName("job_meters") val jobMeters: Double? = null,
    @SerialName("job_started") val jobStarted: String? = null,
    @SerialName("meters_today") val metersToday: Double = 0.0,
    @SerialName("waste_today") val wasteToday: Double = 0.0,
    @SerialName("meters_7d") val meters7d: Double = 0.0,
)

@Serializable
data class Conversation(
    @SerialName("client_id") val clientId: String,
    @SerialName("full_name") val fullName: String? = null,
    val phone: String? = null,
    @SerialName("last_at") val lastAt: String? = null,
    @SerialName("last_body") val lastBody: String? = null,
    val unread: Int = 0,
)

@Serializable
data class Msg(
    val id: Long,
    @SerialName("client_id") val clientId: String,
    @SerialName("from_staff") val fromStaff: Boolean,
    val body: String,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class Supply(val kind: String, val stock: Double, val alert: Double)

@Serializable
data class ShopState(@SerialName("is_open") val isOpen: Boolean = true, @SerialName("open_note") val openNote: String? = null, @SerialName("price_per_meter") val pricePerMeter: Double = 1400.0)

// ---------------- Accès aux données ----------------

object Pro {
    private val sb get() = Supa.client
    val uid: String? get() = sb.auth.currentUserOrNull()?.id
    const val NOT_STAFF = "هذا الحساب خاص بالزبائن — استعمل تطبيق My DTF"

    private suspend inline fun <reified T : Any> call(fn: String, args: JsonObject = buildJsonObject { }): T =
        sb.postgrest.rpc(fn, args).decodeAs<T>()
    private suspend fun exec(fn: String, args: JsonObject = buildJsonObject { }) { sb.postgrest.rpc(fn, args) }

    suspend fun signIn(email: String, password: String): StaffMe {
        sb.auth.signInWith(Email) { this.email = email; this.password = password }
        val me = me()
        if (me == null || me.role == "client" || !me.active) { sb.auth.signOut(); throw IllegalStateException(NOT_STAFF) }
        return me
    }
    suspend fun signOut() = runCatching { sb.auth.signOut() }
    suspend fun me(): StaffMe? = uid?.let { id -> sb.from("dtf_profiles").select { filter { eq("id", id) } }.decodeSingleOrNull<StaffMe>() }
    suspend fun staff(): List<StaffLite> = sb.from("dtf_profiles").select { filter { neq("role", "client") } }.decodeList()

    suspend fun pinStatus(): PinStatus = call<List<PinStatus>>("dtf_pin_status").first()
    suspend fun pinSet(pin: String) = exec("dtf_pin_set", buildJsonObject { put("p_new", pin) })
    suspend fun clockIn(pin: String): Attendance = call("dtf_clock_in", buildJsonObject { put("p_pin", pin) })
    suspend fun clockOut(pin: String): Attendance = call("dtf_clock_out", buildJsonObject { put("p_pin", pin) })

    suspend fun workOrders(): List<WorkOrder> = call("dtf_work_orders")
    suspend fun board(): List<Machine> = call("dtf_machine_board")
    suspend fun images(orderId: String): List<Img> = sb.from("dtf_order_images").select { filter { eq("order_id", orderId) } }.decodeList()
    suspend fun signed(paths: List<String>): Map<String, String> =
        paths.distinct().associateWith { runCatching { sb.storage.from(Supa.BUCKET).createSignedUrl(it, 2.hours) }.getOrDefault("") }
    suspend fun download(path: String): ByteArray = sb.storage.from(Supa.BUCKET).downloadAuthenticated(path)

    suspend fun startPrinting(order: String, machine: String?) = exec("dtf_start_printing", buildJsonObject { put("p_order", order); put("p_machine", machine) })
    suspend fun finishPrinting(order: String) = exec("dtf_finish_printing", buildJsonObject { put("p_order", order) })
    suspend fun designDone(order: String, lengthCm: Double) = exec("dtf_design_done", buildJsonObject { put("p_order", order); put("p_final_length_cm", lengthCm) })
    suspend fun waste(meters: Double, note: String?, machine: String) = exec("dtf_record_waste", buildJsonObject { put("p_meters", meters); put("p_note", note); put("p_machine", machine) })
    suspend fun mountRoll(machine: String) = exec("dtf_activate_roll", buildJsonObject { put("p_machine", machine) })
    suspend fun machineStatus(machine: String, status: String, note: String?) =
        exec("dtf_set_machine_status", buildJsonObject { put("p_machine", machine); put("p_status", status); put("p_note", note) })

    suspend fun mgrOrders(): List<MgrOrder> = sb.from("dtf_orders").select {
        filter { isIn("status", listOf("new", "in_design", "ready_to_print", "printing", "printed", "ready_pickup", "shipped")) }
        order("created_at", SortOrder.ASCENDING)
    }.decodeList()
    suspend fun assign(order: String, designer: String) = exec("dtf_assign_designer", buildJsonObject { put("p_order", order); put("p_designer", designer) })
    suspend fun reject(order: String, reason: String) = exec("dtf_reject_order", buildJsonObject { put("p_order", order); put("p_reason", reason) })
    suspend fun shipped(order: String, carrier: String, tracking: String) =
        exec("dtf_mark_shipped", buildJsonObject { put("p_order", order); put("p_carrier", carrier); put("p_tracking", tracking) })
    suspend fun delivered(order: String, paid: Double) = exec("dtf_mark_delivered", buildJsonObject { put("p_order", order); put("p_amount_paid", paid) })
    suspend fun setOpen(open: Boolean, note: String?) = exec("dtf_set_open", buildJsonObject { put("p_open", open); put("p_note", note) })
    suspend fun shop(): ShopState = sb.from("dtf_settings").select { filter { eq("id", 1) } }.decodeSingle()
    suspend fun supplies(): List<Supply> = runCatching { sb.from("dtf_supplies").select().decodeList<Supply>() }.getOrDefault(emptyList())

    suspend fun conversations(): List<Conversation> = sb.from("dtf_conversations").select { order("last_at", SortOrder.DESCENDING) }.decodeList()
    suspend fun messages(client: String): List<Msg> = sb.from("dtf_messages").select {
        filter { eq("client_id", client) }; order("created_at", SortOrder.ASCENDING); limit(300)
    }.decodeList()
    suspend fun reply(client: String, body: String) {
        sb.from("dtf_messages").insert(buildJsonObject { put("client_id", client); put("sender_id", uid); put("from_staff", true); put("body", body) })
    }
    suspend fun markRead(client: String) = runCatching { exec("dtf_chat_mark_read", buildJsonObject { put("p_client", client) }) }

    suspend fun live(): Flow<PostgresAction> {
        val ch = sb.channel("pro-${uid}-${System.currentTimeMillis()}")
        val flows = listOf("dtf_orders", "dtf_machines", "dtf_machine_events", "dtf_settings", "dtf_messages", "dtf_rolls", "dtf_supplies")
            .map { t -> ch.postgresChangeFlow<PostgresAction>(schema = "public") { table = t } }
        ch.subscribe()
        return merge(*flows.toTypedArray())
    }
    suspend fun stopLive() = runCatching { sb.realtime.removeAllChannels() }
}
