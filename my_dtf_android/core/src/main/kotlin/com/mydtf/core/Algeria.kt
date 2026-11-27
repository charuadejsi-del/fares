package com.mydtf.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.text.Normalizer

@Serializable
data class Wilaya(
    val c: Int, val fr: String, val ar: String,
    /** Tarifs de la société de livraison (null = liste générale, pas de tarif connu). */
    val home: Int? = null, val desk: Int? = null, val hasDesk: Boolean = false,
) {
    val code: String get() = c.toString().padStart(2, '0')
    val label: String get() = "$code - $ar · $fr"
}

@Serializable
data class Commune(
    val w: Int, val fr: String, val ar: String,
    /** Bureau (stop desk) de la société dans cette commune ; null = inconnu (liste générale). */
    val desk: Boolean? = null, val code: String? = null,
) {
    val label: String get() = "$ar · $fr"
}

/** Tarif d'une wilaya chez la société de livraison (dtf_ship_rates). */
data class ShipRate(val wilaya: Int, val home: Int?, val desk: Int?)
/** Commune desservie (dtf_ship_communes). */
data class ShipCommune(val wilaya: Int, val name: String, val hasDesk: Boolean, val code: String?)

@Serializable
private data class AlgeriaData(val wilayas: List<Wilaya>, val communes: List<Commune>)

/** 58 wilayas et 1541 communes (arabe + français), embarquées hors ligne. */
object Algeria {
    private val data: AlgeriaData by lazy {
        val text = Algeria::class.java.getResourceAsStream("/dz/algeria.json")!!
            .bufferedReader(Charsets.UTF_8).use { it.readText() }
        Json { ignoreUnknownKeys = true }.decodeFromString(AlgeriaData.serializer(), text)
    }

    // Liste de la société de livraison (Expedia…) quand elle est chargée : seules les wilayas et communes
    // qu'elle dessert, avec tarifs et bureaux. Le nom français `fr` d'une commune est alors celui de la société.
    @Volatile private var live: AlgeriaData? = null
    val isLive: Boolean get() = live != null

    fun applyShipping(rates: List<ShipRate>, communes: List<ShipCommune>) {
        if (rates.isEmpty() || communes.isEmpty()) return
        val base = data
        val arOf = base.communes.associate { (it.w to normalize(it.fr)) to it.ar }
        val coms = communes.map { Commune(it.wilaya, it.name, arOf[it.wilaya to normalize(it.name)] ?: it.name, it.hasDesk, it.code) }
        val deskW = coms.filter { it.desk == true }.map { it.w }.toSet()
        val wils = rates.mapNotNull { r ->
            val w = base.wilayas.firstOrNull { it.c == r.wilaya } ?: return@mapNotNull null
            val hasDesk = r.wilaya in deskW && (r.desk ?: 0) > 0
            w.copy(home = r.home?.takeIf { it > 0 }, desk = if (hasDesk) r.desk else null, hasDesk = hasDesk)
        }.sortedBy { it.c }
        live = AlgeriaData(wils, coms)
    }

    val wilayas: List<Wilaya> get() = (live ?: data).wilayas
    fun communesOf(wilayaCode: Int): List<Commune> = (live ?: data).communes.filter { it.w == wilayaCode }
    fun wilayaByName(name: String?): Wilaya? =
        if (name == null) null else wilayas.firstOrNull { it.fr.equals(name, true) || it.ar == name || normalize(it.fr) == normalize(name) }
    fun communeByName(w: Wilaya?, name: String?): Commune? =
        if (w == null || name == null) null else communesOf(w.c).firstOrNull { it.fr == name || it.ar == name || normalize(it.fr) == normalize(name) }

    /** Recherche tolérante : « bejaia », « Béjaïa », « بجاية », « 06 », « 6 ». */
    fun searchWilayas(query: String): List<Wilaya> {
        val q = normalize(query)
        if (q.isEmpty()) return wilayas
        val num = query.trim().toIntOrNull()
        return wilayas
            .filter { num != null && it.c == num || normalize(it.fr).contains(q) || normalize(it.ar).contains(q) }
            .sortedBy { if (num != null && it.c == num) 0 else if (normalize(it.fr).startsWith(q) || normalize(it.ar).startsWith(q)) 1 else 2 }
    }

    fun searchCommunes(wilayaCode: Int, query: String): List<Commune> {
        val list = communesOf(wilayaCode)
        val q = normalize(query)
        if (q.isEmpty()) return list
        return list.filter { normalize(it.fr).contains(q) || normalize(it.ar).contains(q) }
            .sortedBy { if (normalize(it.fr).startsWith(q) || normalize(it.ar).startsWith(q)) 0 else 1 }
    }

    /** Minuscules, sans accents, alef/ta marbouta/ya unifiés, sans tirets ni espaces. */
    fun normalize(s: String): String {
        val noAccents = Normalizer.normalize(s.lowercase(), Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}+"), "")
        return noAccents
            .replace(Regex("[أإآٱ]"), "ا")
            .replace('ة', 'ه')
            .replace('ى', 'ي')
            .replace(Regex("[\\u0640\\s'’\\-_.]"), "")
    }
}
