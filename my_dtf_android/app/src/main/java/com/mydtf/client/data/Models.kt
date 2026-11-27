package com.mydtf.client.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Profile(
    val id: String,
    val role: String = "client",
    @SerialName("full_name") val fullName: String,
    val phone: String,
    val wilaya: String? = null,
    val commune: String? = null,
    val address: String? = null,
)

@Serializable
data class Settings(
    @SerialName("price_per_meter") val pricePerMeter: Double,
    @SerialName("min_order_amount") val minOrderAmount: Double,
    @SerialName("meter_rounding_step") val meterRoundingStep: Double,
    @SerialName("film_width_cm") val filmWidthCm: Double,
    @SerialName("gap_cm") val gapCm: Double,
    @SerialName("allow_rotation") val allowRotation: Boolean,
    @SerialName("workshop_name") val workshopName: String,
    @SerialName("workshop_phone") val workshopPhone: String? = null,
    @SerialName("workshop_address") val workshopAddress: String? = null,
)

@Serializable
data class Order(
    val id: String,
    val code: Long,
    val status: String,
    @SerialName("estimated_length_cm") val estimatedLengthCm: Double,
    @SerialName("final_length_cm") val finalLengthCm: Double? = null,
    @SerialName("billed_meters") val billedMeters: Double,
    @SerialName("print_amount") val printAmount: Double,
    @SerialName("delivery_mode") val deliveryMode: String,
    @SerialName("delivery_fee") val deliveryFee: Double = 0.0,
    @SerialName("ship_wilaya") val shipWilaya: String? = null,
    @SerialName("ship_commune") val shipCommune: String? = null,
    val carrier: String? = null,
    @SerialName("tracking_number") val trackingNumber: String? = null,
    @SerialName("amount_paid") val amountPaid: Double = 0.0,
    @SerialName("reject_reason") val rejectReason: String? = null,
    @SerialName("client_note") val clientNote: String? = null,
    @SerialName("created_at") val createdAt: String,
) {
    val total: Double get() = printAmount + deliveryFee
}

@Serializable
data class OrderImage(
    val id: String,
    @SerialName("storage_path") val storagePath: String,
    @SerialName("width_cm") val widthCm: Double,
    @SerialName("height_cm") val heightCm: Double,
    val quantity: Int,
)

@Serializable
data class OrderEvent(
    val id: Long,
    @SerialName("from_status") val fromStatus: String? = null,
    @SerialName("to_status") val toStatus: String? = null,
    val note: String? = null,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class AppNotification(
    val id: Long,
    @SerialName("order_id") val orderId: String? = null,
    val title: String,
    val body: String? = null,
    val read: Boolean = false,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class NewProfile(
    val id: String,
    val role: String = "client",
    @SerialName("full_name") val fullName: String,
    val phone: String,
    val wilaya: String?,
    val commune: String?,
    val address: String?,
)

@Serializable
data class NewOrderImage(
    @SerialName("order_id") val orderId: String,
    @SerialName("storage_path") val storagePath: String,
    @SerialName("width_cm") val widthCm: Double,
    @SerialName("height_cm") val heightCm: Double,
    val quantity: Int,
)
