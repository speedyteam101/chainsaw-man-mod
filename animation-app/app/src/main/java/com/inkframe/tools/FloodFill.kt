package com.inkframe.tools

import kotlin.math.abs
import kotlin.math.max

/** Integer rectangle [left, right) x [top, bottom). */
data class IntBounds(val left: Int, val top: Int, val right: Int, val bottom: Int)

/**
 * Color fill on plain ARGB (non-premultiplied) pixel arrays. Pure Kotlin so it can be unit tested.
 */
object FloodFill {

    /**
     * Fills the region connected to (x, y) whose color in [reference] is within [tolerance] (0..255)
     * of the color at (x, y). The region is grown by [expand] pixels so the fill tucks under
     * anti-aliased line edges, then [color] is composited over [target] inside it.
     *
     * [reference] can be [target] itself or a merged image of all layers.
     * Returns the changed bounds, or null if nothing changed.
     */
    fun fill(
        target: IntArray,
        reference: IntArray,
        width: Int,
        height: Int,
        x: Int,
        y: Int,
        color: Int,
        tolerance: Int,
        expand: Int,
    ): IntBounds? {
        val mask = regionMask(reference, width, height, x, y, tolerance) ?: return null
        if (expand > 0) dilate(mask, width, height, expand)
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        var changed = false
        for (py in 0 until height) {
            val row = py * width
            for (px in 0 until width) {
                if (mask[row + px].toInt() == 0) continue
                val before = target[row + px]
                val after = srcOver(color, before)
                if (after != before) {
                    target[row + px] = after
                    changed = true
                }
                if (px < minX) minX = px
                if (px > maxX) maxX = px
                if (py < minY) minY = py
                if (py > maxY) maxY = py
            }
        }
        if (!changed) return null
        return IntBounds(minX, minY, maxX + 1, maxY + 1)
    }

    /** 1 for every pixel in the connected region around (x, y), or null if (x, y) is outside. */
    fun regionMask(reference: IntArray, width: Int, height: Int, x: Int, y: Int, tolerance: Int): ByteArray? {
        if (x !in 0 until width || y !in 0 until height) return null
        val seed = premultiply(reference[y * width + x])
        val mask = ByteArray(width * height)
        val tol = tolerance.coerceIn(0, 255)
        fun matches(i: Int) = mask[i].toInt() == 0 && distance(premultiply(reference[i]), seed) <= tol

        // Scanline fill with an explicit stack of (x, y) seeds.
        var stack = IntArray(1024)
        var sp = 0
        fun push(px: Int, py: Int) {
            if (sp + 2 > stack.size) stack = stack.copyOf(stack.size * 2)
            stack[sp++] = px
            stack[sp++] = py
        }
        push(x, y)
        while (sp > 0) {
            val py = stack[--sp]
            var px = stack[--sp]
            val row = py * width
            if (!matches(row + px)) continue
            while (px > 0 && matches(row + px - 1)) px--
            var spanAbove = false
            var spanBelow = false
            while (px < width && matches(row + px)) {
                mask[row + px] = 1
                if (py > 0) {
                    val m = matches(row - width + px)
                    if (m && !spanAbove) push(px, py - 1)
                    spanAbove = m
                }
                if (py < height - 1) {
                    val m = matches(row + width + px)
                    if (m && !spanBelow) push(px, py + 1)
                    spanBelow = m
                }
                px++
            }
        }
        return mask
    }

    /** Grows the mask by [r] pixels (square neighbourhood), in two separable passes. */
    fun dilate(mask: ByteArray, width: Int, height: Int, r: Int) {
        val tmp = ByteArray(mask.size)
        for (y in 0 until height) {
            val row = y * width
            var last = -r - 1
            for (x in 0 until width) {
                if (mask[row + x].toInt() != 0) last = x
                if (x - last <= r) tmp[row + x] = 1
            }
            last = width + r + 1
            for (x in width - 1 downTo 0) {
                if (mask[row + x].toInt() != 0) last = x
                if (last - x <= r) tmp[row + x] = 1
            }
        }
        for (x in 0 until width) {
            var last = -r - 1
            for (y in 0 until height) {
                if (tmp[y * width + x].toInt() != 0) last = y
                if (y - last <= r) mask[y * width + x] = 1
            }
            last = height + r + 1
            for (y in height - 1 downTo 0) {
                if (tmp[y * width + x].toInt() != 0) last = y
                if (last - y <= r) mask[y * width + x] = 1
            }
        }
    }

    /** Premultiplied so every fully transparent pixel compares equal, whatever its RGB. */
    fun premultiply(c: Int): Int {
        val a = c ushr 24
        if (a == 255) return c
        if (a == 0) return 0
        val r = ((c shr 16) and 0xFF) * a / 255
        val g = ((c shr 8) and 0xFF) * a / 255
        val b = (c and 0xFF) * a / 255
        return (a shl 24) or (r shl 16) or (g shl 8) or b
    }

    fun distance(a: Int, b: Int): Int {
        val da = abs((a ushr 24) - (b ushr 24))
        val dr = abs(((a shr 16) and 0xFF) - ((b shr 16) and 0xFF))
        val dg = abs(((a shr 8) and 0xFF) - ((b shr 8) and 0xFF))
        val db = abs((a and 0xFF) - (b and 0xFF))
        return max(max(da, dr), max(dg, db))
    }

    /** Non-premultiplied source-over. */
    fun srcOver(src: Int, dst: Int): Int {
        val sa = src ushr 24
        if (sa == 255) return src
        if (sa == 0) return dst
        val da = dst ushr 24
        val outA = sa + da * (255 - sa) / 255
        if (outA == 0) return 0
        fun ch(shift: Int): Int {
            val s = (src shr shift) and 0xFF
            val d = (dst shr shift) and 0xFF
            return ((s * sa + d * da * (255 - sa) / 255) / outA).coerceIn(0, 255)
        }
        return (outA shl 24) or (ch(16) shl 16) or (ch(8) shl 8) or ch(0)
    }
}
