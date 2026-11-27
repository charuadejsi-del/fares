package com.mydtf.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.text.Normalizer

@Serializable
data class Wilaya(val c: Int, val fr: String, val ar: String) {
    val code: String get() = c.toString().padStart(2, '0')
    val label: String get() = "$code - $ar · $fr"
}

@Serializable
data class Commune(val w: Int, val fr: String, val ar: String) {
    val label: String get() = "$ar · $fr"
}

@Serializable
private data class AlgeriaData(val wilayas: List<Wilaya>, val communes: List<Commune>)

/** 58 wilayas et 1541 communes (arabe + français), embarquées hors ligne. */
object Algeria {
    private val data: AlgeriaData by lazy {
        val text = Algeria::class.java.getResourceAsStream("/dz/algeria.json")!!
            .bufferedReader(Charsets.UTF_8).use { it.readText() }
        Json { ignoreUnknownKeys = true }.decodeFromString(AlgeriaData.serializer(), text)
    }

    val wilayas: List<Wilaya> get() = data.wilayas
    fun communesOf(wilayaCode: Int): List<Commune> = data.communes.filter { it.w == wilayaCode }
    fun wilayaByName(name: String?): Wilaya? =
        if (name == null) null else wilayas.firstOrNull { it.fr.equals(name, true) || it.ar == name }

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
