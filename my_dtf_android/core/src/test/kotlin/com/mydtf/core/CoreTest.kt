package com.mydtf.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class CoreTest {
    private val engine = NestingEngine(58.0, 0.3, true)

    private fun assertNoOverlap(r: NestResult) {
        val p = r.placements
        for (a in p.indices) {
            assertTrue(p[a].x >= -1e-9 && p[a].x + p[a].width <= 58 + 1e-9)
            for (b in a + 1 until p.size) {
                val sep = p[a].x + p[a].width <= p[b].x + 1e-9 || p[b].x + p[b].width <= p[a].x + 1e-9 ||
                    p[a].y + p[a].height <= p[b].y + 1e-9 || p[b].y + p[b].height <= p[a].y + 1e-9
                assertTrue(sep, "chevauchement ${p[a]} / ${p[b]}")
            }
        }
    }

    @Test fun `28,5 x 30 x 10 donne 2 par ligne et 5 lignes`() {
        val r = engine.nest(listOf(NestItem("a", 28.5, 30.0, 10)))
        assertEquals(10, r.placements.size)
        assertEquals(151.2, r.lengthCm, 0.01)
        assertNoOverlap(r)
    }

    @Test fun `10 x 10 x 20`() {
        val r = engine.nest(listOf(NestItem("a", 10.0, 10.0, 20)))
        assertEquals(40.9, r.lengthCm, 0.01)
        assertNoOverlap(r)
    }

    @Test fun `commande mixte`() {
        val r = engine.nest(listOf(NestItem("p", 8.0, 10.0, 6), NestItem("q", 25.0, 30.0, 1), NestItem("r", 25.0, 40.0, 1)))
        assertEquals(8, r.placements.size)
        assertEquals(45.6, r.lengthCm, 0.01)
        assertNoOverlap(r)
    }

    @Test fun `image trop large refusee`() {
        assertFailsWith<ItemTooWideException> { engine.nest(listOf(NestItem("x", 70.0, 65.0, 1))) }
    }

    @Test fun `image large posee tournee`() {
        val r = engine.nest(listOf(NestItem("x", 65.0, 40.0, 1)))
        assertTrue(r.placements.single().rotated)
        assertNoOverlap(r)
    }

    @Test fun `prix arrondi et minimum`() {
        val s = PricingSettings(1000.0, 500.0, 0.1)
        assertEquals(1.6, computeQuote(151.2, s).billedMeters, 1e-9)
        assertEquals(1600.0, computeQuote(151.2, s).printAmount)
        assertEquals(500.0, computeQuote(20.0, s).printAmount)
    }

    @Test fun `wilayas et communes`() {
        assertEquals(58, Algeria.wilayas.size)
        assertEquals(6, Algeria.searchWilayas("bejaia").first().c)
        assertEquals(6, Algeria.searchWilayas("بجاية").first().c)
        assertEquals(6, Algeria.searchWilayas("06").first().c)
        assertTrue(Algeria.searchCommunes(6, "kseur").any { it.fr.contains("Kseur", true) })
        assertTrue(Algeria.communesOf(6).size > 40)
    }
}
