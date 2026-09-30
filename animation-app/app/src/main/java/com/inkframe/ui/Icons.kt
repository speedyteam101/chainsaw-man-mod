package com.inkframe.ui

import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.drawable.Drawable

enum class Icon {
    GALLERY, ACTIONS, TRANSFORM, BRUSH, ERASER, FILL, LAYERS, UNDO, REDO, PLAY, PAUSE, PLUS, MINUS,
    SETTINGS, EXPORT, EYEDROPPER, EYE, EYE_OFF, CHECK, CLOSE, FLIP_H, FLIP_V, ROTATE, TRASH, DUPLICATE,
    CHEVRON_LEFT, CHEVRON_RIGHT, CHEVRON_UP, CHEVRON_DOWN, ALPHA_LOCK, IMAGE, SHARE, DOWNLOAD, MORE,
    FIT, MERGE, RENAME, HELP, FOLDER,
}

/**
 * Line icons drawn with canvas primitives on a 24x24 grid, so they stay crisp at any size
 * and need no image assets.
 */
class IconDrawable(val icon: Icon, color: Int) : Drawable() {
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1.7f
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        this.color = color
    }
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        this.color = color
    }
    private val path = Path()
    private val rect = RectF()

    var color: Int
        get() = stroke.color
        set(value) {
            stroke.color = value
            fill.color = value
            invalidateSelf()
        }

    override fun draw(canvas: Canvas) {
        val b = bounds
        val s = minOf(b.width(), b.height()) / 24f
        canvas.save()
        canvas.translate(b.exactCenterX() - 12f * s, b.exactCenterY() - 12f * s)
        canvas.scale(s, s)
        drawIcon(canvas)
        canvas.restore()
    }

    private fun line(c: Canvas, x0: Float, y0: Float, x1: Float, y1: Float) = c.drawLine(x0, y0, x1, y1, stroke)

    private fun poly(c: Canvas, close: Boolean, vararg p: Float, paint: Paint = stroke) {
        path.reset()
        path.moveTo(p[0], p[1])
        var i = 2
        while (i + 1 < p.size) {
            path.lineTo(p[i], p[i + 1])
            i += 2
        }
        if (close) path.close()
        c.drawPath(path, paint)
    }

    private fun roundRect(c: Canvas, l: Float, t: Float, r: Float, b: Float, radius: Float, paint: Paint = stroke) {
        rect.set(l, t, r, b)
        c.drawRoundRect(rect, radius, radius, paint)
    }

    private fun arc(c: Canvas, cx: Float, cy: Float, r: Float, start: Float, sweep: Float) {
        rect.set(cx - r, cy - r, cx + r, cy + r)
        c.drawArc(rect, start, sweep, false, stroke)
    }

    private fun drawIcon(c: Canvas) {
        when (icon) {
            Icon.GALLERY -> {
                roundRect(c, 4f, 4f, 10.5f, 10.5f, 1.8f)
                roundRect(c, 13.5f, 4f, 20f, 10.5f, 1.8f)
                roundRect(c, 4f, 13.5f, 10.5f, 20f, 1.8f)
                roundRect(c, 13.5f, 13.5f, 20f, 20f, 1.8f)
            }
            Icon.ACTIONS -> { // wrench
                arc(c, 15.5f, 8.5f, 4.3f, -10f, 290f)
                val w = stroke.strokeWidth
                stroke.strokeWidth = 2.6f
                line(c, 12.4f, 11.6f, 5f, 19f)
                stroke.strokeWidth = w
            }
            Icon.TRANSFORM -> poly(c, true, 6f, 3.5f, 6f, 18f, 9.8f, 14.6f, 12.6f, 20.5f, 15.2f, 19.3f, 12.4f, 13.4f, 17.2f, 13.2f)
            Icon.BRUSH -> {
                line(c, 20f, 4f, 12.5f, 11.5f)
                poly(c, false, 11.6f, 10.4f, 13.6f, 12.4f)
                path.reset()
                path.moveTo(11.2f, 12.6f)
                path.cubicTo(8.3f, 12.4f, 7f, 14.4f, 7f, 16.5f)
                path.cubicTo(7f, 18.4f, 5.8f, 19.4f, 4.2f, 19.8f)
                path.cubicTo(7.2f, 21.2f, 12.6f, 20.4f, 12.6f, 15.8f)
                path.close()
                c.drawPath(path, stroke)
            }
            Icon.ERASER -> {
                poly(c, true, 9f, 19.5f, 4.5f, 15f, 14f, 5.5f, 19.5f, 11f, 11f, 19.5f)
                line(c, 9.3f, 10.2f, 14.8f, 15.7f)
                line(c, 11f, 19.5f, 20f, 19.5f)
            }
            Icon.FILL -> {
                poly(c, true, 4.5f, 11f, 11f, 4.5f, 18f, 11.5f, 11.5f, 18f)
                line(c, 8.5f, 3.5f, 11f, 6f)
                line(c, 5f, 11.5f, 17.5f, 11.5f)
                c.drawCircle(19.5f, 17.2f, 1.7f, fill)
                poly(c, true, 19.5f, 13.2f, 18.1f, 16.6f, 20.9f, 16.6f, paint = fill)
            }
            Icon.LAYERS -> {
                poly(c, true, 12f, 4f, 20f, 8.3f, 12f, 12.6f, 4f, 8.3f)
                poly(c, false, 4f, 12f, 12f, 16.3f, 20f, 12f)
                poly(c, false, 4f, 15.7f, 12f, 20f, 20f, 15.7f)
            }
            Icon.UNDO -> {
                poly(c, false, 8.5f, 6.5f, 4.5f, 10.5f, 8.5f, 14.5f)
                path.reset()
                path.moveTo(4.5f, 10.5f)
                path.lineTo(14f, 10.5f)
                path.cubicTo(17.6f, 10.5f, 20f, 13f, 20f, 16f)
                path.cubicTo(20f, 17.2f, 19.7f, 18.2f, 19.2f, 19f)
                c.drawPath(path, stroke)
            }
            Icon.REDO -> {
                c.save(); c.scale(-1f, 1f, 12f, 12f)
                poly(c, false, 8.5f, 6.5f, 4.5f, 10.5f, 8.5f, 14.5f)
                path.reset()
                path.moveTo(4.5f, 10.5f)
                path.lineTo(14f, 10.5f)
                path.cubicTo(17.6f, 10.5f, 20f, 13f, 20f, 16f)
                path.cubicTo(20f, 17.2f, 19.7f, 18.2f, 19.2f, 19f)
                c.drawPath(path, stroke)
                c.restore()
            }
            Icon.PLAY -> poly(c, true, 8f, 5f, 19f, 12f, 8f, 19f, paint = fill)
            Icon.PAUSE -> {
                roundRect(c, 6.5f, 5f, 10f, 19f, 1f, fill)
                roundRect(c, 14f, 5f, 17.5f, 19f, 1f, fill)
            }
            Icon.PLUS -> {
                line(c, 12f, 5f, 12f, 19f)
                line(c, 5f, 12f, 19f, 12f)
            }
            Icon.MINUS -> line(c, 5f, 12f, 19f, 12f)
            Icon.SETTINGS -> {
                line(c, 4f, 7f, 20f, 7f); line(c, 4f, 12f, 20f, 12f); line(c, 4f, 17f, 20f, 17f)
                for ((x, y) in listOf(9f to 7f, 15.5f to 12f, 11f to 17f)) {
                    c.drawCircle(x, y, 2.4f, fill)
                }
            }
            Icon.EXPORT, Icon.SHARE -> {
                poly(c, false, 8.5f, 9.5f, 6f, 9.5f, 6f, 20f, 18f, 20f, 18f, 9.5f, 15.5f, 9.5f)
                line(c, 12f, 14.5f, 12f, 3.5f)
                poly(c, false, 8.5f, 7f, 12f, 3.5f, 15.5f, 7f)
            }
            Icon.DOWNLOAD -> {
                poly(c, false, 5f, 15f, 5f, 19.5f, 19f, 19.5f, 19f, 15f)
                line(c, 12f, 4f, 12f, 15f)
                poly(c, false, 8f, 11f, 12f, 15f, 16f, 11f)
            }
            Icon.EYEDROPPER -> {
                val w = stroke.strokeWidth
                stroke.strokeWidth = 2.2f
                line(c, 5f, 19f, 13.2f, 10.8f)
                stroke.strokeWidth = w
                c.drawCircle(16.6f, 7.4f, 3f, fill)
                line(c, 11.5f, 8f, 16f, 12.5f)
            }
            Icon.EYE, Icon.EYE_OFF -> {
                path.reset()
                path.moveTo(2.8f, 12f)
                path.cubicTo(6f, 6.2f, 18f, 6.2f, 21.2f, 12f)
                path.cubicTo(18f, 17.8f, 6f, 17.8f, 2.8f, 12f)
                path.close()
                c.drawPath(path, stroke)
                c.drawCircle(12f, 12f, 2.8f, stroke)
                if (icon == Icon.EYE_OFF) line(c, 4.5f, 4.5f, 19.5f, 19.5f)
            }
            Icon.CHECK -> poly(c, false, 5f, 12.5f, 10f, 17.5f, 19f, 7f)
            Icon.CLOSE -> {
                line(c, 6f, 6f, 18f, 18f)
                line(c, 18f, 6f, 6f, 18f)
            }
            Icon.FLIP_H -> drawFlip(c)
            Icon.FLIP_V -> {
                c.save(); c.rotate(90f, 12f, 12f); drawFlip(c); c.restore()
            }
            Icon.ROTATE -> {
                arc(c, 12f, 12.5f, 7f, -60f, 300f)
                poly(c, false, 15.2f, 2.8f, 15.6f, 6.6f, 19.3f, 6.6f)
            }
            Icon.TRASH -> {
                line(c, 4.5f, 6.5f, 19.5f, 6.5f)
                poly(c, false, 9.5f, 6.5f, 9.5f, 4f, 14.5f, 4f, 14.5f, 6.5f)
                poly(c, false, 6.5f, 6.5f, 7.5f, 20f, 16.5f, 20f, 17.5f, 6.5f)
                line(c, 10.3f, 10f, 10.3f, 16.5f)
                line(c, 13.7f, 10f, 13.7f, 16.5f)
            }
            Icon.DUPLICATE -> {
                roundRect(c, 8.5f, 8.5f, 20f, 20f, 2f)
                poly(c, false, 15.5f, 5.5f, 15.5f, 4f, 4f, 4f, 4f, 15.5f, 5.5f, 15.5f)
            }
            Icon.CHEVRON_LEFT -> poly(c, false, 15f, 5f, 8f, 12f, 15f, 19f)
            Icon.CHEVRON_RIGHT -> poly(c, false, 9f, 5f, 16f, 12f, 9f, 19f)
            Icon.CHEVRON_UP -> poly(c, false, 5f, 15f, 12f, 8f, 19f, 15f)
            Icon.CHEVRON_DOWN -> poly(c, false, 5f, 9f, 12f, 16f, 19f, 9f)
            Icon.ALPHA_LOCK -> {
                roundRect(c, 5f, 10.5f, 19f, 20f, 2f)
                arc(c, 12f, 9.5f, 4f, 180f, 180f)
                line(c, 8f, 9.5f, 8f, 10.5f)
                line(c, 16f, 9.5f, 16f, 10.5f)
                c.drawCircle(12f, 15.2f, 1.5f, fill)
            }
            Icon.IMAGE -> {
                roundRect(c, 3.5f, 5f, 20.5f, 19f, 2f)
                poly(c, false, 3.8f, 16.5f, 9f, 11.5f, 13f, 15.5f, 15.5f, 13f, 20.2f, 17.5f)
                c.drawCircle(15.5f, 8.8f, 1.6f, fill)
            }
            Icon.MORE -> {
                c.drawCircle(6f, 12f, 1.6f, fill)
                c.drawCircle(12f, 12f, 1.6f, fill)
                c.drawCircle(18f, 12f, 1.6f, fill)
            }
            Icon.FIT -> {
                poly(c, false, 4f, 9f, 4f, 4f, 9f, 4f)
                poly(c, false, 15f, 4f, 20f, 4f, 20f, 9f)
                poly(c, false, 20f, 15f, 20f, 20f, 15f, 20f)
                poly(c, false, 9f, 20f, 4f, 20f, 4f, 15f)
            }
            Icon.MERGE -> {
                poly(c, false, 7f, 4f, 12f, 9f, 17f, 4f)
                line(c, 12f, 9f, 12f, 14f)
                roundRect(c, 5f, 14f, 19f, 20f, 1.5f)
            }
            Icon.RENAME -> {
                line(c, 4f, 20f, 20f, 20f)
                poly(c, true, 6f, 17.5f, 6.5f, 14f, 15.5f, 5f, 18.5f, 8f, 9.5f, 17f)
            }
            Icon.HELP -> {
                c.drawCircle(12f, 12f, 8.5f, stroke)
                path.reset()
                path.moveTo(9.5f, 9.8f)
                path.cubicTo(9.5f, 6.8f, 14.6f, 6.8f, 14.6f, 9.8f)
                path.cubicTo(14.6f, 11.8f, 12f, 11.8f, 12f, 14f)
                c.drawPath(path, stroke)
                c.drawCircle(12f, 16.9f, 1.1f, fill)
            }
            Icon.FOLDER -> poly(c, true, 3.5f, 6f, 9.5f, 6f, 11.5f, 8f, 20.5f, 8f, 20.5f, 19f, 3.5f, 19f)
        }
    }

    private fun drawFlip(c: Canvas) {
        poly(c, true, 10f, 6f, 10f, 18f, 3.5f, 18f)
        poly(c, true, 14f, 6f, 14f, 18f, 20.5f, 18f, paint = fill)
        val dash = floatArrayOf(2f, 2.2f)
        var y = 3f
        while (y < 21f) {
            line(c, 12f, y, 12f, minOf(21f, y + dash[0]))
            y += dash[0] + dash[1]
        }
    }

    override fun setAlpha(alpha: Int) {
        stroke.alpha = alpha
        fill.alpha = alpha
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
        stroke.colorFilter = colorFilter
        fill.colorFilter = colorFilter
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
}
