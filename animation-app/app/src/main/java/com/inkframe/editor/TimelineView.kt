package com.inkframe.editor

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.GestureDetector
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.widget.OverScroller
import com.inkframe.ui.Theme
import com.inkframe.ui.dp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * The frame strip: one thumbnail per drawing, scrollable, tap to select, tap the
 * selected frame for its options, touch and hold then drag to reorder.
 */
@SuppressLint("ViewConstructor")
class TimelineView(
    context: Context,
    private val doc: Document,
    private val callbacks: Callbacks,
) : View(context) {

    interface Callbacks {
        fun onFrameSelected(index: Int)
        fun onCurrentFrameTapped(index: Int, anchorX: Float)
        fun onAddFrameTapped()
        fun onFrameMoved(from: Int, to: Int)
    }

    val thumbs = ThumbnailCache(doc, dp(72)) { invalidate() }

    /** Frame shown by playback, highlighted instead of the current frame while playing. */
    var playingIndex = -1
        set(v) {
            if (field == v) return
            field = v
            if (v >= 0) ensureVisible(v, animate = false)
            invalidate()
        }

    private val scroller = OverScroller(context)
    private var scrollPos = 0f
    private val pad = dp(10f)
    private val gap = dp(6f)
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = dp(11f)
        typeface = Theme.bold
    }
    private val dashPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(1.5f)
        color = Theme.textDim
        pathEffect = DashPathEffect(floatArrayOf(dp(5f), dp(4f)), 0f)
    }
    private val rect = RectF()
    private val clip = Path()

    private var dragIndex = -1
    private var dragX = 0f
    private var dragGrabOffset = 0f

    private val itemH: Float get() = height - pad * 2
    private val itemW: Float
        get() {
            val aspect = doc.project.width / doc.project.height.toFloat()
            return (itemH * aspect).coerceIn(itemH * 0.56f, itemH * 1.8f)
        }
    private val stride: Float get() = itemW + gap
    private val count: Int get() = doc.project.frames.size
    private val contentWidth: Float get() = pad * 2 + count * stride + itemW * 0.7f
    private val maxScroll: Float get() = max(0f, contentWidth - width)

    private val detector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
        override fun onDown(e: MotionEvent): Boolean {
            scroller.forceFinished(true)
            return true
        }

        override fun onScroll(e1: MotionEvent?, e2: MotionEvent, dx: Float, dy: Float): Boolean {
            scrollPos = (scrollPos + dx).coerceIn(0f, maxScroll)
            invalidate()
            return true
        }

        override fun onFling(e1: MotionEvent?, e2: MotionEvent, vx: Float, vy: Float): Boolean {
            scroller.fling(scrollPos.toInt(), 0, -vx.toInt(), 0, 0, maxScroll.toInt(), 0, 0)
            postInvalidateOnAnimation()
            return true
        }

        override fun onSingleTapUp(e: MotionEvent): Boolean {
            val i = hit(e.x)
            when {
                i == count -> callbacks.onAddFrameTapped()
                i in 0 until count -> {
                    if (i == doc.project.currentFrame) {
                        callbacks.onCurrentFrameTapped(i, xOf(i) + itemW / 2)
                    } else {
                        callbacks.onFrameSelected(i)
                    }
                }
            }
            return true
        }

        override fun onLongPress(e: MotionEvent) {
            val i = hit(e.x)
            if (i !in 0 until count) return
            dragIndex = i
            dragGrabOffset = e.x - xOf(i)
            dragX = e.x
            performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
            parent?.requestDisallowInterceptTouchEvent(true)
            invalidate()
        }
    })

    init {
        detector.setIsLongpressEnabled(true)
    }

    private fun xOf(index: Int) = pad + index * stride - scrollPos

    /** Item under x: a frame index, [count] for the add tile, or -1. */
    private fun hit(x: Float): Int {
        val i = ((x + scrollPos - pad) / stride).toInt()
        if (x + scrollPos - pad < 0) return -1
        return if (i <= count) i else -1
    }

    fun ensureVisible(index: Int, animate: Boolean = true) {
        val left = pad + index * stride
        val target = when {
            left - pad < scrollPos -> left - pad
            left + itemW + pad > scrollPos + width -> left + itemW + pad - width
            else -> return
        }.coerceIn(0f, maxScroll)
        if (animate) {
            scroller.startScroll(scrollPos.toInt(), 0, (target - scrollPos).toInt(), 0, 200)
            postInvalidateOnAnimation()
        } else {
            scrollPos = target
            invalidate()
        }
    }

    override fun computeScroll() {
        if (scroller.computeScrollOffset()) {
            scrollPos = scroller.currX.toFloat().coerceIn(0f, maxScroll)
            postInvalidateOnAnimation()
        }
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        scrollPos = scrollPos.coerceIn(0f, maxScroll)
        ensureVisible(doc.project.currentFrame, animate = false)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(e: MotionEvent): Boolean {
        if (dragIndex >= 0) {
            when (e.actionMasked) {
                MotionEvent.ACTION_MOVE -> {
                    dragX = e.x
                    // Scroll when dragging near the edges.
                    val edge = dp(40f)
                    if (e.x < edge) scrollPos = (scrollPos - dp(8f)).coerceIn(0f, maxScroll)
                    if (e.x > width - edge) scrollPos = (scrollPos + dp(8f)).coerceIn(0f, maxScroll)
                    invalidate()
                }
                MotionEvent.ACTION_UP -> {
                    val target = dropIndex()
                    val from = dragIndex
                    dragIndex = -1
                    if (target != from) callbacks.onFrameMoved(from, target)
                    invalidate()
                }
                MotionEvent.ACTION_CANCEL -> {
                    dragIndex = -1
                    invalidate()
                }
            }
            return true
        }
        return detector.onTouchEvent(e) || super.onTouchEvent(e)
    }

    private fun dropIndex(): Int {
        val left = dragX - dragGrabOffset + scrollPos - pad
        return (left / stride).roundToInt().coerceIn(0, count - 1)
    }

    override fun onDraw(c: Canvas) {
        val w = itemW
        val h = itemH
        val top = pad
        val r = dp(8f)
        val current = if (playingIndex >= 0) playingIndex else doc.project.currentFrame
        val first = max(0, ((scrollPos - pad) / stride).toInt())
        val last = min(count - 1, ((scrollPos + width) / stride).toInt() + 1)
        val drop = if (dragIndex >= 0) dropIndex() else -1

        for (i in first..last) {
            if (i == dragIndex) continue
            // While dragging, open a gap where the frame will land.
            var slot = i
            if (dragIndex >= 0) {
                if (i > dragIndex && i <= drop) slot = i - 1
                if (i < dragIndex && i >= drop) slot = i + 1
            }
            drawItem(c, i, pad + slot * stride - scrollPos, top, w, h, r, i == current)
        }
        // Add-frame tile.
        val ax = xOf(count)
        if (ax < width) {
            rect.set(ax + dp(2f), top + dp(2f), ax + w * 0.7f - dp(2f), top + h - dp(2f))
            c.drawRoundRect(rect, r, r, dashPaint)
            paint.color = Theme.textDim
            paint.strokeWidth = dp(2f)
            val cx = rect.centerX()
            val cy = rect.centerY()
            val s = dp(9f)
            c.drawLine(cx - s, cy, cx + s, cy, paint)
            c.drawLine(cx, cy - s, cx, cy + s, paint)
        }
        if (dragIndex >= 0) {
            val x = dragX - dragGrabOffset
            c.save()
            c.translate(0f, -dp(6f))
            drawItem(c, dragIndex, x, top, w, h, r, true)
            c.restore()
        }
    }

    private fun drawItem(c: Canvas, i: Int, x: Float, top: Float, w: Float, h: Float, r: Float, selected: Boolean) {
        rect.set(x, top, x + w, top + h)
        paint.style = Paint.Style.FILL
        paint.color = Theme.panelRaised
        c.drawRoundRect(rect, r, r, paint)
        thumbs.get(i)?.let { bmp ->
            c.save()
            clip.reset()
            clip.addRoundRect(rect, r, r, Path.Direction.CW)
            c.clipPath(clip)
            c.drawBitmap(bmp, null, rect, paint)
            c.restore()
        }
        val frame = doc.project.frames[i]
        // Frame number.
        val label = (i + 1).toString()
        textPaint.color = 0xCC000000.toInt()
        val tw = textPaint.measureText(label)
        rect.set(x + dp(4f), top + h - dp(19f), x + dp(4f) + tw + dp(10f), top + h - dp(4f))
        paint.color = 0x99000000.toInt()
        c.drawRoundRect(rect, dp(6f), dp(6f), paint)
        textPaint.color = Theme.text
        c.drawText(label, rect.left + dp(5f), rect.bottom - dp(4f), textPaint)
        if (frame.hold > 1) {
            val hl = "×${frame.hold}"
            val hw = textPaint.measureText(hl)
            rect.set(x + w - hw - dp(14f), top + dp(4f), x + w - dp(4f), top + dp(19f))
            paint.color = Theme.accent
            c.drawRoundRect(rect, dp(6f), dp(6f), paint)
            c.drawText(hl, rect.left + dp(5f), rect.bottom - dp(4f), textPaint)
        }
        if (selected) {
            rect.set(x, top, x + w, top + h)
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = dp(2.5f)
            paint.color = Theme.accent
            c.drawRoundRect(rect, r, r, paint)
            paint.style = Paint.Style.FILL
        }
    }
}
