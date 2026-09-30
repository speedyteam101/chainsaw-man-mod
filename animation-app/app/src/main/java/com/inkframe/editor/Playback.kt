package com.inkframe.editor

import android.graphics.Bitmap
import android.view.Choreographer
import com.inkframe.model.PlayMode
import com.inkframe.model.Project
import com.inkframe.render.Compositor
import com.inkframe.render.FrameSpec
import com.inkframe.util.Bg
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** Small composited images of frames for the timeline, rendered in the background. */
class ThumbnailCache(private val doc: Document, private val heightPx: Int, private val onUpdate: () -> Unit) {
    private class Entry(val version: Long, val bitmap: Bitmap)

    private val map = HashMap<String, Entry>()
    private val inFlight = HashMap<String, Long>()

    /** Returns the latest thumbnail (possibly slightly stale) and schedules a refresh when needed. */
    fun get(index: Int): Bitmap? {
        val f = doc.project.frames.getOrNull(index) ?: return null
        val v = doc.frameVersion(f.id)
        val e = map[f.id]
        if ((e == null || e.version != v) && inFlight[f.id] != v) {
            inFlight[f.id] = v
            val spec = doc.frameSpec(index)
            val scale = heightPx / doc.project.height.toFloat()
            val store = doc.store
            Bg.render.execute {
                val bmp = try {
                    Compositor.render(spec, store, min(1f, scale))
                } catch (t: OutOfMemoryError) {
                    null
                }
                Bg.post {
                    if (inFlight[f.id] == v) inFlight.remove(f.id)
                    if (bmp != null && (map[f.id]?.version ?: Long.MIN_VALUE) != v) {
                        map[f.id] = Entry(v, bmp)
                        onUpdate()
                    }
                }
            }
        }
        return e?.bitmap
    }

    fun clear() {
        map.clear()
    }
}

/**
 * Plays the animation. Every frame is composited once at screen resolution and kept
 * until it changes, so playback is smooth however many layers the drawing has.
 */
class Player(private val doc: Document, private val budgetBytes: Long, private val listener: Listener) :
    Choreographer.FrameCallback {

    interface Listener {
        fun onPlaybackFrame(index: Int, bitmap: Bitmap?)
        fun onPreparing(progress: Float)
        fun onPlaybackStopped()
    }

    private class Cached(val version: Long, val bitmap: Bitmap)

    private val cache = HashMap<String, Cached>()
    private var cacheScale = 0f
    private var cacheConfig: Bitmap.Config? = null
    private var sequence = IntArray(0)
    private var frameIds = emptyList<String>()
    private var startNanos = 0L
    private var startTick = 0
    private var lastIndex = -1
    private var generation = 0
    private var fps = 12
    private var mode = PlayMode.LOOP

    var isPlaying = false
        private set
    var isPreparing = false
        private set

    /** Starts from the current frame. [maxW]/[maxH] is the on-screen size of the canvas in pixels. */
    fun play(maxW: Int, maxH: Int) {
        if (isPlaying) return
        val p = doc.project
        fps = p.fps
        mode = p.playMode
        sequence = buildSequence(p)
        frameIds = p.frames.map { it.id }
        // Start at the first tick of the current frame.
        var t = 0
        for (i in 0 until p.currentFrame) t += p.frames[i].hold
        startTick = t

        val config = if (p.backgroundVisible) Bitmap.Config.RGB_565 else Bitmap.Config.ARGB_8888
        val bpp = if (config == Bitmap.Config.RGB_565) 2 else 4
        var scale = min(1f, max(maxW / p.width.toFloat(), maxH / p.height.toFloat()))
        val needed = p.frames.size.toLong() * (p.width * scale).toLong() * (p.height * scale).toLong() * bpp
        if (needed > budgetBytes) scale *= sqrt(budgetBytes.toDouble() / needed).toFloat()
        scale = max(scale, 0.05f)
        if (abs(scale - cacheScale) > 0.001f || config != cacheConfig) {
            cache.clear()
            cacheScale = scale
            cacheConfig = config
        }
        val live = frameIds.toHashSet()
        cache.keys.retainAll(live)

        val specs = p.frames.indices.map { doc.frameSpec(it) }
        val missing = specs.filter { cache[it.frameId]?.version != it.version }
        isPlaying = true
        lastIndex = -1
        val gen = ++generation
        if (missing.isEmpty()) {
            start()
            return
        }
        isPreparing = true
        listener.onPreparing(0f)
        val store = doc.store
        Bg.render.execute {
            for ((n, spec) in missing.withIndex()) {
                if (gen != generation) return@execute
                val bmp = try {
                    Compositor.render(spec, store, scale, config)
                } catch (e: OutOfMemoryError) {
                    null
                }
                Bg.post {
                    if (gen == generation && bmp != null) {
                        cache[spec.frameId] = Cached(spec.version, bmp)
                        listener.onPreparing((n + 1f) / missing.size)
                    }
                }
            }
            Bg.post {
                if (gen == generation) {
                    isPreparing = false
                    start()
                }
            }
        }
    }

    private fun start() {
        startNanos = System.nanoTime()
        Choreographer.getInstance().postFrameCallback(this)
    }

    fun stop() {
        if (!isPlaying) return
        isPlaying = false
        isPreparing = false
        generation++
        Choreographer.getInstance().removeFrameCallback(this)
        listener.onPlaybackStopped()
    }

    fun clear() {
        cache.clear()
    }

    override fun doFrame(frameTimeNanos: Long) {
        if (!isPlaying || sequence.isEmpty()) return
        val elapsed = max(0L, frameTimeNanos - startNanos)
        val tick = startTick + (elapsed * fps / 1_000_000_000L).toInt()
        val index = if (mode == PlayMode.ONE_SHOT && tick >= sequence.size) {
            sequence.last()
        } else {
            sequence[tick % sequence.size]
        }
        if (index != lastIndex) {
            lastIndex = index
            listener.onPlaybackFrame(index, frameIds.getOrNull(index)?.let { cache[it]?.bitmap })
        }
        if (mode == PlayMode.ONE_SHOT && tick >= sequence.size) {
            stop()
            return
        }
        Choreographer.getInstance().postFrameCallback(this)
    }

    private fun abs(v: Float) = kotlin.math.abs(v)

    companion object {
        /** Frame index for every tick of one cycle, honouring holds and the play mode. */
        fun buildSequence(p: Project): IntArray {
            val holds = p.frames.map { it.hold }.toIntArray()
            return sequence(holds, p.playMode)
        }

        fun sequence(holds: IntArray, mode: PlayMode): IntArray {
            val order = ArrayList<Int>()
            for (i in holds.indices) order += i
            if (mode == PlayMode.PING_PONG && holds.size > 2) {
                for (i in holds.size - 2 downTo 1) order += i
            }
            val out = ArrayList<Int>()
            for (i in order) repeat(holds[i]) { out += i }
            return out.toIntArray()
        }

        /** Spec list for export or thumbnails, captured on the main thread. */
        fun specs(doc: Document, withBackground: Boolean): List<FrameSpec> =
            doc.project.frames.indices.map { doc.frameSpec(it, withBackground) }
    }
}
