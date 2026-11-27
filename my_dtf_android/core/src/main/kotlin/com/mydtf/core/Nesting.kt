package com.mydtf.core

import kotlin.math.abs
import kotlin.math.max

/**
 * Moteur d'imbrication My DTF : range les images sur une laize fixe (58 cm),
 * avec espacement (0,3 cm) et rotation 90°, en minimisant la longueur de film.
 * Algorithme « skyline bottom-left » essayé avec plusieurs ordres de tri et
 * plusieurs stratégies d'orientation ; on garde le film le plus court.
 */
data class NestItem(val id: String, val widthCm: Double, val heightCm: Double, val quantity: Int)

data class Placement(
    val itemId: String,
    val x: Double,
    val y: Double,
    val width: Double,
    val height: Double,
    val rotated: Boolean,
)

data class NestResult(val lengthCm: Double, val filmWidthCm: Double, val placements: List<Placement>) {
    val lengthM: Double get() = lengthCm / 100
    val fillRatio: Double
        get() = if (lengthCm <= 0) 0.0
        else placements.sumOf { it.width * it.height } / (lengthCm * filmWidthCm)
}

class ItemTooWideException(val itemId: String) : Exception("Image $itemId plus large que le film")

class NestingEngine(
    val filmWidthCm: Double = 58.0,
    val gapCm: Double = 0.3,
    val allowRotation: Boolean = true,
) {
    private data class Copy(val id: String, val w: Double, val h: Double, val rotated: Boolean = false)
    private data class Seg(val x: Double, val y: Double, val w: Double)

    fun nest(items: List<NestItem>): NestResult {
        val copies = mutableListOf<Copy>()
        for (item in items) {
            if (item.widthCm <= 0 || item.heightCm <= 0 || item.quantity <= 0) continue
            val fits = item.widthCm <= filmWidthCm || (allowRotation && item.heightCm <= filmWidthCm)
            if (!fits) throw ItemTooWideException(item.id)
            val turn = item.widthCm > filmWidthCm
            repeat(item.quantity) {
                copies += if (turn) Copy(item.id, item.heightCm, item.widthCm, true) else Copy(item.id, item.widthCm, item.heightCm)
            }
        }
        if (copies.isEmpty()) return NestResult(0.0, filmWidthCm, emptyList())

        val orders: List<Comparator<Copy>> = listOf(
            compareByDescending { it.h },
            compareByDescending { it.w },
            compareByDescending { it.w * it.h },
            compareByDescending { max(it.w, it.h) },
        )

        fun orient(c: Copy, landscape: Boolean): Copy {
            val shouldTurn = if (landscape) c.w < c.h else c.w > c.h
            return if (shouldTurn && c.h <= filmWidthCm) Copy(c.id, c.h, c.w, !c.rotated) else c
        }

        val variants = buildList {
            add(copies to false)
            if (allowRotation) {
                add(copies to true)
                add(copies.map { orient(it, true) } to false)
                add(copies.map { orient(it, false) } to false)
            }
        }

        var best: NestResult? = null
        for ((cs, greedy) in variants) for (cmp in orders) {
            val r = skyline(cs.sortedWith(cmp), greedy)
            if (best == null || r.lengthCm < best.lengthCm - EPS) best = r
        }
        return best!!
    }

    private fun skyline(copies: List<Copy>, greedyRotation: Boolean): NestResult {
        val binW = filmWidthCm + gapCm
        var sky = listOf(Seg(0.0, 0.0, binW))
        val out = mutableListOf<Placement>()

        for (c in copies) {
            val options = buildList {
                add(Triple(c.w, c.h, c.rotated))
                if (greedyRotation && abs(c.w - c.h) > EPS) add(Triple(c.h, c.w, !c.rotated))
            }
            var bx = 0.0; var by = 0.0; var bw = 0.0; var bh = 0.0; var bTop = Double.MAX_VALUE
            var bRot = false; var found = false
            for ((ow, oh, rot) in options) {
                val w = ow + gapCm
                val h = oh + gapCm
                if (w > binW + EPS) continue
                for (i in sky.indices) {
                    val x = sky[i].x
                    if (x + w > binW + EPS) break
                    var y = 0.0
                    var rem = w
                    var j = i
                    while (j < sky.size && rem > EPS) {
                        y = max(y, sky[j].y); rem -= sky[j].w; j++
                    }
                    val top = y + h
                    val better = !found || top < bTop - EPS ||
                        (abs(top - bTop) <= EPS && (y < by - EPS || (abs(y - by) <= EPS && x < bx)))
                    if (better) {
                        found = true; bx = x; by = y; bw = w; bh = h; bTop = top; bRot = rot
                    }
                }
            }
            check(found) { "Placement impossible" }
            out += Placement(c.id, bx, by, bw - gapCm, bh - gapCm, bRot)
            sky = addToSkyline(sky, bx, bw, bTop)
        }
        val length = out.maxOf { it.y + it.height }
        return NestResult(Math.round(length * 1000) / 1000.0, filmWidthCm, out)
    }

    private fun addToSkyline(sky: List<Seg>, x: Double, w: Double, top: Double): List<Seg> {
        val res = mutableListOf<Seg>()
        val end = x + w
        for (s in sky) {
            val sEnd = s.x + s.w
            if (sEnd <= x + EPS || s.x >= end - EPS) { res += s; continue }
            if (s.x < x) res += Seg(s.x, s.y, x - s.x)
            if (sEnd > end) res += Seg(end, s.y, sEnd - end)
        }
        res += Seg(x, top, w)
        res.sortBy { it.x }
        val merged = mutableListOf<Seg>()
        for (s in res) {
            val last = merged.lastOrNull()
            if (last != null && abs(last.y - s.y) < EPS) merged[merged.size - 1] = Seg(last.x, last.y, last.w + s.w)
            else merged += s
        }
        return merged
    }

    private companion object { const val EPS = 1e-9 }
}
