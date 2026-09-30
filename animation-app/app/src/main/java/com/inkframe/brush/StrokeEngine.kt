package com.inkframe.brush

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import java.util.Random
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** Grayscale stamp textures, generated once. */
object DabTextures {
    private const val SIZE = 128
    private val cache = HashMap<DabShape, Bitmap>()

    @Synchronized
    fun get(shape: DabShape): Bitmap = cache.getOrPut(shape) { generate(shape) }

    private fun generate(shape: DabShape): Bitmap {
        val s = SIZE
        val px = IntArray(s * s)
        val rnd = Random(shape.ordinal * 7919L + 17)
        // Low-frequency value noise for chalk.
        val g = 12
        val grid = FloatArray((g + 1) * (g + 1)) { rnd.nextFloat() }
        fun lowNoise(u: Float, v: Float): Float {
            val gx = u * g
            val gy = v * g
            val ix = floor(gx).toInt().coerceIn(0, g - 1)
            val iy = floor(gy).toInt().coerceIn(0, g - 1)
            val fx = gx - ix
            val fy = gy - iy
            val a = grid[iy * (g + 1) + ix]
            val b = grid[iy * (g + 1) + ix + 1]
            val c = grid[(iy + 1) * (g + 1) + ix]
            val d = grid[(iy + 1) * (g + 1) + ix + 1]
            return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
        }
        val half = s / 2f
        for (y in 0 until s) {
            for (x in 0 until s) {
                val dx = (x + 0.5f - half) / half
                val dy = (y + 0.5f - half) / half
                val r = sqrt(dx * dx + dy * dy)
                // Anti-aliased disc edge, about 1.5 texels wide.
                val edge = ((1f - r) * half / 1.5f).coerceIn(0f, 1f)
                val a = when (shape) {
                    DabShape.HARD -> edge
                    DabShape.SOFT -> {
                        if (r >= 1f) 0f else {
                            val t = 1f - r
                            t * t * (3f - 2f * t)
                        }
                    }
                    DabShape.PENCIL -> {
                        val n = rnd.nextFloat()
                        edge * (if (n < 0.5f) 0.25f + n else 0.15f * n) * (1f - r * 0.35f)
                    }
                    DabShape.CHALK -> {
                        val n = lowNoise(x / s.toFloat(), y / s.toFloat())
                        val grain = rnd.nextFloat()
                        val v = ((n - 0.28f) * 2.4f).coerceIn(0f, 1f) * (0.55f + 0.45f * grain)
                        edge * v
                    }
                    DabShape.INK -> {
                        val wobble = 1f - 0.08f * lowNoise(x / s.toFloat(), y / s.toFloat())
                        (((wobble - r) * half / 1.5f).coerceIn(0f, 1f)) * (0.85f + 0.15f * rnd.nextFloat())
                    }
                }
                val alpha = (a.coerceIn(0f, 1f) * 255f + 0.5f).toInt()
                px[y * s + x] = alpha shl 24
            }
        }
        val argb = Bitmap.createBitmap(px, s, s, Bitmap.Config.ARGB_8888)
        return argb.extractAlpha()
    }
}

/**
 * A canvas-sized transparent layer split into tiles. Only the tiles a stroke touches
 * are allocated and re-uploaded to the GPU each frame, which keeps live drawing fast
 * even on large canvases.
 */
class TiledLayer(val width: Int, val height: Int, private val tile: Int = 256) {
    private val cols = (width + tile - 1) / tile
    private val rows = (height + tile - 1) / tile
    private val bitmaps = arrayOfNulls<Bitmap>(cols * rows)
    private val canvases = arrayOfNulls<Canvas>(cols * rows)
    private val used = BooleanArray(cols * rows)

    val isEmpty: Boolean get() = used.none { it }

    inline fun draw(bounds: RectF, block: (Canvas) -> Unit) = drawIn(bounds.left, bounds.top, bounds.right, bounds.bottom, block)

    inline fun drawIn(l: Float, t: Float, r: Float, b: Float, block: (Canvas) -> Unit) {
        val range = tileRange(l, t, r, b) ?: return
        for (row in range.top..range.bottom) {
            for (col in range.left..range.right) {
                val c = canvasAt(col, row)
                c.save()
                c.translate(-(col * tileSize).toFloat(), -(row * tileSize).toFloat())
                block(c)
                c.restore()
            }
        }
    }

    val tileSize: Int get() = tile

    fun tileRange(l: Float, t: Float, r: Float, b: Float): Rect? {
        val c0 = max(0, floor(l / tile).toInt())
        val r0 = max(0, floor(t / tile).toInt())
        val c1 = min(cols - 1, floor(r / tile).toInt())
        val r1 = min(rows - 1, floor(b / tile).toInt())
        if (c0 > c1 || r0 > r1) return null
        return Rect(c0, r0, c1, r1)
    }

    fun canvasAt(col: Int, row: Int): Canvas {
        val i = row * cols + col
        var c = canvases[i]
        if (c == null) {
            val bmp = Bitmap.createBitmap(tile, tile, Bitmap.Config.ARGB_8888)
            bitmaps[i] = bmp
            c = Canvas(bmp)
            canvases[i] = c
        }
        used[i] = true
        return c
    }

    fun clear() {
        for (i in used.indices) {
            if (used[i]) {
                bitmaps[i]?.eraseColor(Color.TRANSPARENT)
                used[i] = false
            }
        }
    }

    /** Draws the used tiles at their canvas positions. */
    fun drawTo(canvas: Canvas, paint: Paint?) {
        for (i in used.indices) {
            if (!used[i]) continue
            val bmp = bitmaps[i] ?: continue
            canvas.drawBitmap(bmp, ((i % cols) * tile).toFloat(), ((i / cols) * tile).toFloat(), paint)
        }
    }
}

/**
 * Renders strokes into a [TiledLayer]. The caller composites the finished stroke
 * into the layer (with the brush opacity, eraser or alpha lock) and records undo.
 */
class StrokeEngine(val width: Int, val height: Int) {
    val layer = TiledLayer(width, height)

    /** Canvas-space bounds of everything drawn by the current stroke. */
    val dirty = RectF()

    var isActive = false
        private set

    private var spec: BrushSpec = Brushes.default
    private var color = Color.BLACK
    private var baseSize = 10f
    private var seed = 0L
    private var path: StrokePath? = null
    /** True once QuickShape replaced the stroke; the shape is final and gets no taper. */
    private var shapeMode = false
    private var dabs = FloatArray(6 * 256)
    private var dabCount = 0
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val oval = RectF()
    private val bounds = RectF()

    /** Raw input of the current stroke: x, y, pressure triples. */
    val rawPoints: FloatArray get() = path?.raw ?: FloatArray(0)
    val rawCount: Int get() = path?.rawCount ?: 0
    val length: Float get() = path?.length ?: 0f

    fun begin(spec: BrushSpec, color: Int, size: Float, x: Float, y: Float, pressure: Float) {
        clear()
        this.spec = spec
        this.color = color or 0xFF000000.toInt()
        this.baseSize = size
        this.seed = System.nanoTime()
        isActive = true
        shapeMode = false
        path = StrokePath(spec, size, seed) { recordAndDraw(it) }.also { it.begin(x, y, pressure) }
    }

    fun add(x: Float, y: Float, pressure: Float) {
        if (isActive && !shapeMode) path?.add(x, y, pressure)
    }

    /** Finishes the stroke. Returns false when nothing was drawn. */
    fun end(): Boolean {
        val p = path ?: return false
        isActive = false
        if (shapeMode) return dabCount > 0
        p.finish()
        if (dabCount == 0) return false
        val total = p.length
        if (total < 1f) {
            // A tap: one full-size dot, whatever the taper.
            val x = dabs[0]
            val y = dabs[1]
            val size = baseSize * (1f - spec.pressureSize + spec.pressureSize * rawPoints[2])
            redraw { drawDab(x, y, size, spec.flow.coerceAtLeast(0.6f), dabs[4]) }
        } else if (spec.taperEnd > 0f) {
            redraw {
                for (i in 0 until dabCount) {
                    val o = i * 6
                    val f = StrokePath.endTaper(spec, baseSize, dabs[o + 5], total)
                    drawDab(dabs[o], dabs[o + 1], dabs[o + 2] * f, dabs[o + 3], dabs[o + 4])
                }
            }
        }
        return true
    }

    fun cancel() {
        isActive = false
        shapeMode = false
        path = null
        clear()
    }

    fun clear() {
        layer.clear()
        dirty.setEmpty()
        dabCount = 0
    }

    /** Replaces the stroke with a perfect shape through [points] (x, y pairs), used by QuickShape. */
    fun replaceWithShape(points: FloatArray, pressure: Float) {
        layer.clear()
        dirty.setEmpty()
        dabCount = 0
        shapeMode = true
        if (points.size < 2) return
        val shapeSpec = spec.copy(taperStart = 0f, taperEnd = 0f, streamline = 0f)
        val p = StrokePath(shapeSpec, baseSize, seed, smoothing = false) { recordAndDraw(it) }
        p.begin(points[0], points[1], pressure)
        var i = 2
        while (i + 1 < points.size) {
            p.add(points[i], points[i + 1], pressure)
            i += 2
        }
        p.finish()
    }

    /** Draws a preview of [spec] into a small bitmap for the brush library. */
    fun renderPreview(spec: BrushSpec, color: Int, w: Int, h: Int): Bitmap {
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val size = (h * 0.28f).coerceAtMost(spec.defaultSize * 2.5f).coerceAtLeast(3f)
        val steps = 60
        val points = ArrayList<FloatArray>()
        for (i in 0..steps) {
            val t = i / steps.toFloat()
            val x = w * (0.08f + 0.84f * t)
            val y = h * (0.5f + 0.28f * kotlin.math.sin(t * 6.2831855f))
            val pressure = kotlin.math.sin(t * 3.1415927f).coerceAtLeast(0.05f)
            points += floatArrayOf(x, y, pressure)
        }
        val sp = spec.copy(streamline = 0f)
        val drawPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        val collected = ArrayList<Dab>()
        val path = StrokePath(sp, size, 42L, smoothing = false) { collected += it }
        path.begin(points[0][0], points[0][1], points[0][2])
        for (i in 1 until points.size) path.add(points[i][0], points[i][1], points[i][2])
        path.finish()
        val total = path.length
        for (d in collected) {
            val f = StrokePath.endTaper(sp, size, d.distance, total)
            drawDabOn(c, drawPaint, sp, color, d.x, d.y, d.size * f, d.alpha, d.angle)
        }
        return out
    }

    private inline fun redraw(block: () -> Unit) {
        layer.clear()
        dirty.setEmpty()
        block()
    }

    private fun recordAndDraw(d: Dab) {
        if (dabCount * 6 + 6 > dabs.size) dabs = dabs.copyOf(dabs.size * 2)
        val o = dabCount * 6
        dabs[o] = d.x
        dabs[o + 1] = d.y
        dabs[o + 2] = d.size
        dabs[o + 3] = d.alpha
        dabs[o + 4] = d.angle
        dabs[o + 5] = d.distance
        dabCount++
        drawDab(d.x, d.y, d.size, d.alpha, d.angle)
    }

    private fun drawDab(x: Float, y: Float, size: Float, alpha: Float, angle: Float) {
        val r = max(size, 1f) / 2f + 2f
        bounds.set(x - r, y - r, x + r, y + r)
        if (!bounds.intersects(0f, 0f, width.toFloat(), height.toFloat())) return
        layer.draw(bounds) { c -> drawDabOn(c, paint, spec, color, x, y, size, alpha, angle) }
        dirty.union(bounds)
    }

    private fun drawDabOn(c: Canvas, p: Paint, spec: BrushSpec, color: Int, x: Float, y: Float, size: Float, alpha: Float, angle: Float) {
        var s = size
        var a = alpha
        if (s < 1f) {
            // Thinner than a pixel: keep the width and fade instead, so hairlines stay smooth.
            a *= max(s, 0.1f)
            s = 1f
        }
        p.color = color
        p.alpha = (a * 255f + 0.5f).toInt().coerceIn(0, 255)
        if (p.alpha == 0) return
        if (spec.shape == DabShape.HARD) {
            if (spec.roundness >= 0.999f) {
                c.drawCircle(x, y, s / 2f, p)
            } else {
                c.save()
                c.rotate(angle, x, y)
                val rh = max(0.5f, s * spec.roundness / 2f)
                oval.set(x - s / 2f, y - rh, x + s / 2f, y + rh)
                c.drawOval(oval, p)
                c.restore()
            }
            return
        }
        val tex = DabTextures.get(spec.shape)
        val scale = s / tex.width
        c.save()
        c.translate(x, y)
        if (angle != 0f) c.rotate(angle)
        c.scale(scale, scale * spec.roundness)
        c.drawBitmap(tex, -tex.width / 2f, -tex.height / 2f, p)
        c.restore()
    }

    companion object {
        /** Integer bounds of [r] clamped to the canvas, or null when empty. */
        fun clampRect(r: RectF, width: Int, height: Int): Rect? {
            val out = Rect(
                floor(r.left).toInt().coerceAtLeast(0),
                floor(r.top).toInt().coerceAtLeast(0),
                ceil(r.right).toInt().coerceAtMost(width),
                ceil(r.bottom).toInt().coerceAtMost(height),
            )
            return if (out.isEmpty) null else out
        }

        fun distance(x0: Float, y0: Float, x1: Float, y1: Float) = hypot(x1 - x0, y1 - y0)
    }
}
