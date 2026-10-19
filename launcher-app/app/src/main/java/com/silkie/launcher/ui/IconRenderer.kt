package com.silkie.launcher.ui

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.CornerPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import com.silkie.launcher.settings.IconShape
import com.silkie.launcher.settings.Prefs
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sign
import kotlin.math.sin

/** How icons are drawn; part of the cache key so a settings change re-renders them. */
data class IconStyle(
    val shape: IconShape,
    val themed: Boolean,
    val plate: Boolean,
    val outline: Boolean,
    val grayscale: Boolean,
    val plateColor: Int,
    val tintColor: Int,
    val outlineColor: Int,
) {
    companion object {
        fun from(p: Prefs, pal: Palette) = IconStyle(
            p.iconShape, p.themedIcons, p.legacyIconPlate, p.iconOutline, p.grayscaleIcons,
            plateColor = if (p.themedIcons) pal.cardRaised else 0xFFFFFFFF.toInt(),
            tintColor = pal.accent,
            outlineColor = ColorMath.withAlpha(pal.text, 0.35f),
        )
    }
}

/**
 * Renders app icons into shaped bitmaps off the main thread and caches them.
 * Adaptive icons are re-composed from their layers so every shape looks native.
 */
class IconRenderer {
    private val cache = object : LruCache<String, Bitmap>((Runtime.getRuntime().maxMemory() / 1024 / 8).toInt()) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount / 1024
    }
    private val executor = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())

    fun cached(key: String, size: Int, style: IconStyle): Bitmap? = cache.get(cacheKey(key, size, style))

    /** Loads [drawable] (called on a worker thread), renders it and hands the bitmap to [done] on the main thread. */
    fun request(key: String, size: Int, style: IconStyle, drawable: () -> Drawable?, done: (Bitmap) -> Unit) {
        val ck = cacheKey(key, size, style)
        cache.get(ck)?.let { done(it); return }
        executor.execute {
            val d = runCatching { drawable() }.getOrNull() ?: return@execute
            val bmp = runCatching { render(d, size, style) }.getOrNull() ?: return@execute
            cache.put(ck, bmp)
            main.post { done(bmp) }
        }
    }

    fun clear() = cache.evictAll()

    private fun cacheKey(key: String, size: Int, style: IconStyle) = "$key|$size|${style.hashCode()}"

    fun render(d: Drawable, size: Int, style: IconStyle): Bitmap {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val s = size.toFloat()

        if (style.shape == IconShape.ORIGINAL) {
            d.setBounds(0, 0, size, size)
            d.draw(c)
            if (style.grayscale) desaturate(bmp)
            return bmp
        }

        val shape = Shapes.path(style.shape, s)
        val layer = c.saveLayer(0f, 0f, s, s, null)
        if (d is AdaptiveIconDrawable) {
            // Layers are 108dp with the visible 72dp in the middle, so draw them 1.5× and centered.
            val extra = (size / 4f).toInt()
            val mono = if (style.themed && Build.VERSION.SDK_INT >= 33) d.monochrome else null
            if (mono != null) {
                c.drawColor(style.plateColor)
                mono.mutate().setTint(style.tintColor)
                mono.setBounds(-extra, -extra, size + extra, size + extra)
                mono.draw(c)
            } else {
                d.background?.let { it.setBounds(-extra, -extra, size + extra, size + extra); it.draw(c) }
                d.foreground?.let { it.setBounds(-extra, -extra, size + extra, size + extra); it.draw(c) }
            }
        } else if (style.plate) {
            // Legacy (non-adaptive) icon: put it on a plate so it still fills the shape.
            c.drawColor(style.plateColor)
            val inset = (size * 0.16f).toInt()
            d.setBounds(inset, inset, size - inset, size - inset)
            d.draw(c)
        } else {
            d.setBounds(0, 0, size, size)
            d.draw(c)
        }
        // Keep only what is inside the shape, with anti-aliased edges.
        val mask = Paint(Paint.ANTI_ALIAS_FLAG).apply { xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN) }
        mask.pathEffect = Shapes.effect(style.shape, s)
        c.drawPath(shape, mask)
        c.restoreToCount(layer)

        if (style.outline) {
            val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.style = Paint.Style.STROKE
                strokeWidth = s * 0.03f
                color = style.outlineColor
                pathEffect = Shapes.effect(style.shape, s)
            }
            val inset = Shapes.path(style.shape, s - p.strokeWidth).apply { offset(p.strokeWidth / 2, p.strokeWidth / 2) }
            c.drawPath(inset, p)
        }
        if (style.grayscale) desaturate(bmp)
        return bmp
    }

    private fun desaturate(bmp: Bitmap) {
        val c = Canvas(bmp)
        val p = Paint().apply {
            colorFilter = ColorMatrixColorFilter(ColorMatrix().apply { setSaturation(0f) })
            xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC)
        }
        val copy = bmp.copy(Bitmap.Config.ARGB_8888, false)
        c.drawBitmap(copy, 0f, 0f, p)
        copy.recycle()
    }
}

/** Icon outlines in a square of side [s]. */
object Shapes {
    fun path(shape: IconShape, s: Float): Path = Path().apply {
        val r = s / 2
        when (shape) {
            IconShape.ORIGINAL, IconShape.SQUARE -> addRect(0f, 0f, s, s, Path.Direction.CW)
            IconShape.CIRCLE -> addCircle(r, r, r, Path.Direction.CW)
            IconShape.ROUNDED -> addRoundRect(RectF(0f, 0f, s, s), s * 0.22f, s * 0.22f, Path.Direction.CW)
            IconShape.SQUIRCLE -> {
                // Superellipse |x|^4 + |y|^4 = r^4
                val n = 96
                for (i in 0 until n) {
                    val t = 2 * Math.PI * i / n
                    val ct = cos(t)
                    val st = sin(t)
                    val x = r + r * sign(ct) * abs(ct).pow(0.5)
                    val y = r + r * sign(st) * abs(st).pow(0.5)
                    if (i == 0) moveTo(x.toFloat(), y.toFloat()) else lineTo(x.toFloat(), y.toFloat())
                }
                close()
            }
            IconShape.TEARDROP -> {
                val k = s * 0.12f
                addRoundRect(RectF(0f, 0f, s, s), floatArrayOf(r, r, r, r, k, k, r, r), Path.Direction.CW)
            }
            IconShape.HEXAGON -> polygon(6, r, Math.PI / 6)
            IconShape.OCTAGON -> polygon(8, r / cos(Math.PI / 8).toFloat(), Math.PI / 8)
            IconShape.DIAMOND -> polygon(4, r, 0.0)
            IconShape.CLOVER -> {
                val lobe = s * 0.29f
                addCircle(r, lobe, lobe, Path.Direction.CW)
                addCircle(r, s - lobe, lobe, Path.Direction.CW)
                addCircle(lobe, r, lobe, Path.Direction.CW)
                addCircle(s - lobe, r, lobe, Path.Direction.CW)
                addCircle(r, r, s * 0.3f, Path.Direction.CW)
            }
        }
    }

    /** Polygons get softly rounded corners. */
    fun effect(shape: IconShape, s: Float): CornerPathEffect? = when (shape) {
        IconShape.HEXAGON, IconShape.OCTAGON, IconShape.DIAMOND -> CornerPathEffect(s * 0.12f)
        else -> null
    }

    private fun Path.polygon(sides: Int, radius: Float, start: Double) {
        // Centered in a square of side 2 * (the shape's half-size); clamp so octagon fills the square.
        val c = radius.coerceAtLeast(0f)
        val half = if (sides == 8) radius * cos(Math.PI / 8).toFloat() else radius
        for (i in 0 until sides) {
            val a = start + 2 * Math.PI * i / sides
            val x = half + c * cos(a).toFloat()
            val y = half + c * sin(a).toFloat()
            if (i == 0) moveTo(x, y) else lineTo(x, y)
        }
        close()
    }
}
