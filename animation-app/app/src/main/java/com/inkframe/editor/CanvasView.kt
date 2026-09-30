package com.inkframe.editor

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.BlendMode
import android.graphics.BlendModeColorFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.os.SystemClock
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.animation.DecelerateInterpolator
import com.inkframe.Tool
import com.inkframe.brush.BrushSpec
import com.inkframe.brush.QuickShape
import com.inkframe.brush.StrokeEngine
import com.inkframe.model.Project
import com.inkframe.render.Compositor
import com.inkframe.render.toBlendMode
import com.inkframe.ui.Theme
import com.inkframe.ui.dp
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** How the current stroke is painted and committed. */
class StrokeStyle(
    val brush: BrushSpec,
    val size: Float,
    val opacity: Float,
    val color: Int,
    val erase: Boolean,
    val alphaLock: Boolean,
)

/** What the canvas needs from the editor. */
interface CanvasHost {
    val doc: Document
    val tool: Tool
    val fingerDrawing: Boolean
    val quickShapeEnabled: Boolean
    val holdToPick: Boolean
    val isPlaying: Boolean

    /** Null when drawing is allowed, otherwise a message explaining why not. */
    fun drawBlockedReason(): String?
    fun strokeStyle(eraser: Boolean): StrokeStyle
    fun onStrokeFinished(engine: StrokeEngine, style: StrokeStyle)
    fun onFill(x: Int, y: Int)
    fun onColorPicked(color: Int)
    fun onUndoGesture()
    fun onRedoGesture()
    fun onToggleFullscreen()
    fun onStylusDetected()
    fun onTouchWhilePlaying()
    fun onEyedropperDone()
    fun showHint(text: String)
}

/**
 * The drawing surface. Renders the current frame (layers, onion skins and the stroke in
 * progress) through a pan/zoom/rotate view transform, and turns touches into strokes,
 * fills, color picks and navigation gestures:
 *
 * - one finger or pen: draw (fingers can be set to navigate only)
 * - two fingers: pan, pinch to zoom, twist to rotate; tap to undo
 * - three-finger tap: redo; four-finger tap: hide the interface
 * - touch and hold: eyedropper; draw and hold: QuickShape
 * - a fast pinch-in snaps back to fit the screen
 */
@SuppressLint("ViewConstructor")
class CanvasView(context: Context, private val host: CanvasHost) : View(context) {

    private val project: Project get() = host.doc.project
    val engine = StrokeEngine(project.width, project.height)

    private val viewMatrix = Matrix()
    private val inverse = Matrix()
    private var fitted = false
    private var mirrored = false

    /** Space covered by toolbars, so "fit" keeps the canvas visible between them. */
    val safeInsets = Rect()

    var playbackFrame: Bitmap? = null
        set(v) {
            field = v
            invalidate()
        }

    var transform: TransformSession? = null
        set(v) {
            field = v
            invalidate()
        }

    /** Next touch picks a color (armed from the side bar). */
    var eyedropperArmed = false

    // --- paints ---
    private val layerPaint = Paint(Paint.FILTER_BITMAP_FLAG)
    private val strokePaint = Paint(Paint.FILTER_BITMAP_FLAG)
    private val onionPaint = Paint(Paint.FILTER_BITMAP_FLAG)
    private val borderPaint = Paint().apply {
        color = 0x40000000
        style = Paint.Style.STROKE
        strokeWidth = 0f
    }
    private val checkerPaint = Paint().apply {
        val b = Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888)
        b.setPixel(0, 0, 0xFFFFFFFF.toInt()); b.setPixel(1, 1, 0xFFFFFFFF.toInt())
        b.setPixel(1, 0, 0xFFD9D9DE.toInt()); b.setPixel(0, 1, 0xFFD9D9DE.toInt())
        shader = BitmapShader(b, Shader.TileMode.REPEAT, Shader.TileMode.REPEAT).apply {
            setLocalMatrix(Matrix().apply { setScale(16f, 16f) })
        }
    }
    private val overlayPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val dashPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = Theme.accent
        pathEffect = DashPathEffect(floatArrayOf(dp(6f), dp(4f)), 0f)
    }
    private val tmpPath = Path()
    private val canvasRect = RectF()

    // --- touch state ---
    private enum class Mode { NONE, DRAW, GESTURE, PAN, FILL, PICK, TRANSFORM, IGNORE }

    private var mode = Mode.NONE
    private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop.toFloat()
    private var downTime = 0L
    private var downX = 0f
    private var downY = 0f
    private var maxPointers = 0
    private var moved = 0f
    private var drawPointerId = -1
    private var drawIsStylus = false
    private var strokeStyle: StrokeStyle? = null
    private var needsBaseline = false
    private var lastCx = 0f
    private var lastCy = 0f
    private var lastDist = 0f
    private var lastAngle = 0f
    private var snapped: QuickShape.Shape? = null
    private var snappedPressure = 1f
    private var lastShapeX = 0f
    private var lastShapeY = 0f
    private val pt = FloatArray(2)

    private var pickX = 0f
    private var pickY = 0f
    private var pickColor = Color.BLACK
    private var pickPrevious = Color.BLACK

    private var hoverX = -1f
    private var hoverY = -1f

    private val holdRunnable = Runnable { onHold() }
    private val shapeRunnable = Runnable { onShapeHold() }
    private var animator: ValueAnimator? = null

    init {
        isFocusable = true
    }

    // --- view transform ---

    private val matrixValues = FloatArray(9)

    val scale: Float
        get() {
            val v = matrixValues
            viewMatrix.getValues(v)
            return sqrt(v[Matrix.MSCALE_X] * v[Matrix.MSCALE_X] + v[Matrix.MSKEW_Y] * v[Matrix.MSKEW_Y])
        }

    private val rotationDegrees: Float
        get() {
            val v = FloatArray(9)
            viewMatrix.getValues(v)
            return Math.toDegrees(atan2(v[Matrix.MSKEW_Y].toDouble(), v[Matrix.MSCALE_X].toDouble())).toFloat()
        }

    private fun fitMatrix(): Matrix {
        val m = Matrix()
        val availW = width - safeInsets.left - safeInsets.right - dp(24f)
        val availH = height - safeInsets.top - safeInsets.bottom - dp(24f)
        if (availW <= 0 || availH <= 0) return m
        val s = min(availW / project.width, availH / project.height)
        val cx = safeInsets.left + (width - safeInsets.left - safeInsets.right) / 2f
        val cy = safeInsets.top + (height - safeInsets.top - safeInsets.bottom) / 2f
        m.setTranslate(-project.width / 2f, -project.height / 2f)
        m.postScale(s, s)
        if (mirrored) m.postScale(-1f, 1f)
        m.postTranslate(cx, cy)
        return m
    }

    private val fitScale: Float
        get() {
            val v = FloatArray(9)
            fitMatrix().getValues(v)
            return abs(v[Matrix.MSCALE_X])
        }

    fun fitToScreen(animate: Boolean = true) {
        if (animate) animateTo(fitMatrix()) else {
            viewMatrix.set(fitMatrix())
            invalidate()
        }
    }

    /** Mirrors the view (not the drawing) to check proportions. */
    fun toggleMirror() {
        mirrored = !mirrored
        val m = Matrix(viewMatrix)
        m.postScale(-1f, 1f, width / 2f, height / 2f)
        animateTo(m)
    }

    val isMirrored get() = mirrored

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (!fitted || oldw == 0) {
            fitToScreen(animate = false)
            fitted = true
        } else {
            // Keep the same canvas point in the middle when the screen rotates.
            viewMatrix.postTranslate((w - oldw) / 2f, (h - oldh) / 2f)
        }
        val band = dp(200)
        val top = (h - band) / 2
        systemGestureExclusionRects = listOf(Rect(0, top, dp(32), top + band), Rect(w - dp(32), top, w, top + band))
    }

    private fun animateTo(target: Matrix) {
        animator?.cancel()
        val from = FloatArray(9).also { viewMatrix.getValues(it) }
        val to = FloatArray(9).also { target.getValues(it) }
        val cur = FloatArray(9)
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 220
            interpolator = DecelerateInterpolator()
            addUpdateListener { a ->
                val t = a.animatedValue as Float
                for (i in 0 until 9) cur[i] = from[i] + (to[i] - from[i]) * t
                viewMatrix.setValues(cur)
                invalidate()
            }
            start()
        }
    }

    private fun toCanvas(x: Float, y: Float): FloatArray {
        viewMatrix.invert(inverse)
        pt[0] = x
        pt[1] = y
        inverse.mapPoints(pt)
        return pt
    }

    // --- drawing ---

    override fun onDraw(c: Canvas) {
        c.drawColor(Theme.workspace)
        val p = project
        canvasRect.set(0f, 0f, p.width.toFloat(), p.height.toFloat())
        val s = scale
        val filter = s < 2f
        layerPaint.isFilterBitmap = filter
        strokePaint.isFilterBitmap = filter
        onionPaint.isFilterBitmap = filter

        c.save()
        c.concat(viewMatrix)
        c.drawRect(canvasRect, borderPaint)
        c.clipRect(canvasRect)
        if (p.backgroundVisible) c.drawColor(p.backgroundColor) else c.drawRect(canvasRect, checkerPaint)

        val pb = playbackFrame
        if (pb != null) {
            c.drawBitmap(pb, null, canvasRect, layerPaint.apply { alpha = 255; blendMode = null })
            c.restore()
            return
        }

        val frame = p.frames[p.currentFrame]
        val store = host.doc.store
        for (i in p.layers.indices) {
            val layer = p.layers[i]
            val key = Project.cellKey(frame.id, layer.id)
            if (i == p.activeLayer) {
                drawOnionSkins(c)
                if (layer.visible) drawActiveLayer(c, key, layer.opacity, layer.blend.toBlendMode())
                continue
            }
            if (!layer.visible) continue
            val bmp = store.get(key) ?: continue
            layerPaint.alpha = (layer.opacity * 255).roundToInt()
            layerPaint.blendMode = layer.blend.toBlendMode()
            c.drawBitmap(bmp, 0f, 0f, layerPaint)
        }
        c.restore()
        drawOverlays(c)
    }

    private fun drawActiveLayer(c: Canvas, key: String, opacity: Float, blend: BlendMode?) {
        val store = host.doc.store
        val t = transform
        if (t != null && t.key == key) {
            layerPaint.alpha = (opacity * 255).roundToInt()
            layerPaint.blendMode = blend
            layerPaint.isFilterBitmap = true
            c.drawBitmap(t.source, t.matrix, layerPaint)
            return
        }
        val bmp = store.get(key)
        val style = strokeStyle
        if (style != null && !engine.layer.isEmpty) {
            // Composite the stroke with the layer in isolation so erasing and alpha lock preview exactly.
            layerPaint.alpha = (opacity * 255).roundToInt()
            layerPaint.blendMode = blend
            val save = c.saveLayer(canvasRect, layerPaint)
            if (bmp != null) c.drawBitmap(bmp, 0f, 0f, null)
            strokePaint.alpha = (style.opacity * 255).roundToInt()
            strokePaint.blendMode = when {
                style.erase -> BlendMode.DST_OUT
                style.alphaLock -> BlendMode.SRC_ATOP
                else -> BlendMode.SRC_OVER
            }
            engine.layer.drawTo(c, strokePaint)
            c.restoreToCount(save)
            return
        }
        if (bmp != null) {
            layerPaint.alpha = (opacity * 255).roundToInt()
            layerPaint.blendMode = blend
            c.drawBitmap(bmp, 0f, 0f, layerPaint)
        }
    }

    private fun drawOnionSkins(c: Canvas) {
        val p = project
        val o = p.onion
        if (!o.enabled || host.isPlaying) return
        val store = host.doc.store
        val cur = p.currentFrame
        fun drawFrame(fi: Int, alpha: Float, tint: Int) {
            val f = p.frames[fi]
            onionPaint.alpha = (alpha * 255).roundToInt().coerceIn(0, 255)
            onionPaint.colorFilter = if (o.colored) BlendModeColorFilter(tint, BlendMode.SRC_IN) else null
            if (o.allLayers) {
                for (l in p.layers) {
                    if (!l.visible) continue
                    store.get(Project.cellKey(f.id, l.id))?.let { c.drawBitmap(it, 0f, 0f, onionPaint) }
                }
            } else {
                store.get(Project.cellKey(f.id, p.layers[p.activeLayer].id))?.let { c.drawBitmap(it, 0f, 0f, onionPaint) }
            }
        }
        // Farthest first so the nearest frames sit on top.
        for (d in o.before downTo 1) {
            val fi = cur - d
            if (fi < 0) continue
            drawFrame(fi, o.opacity * (1f - (d - 1f) / (o.before + 1f)), Theme.onionBefore)
        }
        for (d in o.after downTo 1) {
            val fi = cur + d
            if (fi >= p.frames.size) continue
            drawFrame(fi, o.opacity * (1f - (d - 1f) / (o.after + 1f)), Theme.onionAfter)
        }
    }

    private fun drawOverlays(c: Canvas) {
        transform?.let { t ->
            val pts = t.corners()
            viewMatrix.mapPoints(pts)
            tmpPath.reset()
            tmpPath.moveTo(pts[0], pts[1])
            for (i in 1..3) tmpPath.lineTo(pts[i * 2], pts[i * 2 + 1])
            tmpPath.close()
            dashPaint.strokeWidth = dp(1.5f)
            c.drawPath(tmpPath, dashPaint)
            overlayPaint.style = Paint.Style.FILL
            for (i in 0..3) {
                overlayPaint.color = Color.WHITE
                c.drawCircle(pts[i * 2], pts[i * 2 + 1], dp(6f), overlayPaint)
                overlayPaint.color = Theme.accent
                c.drawCircle(pts[i * 2], pts[i * 2 + 1], dp(4f), overlayPaint)
            }
        }
        if (mode == Mode.PICK) drawLoupe(c)
        if (hoverX >= 0 && mode == Mode.NONE && (host.tool == Tool.BRUSH || host.tool == Tool.ERASER)) {
            val style = host.strokeStyle(host.tool == Tool.ERASER)
            val r = max(style.size * scale / 2f, dp(2f))
            overlayPaint.style = Paint.Style.STROKE
            overlayPaint.strokeWidth = dp(1f)
            overlayPaint.color = 0xAA000000.toInt()
            c.drawCircle(hoverX, hoverY, r + dp(1f), overlayPaint)
            overlayPaint.color = 0xDDFFFFFF.toInt()
            c.drawCircle(hoverX, hoverY, r, overlayPaint)
        }
    }

    /** Ring above the finger: new color on top, previous color below. */
    private fun drawLoupe(c: Canvas) {
        val cx = pickX
        val cy = pickY - dp(70f)
        val r = dp(46f)
        val w = dp(14f)
        val oval = RectF(cx - r, cy - r, cx + r, cy + r)
        overlayPaint.style = Paint.Style.STROKE
        overlayPaint.strokeWidth = w
        overlayPaint.color = pickColor
        c.drawArc(oval, 180f, 180f, false, overlayPaint)
        overlayPaint.color = pickPrevious
        c.drawArc(oval, 0f, 180f, false, overlayPaint)
        overlayPaint.strokeWidth = dp(1.5f)
        overlayPaint.color = 0x66000000
        c.drawCircle(cx, cy, r + w / 2, overlayPaint)
        c.drawCircle(cx, cy, r - w / 2, overlayPaint)
    }

    // --- input ---

    override fun onHoverEvent(e: MotionEvent): Boolean {
        val tt = e.getToolType(0)
        if (tt != MotionEvent.TOOL_TYPE_STYLUS && tt != MotionEvent.TOOL_TYPE_ERASER) return super.onHoverEvent(e)
        when (e.actionMasked) {
            MotionEvent.ACTION_HOVER_ENTER, MotionEvent.ACTION_HOVER_MOVE -> {
                hoverX = e.x; hoverY = e.y
            }
            MotionEvent.ACTION_HOVER_EXIT -> hoverX = -1f
        }
        invalidate()
        return true
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(e: MotionEvent): Boolean {
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> onDown(e)
            MotionEvent.ACTION_POINTER_DOWN -> onPointerDown(e)
            MotionEvent.ACTION_MOVE -> onMove(e)
            MotionEvent.ACTION_POINTER_UP -> needsBaseline = true
            MotionEvent.ACTION_UP -> onUp(e)
            MotionEvent.ACTION_CANCEL -> {
                if (mode == Mode.DRAW) cancelStroke()
                resetTouch()
            }
        }
        return true
    }

    private fun isStylus(e: MotionEvent, index: Int): Boolean {
        val t = e.getToolType(index)
        return t == MotionEvent.TOOL_TYPE_STYLUS || t == MotionEvent.TOOL_TYPE_ERASER
    }

    private fun onDown(e: MotionEvent) {
        animator?.cancel()
        hoverX = -1f
        downTime = e.eventTime
        downX = e.x
        downY = e.y
        maxPointers = 1
        moved = 0f
        needsBaseline = false
        snapped = null
        val stylus = isStylus(e, 0)
        if (stylus) host.onStylusDetected()
        if (host.isPlaying) {
            host.onTouchWhilePlaying()
            mode = Mode.IGNORE
            return
        }
        val stylusButton = stylus && (e.buttonState and MotionEvent.BUTTON_STYLUS_PRIMARY) != 0
        when {
            transform != null -> {
                mode = Mode.TRANSFORM
                setBaseline(e)
            }
            eyedropperArmed || stylusButton -> startPick(e.x, e.y)
            !stylus && !host.fingerDrawing -> {
                mode = Mode.PAN
                setBaseline(e)
            }
            host.tool == Tool.FILL -> mode = Mode.FILL
            host.tool == Tool.TRANSFORM -> {
                mode = Mode.PAN
                setBaseline(e)
            }
            else -> {
                val blocked = host.drawBlockedReason()
                if (blocked != null) {
                    host.showHint(blocked)
                    mode = Mode.PAN
                    setBaseline(e)
                    return
                }
                val eraser = host.tool == Tool.ERASER || e.getToolType(0) == MotionEvent.TOOL_TYPE_ERASER
                val style = host.strokeStyle(eraser)
                strokeStyle = style
                drawPointerId = e.getPointerId(0)
                drawIsStylus = stylus
                val p = toCanvas(e.x, e.y)
                engine.begin(style.brush, style.color, style.size, p[0], p[1], pressure(e, 0, -1))
                mode = Mode.DRAW
                lastShapeX = e.x
                lastShapeY = e.y
                if (host.holdToPick) postDelayed(holdRunnable, 550)
                invalidate()
            }
        }
    }

    private fun pressure(e: MotionEvent, index: Int, historical: Int): Float {
        if (!isStylus(e, index)) return 1f
        val p = if (historical >= 0) e.getHistoricalPressure(index, historical) else e.getPressure(index)
        return p.coerceIn(0.02f, 1f)
    }

    private fun onPointerDown(e: MotionEvent) {
        maxPointers = max(maxPointers, e.pointerCount)
        when (mode) {
            Mode.DRAW -> {
                if (drawIsStylus && !isStylus(e, e.actionIndex)) return // resting hand while using a pen
                val young = e.eventTime - downTime < 300
                if (young || engine.length * scale < touchSlop * 3) {
                    cancelStroke()
                    beginGesture(e)
                }
            }
            Mode.PAN, Mode.FILL, Mode.NONE -> beginGesture(e)
            Mode.PICK -> {
                mode = Mode.NONE
                beginGesture(e)
            }
            Mode.GESTURE, Mode.TRANSFORM -> needsBaseline = true
            Mode.IGNORE -> Unit
        }
    }

    private fun beginGesture(e: MotionEvent) {
        removeCallbacks(holdRunnable)
        removeCallbacks(shapeRunnable)
        mode = Mode.GESTURE
        setBaseline(e)
    }

    private fun setBaseline(e: MotionEvent) {
        needsBaseline = false
        if (e.pointerCount >= 2) {
            lastCx = (e.getX(0) + e.getX(1)) / 2f
            lastCy = (e.getY(0) + e.getY(1)) / 2f
            lastDist = hypot(e.getX(1) - e.getX(0), e.getY(1) - e.getY(0))
            lastAngle = Math.toDegrees(atan2((e.getY(1) - e.getY(0)).toDouble(), (e.getX(1) - e.getX(0)).toDouble())).toFloat()
        } else {
            lastCx = e.getX(0)
            lastCy = e.getY(0)
            lastDist = 0f
        }
    }

    private fun onMove(e: MotionEvent) {
        when (mode) {
            Mode.DRAW -> moveStroke(e)
            Mode.GESTURE, Mode.PAN -> {
                if (needsBaseline) return setBaseline(e)
                navigate(e)
            }
            Mode.PICK -> {
                pickX = e.x
                pickY = e.y
                samplePick()
                invalidate()
            }
            Mode.FILL -> moved = max(moved, hypot(e.x - downX, e.y - downY))
            Mode.TRANSFORM -> {
                if (needsBaseline) return setBaseline(e)
                transformContent(e)
            }
            Mode.NONE, Mode.IGNORE -> Unit
        }
    }

    private fun moveStroke(e: MotionEvent) {
        val i = e.findPointerIndex(drawPointerId)
        if (i < 0) return
        val shape = snapped
        if (shape != null) {
            // After QuickShape, dragging adjusts the end of a line.
            if (shape is QuickShape.Line) {
                val p = toCanvas(e.getX(i), e.getY(i))
                shape.x1 = p[0]
                shape.y1 = p[1]
                engine.replaceWithShape(shape.points(), snappedPressure)
                invalidate()
            }
            return
        }
        for (h in 0 until e.historySize) {
            val p = toCanvas(e.getHistoricalX(i, h), e.getHistoricalY(i, h))
            engine.add(p[0], p[1], pressure(e, i, h))
        }
        val p = toCanvas(e.getX(i), e.getY(i))
        engine.add(p[0], p[1], pressure(e, i, -1))
        if (hypot(e.getX(i) - downX, e.getY(i) - downY) > touchSlop) removeCallbacks(holdRunnable)
        if (hypot(e.getX(i) - lastShapeX, e.getY(i) - lastShapeY) > dp(4f)) {
            lastShapeX = e.getX(i)
            lastShapeY = e.getY(i)
            removeCallbacks(shapeRunnable)
            if (host.quickShapeEnabled) postDelayed(shapeRunnable, 600)
        }
        invalidate()
    }

    private fun navigate(e: MotionEvent) {
        if (e.pointerCount >= 2) {
            val cx = (e.getX(0) + e.getX(1)) / 2f
            val cy = (e.getY(0) + e.getY(1)) / 2f
            val dist = hypot(e.getX(1) - e.getX(0), e.getY(1) - e.getY(0))
            val angle = Math.toDegrees(atan2((e.getY(1) - e.getY(0)).toDouble(), (e.getX(1) - e.getX(0)).toDouble())).toFloat()
            viewMatrix.postTranslate(cx - lastCx, cy - lastCy)
            if (lastDist > 0f && dist > 0f) {
                var f = dist / lastDist
                val s = scale
                val minS = fitScale * 0.15f
                val maxS = 64f
                if (s * f < minS) f = minS / s
                if (s * f > maxS) f = maxS / s
                viewMatrix.postScale(f, f, cx, cy)
            }
            var da = angle - lastAngle
            if (da > 180f) da -= 360f
            if (da < -180f) da += 360f
            viewMatrix.postRotate(da, cx, cy)
            moved += abs(cx - lastCx) + abs(cy - lastCy) + abs(dist - lastDist)
            lastCx = cx; lastCy = cy; lastDist = dist; lastAngle = angle
        } else {
            val x = e.getX(0)
            val y = e.getY(0)
            viewMatrix.postTranslate(x - lastCx, y - lastCy)
            moved += abs(x - lastCx) + abs(y - lastCy)
            lastCx = x; lastCy = y
        }
        invalidate()
    }

    private fun transformContent(e: MotionEvent) {
        val t = transform ?: return
        viewMatrix.invert(inverse)
        val s = scale
        if (e.pointerCount >= 2) {
            val cx = (e.getX(0) + e.getX(1)) / 2f
            val cy = (e.getY(0) + e.getY(1)) / 2f
            val dist = hypot(e.getX(1) - e.getX(0), e.getY(1) - e.getY(0))
            val angle = Math.toDegrees(atan2((e.getY(1) - e.getY(0)).toDouble(), (e.getX(1) - e.getX(0)).toDouble())).toFloat()
            val c = floatArrayOf(cx, cy)
            inverse.mapPoints(c)
            val d = floatArrayOf(cx - lastCx, cy - lastCy)
            inverse.mapVectors(d)
            t.matrix.postTranslate(d[0], d[1])
            if (lastDist > 0f && dist > 0f) t.matrix.postScale(dist / lastDist, dist / lastDist, c[0], c[1])
            var da = angle - lastAngle
            if (da > 180f) da -= 360f
            if (da < -180f) da += 360f
            t.matrix.postRotate(if (mirrored) -da else da, c[0], c[1])
            lastCx = cx; lastCy = cy; lastDist = dist; lastAngle = angle
        } else {
            val d = floatArrayOf(e.getX(0) - lastCx, e.getY(0) - lastCy)
            inverse.mapVectors(d)
            t.matrix.postTranslate(d[0], d[1])
            lastCx = e.getX(0)
            lastCy = e.getY(0)
        }
        if (s <= 0f) return
        invalidate()
    }

    private fun onUp(e: MotionEvent) {
        removeCallbacks(holdRunnable)
        removeCallbacks(shapeRunnable)
        when (mode) {
            Mode.DRAW -> finishStroke()
            Mode.GESTURE -> {
                val quick = e.eventTime - downTime < 350 && moved < touchSlop * 2.5f
                if (quick && maxPointers >= 2) {
                    performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                    when (maxPointers) {
                        2 -> host.onUndoGesture()
                        3 -> host.onRedoGesture()
                        else -> host.onToggleFullscreen()
                    }
                } else {
                    snapView()
                }
            }
            Mode.PAN -> if (moved > touchSlop) snapView()
            Mode.FILL -> if (moved < touchSlop) {
                val p = toCanvas(e.x, e.y)
                val x = p[0].toInt()
                val y = p[1].toInt()
                if (x in 0 until project.width && y in 0 until project.height) host.onFill(x, y)
            }
            Mode.PICK -> {
                host.onColorPicked(pickColor)
                eyedropperArmed = false
                host.onEyedropperDone()
            }
            else -> Unit
        }
        resetTouch()
        invalidate()
    }

    private fun resetTouch() {
        removeCallbacks(holdRunnable)
        removeCallbacks(shapeRunnable)
        mode = Mode.NONE
        drawPointerId = -1
    }

    /** Snaps a nearly straight rotation to the nearest right angle and a too-small zoom back to fit. */
    private fun snapView() {
        val target = Matrix(viewMatrix)
        var changed = false
        val rot = rotationDegrees
        val nearest = (rot / 90f).roundToInt() * 90f
        if (abs(rot - nearest) in 0.01f..7f) {
            target.postRotate(nearest - rot, width / 2f, height / 2f)
            changed = true
        }
        if (scale < fitScale * 0.8f) {
            animateTo(fitMatrix())
            return
        }
        if (changed) animateTo(target)
    }

    private fun finishStroke() {
        val style = strokeStyle ?: return
        val drew = engine.end()
        if (drew) host.onStrokeFinished(engine, style)
        engine.clear()
        strokeStyle = null
        snapped = null
        invalidate()
    }

    private fun cancelStroke() {
        removeCallbacks(holdRunnable)
        removeCallbacks(shapeRunnable)
        engine.cancel()
        strokeStyle = null
        snapped = null
        invalidate()
    }

    /** Touch and hold without moving: switch to the eyedropper. */
    private fun onHold() {
        if (mode != Mode.DRAW || engine.length * scale > touchSlop) return
        cancelStroke()
        performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
        startPick(downX, downY)
        invalidate()
    }

    private fun startPick(x: Float, y: Float) {
        mode = Mode.PICK
        pickX = x
        pickY = y
        pickPrevious = host.strokeStyle(false).color
        samplePick()
        invalidate()
    }

    private fun samplePick() {
        val p = toCanvas(pickX, pickY)
        val x = p[0].toInt().coerceIn(0, project.width - 1)
        val y = p[1].toInt().coerceIn(0, project.height - 1)
        val c = Compositor.sampleColor(host.doc.frameSpec(project.currentFrame), host.doc.store, x, y)
        pickColor = if (Color.alpha(c) == 0) pickPrevious else c or 0xFF000000.toInt()
    }

    /** Draw and hold still: snap the stroke to a perfect line or ellipse. */
    private fun onShapeHold() {
        if (mode != Mode.DRAW || snapped != null) return
        val n = engine.rawCount
        if (n < 3) return
        val raw = engine.rawPoints
        val shape = QuickShape.detect(raw, n, minSize = dp(40f) / scale) ?: return
        var pSum = 0f
        for (i in 0 until n) pSum += raw[i * 3 + 2]
        snappedPressure = pSum / n
        engine.replaceWithShape(shape.points(), snappedPressure)
        snapped = shape
        performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
        host.showHint("${shape.label} snapped")
        invalidate()
    }
}
