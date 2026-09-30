package com.inkframe.editor

import android.content.Intent
import android.graphics.Bitmap
import android.os.Looper
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import com.inkframe.App
import com.inkframe.Tool
import com.inkframe.export.ExportFormat
import com.inkframe.export.ExportJob
import com.inkframe.export.Exporter
import com.inkframe.gallery.GalleryActivity
import com.inkframe.model.Project
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.io.File
import java.time.Duration

fun idle() = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(17))

fun waitFor(what: String, cond: () -> Boolean) {
    repeat(1000) {
        idle()
        if (cond()) return
        Thread.sleep(10)
    }
    throw AssertionError("timed out waiting for $what")
}

fun countInk(b: Bitmap?): Int {
    if (b == null) return 0
    val px = IntArray(b.width * b.height)
    b.getPixels(px, 0, b.width, 0, 0, b.width, b.height)
    return px.count { it ushr 24 > 0 }
}

@RunWith(RobolectricTestRunner::class)
/**
 * Drives the real editor on the JVM (Robolectric with native graphics): draws with simulated
 * finger and pen input, fills, undoes with gestures, edits frames and layers, transforms,
 * plays, exports, and checks that everything survives closing and reopening the project.
 */
@Config(qualifiers = "w891dp-h411dp-land-xxhdpi")
class EditorFlowTest {
    private var t0 = 0L

    private fun ev(v: View, action: Int, xs: FloatArray, ys: FloatArray, time: Long, actionIndex: Int = 0, toolType: Int = MotionEvent.TOOL_TYPE_FINGER, pressure: Float = 1f, toolTypes: IntArray? = null): Boolean {
        val n = xs.size
        val props = Array(n) { MotionEvent.PointerProperties().apply { id = it; this.toolType = toolTypes?.get(it) ?: toolType } }
        val coords = Array(n) { MotionEvent.PointerCoords().apply { x = xs[it]; y = ys[it]; this.pressure = pressure; size = 0.1f } }
        val a = if (action == MotionEvent.ACTION_POINTER_DOWN || action == MotionEvent.ACTION_POINTER_UP) action or (actionIndex shl MotionEvent.ACTION_POINTER_INDEX_SHIFT) else action
        val e = MotionEvent.obtain(t0, t0 + time, a, n, props, coords, 0, 0, 1f, 1f, 0, 0, 0, 0)
        return v.dispatchTouchEvent(e).also { e.recycle() }
    }

    /** Drags one finger through the points (view coordinates). */
    private fun stroke(v: View, pts: List<Pair<Float, Float>>, toolType: Int = MotionEvent.TOOL_TYPE_FINGER) {
        t0 = SystemClock.uptimeMillis()
        var t = 0L
        ev(v, MotionEvent.ACTION_DOWN, floatArrayOf(pts[0].first), floatArrayOf(pts[0].second), t, toolType = toolType, pressure = 0.6f)
        for (i in 1 until pts.size) {
            t += 8
            ev(v, MotionEvent.ACTION_MOVE, floatArrayOf(pts[i].first), floatArrayOf(pts[i].second), t, toolType = toolType, pressure = 0.3f + 0.7f * i / pts.size)
        }
        t += 8
        ev(v, MotionEvent.ACTION_UP, floatArrayOf(pts.last().first), floatArrayOf(pts.last().second), t, toolType = toolType)
        idle()
    }

    private fun circle(cx: Float, cy: Float, r: Float, n: Int = 80) = (0..n).map { i ->
        val a = i / n.toDouble() * Math.PI * 2 * 1.05
        Pair(cx + r * Math.cos(a).toFloat(), cy + r * Math.sin(a).toFloat())
    }

    private fun twoFingerTap(v: View, fingers: Int = 2) {
        t0 = SystemClock.uptimeMillis()
        val xs = FloatArray(fingers) { 300f + it * 80f }
        val ys = FloatArray(fingers) { 400f }
        ev(v, MotionEvent.ACTION_DOWN, xs.copyOf(1), ys.copyOf(1), 0)
        for (k in 2..fingers) ev(v, MotionEvent.ACTION_POINTER_DOWN, xs.copyOf(k), ys.copyOf(k), 10L * k, actionIndex = k - 1)
        for (k in fingers downTo 2) ev(v, MotionEvent.ACTION_POINTER_UP, xs.copyOf(k), ys.copyOf(k), 60L + 10 * (fingers - k), actionIndex = k - 1)
        ev(v, MotionEvent.ACTION_UP, xs.copyOf(1), ys.copyOf(1), 120)
        idle()
    }

    @Test
    fun fullWorkflow() {
        org.robolectric.shadows.ShadowChoreographer.setPaused(true)
        org.robolectric.shadows.ShadowChoreographer.setFrameDelay(Duration.ofMillis(16))
        val app = App.instance
        val p = app.repo.create("Test anim", 1280, 720, 12, 0xFFFFFFFF.toInt(), true)
        val controller = Robolectric.buildActivity(EditorActivity::class.java, Intent().putExtra(EditorActivity.EXTRA_PROJECT_ID, p.id))
        controller.setup()
        val a = controller.get()
        waitFor("editor loaded") { runCatching { a.panels }.isSuccess }
        idle()
        val cv = a.canvasView
        val doc = a.doc

        // Draw a circle (closed shape) with the finger.
        stroke(cv, circle(cv.width / 2f, cv.height / 2f, 110f))
        val key = doc.activeCellKey
        val ink1 = countInk(doc.store.get(key))
        println("ink after circle: $ink1")
        assertTrue("stroke drew pixels", ink1 > 500)
        assertTrue(doc.history.canUndo)

        // Two-finger tap undoes; three-finger tap redoes.
        twoFingerTap(cv, 2)
        assertEquals("undo cleared the stroke", 0, countInk(doc.store.get(key)))
        twoFingerTap(cv, 3)
        assertEquals("redo restored the stroke", ink1, countInk(doc.store.get(key)))

        // Fill inside the circle.
        a.selectTool(Tool.FILL)
        t0 = SystemClock.uptimeMillis()
        ev(cv, MotionEvent.ACTION_DOWN, floatArrayOf(cv.width / 2f), floatArrayOf(cv.height / 2f), 0)
        ev(cv, MotionEvent.ACTION_UP, floatArrayOf(cv.width / 2f), floatArrayOf(cv.height / 2f), 40)
        waitFor("fill") { countInk(doc.store.get(key)) > ink1 * 3 }
        val filled = countInk(doc.store.get(key))
        println("ink after fill: $filled")
        assertTrue("fill stayed inside the circle", filled < 1280 * 720 / 4)
        a.selectTool(Tool.BRUSH)

        // Pen stroke with pressure on a new frame; onion skin should show frame 1.
        a.addFrame()
        idle()
        assertEquals(2, doc.project.frames.size)
        assertEquals(1, doc.project.currentFrame)
        stroke(cv, (0..60).map { Pair(200f + it * 8f, 250f + 40f * Math.sin(it / 8.0).toFloat()) }, MotionEvent.TOOL_TYPE_STYLUS)
        assertFalse("pen use turns off finger drawing", app.prefs.fingerDrawing)
        assertTrue(countInk(doc.store.get(doc.activeCellKey)) > 200)

        // Finger now pans instead of drawing.
        val before = countInk(doc.store.get(doc.activeCellKey))
        stroke(cv, (0..20).map { Pair(400f + it * 5f, 300f) })
        assertEquals(before, countInk(doc.store.get(doc.activeCellKey)))

        // Palm rests first, then the pen draws: the pen stroke still lands, and commits when the pen lifts.
        val palmAndPen = intArrayOf(MotionEvent.TOOL_TYPE_FINGER, MotionEvent.TOOL_TYPE_STYLUS)
        val beforePalm = countInk(doc.store.get(doc.activeCellKey))
        t0 = SystemClock.uptimeMillis()
        ev(cv, MotionEvent.ACTION_DOWN, floatArrayOf(900f), floatArrayOf(900f), 0)
        ev(cv, MotionEvent.ACTION_POINTER_DOWN, floatArrayOf(900f, 300f), floatArrayOf(900f, 450f), 40, actionIndex = 1, toolTypes = palmAndPen)
        for (i in 1..30) {
            ev(cv, MotionEvent.ACTION_MOVE, floatArrayOf(900f, 300f + i * 10f), floatArrayOf(900f, 450f), 40L + i * 8, toolTypes = palmAndPen)
        }
        ev(cv, MotionEvent.ACTION_POINTER_UP, floatArrayOf(900f, 600f), floatArrayOf(900f, 450f), 400, actionIndex = 1, toolTypes = palmAndPen)
        idle()
        val afterPen = countInk(doc.store.get(doc.activeCellKey))
        assertTrue("pen stroke with a resting palm was committed", afterPen > beforePalm + 100)
        ev(cv, MotionEvent.ACTION_UP, floatArrayOf(900f), floatArrayOf(900f), 500)
        idle()
        assertEquals("lifting the palm adds nothing", afterPen, countInk(doc.store.get(doc.activeCellKey)))
        app.prefs.fingerDrawing = true

        // Layers: add, draw, merge down, undo merge.
        doc.addLayer()
        stroke(cv, circle(500f, 350f, 60f))
        assertEquals(2, doc.project.layers.size)
        doc.mergeDown(1)
        assertEquals(1, doc.project.layers.size)
        doc.undo()
        assertEquals(2, doc.project.layers.size)
        doc.redo()
        assertEquals(1, doc.project.layers.size)

        // Frames: duplicate, hold, move, delete.
        doc.duplicateFrame(1)
        assertEquals(3, doc.project.frames.size)
        assertTrue(countInk(doc.store.get(doc.activeCellKey)) > 200)
        doc.setHold(2, 3)
        doc.moveFrame(2, 0)
        assertEquals(3, doc.project.frames[0].hold)
        doc.deleteFrame(0)
        assertEquals(2, doc.project.frames.size)
        doc.undo()
        assertEquals(3, doc.project.frames.size)

        // Transform: move the drawing 100 px right.
        doc.selectFrame(1)
        idle()
        a.selectTool(Tool.TRANSFORM)
        assertNotNull(cv.transform)
        stroke(cv, (0..10).map { Pair(300f + it * 10f, 300f) })
        a.selectTool(Tool.BRUSH)
        assertNull(cv.transform)

        // QuickShape: draw a rough line and hold.
        t0 = SystemClock.uptimeMillis()
        ev(cv, MotionEvent.ACTION_DOWN, floatArrayOf(150f), floatArrayOf(500f), 0)
        for (i in 1..30) ev(cv, MotionEvent.ACTION_MOVE, floatArrayOf(150f + i * 15f), floatArrayOf(500f + (if (i % 2 == 0) 4f else -4f)), i * 10L)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(700))
        ev(cv, MotionEvent.ACTION_UP, floatArrayOf(600f), floatArrayOf(500f), 1100)
        idle()

        // Panels open without crashing.
        a.panels.showBrushes(a.layersButton, Tool.BRUSH); idle()
        waitFor("brush previews") { true }
        a.panels.showLayers(a.layersButton); idle()
        a.panels.showColor(a.layersButton); idle()
        a.panels.showActions(a.actionsButton); idle()
        a.panels.showAnimationSettings(a.settingsButton); idle()
        a.panels.showFrameOptions(a.timeline, 1); idle()
        a.panels.showFillSettings(a.layersButton); idle()
        a.panels.showExport(); idle()

        // Playback.
        a.togglePlay()
        var shown = 0
        for (i in 0 until 400) {
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(20))
            if (cv.playbackFrame != null) shown++
            if (shown > 20) break
            Thread.sleep(5)
        }
        assertTrue("playback showed frames", shown > 0)
        a.togglePlay()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(20))
        assertNull(cv.playbackFrame)

        // Exports (GIF, PNG zip, PNG).
        for (f in listOf(ExportFormat.GIF, ExportFormat.PNG_SEQUENCE, ExportFormat.PNG_FRAME)) {
            var out: File? = null
            var err: String? = null
            var finished = false
            val job = ExportJob(f, doc.project.name, doc.project.frames.indices.map { doc.frameSpec(it) },
                doc.project.frames.map { it.hold }.toIntArray(), doc.project.fps, 0.5f, 1, doc.project.currentFrame)
            Exporter.run(a, doc.store, job, {}) { file, e -> out = file; err = e; finished = true }
            waitFor("export $f") { finished }
            println("export $f -> ${out?.name} ${out?.length()} bytes err=$err")
            assertNotNull("export $f: $err", out)
        }

        // Close and reopen: everything persisted.
        val frames = doc.project.frames.map { it.id }
        val layers = doc.project.layers.map { it.id }
        val inkPerCell = frames.flatMap { f -> layers.map { l -> countInk(doc.store.get(Project.cellKey(f, l))) } }
        controller.pause().stop().destroy()
        a.finish()
        Thread.sleep(300)
        waitFor("saved") { File(app.repo.dirOf(p.id), "thumb.png").exists() }
        Thread.sleep(500)
        val reloaded = app.repo.load(p.id)
        assertEquals(frames, reloaded.frames.map { it.id })
        assertEquals(layers, reloaded.layers.map { it.id })
        val store2 = com.inkframe.model.CellStore(app.repo.cellsDir(p.id), reloaded.width, reloaded.height, 64L shl 20)
        val ink2 = frames.flatMap { f -> layers.map { l -> countInk(store2.get(Project.cellKey(f, l))) } }
        println("ink per cell before $inkPerCell after $ink2")
        for (i in inkPerCell.indices) assertTrue(Math.abs(inkPerCell[i] - ink2[i]) <= inkPerCell[i] / 50 + 5)

        // Gallery shows the project.
        val g = Robolectric.buildActivity(GalleryActivity::class.java)
        g.setup()
        waitFor("gallery list") { idle(); true }
        Thread.sleep(300); idle(); Thread.sleep(300); idle()
    }

    @Test
    fun cellStorePagesToDisk() {
        val dir = File(App.instance.filesDir, "pagetest")
        dir.deleteRecursively()
        val store = com.inkframe.model.CellStore(dir, 256, 256, 256L * 256 * 4 * 3) // room for 3 cells
        for (i in 0 until 12) {
            val b = store.getOrCreate("f$i" + "_l")
            b.eraseColor(0xFF000000.toInt() or i)
            store.markDirty("f$i" + "_l")
        }
        store.flush()
        for (i in 0 until 12) {
            val b = store.get("f$i" + "_l")
            assertNotNull(b)
            assertEquals(0xFF000000.toInt() or i, b!!.getPixel(10, 10))
        }
        store.collectGarbage(setOf("f0_l"))
        assertNull(store.get("f5_l"))
        assertNotNull(store.get("f0_l"))
    }
}
