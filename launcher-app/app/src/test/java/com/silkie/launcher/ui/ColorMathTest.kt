package com.silkie.launcher.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

class ColorMathTest {
    @Test
    fun parsesAndFormatsHex() {
        assertEquals(0xFFFFB86B.toInt(), ColorMath.parseHex("#FFB86B"))
        assertEquals(0x80FFB86B.toInt(), ColorMath.parseHex("80ffb86b"))
        assertNull(ColorMath.parseHex("#12345"))
        assertNull(ColorMath.parseHex("nothex"))
        assertEquals("#FFB86B", ColorMath.toHex(0xFFFFB86B.toInt()))
        assertEquals("#80FFB86B", ColorMath.toHex(0x80FFB86B.toInt()))
    }

    @Test
    fun hsvRoundTrips() {
        for (c in intArrayOf(0xFFFF0000.toInt(), 0xFF00FF00.toInt(), 0xFF3A6EA5.toInt(), 0xFFFFB86B.toInt(), 0xFF141218.toInt(), 0xFF808080.toInt())) {
            val hsv = ColorMath.toHsv(c)
            val back = ColorMath.fromHsv(hsv[0], hsv[1], hsv[2])
            for (shift in intArrayOf(0, 8, 16)) {
                val d = abs(((c shr shift) and 0xFF) - ((back shr shift) and 0xFF))
                assertTrue("channel off by $d for ${ColorMath.toHex(c)}", d <= 1)
            }
        }
    }

    @Test
    fun picksReadableText() {
        assertEquals(0xFFFFFFFF.toInt(), ColorMath.readableOn(0xFF000000.toInt()))
        assertEquals(0xFF141218.toInt(), ColorMath.readableOn(0xFFFFFFFF.toInt()))
        assertEquals(0xFF141218.toInt(), ColorMath.readableOn(0xFFFFD54F.toInt()))
        assertTrue(ColorMath.contrast(0xFF000000.toInt(), 0xFFFFFFFF.toInt()) > 20)
    }

    @Test
    fun mixesAndShades() {
        assertEquals(0xFF808080.toInt(), ColorMath.mix(0xFF000000.toInt(), 0xFFFFFFFF.toInt(), 0.5f))
        assertEquals(0xFFFFFFFF.toInt(), ColorMath.shade(0xFF336699.toInt(), 1f))
        assertEquals(0xFF000000.toInt(), ColorMath.shade(0xFF336699.toInt(), -1f))
        assertEquals(0x80, ColorMath.alpha(ColorMath.withAlpha(0xFF123456.toInt(), 0.5f)))
    }
}
