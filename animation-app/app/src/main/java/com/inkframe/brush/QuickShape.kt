package com.inkframe.brush

import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * QuickShape: draw a line or loop and hold the pen still, and it snaps to a perfect
 * straight line or ellipse. Pure Kotlin so it can be unit tested.
 */
object QuickShape {

    sealed class Shape {
        abstract fun points(): FloatArray
        abstract val label: String
    }

    class Line(val x0: Float, val y0: Float, var x1: Float, var y1: Float) : Shape() {
        override val label = "Line"
        override fun points(): FloatArray {
            val len = hypot(x1 - x0, y1 - y0)
            val n = max(2, (len / 2f).toInt())
            val out = FloatArray((n + 1) * 2)
            for (i in 0..n) {
                val t = i / n.toFloat()
                out[i * 2] = x0 + (x1 - x0) * t
                out[i * 2 + 1] = y0 + (y1 - y0) * t
            }
            return out
        }
    }

    class Ellipse(val cx: Float, val cy: Float, val rx: Float, val ry: Float, val angle: Float) : Shape() {
        override val label = if (abs(rx - ry) < 0.08f * max(rx, ry)) "Circle" else "Ellipse"
        override fun points(): FloatArray {
            val perimeter = (Math.PI * (3 * (rx + ry) - sqrt(((3 * rx + ry) * (rx + 3 * ry)).toDouble()))).toFloat()
            val n = max(24, (perimeter / 2f).toInt())
            val out = FloatArray((n + 2) * 2)
            val ca = cos(angle)
            val sa = sin(angle)
            // One extra point overlaps the start so the loop closes cleanly.
            for (i in 0..n + 1) {
                val t = (i / n.toFloat()) * 2f * Math.PI.toFloat()
                val ex = rx * cos(t)
                val ey = ry * sin(t)
                out[i * 2] = cx + ex * ca - ey * sa
                out[i * 2 + 1] = cy + ex * sa + ey * ca
            }
            return out
        }
    }

    /**
     * Recognises a shape from stroke samples ([pts] holds x, y, pressure triples; [count] samples).
     * Returns null when the stroke is neither clearly a line nor clearly an ellipse.
     */
    fun detect(pts: FloatArray, count: Int, minSize: Float = 12f): Shape? {
        if (count < 3) return null
        val x0 = pts[0]
        val y0 = pts[1]
        val xn = pts[(count - 1) * 3]
        val yn = pts[(count - 1) * 3 + 1]
        var length = 0f
        for (i in 1 until count) {
            length += hypot(pts[i * 3] - pts[(i - 1) * 3], pts[i * 3 + 1] - pts[(i - 1) * 3 + 1])
        }
        if (length < minSize) return null
        val chord = hypot(xn - x0, yn - y0)

        // Straight line: every sample stays close to the chord.
        if (chord > 0.7f * length) {
            var maxDev = 0f
            for (i in 0 until count) {
                maxDev = max(maxDev, distanceToSegment(pts[i * 3], pts[i * 3 + 1], x0, y0, xn, yn))
            }
            if (maxDev < max(6f, chord * 0.06f)) return Line(x0, y0, xn, yn)
            return null
        }

        // Closed loop: fit an ellipse along the principal axes.
        if (chord < 0.25f * length) {
            var mx = 0.0
            var my = 0.0
            for (i in 0 until count) {
                mx += pts[i * 3]
                my += pts[i * 3 + 1]
            }
            mx /= count
            my /= count
            var sxx = 0.0
            var syy = 0.0
            var sxy = 0.0
            for (i in 0 until count) {
                val dx = pts[i * 3] - mx
                val dy = pts[i * 3 + 1] - my
                sxx += dx * dx
                syy += dy * dy
                sxy += dx * dy
            }
            val angle = 0.5 * atan2(2 * sxy, sxx - syy)
            val ca = cos(angle)
            val sa = sin(angle)
            var minU = Double.MAX_VALUE
            var maxU = -Double.MAX_VALUE
            var minV = Double.MAX_VALUE
            var maxV = -Double.MAX_VALUE
            for (i in 0 until count) {
                val dx = pts[i * 3] - mx
                val dy = pts[i * 3 + 1] - my
                val u = dx * ca + dy * sa
                val v = -dx * sa + dy * ca
                minU = minOf(minU, u); maxU = maxOf(maxU, u)
                minV = minOf(minV, v); maxV = maxOf(maxV, v)
            }
            val rx = ((maxU - minU) / 2).toFloat()
            val ry = ((maxV - minV) / 2).toFloat()
            if (rx < minSize / 2 || ry < minSize / 4) return null
            val cu = (maxU + minU) / 2
            val cv = (maxV + minV) / 2
            val cx = (mx + cu * ca - cv * sa).toFloat()
            val cy = (my + cu * sa + cv * ca).toFloat()
            // Check the samples actually lie near the ellipse.
            var err = 0.0
            for (i in 0 until count) {
                val dx = pts[i * 3] - cx
                val dy = pts[i * 3 + 1] - cy
                val u = (dx * ca + dy * sa) / rx
                val v = (-dx * sa + dy * ca) / ry
                err += abs(sqrt(u * u + v * v) - 1.0)
            }
            err /= count
            if (err > 0.16) return null
            return Ellipse(cx, cy, rx, ry, angle.toFloat())
        }
        return null
    }

    fun distanceToSegment(px: Float, py: Float, ax: Float, ay: Float, bx: Float, by: Float): Float {
        val dx = bx - ax
        val dy = by - ay
        val len2 = dx * dx + dy * dy
        if (len2 == 0f) return hypot(px - ax, py - ay)
        val t = (((px - ax) * dx + (py - ay) * dy) / len2).coerceIn(0f, 1f)
        return hypot(px - (ax + t * dx), py - (ay + t * dy))
    }
}
