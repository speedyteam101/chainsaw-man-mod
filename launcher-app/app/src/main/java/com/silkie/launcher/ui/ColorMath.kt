package com.silkie.launcher.ui

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * ARGB color helpers in plain Kotlin (no android.graphics), so they run in unit tests.
 */
object ColorMath {
    fun alpha(c: Int) = (c ushr 24) and 0xFF
    fun red(c: Int) = (c shr 16) and 0xFF
    fun green(c: Int) = (c shr 8) and 0xFF
    fun blue(c: Int) = c and 0xFF

    fun argb(a: Int, r: Int, g: Int, b: Int): Int =
        (a.coerceIn(0, 255) shl 24) or (r.coerceIn(0, 255) shl 16) or (g.coerceIn(0, 255) shl 8) or b.coerceIn(0, 255)

    fun withAlpha(c: Int, alpha: Float): Int = (c and 0xFFFFFF) or ((alpha.coerceIn(0f, 1f) * 255).roundToInt() shl 24)

    /** Linear blend from [a] (t = 0) to [b] (t = 1), alpha included. */
    fun mix(a: Int, b: Int, t: Float): Int {
        val u = t.coerceIn(0f, 1f)
        fun ch(x: Int, y: Int) = (x + (y - x) * u).roundToInt()
        return argb(ch(alpha(a), alpha(b)), ch(red(a), red(b)), ch(green(a), green(b)), ch(blue(a), blue(b)))
    }

    /** WCAG relative luminance, 0 (black) to 1 (white). */
    fun luminance(c: Int): Double {
        fun lin(v: Int): Double {
            val s = v / 255.0
            return if (s <= 0.03928) s / 12.92 else ((s + 0.055) / 1.055).pow(2.4)
        }
        return 0.2126 * lin(red(c)) + 0.7152 * lin(green(c)) + 0.0722 * lin(blue(c))
    }

    fun contrast(a: Int, b: Int): Double {
        val la = luminance(a)
        val lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    fun isLight(c: Int) = luminance(c) > 0.4

    /** Near-black or white, whichever reads better on [background]. */
    fun readableOn(background: Int): Int {
        val dark = 0xFF141218.toInt()
        val light = 0xFFFFFFFF.toInt()
        return if (contrast(dark, background) >= contrast(light, background)) dark else light
    }

    /** Lighten (positive) or darken (negative) by mixing toward white or black. */
    fun shade(c: Int, amount: Float): Int =
        if (amount >= 0) mix(c, (c and 0xFF000000.toInt()) or 0xFFFFFF, amount)
        else mix(c, c and 0xFF000000.toInt(), -amount)

    /** "#RRGGBB" or "#AARRGGBB" (the # is optional). Returns null when it doesn't parse. */
    fun parseHex(text: String): Int? {
        val s = text.trim().removePrefix("#")
        if (s.length != 6 && s.length != 8) return null
        val v = s.toLongOrNull(16) ?: return null
        return if (s.length == 6) (0xFF000000L or v).toInt() else v.toInt()
    }

    fun toHex(c: Int, withAlpha: Boolean = false): String =
        if (withAlpha || alpha(c) != 255) "#%08X".format(c) else "#%06X".format(c and 0xFFFFFF)

    /** HSV with hue 0..360 and saturation/value 0..1. */
    fun toHsv(c: Int): FloatArray {
        val r = red(c) / 255f
        val g = green(c) / 255f
        val b = blue(c) / 255f
        val mx = max(r, max(g, b))
        val mn = min(r, min(g, b))
        val d = mx - mn
        var h = when {
            d == 0f -> 0f
            mx == r -> 60f * (((g - b) / d) % 6f)
            mx == g -> 60f * ((b - r) / d + 2f)
            else -> 60f * ((r - g) / d + 4f)
        }
        if (h < 0) h += 360f
        val s = if (mx == 0f) 0f else d / mx
        return floatArrayOf(h, s, mx)
    }

    fun fromHsv(h: Float, s: Float, v: Float, alpha: Int = 255): Int {
        val hh = ((h % 360f) + 360f) % 360f
        val ss = s.coerceIn(0f, 1f)
        val vv = v.coerceIn(0f, 1f)
        val c = vv * ss
        val x = c * (1 - abs((hh / 60f) % 2f - 1))
        val m = vv - c
        val (r, g, b) = when {
            hh < 60 -> Triple(c, x, 0f)
            hh < 120 -> Triple(x, c, 0f)
            hh < 180 -> Triple(0f, c, x)
            hh < 240 -> Triple(0f, x, c)
            hh < 300 -> Triple(x, 0f, c)
            else -> Triple(c, 0f, x)
        }
        return argb(alpha, ((r + m) * 255).roundToInt(), ((g + m) * 255).roundToInt(), ((b + m) * 255).roundToInt())
    }
}
