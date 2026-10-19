package com.silkie.launcher.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ImageDecoder
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RenderEffect
import android.graphics.Shader
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import com.silkie.launcher.settings.Ambient
import com.silkie.launcher.settings.BackgroundStyle
import com.silkie.launcher.settings.Prefs
import java.util.concurrent.Executors
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.sin
import kotlin.random.Random

/** The home screen background: a color, gradient, pattern or picture, plus an optional ambient effect. */
class Backdrop(context: Context) : FrameLayout(context) {
    private val image = ImageView(context).apply { scaleType = ImageView.ScaleType.CENTER_CROP }
    private val layer = Layer(context)
    private var imageUri = ""

    init {
        addView(image, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        addView(layer, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    }

    fun configure(p: Prefs, pal: Palette) {
        layer.configure(p, pal)
        setBackgroundColor(if (p.bgStyle == BackgroundStyle.WALLPAPER) 0 else pal.bg)
        val wantImage = p.bgStyle == BackgroundStyle.IMAGE && p.bgImage.isNotEmpty()
        image.visibility = if (wantImage) VISIBLE else GONE
        if (wantImage && p.bgImage != imageUri) loadImage(p.bgImage)
        if (!wantImage) {
            image.setImageDrawable(null)
            imageUri = ""
        }
        if (Build.VERSION.SDK_INT >= 31) {
            image.setRenderEffect(
                if (p.bgBlur > 0) RenderEffect.createBlurEffect(p.bgBlur.toFloat(), p.bgBlur.toFloat(), Shader.TileMode.CLAMP) else null,
            )
        }
    }

    /** Ambient animation runs only while the home screen is in front. */
    var running: Boolean
        get() = layer.running
        set(value) {
            layer.running = value
        }

    private fun loadImage(uri: String) {
        imageUri = uri
        val ctx = context
        val dm = resources.displayMetrics
        val target = max(dm.widthPixels, dm.heightPixels)
        io.execute {
            val bmp: Bitmap? = runCatching {
                val src = ImageDecoder.createSource(ctx.contentResolver, Uri.parse(uri))
                ImageDecoder.decodeBitmap(src) { decoder, info, _ ->
                    val s = info.size
                    val scale = target.toFloat() / max(s.width, s.height)
                    if (scale < 1f) decoder.setTargetSize((s.width * scale).toInt().coerceAtLeast(1), (s.height * scale).toInt().coerceAtLeast(1))
                }
            }.getOrNull()
            main.post { if (imageUri == uri) image.setImageBitmap(bmp) }
        }
    }

    private class Layer(context: Context) : View(context) {
        private var style = BackgroundStyle.GRADIENT
        private var ambient = Ambient.NONE
        private var bg = 0
        private var bg2 = 0
        private var accent = 0
        private var text = 0
        private var angle = 135
        private var dim = 0
        private var density = 40
        private var still = false
        private var speed = 1f
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }
        private val path = Path()
        private val random = Random(7)
        private var particles = Array(0) { Mote() }
        private var lastFrame = 0L
        private var scroll = 0f
        private var shader: Shader? = null
        private var shaderKey = ""

        var running = false
            set(value) {
                field = value
                if (value) {
                    lastFrame = 0L
                    invalidate()
                }
            }

        private class Mote {
            var x = 0f
            var y = 0f
            var vx = 0f
            var vy = 0f
            var size = 1f
            var phase = 0f
            var life = 0f
        }

        fun configure(p: Prefs, pal: Palette) {
            style = p.bgStyle
            ambient = p.ambient
            bg = pal.bg
            bg2 = pal.bg2
            accent = pal.accent
            text = pal.text
            angle = p.gradientAngle
            dim = p.bgDim
            density = p.ambientDensity
            still = p.reduceMotion
            speed = p.animationSpeed / 100f
            shaderKey = ""
            particles = Array(if (ambient == Ambient.NONE) 0 else countFor(ambient)) { Mote() }
            if (width > 0) particles.forEach { respawn(it, initial = true) }
            invalidate()
        }

        private fun countFor(a: Ambient): Int = when (a) {
            Ambient.SILK -> 3 + density / 12
            Ambient.SPARKLES -> 6 + density / 3
            else -> 6 + density / 2
        }

        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            shaderKey = ""
            particles.forEach { respawn(it, initial = true) }
        }

        private fun respawn(m: Mote, initial: Boolean) {
            val w = width.toFloat()
            val h = height.toFloat()
            val d = resources.displayMetrics.density
            m.x = random.nextFloat() * w
            m.y = if (initial) random.nextFloat() * h else when (ambient) {
                Ambient.SNOW, Ambient.PETALS -> -20f * d
                Ambient.BUBBLES -> h + 20f * d
                else -> random.nextFloat() * h
            }
            m.phase = random.nextFloat() * 6.28f
            m.life = if (initial) random.nextFloat() else 0f
            when (ambient) {
                Ambient.SNOW -> { m.size = (1.5f + random.nextFloat() * 2.5f) * d; m.vy = (20f + random.nextFloat() * 40f) * d; m.vx = 0f }
                Ambient.PETALS -> { m.size = (4f + random.nextFloat() * 4f) * d; m.vy = (18f + random.nextFloat() * 22f) * d; m.vx = (6f + random.nextFloat() * 12f) * d }
                Ambient.BUBBLES -> { m.size = (4f + random.nextFloat() * 10f) * d; m.vy = -(14f + random.nextFloat() * 26f) * d; m.vx = 0f }
                Ambient.FIREFLIES -> { m.size = (1.6f + random.nextFloat() * 1.6f) * d; m.vx = (random.nextFloat() - 0.5f) * 16f * d; m.vy = (random.nextFloat() - 0.5f) * 16f * d }
                Ambient.SPARKLES -> { m.size = (2f + random.nextFloat() * 3f) * d; m.vx = 0f; m.vy = 0f }
                Ambient.SILK -> { m.size = (60f + random.nextFloat() * 120f) * d; m.vx = (4f + random.nextFloat() * 8f) * d; m.vy = (random.nextFloat() - 0.5f) * 3f * d }
                Ambient.NONE -> Unit
            }
        }

        override fun onDraw(canvas: Canvas) {
            val w = width.toFloat()
            val h = height.toFloat()
            drawBase(canvas, w, h)
            if (dim > 0) canvas.drawColor(ColorMath.withAlpha(0xFF000000.toInt(), dim / 100f * if (style == BackgroundStyle.IMAGE || style == BackgroundStyle.WALLPAPER) 1f else 0.6f))

            val now = System.nanoTime()
            val dt = if (lastFrame == 0L || still) 0f else ((now - lastFrame) / 1e9f).coerceAtMost(0.1f) * speed
            lastFrame = now
            scroll += dt
            drawAmbient(canvas, w, h, dt)

            val animated = (ambient != Ambient.NONE || style == BackgroundStyle.HORIZON) && !still
            if (running && animated) postInvalidateDelayed(33)
        }

        private fun drawBase(c: Canvas, w: Float, h: Float) {
            when (style) {
                // The picture (or the system wallpaper) shows through from below.
                BackgroundStyle.WALLPAPER, BackgroundStyle.IMAGE -> return
                BackgroundStyle.SOLID -> {
                    c.drawColor(bg)
                    return
                }
                BackgroundStyle.RADIAL -> {
                    val key = "r$w$h$bg$bg2"
                    if (key != shaderKey) {
                        shader = RadialGradient(w * 0.5f, h * 0.12f, max(w, h) * 0.95f, bg2, bg, Shader.TileMode.CLAMP)
                        shaderKey = key
                    }
                }
                else -> {
                    val key = "l$w$h$bg$bg2$angle"
                    if (key != shaderKey) {
                        val a = Math.toRadians(angle.toDouble())
                        val r = hypot(w, h) / 2
                        val dx = (cos(a) * r).toFloat()
                        val dy = (sin(a) * r).toFloat()
                        shader = LinearGradient(w / 2 - dx, h / 2 - dy, w / 2 + dx, h / 2 + dy, bg, bg2, Shader.TileMode.CLAMP)
                        shaderKey = key
                    }
                }
            }
            paint.shader = shader
            c.drawRect(0f, 0f, w, h, paint)
            paint.shader = null
            val d = resources.displayMetrics.density
            when (style) {
                BackgroundStyle.DOTS -> {
                    paint.color = ColorMath.withAlpha(text, 0.09f)
                    val step = 22 * d
                    var y = step / 2
                    while (y < h) {
                        var x = step / 2
                        while (x < w) {
                            c.drawCircle(x, y, 1.4f * d, paint)
                            x += step
                        }
                        y += step
                    }
                }
                BackgroundStyle.GRID -> {
                    stroke.color = ColorMath.withAlpha(accent, 0.1f)
                    stroke.strokeWidth = d
                    val step = 32 * d
                    var x = 0f
                    while (x < w) { c.drawLine(x, 0f, x, h, stroke); x += step }
                    var y = 0f
                    while (y < h) { c.drawLine(0f, y, w, y, stroke); y += step }
                }
                BackgroundStyle.HORIZON -> drawHorizon(c, w, h, d)
                else -> Unit
            }
        }

        private fun drawHorizon(c: Canvas, w: Float, h: Float, d: Float) {
            val horizon = h * 0.58f
            // Sun
            paint.shader = LinearGradient(0f, horizon - h * 0.3f, 0f, horizon, accent, ColorMath.mix(accent, bg2, 0.5f), Shader.TileMode.CLAMP)
            c.save()
            c.clipRect(0f, 0f, w, horizon)
            c.drawCircle(w / 2, horizon, h * 0.2f, paint)
            c.restore()
            paint.shader = null
            paint.color = bg
            c.drawRect(0f, horizon, w, h, paint)
            stroke.color = ColorMath.withAlpha(accent, 0.45f)
            stroke.strokeWidth = 1.2f * d
            c.drawLine(0f, horizon, w, horizon, stroke)
            val lines = 12
            val offset = (scroll * 0.35f) % 1f
            for (i in 0 until lines) {
                val u = (i + offset) / lines
                val y = horizon + (h - horizon) * u * u
                stroke.color = ColorMath.withAlpha(accent, 0.15f + 0.35f * u)
                c.drawLine(0f, y, w, y, stroke)
            }
            stroke.color = ColorMath.withAlpha(accent, 0.3f)
            for (i in -10..10) {
                val bx = w / 2 + i * w / 7f
                c.drawLine(w / 2 + i * w / 60f, horizon, bx + (bx - w / 2) * 1.5f, h, stroke)
            }
        }

        private fun drawAmbient(c: Canvas, w: Float, h: Float, dt: Float) {
            if (particles.isEmpty()) return
            val d = resources.displayMetrics.density
            for (m in particles) {
                m.phase += dt
                m.life += dt
                when (ambient) {
                    Ambient.SNOW -> {
                        m.y += m.vy * dt
                        m.x += sin(m.phase * 1.3f) * 12f * d * dt
                        paint.color = ColorMath.withAlpha(0xFFFFFFFF.toInt(), 0.75f)
                        c.drawCircle(m.x, m.y, m.size, paint)
                        if (m.y > h + 20 * d) respawn(m, false)
                    }
                    Ambient.PETALS -> {
                        m.y += m.vy * dt
                        m.x += (m.vx + sin(m.phase) * 14f * d) * dt
                        paint.color = ColorMath.withAlpha(ColorMath.mix(accent, 0xFFFFC1D9.toInt(), 0.55f), 0.8f)
                        c.save()
                        c.rotate(m.phase * 50f, m.x, m.y)
                        c.drawOval(m.x - m.size, m.y - m.size * 0.55f, m.x + m.size, m.y + m.size * 0.55f, paint)
                        c.restore()
                        if (m.y > h + 20 * d || m.x > w + 20 * d) respawn(m, false)
                    }
                    Ambient.BUBBLES -> {
                        m.y += m.vy * dt
                        m.x += sin(m.phase * 2f) * 8f * d * dt
                        stroke.color = ColorMath.withAlpha(text, 0.22f)
                        stroke.strokeWidth = 1.2f * d
                        c.drawCircle(m.x, m.y, m.size, stroke)
                        paint.color = ColorMath.withAlpha(0xFFFFFFFF.toInt(), 0.25f)
                        c.drawCircle(m.x - m.size * 0.35f, m.y - m.size * 0.35f, m.size * 0.2f, paint)
                        if (m.y < -20 * d) respawn(m, false)
                    }
                    Ambient.FIREFLIES -> {
                        m.x += (m.vx + sin(m.phase * 0.7f) * 10f * d) * dt
                        m.y += (m.vy + cos(m.phase * 0.9f) * 10f * d) * dt
                        if (m.x < -10 || m.x > w + 10 || m.y < -10 || m.y > h + 10) respawn(m, true)
                        val glow = 0.35f + 0.65f * (0.5f + 0.5f * sin(m.phase * 2.2f))
                        val col = ColorMath.mix(accent, 0xFFFFF59D.toInt(), 0.5f)
                        paint.color = ColorMath.withAlpha(col, 0.18f * glow)
                        c.drawCircle(m.x, m.y, m.size * 4f, paint)
                        paint.color = ColorMath.withAlpha(col, 0.9f * glow)
                        c.drawCircle(m.x, m.y, m.size, paint)
                    }
                    Ambient.SPARKLES -> {
                        val tw = sin(m.life * 2.5f)
                        if (m.life > PI.toFloat() / 2.5f) respawn(m, false)
                        val r = m.size * (0.2f + 0.8f * tw.coerceAtLeast(0f))
                        paint.color = ColorMath.withAlpha(ColorMath.mix(accent, 0xFFFFFFFF.toInt(), 0.5f), 0.8f * tw.coerceAtLeast(0f))
                        path.reset()
                        path.moveTo(m.x, m.y - r * 2)
                        path.quadTo(m.x, m.y, m.x + r * 2, m.y)
                        path.quadTo(m.x, m.y, m.x, m.y + r * 2)
                        path.quadTo(m.x, m.y, m.x - r * 2, m.y)
                        path.quadTo(m.x, m.y, m.x, m.y - r * 2)
                        c.drawPath(path, paint)
                    }
                    Ambient.SILK -> {
                        m.x += m.vx * dt
                        m.y += m.vy * dt
                        if (m.x - m.size > w) { respawn(m, false); m.x = -m.size }
                        stroke.color = ColorMath.withAlpha(text, 0.1f)
                        stroke.strokeWidth = 1f * d
                        path.reset()
                        val segs = 16
                        for (i in 0..segs) {
                            val u = i / segs.toFloat()
                            val x = m.x - m.size / 2 + m.size * u
                            val y = m.y + sin(u * 6f + m.phase * 0.8f) * 10f * d
                            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
                        }
                        c.drawPath(path, stroke)
                    }
                    Ambient.NONE -> Unit
                }
            }
        }
    }

    companion object {
        private val io = Executors.newSingleThreadExecutor()
        private val main = Handler(Looper.getMainLooper())
    }
}
