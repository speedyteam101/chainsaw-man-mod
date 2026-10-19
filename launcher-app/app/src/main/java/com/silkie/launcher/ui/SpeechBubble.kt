package com.silkie.launcher.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.util.TypedValue
import android.widget.TextView

/** The mascot's speech bubble. Text types itself out and the bubble fades after a while. */
class SpeechBubble(context: Context) : TextView(context) {
    /** Which side the tail points to (toward the mascot). */
    var tailLeft = true
        set(value) {
            field = value
            updatePadding()
            invalidate()
        }
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val path = Path()
    private val rect = RectF()
    private var full = ""
    private var shown = 0
    private val tail = dp(10f)
    private var stepMs = 28L

    private val typeNext = object : Runnable {
        override fun run() {
            if (shown >= full.length) {
                postDelayed(hide, 3500L + full.length * 40L)
                return
            }
            shown++
            text = full.substring(0, shown)
            postDelayed(this, stepMs)
        }
    }

    private val hide = Runnable {
        animate().alpha(0f).setDuration(250).withEndAction { visibility = INVISIBLE }.start()
    }

    init {
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
        maxWidth = dp(240)
        visibility = INVISIBLE
        updatePadding()
    }

    private fun updatePadding() {
        val h = dp(14)
        val v = dp(10)
        val t = tail.toInt()
        setPadding(h + if (tailLeft) t else 0, v, h + if (tailLeft) 0 else t, v)
    }

    fun style(pal: Palette) {
        fill.color = pal.cardRaised
        setTextColor(pal.text)
        typeface = pal.typeface
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f * pal.fontScale)
        invalidate()
    }

    /** Shows [message]; returns roughly how long the typing takes, so the mascot can "talk" that long. */
    fun say(message: String, instant: Boolean = false): Long {
        removeCallbacks(typeNext)
        removeCallbacks(hide)
        animate().cancel()
        full = message
        visibility = VISIBLE
        alpha = 0f
        animate().alpha(1f).setDuration(150).start()
        return if (instant) {
            shown = full.length
            text = full
            postDelayed(hide, 4000L + full.length * 40L)
            0L
        } else {
            shown = 0
            text = ""
            post(typeNext)
            full.length * stepMs
        }
    }

    fun dismiss() {
        removeCallbacks(typeNext)
        removeCallbacks(hide)
        visibility = INVISIBLE
    }

    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat()
        val h = height.toFloat()
        val r = dp(14f)
        val left = if (tailLeft) tail else 0f
        val right = if (tailLeft) w else w - tail
        rect.set(left, 0f, right, h)
        path.reset()
        path.addRoundRect(rect, r, r, Path.Direction.CW)
        val ty = h * 0.65f
        if (tailLeft) {
            path.moveTo(left + 1, ty - tail * 0.8f)
            path.lineTo(0f, ty + tail * 0.3f)
            path.lineTo(left + tail, ty)
        } else {
            path.moveTo(right - 1, ty - tail * 0.8f)
            path.lineTo(w, ty + tail * 0.3f)
            path.lineTo(right - tail, ty)
        }
        path.close()
        canvas.drawPath(path, fill)
        super.onDraw(canvas)
    }
}
