package com.inkframe.tools

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class FloodFillTest {
    private val black = 0xFF000000.toInt()
    private val red = 0xFFFF0000.toInt()
    private val clear = 0

    /** 20x20 transparent image with a closed 1 px black square outline from (5,5) to (14,14). */
    private fun boxImage(): IntArray {
        val w = 20
        val px = IntArray(w * w)
        for (i in 5..14) {
            px[5 * w + i] = black; px[14 * w + i] = black
            px[i * w + 5] = black; px[i * w + 14] = black
        }
        return px
    }

    @Test
    fun fillsInsideClosedShapeOnly() {
        val img = boxImage()
        val bounds = FloodFill.fill(img, img.copyOf(), 20, 20, 10, 10, red, 10, 0)
        assertNotNull(bounds)
        assertEquals(IntBounds(6, 6, 14, 14), bounds)
        assertEquals(red, img[10 * 20 + 10])
        assertEquals(black, img[5 * 20 + 10])
        assertEquals(clear, img[2 * 20 + 2])
    }

    @Test
    fun expandGrowsUnderTheLine() {
        val img = boxImage()
        val ref = img.copyOf()
        val target = IntArray(img.size)
        val bounds = FloodFill.fill(target, ref, 20, 20, 10, 10, red, 10, 1)
        assertEquals(IntBounds(5, 5, 15, 15), bounds)
        assertEquals(red, target[5 * 20 + 10])
        assertEquals(clear, target[4 * 20 + 10])
    }

    @Test
    fun fillingOutsideStopsAtTheOutline() {
        val img = boxImage()
        FloodFill.fill(img, img.copyOf(), 20, 20, 0, 0, red, 10, 0)
        assertEquals(red, img[0])
        assertEquals(red, img[19 * 20 + 19])
        assertEquals(clear, img[10 * 20 + 10])
    }

    @Test
    fun toleranceIncludesSimilarColors() {
        val w = 4
        // Checkerboard of two grays 8 levels apart.
        fun board() = IntArray(w * w) { i -> if ((i % w + i / w) % 2 == 0) 0xFF808080.toInt() else 0xFF888888.toInt() }
        val strict = board()
        FloodFill.fill(strict, strict.copyOf(), w, w, 0, 0, red, 4, 0)
        assertEquals(1, strict.count { it == red }) // diagonal neighbours are not connected
        val loose = board()
        FloodFill.fill(loose, loose.copyOf(), w, w, 0, 0, red, 10, 0)
        assertEquals(listOf(red), loose.distinct())
    }

    @Test
    fun outsideOrUnchangedReturnsNull() {
        val img = IntArray(4) { red }
        assertNull(FloodFill.fill(img, img.copyOf(), 2, 2, 5, 5, red, 0, 0))
        assertNull(FloodFill.fill(img, img.copyOf(), 2, 2, 0, 0, red, 0, 0))
    }

    @Test
    fun srcOverBlendsSemiTransparentColor() {
        val half = 0x80FF0000.toInt()
        assertEquals(0xFFFF0000.toInt() , FloodFill.srcOver(red, black))
        val onWhite = FloodFill.srcOver(half, 0xFFFFFFFF.toInt())
        assertEquals(255, onWhite ushr 24)
        assertEquals(255, (onWhite shr 16) and 0xFF)
        assertEquals(127, (onWhite shr 8) and 0xFF, 1)
        assertEquals(half, FloodFill.srcOver(half, 0))
    }

    private fun assertEquals(expected: Int, actual: Int, delta: Int) {
        org.junit.Assert.assertTrue("expected $expected got $actual", kotlin.math.abs(expected - actual) <= delta)
    }
}
