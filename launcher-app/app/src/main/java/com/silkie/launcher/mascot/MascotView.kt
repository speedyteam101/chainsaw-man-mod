package com.silkie.launcher.mascot

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import com.silkie.launcher.settings.MascotAccessory
import com.silkie.launcher.settings.MascotEyes
import com.silkie.launcher.settings.MascotHat
import com.silkie.launcher.ui.ColorMath
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/** Everything about how the mascot looks. */
data class MascotLook(
    val stage: MascotStage = MascotStage.MOTH,
    val body: Int = 0xFFFFF4E6.toInt(),
    val wings: Int = 0xFFFFD9A8.toInt(),
    val cheeks: Int = 0xFFFF9EB5.toInt(),
    val accent: Int = 0xFFFFB86B.toInt(),
    val eyes: MascotEyes = MascotEyes.ROUND,
    val hat: MascotHat = MascotHat.NONE,
    val accessory: MascotAccessory = MascotAccessory.NONE,
)

/**
 * Silkie, the launcher's mascot: a fluffy silk moth (or, earlier in life, a caterpillar and then a
 * cocoon). Drawn entirely with Canvas on a 100×100 grid, standing on the bottom edge of the view.
 */
class MascotView(context: Context) : View(context) {
    var look = MascotLook()
        set(value) {
            field = value
            invalidate()
        }
    var mood = Mood.HAPPY
        set(value) {
            field = value
            invalidate()
        }
    /** 1 = normal; scales every animation. */
    var speed = 1f
    /** No idle animation at all (the "reduce motion" setting). */
    var still = false
        set(value) {
            field = value
            invalidate()
        }
    /** Size inside the view, 0.5..1.6. */
    var sizeFactor = 1f
        set(value) {
            field = value
            invalidate()
        }

    private val start = SystemClock.uptimeMillis()
    private var nextBlink = 1500L
    private var blinkAt = -1000L
    private var jumpAt = -10_000L
    private var cheerUntil = 0L
    private var talkUntil = 0L
    private var lookX = 0f
    private var lookTarget = 0f
    private var lastZ = 0L
    private val random = Random(SystemClock.uptimeMillis())

    private class Particle(val kind: Int, var x: Float, var y: Float, val vx: Float, val vy: Float, val born: Long, val life: Long, val size: Float)
    private val particles = mutableListOf<Particle>()

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER; isFakeBoldText = true }
    private val path = Path()
    private val rect = RectF()

    private val ink = 0xFF2A2233.toInt()

    private class Head(val cx: Float, val cy: Float, val r: Float) {
        val s get() = r / 24f
        val top get() = cy - r
    }

    init {
        isClickable = true
        isFocusable = true
        contentDescription = "Mascot"
    }

    private fun now() = ((SystemClock.uptimeMillis() - start) * speed).toLong()

    /** Little hop and hearts, e.g. when tapped. */
    fun poke() {
        val t = now()
        jumpAt = t
        repeat(3) { spawn(KIND_HEART, 50f + random.nextFloat() * 30 - 15, 30f, t) }
        invalidate()
    }

    /** Excited wing flapping and sparkles, e.g. when a game launches. */
    fun cheer() {
        val t = now()
        jumpAt = t
        cheerUntil = t + 1800
        repeat(6) { spawn(KIND_SPARKLE, 50f + random.nextFloat() * 60 - 30, 40f + random.nextFloat() * 20, t) }
        invalidate()
    }

    /** A bigger burst of sparkles for evolving. */
    fun celebrate() {
        val t = now()
        cheerUntil = t + 2500
        repeat(14) { spawn(KIND_SPARKLE, 50f + random.nextFloat() * 80 - 40, 30f + random.nextFloat() * 50, t) }
        repeat(3) { spawn(KIND_NOTE, 50f + random.nextFloat() * 40 - 20, 30f, t) }
        invalidate()
    }

    fun talk(ms: Long) {
        talkUntil = now() + ms
        invalidate()
    }

    /** Point the eyes toward a spot: -1 = far left, 1 = far right. */
    fun lookToward(x: Float) {
        lookTarget = x.coerceIn(-1f, 1f)
        invalidate()
    }

    private fun spawn(kind: Int, x: Float, y: Float, t: Long) {
        particles += Particle(
            kind, x, y,
            vx = (random.nextFloat() - 0.5f) * 14f,
            vy = -18f - random.nextFloat() * 14f,
            born = t, life = 1400L + random.nextInt(600), size = 0.7f + random.nextFloat() * 0.6f,
        )
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_DOWN) lookToward((event.x / width.coerceAtLeast(1)) * 2 - 1)
        return super.onTouchEvent(event)
    }

    override fun onDraw(canvas: Canvas) {
        val t = now()
        val sec = if (still) 0f else t / 1000f
        val k = min(width, height) / 100f * sizeFactor
        if (k <= 0f) return

        if (!still && t > nextBlink) {
            blinkAt = t
            nextBlink = t + 2200 + random.nextInt(3200)
        }
        lookX += (lookTarget - lookX) * 0.15f

        val excited = t < cheerUntil || mood == Mood.EXCITED
        val sleepy = mood == Mood.SLEEPY
        val jump = ((t - jumpAt) / 550f).let { if (it in 0f..1f && !still) -sin(it * PI.toFloat()) * 12f else 0f }
        val bob = if (still) 0f else sin(sec * if (sleepy) 1.2f else 2.4f) * if (sleepy) 0.8f else 1.6f

        canvas.save()
        canvas.translate(width / 2f - 50f * k, height - 100f * k)
        canvas.scale(k, k)

        // Shadow on the ground, shrinking while airborne.
        fill.color = 0x33000000
        val sh = 1f + jump / 24f
        rect.set(50 - 18 * sh, 88f, 50 + 18 * sh, 93f)
        canvas.drawOval(rect, fill)

        canvas.save()
        canvas.translate(0f, bob + jump)
        val head = when (stageToDraw()) {
            MascotStage.LARVA -> drawLarva(canvas, sec)
            MascotStage.COCOON -> drawCocoon(canvas, sec)
            else -> drawMoth(canvas, sec, excited)
        }
        drawFace(canvas, head, t, sec, excited, sleepy)
        drawAccessory(canvas, head)
        drawHat(canvas, head, sec)
        canvas.restore()

        if (sleepy && !still && t - lastZ > 1600) {
            lastZ = t
            particles += Particle(KIND_Z, head.cx + head.r * 0.8f, head.top + 4, 6f, -10f, t, 2400, 1f)
        }
        drawParticles(canvas, t)
        canvas.restore()

        if (!still || particles.isNotEmpty() || abs(lookTarget - lookX) > 0.01f) postInvalidateDelayed(FRAME_MS)
    }

    private fun stageToDraw() = if (look.stage == MascotStage.AUTO) MascotStage.MOTH else look.stage

    // --- Body shapes -------------------------------------------------------------------------

    private fun drawMoth(c: Canvas, sec: Float, excited: Boolean): Head {
        val flap = if (excited) 0.5f + 0.5f * sin(sec * 22f) else 0.5f + 0.5f * sin(sec * 2.6f)
        val sx = 1f - (if (excited) 0.45f else 0.12f) * flap
        val wingDark = ColorMath.mix(look.wings, ink, 0.25f)
        val wingLight = ColorMath.mix(look.wings, 0xFFFFFFFF.toInt(), 0.55f)

        for (side in intArrayOf(-1, 1)) {
            c.save()
            c.translate(50f, 54f)
            c.scale(side * sx, 1f)
            // Upper wing
            c.save()
            c.translate(21f, -10f)
            c.rotate(-24f)
            rect.set(-21f, -14f, 21f, 14f)
            fill.color = look.wings
            c.drawOval(rect, fill)
            stroke.color = wingDark
            stroke.strokeWidth = 1.3f
            c.drawOval(rect, stroke)
            fill.color = wingLight
            c.drawCircle(7f, -1f, 5.5f, fill)
            fill.color = wingDark
            c.drawCircle(7f, -1f, 2.2f, fill)
            stroke.strokeWidth = 0.9f
            c.drawLine(-16f, 2f, 14f, 6f, stroke)
            c.restore()
            // Lower wing
            c.save()
            c.translate(15f, 12f)
            c.rotate(28f)
            rect.set(-13f, -9f, 13f, 9f)
            fill.color = ColorMath.mix(look.wings, look.accent, 0.25f)
            c.drawOval(rect, fill)
            stroke.strokeWidth = 1.3f
            c.drawOval(rect, stroke)
            c.restore()
            c.restore()
        }

        // Feathery antennae
        val sway = sin(sec * 1.7f) * 1.6f
        stroke.color = ColorMath.mix(look.body, ink, 0.45f)
        for (side in intArrayOf(-1, 1)) {
            val x0 = 50f + side * 7f
            val y0 = 36f
            val x2 = 50f + side * 19f + sway
            val y2 = 13f
            val x1 = 50f + side * 9f
            val y1 = 20f
            stroke.strokeWidth = 1.6f
            path.reset()
            path.moveTo(x0, y0)
            path.quadTo(x1, y1, x2, y2)
            c.drawPath(path, stroke)
            stroke.strokeWidth = 1f
            for (i in 2..8) {
                val u = i / 9f
                val px = quad(x0, x1, x2, u)
                val py = quad(y0, y1, y2, u)
                val len = 2.8f * (1 - abs(u - 0.6f))
                c.drawLine(px, py, px - len, py - len * 0.6f, stroke)
                c.drawLine(px, py, px + len, py - len * 0.6f, stroke)
            }
        }

        drawFluffBall(c, 50f, 58f, 24f)
        // Feet
        fill.color = ColorMath.mix(look.body, ink, 0.3f)
        rect.set(39f, 80f, 47f, 85f); c.drawOval(rect, fill)
        rect.set(53f, 80f, 61f, 85f); c.drawOval(rect, fill)
        return Head(50f, 56f, 24f)
    }

    private fun drawFluffBall(c: Canvas, cx: Float, cy: Float, r: Float) {
        val edge = ColorMath.mix(look.body, ink, 0.12f)
        fill.color = edge
        for (i in 0 until 16) {
            val a = 2 * PI * i / 16
            c.drawCircle(cx + (r - 1.5f) * cos(a).toFloat(), cy + (r - 1.5f) * sin(a).toFloat(), 5.6f, fill)
        }
        fill.color = look.body
        for (i in 0 until 16) {
            val a = 2 * PI * i / 16
            c.drawCircle(cx + (r - 2.5f) * cos(a).toFloat(), cy + (r - 2.5f) * sin(a).toFloat(), 5f, fill)
        }
        c.drawCircle(cx, cy, r - 2f, fill)
        // Fluffy collar and soft belly
        fill.color = ColorMath.mix(look.body, 0xFFFFFFFF.toInt(), 0.5f)
        rect.set(cx - r * 0.55f, cy + r * 0.2f, cx + r * 0.55f, cy + r * 0.85f)
        c.drawOval(rect, fill)
    }

    private fun drawLarva(c: Canvas, sec: Float): Head {
        val spot = look.wings
        val shade = ColorMath.mix(look.body, ink, 0.15f)
        for (i in 0 until 4) {
            val x = 18f + i * 11.5f
            val y = 76f - abs(sin(sec * 3f - i * 0.8f)) * 3.5f
            fill.color = ColorMath.mix(look.body, ink, 0.35f)
            rect.set(x - 3f, 83f, x + 3f, 86f); c.drawOval(rect, fill)
            fill.color = shade
            c.drawCircle(x, y, 10f, fill)
            fill.color = look.body
            c.drawCircle(x, y - 0.6f, 9f, fill)
            fill.color = spot
            c.drawCircle(x + 1f, y - 4f, 2.4f, fill)
        }
        val hx = 70f
        val hy = 62f - abs(sin(sec * 3f + 0.8f)) * 2f
        // Antenna nubs
        stroke.color = ColorMath.mix(look.body, ink, 0.45f)
        stroke.strokeWidth = 1.6f
        fill.color = look.accent
        for (side in intArrayOf(-1, 1)) {
            val tx = hx + side * 7f + sin(sec * 2f + side) * 1.2f
            c.drawLine(hx + side * 4f, hy - 13f, tx, hy - 22f, stroke)
            c.drawCircle(tx, hy - 22f, 2.2f, fill)
        }
        fill.color = shade
        c.drawCircle(hx, hy, 16f, fill)
        fill.color = look.body
        c.drawCircle(hx, hy - 0.8f, 15f, fill)
        return Head(hx, hy, 15f)
    }

    private fun drawCocoon(c: Canvas, sec: Float): Head {
        val wobble = sin(sec * 1.4f) * 4f
        stroke.color = ColorMath.withAlpha(look.body, 0.8f)
        stroke.strokeWidth = 0.8f
        c.drawLine(50f, -40f, 50f, 24f, stroke)
        c.save()
        c.rotate(wobble, 50f, 22f)
        rect.set(28f, 22f, 72f, 88f)
        fill.color = ColorMath.mix(look.body, ink, 0.12f)
        c.drawOval(rect, fill)
        rect.set(29.5f, 23f, 70.5f, 86.5f)
        fill.color = look.body
        c.drawOval(rect, fill)
        // Silk wrapping
        c.save()
        path.reset()
        path.addOval(rect, Path.Direction.CW)
        c.clipPath(path)
        stroke.color = ColorMath.mix(look.body, look.wings, 0.6f)
        stroke.strokeWidth = 1.4f
        var y = 40f
        while (y < 100f) {
            c.drawLine(20f, y, 80f, y - 18f, stroke)
            y += 7f
        }
        c.restore()
        c.restore()
        // The face peeks out of an opening near the top.
        val hx = 50f + wobble * 0.4f
        fill.color = ColorMath.mix(look.body, 0xFFFFFFFF.toInt(), 0.4f)
        rect.set(hx - 15f, 33f, hx + 15f, 60f)
        c.drawOval(rect, fill)
        return Head(hx, 46f, 18f)
    }

    // --- Face --------------------------------------------------------------------------------

    private fun drawFace(c: Canvas, h: Head, t: Long, sec: Float, excited: Boolean, sleepy: Boolean) {
        val s = h.s
        val ex = 9f * s
        val ey = h.cy - 3f * s
        val blinking = t - blinkAt in 0..140
        val gaze = lookX * 1.6f * s
        val eyesClosed = sleepy || blinking

        // Cheeks
        fill.color = ColorMath.withAlpha(look.cheeks, 0.75f)
        for (side in intArrayOf(-1, 1)) {
            rect.set(h.cx + side * 14f * s - 4f * s, h.cy + 2.5f * s, h.cx + side * 14f * s + 4f * s, h.cy + 7f * s)
            c.drawOval(rect, fill)
        }

        stroke.color = ink
        stroke.strokeWidth = 1.6f * s
        fill.color = ink
        for (side in intArrayOf(-1, 1)) {
            val x = h.cx + side * ex
            when {
                look.eyes == MascotEyes.HAPPY || (excited && !eyesClosed && look.eyes != MascotEyes.ANIME) -> {
                    path.reset()
                    path.moveTo(x - 4f * s, ey + 1.5f * s)
                    path.quadTo(x, ey - 5f * s, x + 4f * s, ey + 1.5f * s)
                    c.drawPath(path, stroke)
                }
                eyesClosed -> {
                    path.reset()
                    path.moveTo(x - 4f * s, ey)
                    path.quadTo(x, ey + 3.5f * s, x + 4f * s, ey)
                    c.drawPath(path, stroke)
                }
                look.eyes == MascotEyes.DOT -> c.drawCircle(x + gaze, ey, 2.6f * s, fill)
                look.eyes == MascotEyes.ANIME -> {
                    rect.set(x - 4.6f * s, ey - 7f * s, x + 4.6f * s, ey + 6f * s)
                    fill.color = ink
                    c.drawOval(rect, fill)
                    fill.color = ColorMath.mix(look.accent, ink, 0.2f)
                    rect.set(x - 3.6f * s + gaze, ey - 1f * s, x + 3.6f * s + gaze, ey + 5f * s)
                    c.drawOval(rect, fill)
                    fill.color = 0xFFFFFFFF.toInt()
                    c.drawCircle(x - 1.6f * s + gaze, ey - 3.2f * s, 2.2f * s, fill)
                    c.drawCircle(x + 1.8f * s + gaze, ey + 2.6f * s, 1f * s, fill)
                    fill.color = ink
                }
                look.eyes == MascotEyes.SLEEPY -> {
                    c.save()
                    rect.set(x - 5.5f * s, ey - 1f * s, x + 5.5f * s, ey + 6f * s)
                    c.clipRect(rect)
                    c.drawCircle(x + gaze, ey, 5f * s, fill)
                    c.restore()
                    c.drawLine(x - 5f * s, ey - 0.6f * s, x + 5f * s, ey - 0.6f * s, stroke)
                    fill.color = 0xFFFFFFFF.toInt()
                    c.drawCircle(x - 1.5f * s + gaze, ey + 1.5f * s, 1.1f * s, fill)
                    fill.color = ink
                }
                else -> {
                    c.drawCircle(x + gaze, ey, 5.5f * s, fill)
                    fill.color = 0xFFFFFFFF.toInt()
                    c.drawCircle(x - 1.8f * s + gaze, ey - 2f * s, 1.9f * s, fill)
                    c.drawCircle(x + 1.6f * s + gaze, ey + 1.6f * s, 0.9f * s, fill)
                    if (look.eyes == MascotEyes.SPARKLE) star(c, x + 2f * s + gaze, ey - 2.4f * s, 1.6f * s, 0xFFFFFFFF.toInt())
                    fill.color = ink
                }
            }
        }

        // Mouth
        val my = h.cy + 6f * s
        val talking = t < talkUntil
        when {
            talking -> {
                val open = 1f + 2.2f * abs(sin(sec * 16f))
                rect.set(h.cx - 2.6f * s, my - open * 0.5f * s, h.cx + 2.6f * s, my + open * s)
                fill.color = ink
                c.drawOval(rect, fill)
            }
            excited -> {
                rect.set(h.cx - 4f * s, my - 3f * s, h.cx + 4f * s, my + 4f * s)
                fill.color = ink
                c.drawArc(rect, 0f, 180f, true, fill)
                fill.color = 0xFFFF7A90.toInt()
                rect.set(h.cx - 2.2f * s, my + 1f * s, h.cx + 2.2f * s, my + 3.6f * s)
                c.drawOval(rect, fill)
            }
            sleepy || mood == Mood.CURIOUS -> {
                fill.color = ink
                c.drawCircle(h.cx, my + 0.5f * s, 1.3f * s, fill)
            }
            mood == Mood.PROUD -> {
                path.reset()
                path.moveTo(h.cx - 4f * s, my)
                path.quadTo(h.cx - 2f * s, my + 2.6f * s, h.cx, my)
                path.quadTo(h.cx + 2f * s, my + 2.6f * s, h.cx + 4f * s, my)
                c.drawPath(path, stroke)
            }
            else -> {
                path.reset()
                path.moveTo(h.cx - 3f * s, my)
                path.quadTo(h.cx, my + 3f * s, h.cx + 3f * s, my)
                c.drawPath(path, stroke)
            }
        }
    }

    // --- Accessories and hats ----------------------------------------------------------------

    private fun drawAccessory(c: Canvas, h: Head) {
        val s = h.s
        val acc = look.accent
        val accDark = ColorMath.mix(acc, ink, 0.3f)
        val ey = h.cy - 3f * s
        when (look.accessory) {
            MascotAccessory.NONE -> Unit
            MascotAccessory.GLASSES -> {
                stroke.color = ink
                stroke.strokeWidth = 1.3f * s
                c.drawCircle(h.cx - 9f * s, ey, 7f * s, stroke)
                c.drawCircle(h.cx + 9f * s, ey, 7f * s, stroke)
                c.drawLine(h.cx - 2f * s, ey - 1f * s, h.cx + 2f * s, ey - 1f * s, stroke)
            }
            MascotAccessory.SUNGLASSES -> {
                fill.color = 0xFF15131A.toInt()
                for (side in intArrayOf(-1, 1)) {
                    rect.set(h.cx + side * 9f * s - 7f * s, ey - 4.5f * s, h.cx + side * 9f * s + 7f * s, ey + 4.5f * s)
                    c.drawRoundRect(rect, 3f * s, 3f * s, fill)
                }
                stroke.color = 0xFF15131A.toInt()
                stroke.strokeWidth = 1.6f * s
                c.drawLine(h.cx - 3f * s, ey - 2f * s, h.cx + 3f * s, ey - 2f * s, stroke)
                stroke.color = 0x66FFFFFF
                stroke.strokeWidth = 1f * s
                c.drawLine(h.cx - 14f * s, ey - 2.5f * s, h.cx - 11f * s, ey - 2.5f * s, stroke)
                c.drawLine(h.cx + 4f * s, ey - 2.5f * s, h.cx + 7f * s, ey - 2.5f * s, stroke)
            }
            MascotAccessory.SCARF -> {
                val y = h.cy + 14f * s
                fill.color = acc
                rect.set(h.cx - 19f * s, y, h.cx + 19f * s, y + 6f * s)
                c.drawRoundRect(rect, 3f * s, 3f * s, fill)
                rect.set(h.cx + 7f * s, y + 3f * s, h.cx + 13f * s, y + 17f * s)
                c.drawRoundRect(rect, 2f * s, 2f * s, fill)
                stroke.color = accDark
                stroke.strokeWidth = 1.2f * s
                c.drawLine(h.cx + 7f * s, y + 10f * s, h.cx + 13f * s, y + 10f * s, stroke)
                c.drawLine(h.cx + 7f * s, y + 14f * s, h.cx + 13f * s, y + 14f * s, stroke)
            }
            MascotAccessory.BOWTIE -> {
                val y = h.cy + 16f * s
                fill.color = acc
                path.reset()
                path.moveTo(h.cx, y)
                path.lineTo(h.cx - 8f * s, y - 4.5f * s)
                path.lineTo(h.cx - 8f * s, y + 4.5f * s)
                path.close()
                path.moveTo(h.cx, y)
                path.lineTo(h.cx + 8f * s, y - 4.5f * s)
                path.lineTo(h.cx + 8f * s, y + 4.5f * s)
                path.close()
                c.drawPath(path, fill)
                fill.color = accDark
                c.drawCircle(h.cx, y, 2.4f * s, fill)
            }
            MascotAccessory.CONTROLLER -> {
                val y = h.cy + 19f * s
                fill.color = 0xFF3A3842.toInt()
                rect.set(h.cx - 13f * s, y - 5f * s, h.cx + 13f * s, y + 6f * s)
                c.drawRoundRect(rect, 5f * s, 5f * s, fill)
                fill.color = 0xFFDADAE0.toInt()
                c.drawRect(h.cx - 9.5f * s, y - 0.6f * s, h.cx - 4.5f * s, y + 1.2f * s, fill)
                c.drawRect(h.cx - 7.9f * s, y - 2.2f * s, h.cx - 6.1f * s, y + 2.8f * s, fill)
                fill.color = 0xFFFF6B6B.toInt(); c.drawCircle(h.cx + 8.5f * s, y - 1f * s, 1.5f * s, fill)
                fill.color = 0xFF6BCBFF.toInt(); c.drawCircle(h.cx + 5.5f * s, y + 1.8f * s, 1.5f * s, fill)
                // Little paws holding it
                fill.color = look.body
                c.drawCircle(h.cx - 13f * s, y + 1f * s, 3.4f * s, fill)
                c.drawCircle(h.cx + 13f * s, y + 1f * s, 3.4f * s, fill)
            }
        }
    }

    private fun drawHat(c: Canvas, h: Head, sec: Float) {
        val s = h.s
        val cx = h.cx
        val top = h.top
        val acc = look.accent
        val accDark = ColorMath.mix(acc, ink, 0.3f)
        val gold = 0xFFFFD54F.toInt()
        when (look.hat) {
            MascotHat.NONE -> Unit
            MascotHat.BEANIE -> {
                fill.color = acc
                rect.set(cx - 19f * s, top - 6f * s, cx + 19f * s, top + 24f * s)
                c.drawArc(rect, 180f, 180f, true, fill)
                fill.color = accDark
                rect.set(cx - 20f * s, top + 5f * s, cx + 20f * s, top + 11f * s)
                c.drawRoundRect(rect, 3f * s, 3f * s, fill)
                fill.color = 0xFFFFFFFF.toInt()
                c.drawCircle(cx, top - 7f * s, 4.5f * s, fill)
            }
            MascotHat.CROWN -> {
                path.reset()
                val b = top + 5f * s
                path.moveTo(cx - 13f * s, b)
                path.lineTo(cx - 13f * s, top - 9f * s)
                path.lineTo(cx - 6.5f * s, top - 1f * s)
                path.lineTo(cx, top - 12f * s)
                path.lineTo(cx + 6.5f * s, top - 1f * s)
                path.lineTo(cx + 13f * s, top - 9f * s)
                path.lineTo(cx + 13f * s, b)
                path.close()
                fill.color = gold
                c.drawPath(path, fill)
                stroke.color = 0xFFE0A800.toInt()
                stroke.strokeWidth = 1f * s
                c.drawPath(path, stroke)
                fill.color = acc
                c.drawCircle(cx, top + 1.5f * s, 2f * s, fill)
                fill.color = 0xFF6BCBFF.toInt()
                c.drawCircle(cx - 7f * s, top + 2f * s, 1.4f * s, fill)
                c.drawCircle(cx + 7f * s, top + 2f * s, 1.4f * s, fill)
            }
            MascotHat.WIZARD -> {
                val col = ColorMath.mix(acc, 0xFF3B2A7A.toInt(), 0.6f)
                path.reset()
                path.moveTo(cx - 13f * s, top + 5f * s)
                path.quadTo(cx - 2f * s, top - 12f * s, cx + 10f * s + sin(sec) * 1.5f * s, top - 28f * s)
                path.quadTo(cx + 6f * s, top - 10f * s, cx + 13f * s, top + 5f * s)
                path.close()
                fill.color = col
                c.drawPath(path, fill)
                rect.set(cx - 22f * s, top + 2f * s, cx + 22f * s, top + 8f * s)
                fill.color = ColorMath.mix(col, ink, 0.2f)
                c.drawOval(rect, fill)
                star(c, cx - 2f * s, top - 6f * s, 2.4f * s, gold)
                star(c, cx + 5f * s, top - 15f * s, 1.6f * s, gold)
            }
            MascotHat.PARTY -> {
                c.save()
                c.rotate(14f, cx, top)
                path.reset()
                path.moveTo(cx - 9f * s, top + 3f * s)
                path.lineTo(cx + 9f * s, top + 3f * s)
                path.lineTo(cx, top - 22f * s)
                path.close()
                fill.color = acc
                c.drawPath(path, fill)
                c.save()
                c.clipPath(path)
                stroke.color = 0xFFFFFFFF.toInt()
                stroke.strokeWidth = 2f * s
                for (i in 0..3) c.drawLine(cx - 12f * s, top - i * 7f * s + 2f * s, cx + 12f * s, top - i * 7f * s - 4f * s, stroke)
                c.restore()
                fill.color = gold
                c.drawCircle(cx, top - 22f * s, 3f * s, fill)
                c.restore()
            }
            MascotHat.HEADPHONES -> {
                stroke.color = 0xFF3A3842.toInt()
                stroke.strokeWidth = 3.4f * s
                rect.set(cx - h.r - 1f, h.cy - h.r - 4f * s, cx + h.r + 1f, h.cy + h.r)
                c.drawArc(rect, 195f, 150f, false, stroke)
                fill.color = acc
                for (side in intArrayOf(-1, 1)) {
                    rect.set(cx + side * (h.r + 1f) - 4f * s, h.cy - 9f * s, cx + side * (h.r + 1f) + 4f * s, h.cy + 4f * s)
                    c.drawRoundRect(rect, 3f * s, 3f * s, fill)
                }
            }
            MascotHat.BOW -> {
                val bx = cx + 12f * s
                val by = top + 5f * s
                fill.color = acc
                path.reset()
                path.moveTo(bx, by)
                path.lineTo(bx - 9f * s, by - 6f * s)
                path.lineTo(bx - 8f * s, by + 5f * s)
                path.close()
                path.moveTo(bx, by)
                path.lineTo(bx + 9f * s, by - 6f * s)
                path.lineTo(bx + 8f * s, by + 5f * s)
                path.close()
                c.drawPath(path, fill)
                fill.color = accDark
                c.drawCircle(bx, by, 2.6f * s, fill)
            }
            MascotHat.FLOWER -> {
                val fx = cx - 12f * s
                val fy = top + 5f * s
                fill.color = acc
                for (i in 0 until 5) {
                    val a = 2 * PI * i / 5 + sec * 0.3
                    c.drawCircle(fx + 4f * s * cos(a).toFloat(), fy + 4f * s * sin(a).toFloat(), 3.4f * s, fill)
                }
                fill.color = gold
                c.drawCircle(fx, fy, 2.6f * s, fill)
            }
            MascotHat.CAP -> {
                fill.color = acc
                rect.set(cx - 18f * s, top - 4f * s, cx + 18f * s, top + 20f * s)
                c.drawArc(rect, 180f, 180f, true, fill)
                fill.color = accDark
                rect.set(cx + 4f * s, top + 5f * s, cx + 30f * s, top + 10f * s)
                c.drawOval(rect, fill)
                c.drawCircle(cx, top - 4f * s, 1.8f * s, fill)
            }
            MascotHat.HORNS -> {
                fill.color = ColorMath.mix(acc, 0xFFB3261E.toInt(), 0.7f)
                for (side in intArrayOf(-1, 1)) {
                    val bx = cx + side * 11f * s
                    path.reset()
                    path.moveTo(bx - 4f * s, top + 6f * s)
                    path.quadTo(bx + side * 1f * s, top - 2f * s, bx + side * 5f * s, top - 9f * s)
                    path.quadTo(bx + side * 4f * s, top + 1f * s, bx + 4f * s, top + 6f * s)
                    path.close()
                    c.drawPath(path, fill)
                }
            }
            MascotHat.HALO -> {
                stroke.color = gold
                stroke.strokeWidth = 2f * s
                val y = top - 7f * s + sin(sec * 2f) * 1.2f * s
                rect.set(cx - 12f * s, y - 3f * s, cx + 12f * s, y + 3f * s)
                c.drawOval(rect, stroke)
            }
        }
    }

    // --- Particles ---------------------------------------------------------------------------

    private fun drawParticles(c: Canvas, t: Long) {
        val it = particles.iterator()
        while (it.hasNext()) {
            val p = it.next()
            val age = (t - p.born) / 1000f
            if (age * 1000 > p.life || still) { it.remove(); continue }
            val x = p.x + p.vx * age
            val y = p.y + p.vy * age
            val alpha = (1f - age * 1000 / p.life).coerceIn(0f, 1f)
            when (p.kind) {
                KIND_HEART -> heart(c, x, y, 3.2f * p.size, ColorMath.withAlpha(0xFFFF6B8B.toInt(), alpha))
                KIND_SPARKLE -> star(c, x, y, 2.6f * p.size * (0.6f + 0.4f * sin(age * 12f)), ColorMath.withAlpha(look.accent, alpha))
                KIND_NOTE -> {
                    text.color = ColorMath.withAlpha(look.accent, alpha)
                    text.textSize = 9f * p.size
                    c.drawText("♪", x, y, text)
                }
                KIND_Z -> {
                    text.color = ColorMath.withAlpha(0xFFFFFFFF.toInt(), alpha * 0.85f)
                    text.textSize = 6f + age * 3f
                    c.drawText("z", x, y, text)
                }
            }
        }
    }

    private fun heart(c: Canvas, x: Float, y: Float, r: Float, color: Int) {
        path.reset()
        path.moveTo(x, y + r)
        path.cubicTo(x - r * 2.2f, y - r * 0.4f, x - r * 0.9f, y - r * 2f, x, y - r * 0.6f)
        path.cubicTo(x + r * 0.9f, y - r * 2f, x + r * 2.2f, y - r * 0.4f, x, y + r)
        fill.color = color
        c.drawPath(path, fill)
    }

    private fun star(c: Canvas, x: Float, y: Float, r: Float, color: Int) {
        path.reset()
        path.moveTo(x, y - r * 1.6f)
        path.quadTo(x, y, x + r * 1.6f, y)
        path.quadTo(x, y, x, y + r * 1.6f)
        path.quadTo(x, y, x - r * 1.6f, y)
        path.quadTo(x, y, x, y - r * 1.6f)
        fill.color = color
        c.drawPath(path, fill)
    }

    private fun quad(a: Float, b: Float, c: Float, u: Float) = (1 - u) * (1 - u) * a + 2 * (1 - u) * u * b + u * u * c

    companion object {
        private const val FRAME_MS = 33L
        private const val KIND_HEART = 0
        private const val KIND_SPARKLE = 1
        private const val KIND_NOTE = 2
        private const val KIND_Z = 3
    }
}
