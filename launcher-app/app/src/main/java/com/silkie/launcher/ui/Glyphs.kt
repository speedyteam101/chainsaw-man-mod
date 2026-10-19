package com.silkie.launcher.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.drawable.Drawable
import android.view.View
import kotlin.math.cos
import kotlin.math.sin

enum class Glyph { SEARCH, SETTINGS, STAR, STAR_FILLED, GRID, LIST, CAROUSEL, PLUS, GAMEPAD, HOME, APPS, MORE, TRASH, EDIT, PLAY, CLOCK, SORT, WIDGET, CHEVRON }

/** Simple line icons drawn on a 24×24 grid, so the app needs no image assets. */
class GlyphDrawable(val glyph: Glyph, color: Int) : Drawable() {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        this.color = color
    }
    private val path = Path()
    private val rect = RectF()

    var color: Int
        get() = paint.color
        set(value) {
            paint.color = value
            invalidateSelf()
        }

    override fun draw(canvas: Canvas) {
        val b = bounds
        val s = minOf(b.width(), b.height()) / 24f
        canvas.save()
        canvas.translate(b.exactCenterX() - 12 * s, b.exactCenterY() - 12 * s)
        canvas.scale(s, s)
        paint.strokeWidth = 2f
        paint.style = Paint.Style.STROKE
        path.reset()
        when (glyph) {
            Glyph.SEARCH -> {
                canvas.drawCircle(10.5f, 10.5f, 6f, paint)
                canvas.drawLine(15f, 15f, 20f, 20f, paint)
            }
            Glyph.SETTINGS -> {
                canvas.drawCircle(12f, 12f, 3f, paint)
                for (i in 0 until 8) {
                    val a = Math.PI * i / 4
                    canvas.drawLine(12 + 6 * cos(a).toFloat(), 12 + 6 * sin(a).toFloat(), 12 + 8.5f * cos(a).toFloat(), 12 + 8.5f * sin(a).toFloat(), paint)
                }
                canvas.drawCircle(12f, 12f, 6f, paint)
            }
            Glyph.STAR, Glyph.STAR_FILLED -> {
                for (i in 0 until 10) {
                    val r = if (i % 2 == 0) 9f else 4f
                    val a = -Math.PI / 2 + Math.PI * i / 5
                    val x = 12 + r * cos(a).toFloat()
                    val y = 12.5f + r * sin(a).toFloat()
                    if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
                }
                path.close()
                if (glyph == Glyph.STAR_FILLED) paint.style = Paint.Style.FILL_AND_STROKE
                canvas.drawPath(path, paint)
            }
            Glyph.GRID -> for (x in 0..1) for (y in 0..1) {
                rect.set(4f + x * 9, 4f + y * 9, 11f + x * 9, 11f + y * 9)
                canvas.drawRoundRect(rect, 1.5f, 1.5f, paint)
            }
            Glyph.LIST -> for (i in 0..2) {
                canvas.drawCircle(5f, 6f + i * 6, 0.6f, paint)
                canvas.drawLine(9f, 6f + i * 6, 20f, 6f + i * 6, paint)
            }
            Glyph.CAROUSEL -> {
                rect.set(7f, 5f, 17f, 19f)
                canvas.drawRoundRect(rect, 2f, 2f, paint)
                canvas.drawLine(3f, 8f, 3f, 16f, paint)
                canvas.drawLine(21f, 8f, 21f, 16f, paint)
            }
            Glyph.PLUS -> {
                canvas.drawLine(12f, 5f, 12f, 19f, paint)
                canvas.drawLine(5f, 12f, 19f, 12f, paint)
            }
            Glyph.GAMEPAD -> {
                rect.set(2.5f, 7f, 21.5f, 18f)
                canvas.drawRoundRect(rect, 5.5f, 5.5f, paint)
                canvas.drawLine(7f, 10.5f, 7f, 14.5f, paint)
                canvas.drawLine(5f, 12.5f, 9f, 12.5f, paint)
                canvas.drawCircle(15.5f, 11.5f, 0.8f, paint)
                canvas.drawCircle(17.5f, 13.8f, 0.8f, paint)
            }
            Glyph.HOME -> {
                path.moveTo(4f, 11f); path.lineTo(12f, 4f); path.lineTo(20f, 11f)
                path.moveTo(6f, 9.5f); path.lineTo(6f, 20f); path.lineTo(18f, 20f); path.lineTo(18f, 9.5f)
                canvas.drawPath(path, paint)
            }
            Glyph.APPS -> {
                paint.style = Paint.Style.FILL
                for (x in 0..2) for (y in 0..2) canvas.drawCircle(6f + x * 6, 6f + y * 6, 1.7f, paint)
            }
            Glyph.MORE -> {
                paint.style = Paint.Style.FILL
                for (i in 0..2) canvas.drawCircle(6f + i * 6, 12f, 1.8f, paint)
            }
            Glyph.TRASH -> {
                canvas.drawLine(4f, 7f, 20f, 7f, paint)
                path.moveTo(6.5f, 7f); path.lineTo(7.5f, 20f); path.lineTo(16.5f, 20f); path.lineTo(17.5f, 7f)
                path.moveTo(9.5f, 7f); path.lineTo(10f, 4f); path.lineTo(14f, 4f); path.lineTo(14.5f, 7f)
                canvas.drawPath(path, paint)
            }
            Glyph.EDIT -> {
                path.moveTo(4f, 20f); path.lineTo(5f, 15.5f); path.lineTo(15.5f, 5f); path.lineTo(19f, 8.5f)
                path.lineTo(8.5f, 19f); path.close()
                canvas.drawPath(path, paint)
            }
            Glyph.PLAY -> {
                path.moveTo(8f, 5f); path.lineTo(19f, 12f); path.lineTo(8f, 19f); path.close()
                paint.style = Paint.Style.FILL_AND_STROKE
                canvas.drawPath(path, paint)
            }
            Glyph.CLOCK -> {
                canvas.drawCircle(12f, 12f, 8.5f, paint)
                canvas.drawLine(12f, 12f, 12f, 7f, paint)
                canvas.drawLine(12f, 12f, 15.5f, 14f, paint)
            }
            Glyph.SORT -> {
                canvas.drawLine(4f, 7f, 20f, 7f, paint)
                canvas.drawLine(7f, 12f, 17f, 12f, paint)
                canvas.drawLine(10f, 17f, 14f, 17f, paint)
            }
            Glyph.WIDGET -> {
                rect.set(3.5f, 3.5f, 11f, 11f); canvas.drawRoundRect(rect, 2f, 2f, paint)
                rect.set(13f, 3.5f, 20.5f, 11f); canvas.drawRoundRect(rect, 2f, 2f, paint)
                rect.set(3.5f, 13f, 20.5f, 20.5f); canvas.drawRoundRect(rect, 2f, 2f, paint)
            }
            Glyph.CHEVRON -> {
                path.moveTo(9f, 5f); path.lineTo(16f, 12f); path.lineTo(9f, 19f)
                canvas.drawPath(path, paint)
            }
        }
        canvas.restore()
    }

    override fun setAlpha(alpha: Int) {
        paint.alpha = alpha
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
        paint.colorFilter = colorFilter
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity() = PixelFormat.TRANSLUCENT
}

/** A round, focusable icon button for top bars and headers. */
fun Context.glyphButton(pal: Palette, glyph: Glyph, description: String, sizeDp: Int = 44, onClick: (View) -> Unit): View =
    View(this).apply {
        val g = GlyphDrawable(glyph, pal.text)
        val pad = dp(sizeDp) / 4
        foreground = null
        background = rippleOver(pal.ripple, -1f, android.graphics.drawable.InsetDrawable(g, pad))
        contentDescription = description
        isClickable = true
        isFocusable = true
        layoutParams = lp(dp(sizeDp), dp(sizeDp))
        setOnClickListener(onClick)
        focusHighlight(pal, 1.1f, dp(sizeDp / 2f))
    }
