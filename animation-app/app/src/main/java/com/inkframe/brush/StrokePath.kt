package com.inkframe.brush

import java.util.Random
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** A single stamp: position, diameter, opacity (0..1), rotation in degrees, and distance along the stroke. */
class Dab(val x: Float, val y: Float, val size: Float, val alpha: Float, val angle: Float, val distance: Float)

/**
 * Turns raw pen samples into evenly spaced stamps.
 *
 * Pipeline: StreamLine smoothing (the drawn point trails the pen, removing jitter) ->
 * quadratic curves through the midpoints of the smoothed points (no corners) ->
 * stamps every `spacing * size` pixels with size and opacity from the interpolated pressure.
 *
 * Pure Kotlin so it can be unit tested on the JVM.
 */
class StrokePath(
    private val spec: BrushSpec,
    private val baseSize: Float,
    seed: Long,
    private val smoothing: Boolean = true,
    private val emit: (Dab) -> Unit,
) {
    private val random = Random(seed)

    /** Raw input, 3 floats per sample (x, y, pressure); used by QuickShape. */
    var raw = FloatArray(96)
        private set
    var rawCount = 0
        private set

    private var sx = 0f
    private var sy = 0f
    private var sp = 0f

    // Quadratic midpoint scheme: the last curve ended at (mx, my); (cx, cy) is the next control point.
    private var mx = 0f
    private var my = 0f
    private var mp = 0f
    private var cx = 0f
    private var cy = 0f
    private var cp = 0f

    private var travelled = 0f
    private var sinceLast = 0f
    private var lastAngle = 0f
    private var started = false

    /** Total length of the stroke so far, in canvas pixels. */
    val length: Float get() = travelled

    fun begin(x: Float, y: Float, pressure: Float) {
        val p = pressure.coerceIn(0f, 1f)
        pushRaw(x, y, p)
        sx = x; sy = y; sp = p
        mx = x; my = y; mp = p
        cx = x; cy = y; cp = p
        travelled = 0f
        started = true
        stamp(x, y, p, 0f)
        sinceLast = 0f
    }

    fun add(x: Float, y: Float, pressure: Float) {
        if (!started) return begin(x, y, pressure)
        val p = pressure.coerceIn(0f, 1f)
        pushRaw(x, y, p)
        feed(x, y, p)
    }

    /** Lets the smoothed position catch up with the pen, then draws the last piece. */
    fun finish() {
        if (!started) return
        if (smoothing && spec.streamline > 0f && rawCount > 0) {
            val lx = raw[(rawCount - 1) * 3]
            val ly = raw[(rawCount - 1) * 3 + 1]
            val lp = raw[(rawCount - 1) * 3 + 2]
            var guard = 0
            while (hypot(lx - sx, ly - sy) > 0.5f && guard++ < 40) feed(lx, ly, lp)
        }
        line(mx, my, mp, cx, cy, cp)
        mx = cx; my = cy; mp = cp
        started = false
    }

    private fun feed(x: Float, y: Float, p: Float) {
        if (smoothing) {
            val k = 1f - spec.streamline.coerceIn(0f, 1f) * 0.92f
            sx += (x - sx) * k
            sy += (y - sy) * k
            sp += (p - sp) * min(1f, k * 1.5f)
        } else {
            sx = x; sy = y; sp = p
        }
        if (hypot(sx - cx, sy - cy) < 0.35f) {
            cp = sp
            return
        }
        val nmx = (cx + sx) / 2f
        val nmy = (cy + sy) / 2f
        val nmp = (cp + sp) / 2f
        quad(mx, my, mp, cx, cy, nmx, nmy, nmp)
        mx = nmx; my = nmy; mp = nmp
        cx = sx; cy = sy; cp = sp
    }

    private fun quad(x0: Float, y0: Float, p0: Float, qx: Float, qy: Float, x1: Float, y1: Float, p1: Float) {
        val approx = (hypot(qx - x0, qy - y0) + hypot(x1 - qx, y1 - qy) + hypot(x1 - x0, y1 - y0)) / 2f
        val steps = max(1, min(256, ceil(approx / 1.5f).toInt()))
        var px = x0
        var py = y0
        var pp = p0
        for (i in 1..steps) {
            val t = i / steps.toFloat()
            val u = 1f - t
            val nx = u * u * x0 + 2f * u * t * qx + t * t * x1
            val ny = u * u * y0 + 2f * u * t * qy + t * t * y1
            val np = p0 + (p1 - p0) * t
            line(px, py, pp, nx, ny, np)
            px = nx; py = ny; pp = np
        }
    }

    private fun line(x0: Float, y0: Float, p0: Float, x1: Float, y1: Float, p1: Float) {
        val len = hypot(x1 - x0, y1 - y0)
        if (len <= 0f) return
        lastAngle = Math.toDegrees(atan2((y1 - y0).toDouble(), (x1 - x0).toDouble())).toFloat()
        var pos = 0f
        while (true) {
            val p = p0 + (p1 - p0) * (pos / len)
            val step = max(0.3f, sizeAt(p, travelled + pos) * spec.spacing)
            val need = step - sinceLast
            if (pos + need > len) {
                sinceLast += len - pos
                break
            }
            pos += need
            sinceLast = 0f
            val t = pos / len
            stamp(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, p0 + (p1 - p0) * t, travelled + pos)
        }
        travelled += len
    }

    private fun pressureScale(p: Float) = 1f - spec.pressureSize + spec.pressureSize * p

    fun taperLength(taper: Float) = taper * (baseSize * 4f + 40f)

    private fun startTaper(distance: Float): Float {
        if (spec.taperStart <= 0f) return 1f
        val t = (distance / taperLength(spec.taperStart)).coerceIn(0f, 1f)
        return 0.12f + 0.88f * t * t * (3f - 2f * t)
    }

    private fun sizeAt(p: Float, distance: Float) = baseSize * pressureScale(p) * startTaper(distance)

    private fun stamp(x: Float, y: Float, p: Float, distance: Float) {
        var size = sizeAt(p, distance)
        if (spec.sizeJitter > 0f) size *= 1f - spec.sizeJitter * random.nextFloat()
        var alpha = spec.flow * (1f - spec.pressureOpacity + spec.pressureOpacity * p)
        if (spec.opacityJitter > 0f) alpha *= 1f - spec.opacityJitter * random.nextFloat()
        var dx = x
        var dy = y
        if (spec.scatter > 0f) {
            val r = spec.scatter * size * random.nextFloat()
            val a = random.nextFloat() * 6.2831855f
            dx += r * cos(a)
            dy += r * sin(a)
        }
        val angle = when {
            spec.followDirection -> lastAngle
            spec.rotationJitter > 0f -> spec.angle + spec.rotationJitter * 360f * random.nextFloat()
            else -> spec.angle
        }
        emit(Dab(dx, dy, size, alpha.coerceIn(0f, 1f), angle, distance))
    }

    private fun pushRaw(x: Float, y: Float, p: Float) {
        if (rawCount * 3 + 3 > raw.size) raw = raw.copyOf(raw.size * 2)
        raw[rawCount * 3] = x
        raw[rawCount * 3 + 1] = y
        raw[rawCount * 3 + 2] = p
        rawCount++
    }

    companion object {
        /** Size multiplier near the end of a stroke of [total] length (applied after the pen lifts). */
        fun endTaper(spec: BrushSpec, baseSize: Float, distance: Float, total: Float): Float {
            if (spec.taperEnd <= 0f) return 1f
            val len = spec.taperEnd * (baseSize * 4f + 40f)
            val t = ((total - distance) / len).coerceIn(0f, 1f)
            return 0.12f + 0.88f * t * t * (3f - 2f * t)
        }
    }
}
