package com.mydtf.core

import kotlin.math.ceil
import kotlin.math.roundToLong

data class PricingSettings(
    val pricePerMeter: Double,
    val minOrderAmount: Double = 0.0,
    val meterRoundingStep: Double = 0.1,
    /** Paliers de gros (mètres minimum → prix du mètre) et prix spécial du client (prioritaire). */
    val tiers: List<Pair<Double, Double>> = emptyList(),
    val special: Double? = null,
) {
    fun priceFor(billedMeters: Double): Double =
        special ?: tiers.filter { it.first <= billedMeters + 1e-9 }.maxByOrNull { it.first }?.second ?: pricePerMeter
    /** Prochain palier plus avantageux, pour inciter : (mètres à atteindre, prix). */
    fun nextTier(billedMeters: Double): Pair<Double, Double>? =
        if (special != null) null else tiers.filter { it.first > billedMeters + 1e-9 && it.second < priceFor(billedMeters) }.minByOrNull { it.first }
}

data class Quote(val lengthCm: Double, val billedMeters: Double, val printAmount: Double, val deliveryFee: Double = 0.0) {
    val total: Double get() = printAmount + deliveryFee
}

/** Même règle que la fonction SQL dtf_price : arrondi au pas supérieur puis minimum de commande. */
fun computeQuote(lengthCm: Double, s: PricingSettings, deliveryFee: Double = 0.0): Quote {
    val meters = lengthCm / 100
    val billed = if (s.meterRoundingStep > 0) ceil(meters / s.meterRoundingStep - 1e-9) * s.meterRoundingStep else meters
    val billedRounded = (billed * 1000).roundToLong() / 1000.0
    val amount = maxOf(billedRounded * s.priceFor(billedRounded), s.minOrderAmount)
    return Quote(lengthCm, billedRounded, amount.roundToLong().toDouble(), deliveryFee)
}

/** Isole un nombre en gauche→droite pour qu'il ne s'inverse jamais dans un texte arabe. */
fun ltr(s: String) = "\u2066$s\u2069"

fun formatDa(v: Double): String {
    val n = v.roundToLong()
    val s = n.toString().reversed().chunked(3).joinToString(".").reversed()
    return "${ltr(s)} دج"
}
