package com.inkframe.brush

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.hypot

class StrokePathTest {
    private val spec = BrushSpec(id = "t", name = "t", shape = DabShape.HARD, spacing = 0.1f, pressureSize = 0f, streamline = 0f)

    private fun run(spec: BrushSpec, size: Float, points: List<FloatArray>): List<Dab> {
        val dabs = ArrayList<Dab>()
        val p = StrokePath(spec, size, 1L) { dabs += it }
        p.begin(points[0][0], points[0][1], points[0][2])
        for (i in 1 until points.size) p.add(points[i][0], points[i][1], points[i][2])
        p.finish()
        return dabs
    }

    @Test
    fun dabsAreEvenlySpacedAlongAStraightLine() {
        val pts = (0..100).map { floatArrayOf(it * 2f, 50f, 1f) }
        val dabs = run(spec, 10f, pts)
        // 200 px line with 1 px spacing (10% of 10 px): about 200 dabs.
        assertTrue("got ${dabs.size}", dabs.size in 190..210)
        for (i in 1 until dabs.size) {
            val d = hypot(dabs[i].x - dabs[i - 1].x, dabs[i].y - dabs[i - 1].y)
            assertEquals(1f, d, 0.05f)
            assertEquals(50f, dabs[i].y, 0.001f)
        }
        assertEquals(200f, dabs.last().x, 1.01f)
    }

    @Test
    fun streamlineStillReachesTheEndOfTheStroke() {
        val smooth = spec.copy(streamline = 0.9f)
        val pts = (0..20).map { floatArrayOf(it * 10f, 0f, 1f) }
        val dabs = run(smooth, 10f, pts)
        assertEquals(200f, dabs.last().x, 1.5f)
    }

    @Test
    fun streamlineRemovesJitter() {
        val jittery = (0..200).map { floatArrayOf(it * 2f, if (it % 2 == 0) 3f else -3f, 1f) }
        val raw = run(spec, 4f, jittery)
        val smoothed = run(spec.copy(streamline = 0.8f), 4f, jittery)
        // Ignore both ends: the stroke deliberately catches up with the pen's last position.
        fun maxY(d: List<Dab>) = d.subList(d.size / 10, d.size * 9 / 10).maxOf { kotlin.math.abs(it.y) }
        assertTrue(maxY(smoothed) < maxY(raw) / 2f)
    }

    @Test
    fun pressureControlsSize() {
        val ps = spec.copy(pressureSize = 1f)
        val pts = (0..50).map { floatArrayOf(it * 4f, 0f, it / 50f) }
        val dabs = run(ps, 20f, pts)
        assertTrue(dabs.first().size < 3f)
        assertTrue(dabs.last().size > 17f)
    }

    @Test
    fun startTaperGrowsFromThin() {
        val tapered = spec.copy(taperStart = 1f)
        val pts = (0..100).map { floatArrayOf(it * 4f, 0f, 1f) }
        val dabs = run(tapered, 10f, pts)
        assertTrue(dabs.first().size < 2f)
        assertEquals(10f, dabs.last().size, 0.01f)
        assertEquals(1f, StrokePath.endTaper(tapered.copy(taperEnd = 0f), 10f, 390f, 400f), 0f)
        assertTrue(StrokePath.endTaper(tapered.copy(taperEnd = 1f), 10f, 399f, 400f) < 0.2f)
    }

    @Test
    fun rawPointsAreRecorded() {
        val p = StrokePath(spec, 5f, 1L) {}
        p.begin(1f, 2f, 0.5f)
        repeat(100) { p.add(it.toFloat(), 2f, 0.5f) }
        assertEquals(101, p.rawCount)
        assertEquals(1f, p.raw[0], 0f)
        assertEquals(99f, p.raw[100 * 3], 0f)
    }
}
