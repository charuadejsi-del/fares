package com.mydtf.pro

import com.mydtf.client.data.Supa
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order as SortOrder
import io.ktor.client.statement.bodyAsText
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

// ---------------- Modèles réservés à l'administrateur ----------------
@Serializable
data class Roll(
    val id: String, val code: Long, @SerialName("length_m") val lengthM: Double, @SerialName("remaining_m") val remainingM: Double,
    val status: String, @SerialName("unit_price") val unitPrice: Double = 0.0, val supplier: String? = null,
    @SerialName("machine_id") val machineId: String? = null, @SerialName("purchased_at") val purchasedAt: String? = null,
)

@Serializable
data class FilmMove(val id: Long, val meters: Double, val kind: String, val note: String? = null, @SerialName("created_at") val createdAt: String, @SerialName("actor_id") val actorId: String? = null)

@Serializable
data class SupplyFull(val kind: String, val stock: Double, val alert: Double, @SerialName("avg_price") val avgPrice: Double = 0.0)

@Serializable
data class NameAmount(val name: String, val amount: Double)

@Serializable
data class CostSettings(
    @SerialName("roll_price") val rollPrice: Double, @SerialName("roll_length_m") val rollLengthM: Double,
    @SerialName("ink_price_l") val inkPriceL: Double, @SerialName("ink_ml_per_m") val inkMlPerM: Double,
    @SerialName("powder_price_kg") val powderPriceKg: Double, @SerialName("powder_g_per_m") val powderGPerM: Double,
    @SerialName("work_days") val workDays: Int, val wages: List<NameAmount>, @SerialName("fixed_costs") val fixedCosts: List<NameAmount>,
    @SerialName("waste_in_profit") val wasteInProfit: Boolean = true,
)

@Serializable
data class CostDay(val day: String, val meters: Double, @SerialName("waste_m") val wasteM: Double, val revenue: Double, val value: Double, val orders: Int)

@Serializable
data class StaffStat(
    @SerialName("user_id") val userId: String, @SerialName("full_name") val fullName: String, val role: String, val active: Boolean,
    @SerialName("orders_done") val ordersDone: Int, val meters: Double, @SerialName("avg_minutes") val avgMinutes: Double, val issues: Int,
    @SerialName("days_worked") val daysWorked: Int, @SerialName("hours_worked") val hoursWorked: Double, @SerialName("late_days") val lateDays: Int,
    @SerialName("forgot_out") val forgotOut: Int,
)

@Serializable
data class StaffRating(@SerialName("user_id") val userId: String, @SerialName("avg_stars") val avgStars: Double, val n: Int)

@Serializable
data class AttendanceRow(
    val id: Long, @SerialName("user_id") val userId: String, @SerialName("work_date") val workDate: String,
    @SerialName("clock_in") val clockIn: String, @SerialName("clock_out") val clockOut: String? = null, @SerialName("auto_closed") val autoClosed: Boolean = false,
)

@Serializable
data class TeamMember(val id: String, @SerialName("full_name") val fullName: String = "", val role: String, val active: Boolean = true, val phone: String? = null)

@Serializable
data class FullSettings(
    @SerialName("price_per_meter") val pricePerMeter: Double, @SerialName("min_order_amount") val minOrderAmount: Double,
    @SerialName("meter_rounding_step") val meterRoundingStep: Double, @SerialName("film_width_cm") val filmWidthCm: Double,
    @SerialName("gap_cm") val gapCm: Double, @SerialName("allow_rotation") val allowRotation: Boolean = true,
    @SerialName("workshop_name") val workshopName: String? = null, @SerialName("workshop_phone") val workshopPhone: String? = null,
    @SerialName("workshop_address") val workshopAddress: String? = null, @SerialName("roll_alert_m") val rollAlertM: Double = 20.0,
    @SerialName("work_end_time") val workEndTime: String? = null, @SerialName("price_tiers") val priceTiers: List<com.mydtf.client.data.PriceTier> = emptyList(),
)

@Serializable
data class OrderRating(val stars: Int, val comment: String? = null)

@Serializable
data class ClientInfo(@SerialName("special_price") val specialPrice: Double? = null, @SerialName("full_name") val fullName: String? = null, val phone: String? = null)

object Admin {
    private val sb get() = Supa.client
    private suspend inline fun <reified T : Any> call(fn: String, args: JsonObject = buildJsonObject { }): T = sb.postgrest.rpc(fn, args).decodeAs<T>()
    private suspend fun exec(fn: String, args: JsonObject) { sb.postgrest.rpc(fn, args) }

    // Stock
    suspend fun rolls(): List<Roll> = sb.from("dtf_rolls").select { order("purchased_at", SortOrder.DESCENDING); limit(200) }.decodeList()
    suspend fun filmMoves(): List<FilmMove> = sb.from("dtf_film_moves").select { order("created_at", SortOrder.DESCENDING); limit(60) }.decodeList()
    suspend fun addRolls(count: Int, length: Double, price: Double, supplier: String?) =
        exec("dtf_add_rolls", buildJsonObject { put("p_count", count); put("p_length_m", length); put("p_unit_price", price); put("p_supplier", supplier); put("p_note", null as String?) })
    suspend fun supplies(): List<SupplyFull> = sb.from("dtf_supplies").select { order("kind") }.decodeList()
    suspend fun buySupply(kind: String, qty: Double, total: Double, supplier: String?) =
        exec("dtf_add_supply", buildJsonObject { put("p_kind", kind); put("p_qty", qty); put("p_total", total); put("p_supplier", supplier); put("p_note", null as String?) })
    suspend fun adjustSupply(kind: String, real: Double) = exec("dtf_adjust_supply", buildJsonObject { put("p_kind", kind); put("p_real", real); put("p_note", null as String?) })
    suspend fun supplyAlert(kind: String, alert: Double) = exec("dtf_set_supply_alert", buildJsonObject { put("p_kind", kind); put("p_alert", alert) })

    // Machines
    suspend fun saveMachine(id: String?, name: String, width: Double, model: String?, active: Boolean) =
        exec("dtf_save_machine", buildJsonObject { put("p_id", id); put("p_name", name); put("p_width", width); put("p_model", model); put("p_active", active) })

    // Coûts
    suspend fun costSettings(): CostSettings = sb.from("dtf_cost_settings").select { filter { eq("id", 1) } }.decodeSingle()
    suspend fun saveCosts(c: CostSettings) {
        val j = Json.encodeToJsonElement(CostSettings.serializer(), c).jsonObject
        sb.from("dtf_cost_settings").update(j) { filter { eq("id", 1) } }
    }
    suspend fun costDays(from: String, to: String): List<CostDay> = call("dtf_cost_days2", buildJsonObject { put("p_from", from); put("p_to", to) })

    // Performance / présence
    suspend fun stats(from: String, to: String): List<StaffStat> = call("dtf_staff_stats", buildJsonObject { put("p_from", from); put("p_to", to) })
    suspend fun ratings(from: String, to: String): List<StaffRating> = runCatching { call<List<StaffRating>>("dtf_staff_ratings", buildJsonObject { put("p_from", from); put("p_to", to) }) }.getOrDefault(emptyList())
    suspend fun attendance(from: String): List<AttendanceRow> = sb.from("dtf_attendance").select { filter { gte("work_date", from) }; order("clock_in", SortOrder.DESCENDING) }.decodeList()

    // Équipe
    suspend fun team(): List<TeamMember> = sb.from("dtf_profiles").select { filter { neq("role", "client") }; order("full_name") }.decodeList()
    suspend fun setActive(id: String, active: Boolean) { sb.from("dtf_profiles").update(buildJsonObject { put("active", active) }) { filter { eq("id", id) } } }
    suspend fun resetPin(id: String) = exec("dtf_pin_reset", buildJsonObject { put("p_user", id) })
    suspend fun edge(body: JsonObject) {
        val r = sb.functions.invoke("dtf-admin", body)
        val txt = r.bodyAsText()
        val err = runCatching { Json.parseToJsonElement(txt).jsonObject["error"]?.jsonPrimitive?.contentOrNull }.getOrNull()
        if (err != null) throw IllegalStateException(err)
    }
    suspend fun createStaff(name: String, phone: String, role: String, email: String, password: String) =
        edge(buildJsonObject { put("action", "create_staff"); put("full_name", name); put("phone", phone); put("role", role); put("email", email); put("password", password) })
    suspend fun setPassword(id: String, password: String) = edge(buildJsonObject { put("action", "set_password"); put("user_id", id); put("password", password) })

    // Réglages
    suspend fun settings(): FullSettings = sb.from("dtf_settings").select { filter { eq("id", 1) } }.decodeSingle()
    suspend fun saveSettings(s: FullSettings) {
        val j = Json.encodeToJsonElement(FullSettings.serializer(), s).jsonObject
        sb.from("dtf_settings").update(j) { filter { eq("id", 1) } }
    }

    // Commandes
    suspend fun archive(): List<MgrOrder> = sb.from("dtf_orders").select { filter { isIn("status", listOf("delivered", "rejected", "cancelled")) }; order("updated_at", SortOrder.DESCENDING); limit(80) }.decodeList()
    suspend fun rating(order: String): OrderRating? = runCatching { sb.from("dtf_ratings").select { filter { eq("order_id", order) } }.decodeList<OrderRating>().firstOrNull() }.getOrNull()
    suspend fun client(id: String): ClientInfo? = runCatching { sb.from("dtf_profiles").select { filter { eq("id", id) } }.decodeSingleOrNull<ClientInfo>() }.getOrNull()
    suspend fun setClientPrice(client: String, price: Double?) = exec("dtf_set_client_price", buildJsonObject { put("p_client", client); put("p_price", price) })
}
