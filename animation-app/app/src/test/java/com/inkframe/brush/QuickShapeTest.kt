package com.inkframe.brush

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.cos
import kotlin.math.sin

class QuickShapeTest {
    private fun samples(n: Int, f: (Int) -> Pair<Float, Float>): FloatArray {
        val out = FloatArray(n * 3)
        for (i in 0 until n) {
            val (x, y) = f(i)
            out[i * 3] = x; out[i * 3 + 1] = y; out[i * 3 + 2] = 1f
        }
        return out
    }

    @Test
    fun wobblyLineSnapsToLine() {
        val pts = samples(60) { i -> Pair(10f + i * 5f, 100f + (if (i % 3 == 0) 2f else -1.5f)) }
        val shape = QuickShape.detect(pts, 60)
        assertTrue(shape is QuickShape.Line)
        val line = shape as QuickShape.Line
        assertEquals(10f, line.x0, 0.01f)
        assertEquals(305f, line.x1, 0.01f)
    }

    @Test
    fun roughLoopSnapsToEllipse() {
        val n = 90
        val pts = samples(n) { i ->
            val t = i / (n - 1f) * 2f * Math.PI.toFloat()
            val wobble = 1f + 0.04f * sin(t * 7f)
            Pair(200f + 120f * cos(t) * wobble, 150f + 60f * sin(t) * wobble)
        }
        val shape = QuickShape.detect(pts, n)
        assertTrue("got $shape", shape is QuickShape.Ellipse)
        val e = shape as QuickShape.Ellipse
        assertEquals(200f, e.cx, 8f)
        assertEquals(150f, e.cy, 8f)
        assertEquals(120f, maxOf(e.rx, e.ry), 10f)
        assertEquals(60f, minOf(e.rx, e.ry), 8f)
        assertTrue(e.points().size > 100)
    }

    @Test
    fun scribbleIsNotAShape() {
        val pts = samples(80) { i -> Pair(i * 4f, if ((i / 10) % 2 == 0) (i % 10) * 12f else (10 - i % 10) * 12f) }
        assertNull(QuickShape.detect(pts, 80))
    }

    @Test
    fun tinyStrokeIsIgnored() {
        val pts = samples(5) { i -> Pair(i.toFloat(), 0f) }
        assertNull(QuickShape.detect(pts, 5))
    }
}
