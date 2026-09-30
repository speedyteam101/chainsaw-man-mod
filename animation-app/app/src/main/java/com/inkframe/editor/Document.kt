package com.inkframe.editor

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import com.inkframe.history.Command
import com.inkframe.history.History
import com.inkframe.history.HistoryHost
import com.inkframe.history.PixelCommand
import com.inkframe.history.StructureCommand
import com.inkframe.model.CellStore
import com.inkframe.model.Frame
import com.inkframe.model.Layer
import com.inkframe.model.LayerBlend
import com.inkframe.model.Project
import com.inkframe.model.ProjectJson
import com.inkframe.model.ProjectRepository
import com.inkframe.model.Structure
import com.inkframe.render.Compositor
import com.inkframe.render.FrameSpec
import com.inkframe.render.toBlendMode
import com.inkframe.util.Bg
import com.inkframe.util.Ids

/**
 * An open project: the model, its pixels and its undo history, plus every editing
 * operation. Must only be used from the main thread.
 */
class Document(
    val project: Project,
    val repo: ProjectRepository,
    val store: CellStore,
    historyBytes: Long,
) : HistoryHost {

    enum class Change {
        /** Frames or layers were added, removed, reordered or changed. */
        STRUCTURE,
        /** Pixels of a cell changed. */
        PIXELS,
        /** The current frame or active layer changed. */
        SELECTION,
        /** Undo/redo availability changed. */
        HISTORY,
        /** Playback, onion skin or background settings changed. */
        SETTINGS,
    }

    fun interface Listener {
        fun onDocumentChanged(change: Change)
    }

    private val listeners = ArrayList<Listener>()
    val history = History(this, historyBytes)

    private val frameVersions = HashMap<String, Long>()
    private var renderVersion = 0L

    /** True when there are changes not yet written to disk. */
    var unsaved = false
        private set

    init {
        repin()
    }

    fun addListener(l: Listener) {
        listeners += l
    }

    fun removeListener(l: Listener) {
        listeners -= l
    }

    private fun notify(vararg changes: Change) {
        for (c in changes) for (l in listeners.toList()) l.onDocumentChanged(c)
    }

    // --- accessors ---

    val currentFrame: Frame get() = project.frames[project.currentFrame]
    val activeLayer: Layer get() = project.layers[project.activeLayer]
    val activeCellKey: String get() = Project.cellKey(currentFrame.id, activeLayer.id)

    fun cellKey(frameIndex: Int, layerIndex: Int) =
        Project.cellKey(project.frames[frameIndex].id, project.layers[layerIndex].id)

    /** Changes whenever anything that affects how the frame looks changes. */
    fun frameVersion(frameId: String): Long = ((frameVersions[frameId] ?: 0L) shl 24) + renderVersion

    fun frameSpec(index: Int, withBackground: Boolean = true) =
        FrameSpec.of(project, index, frameVersion(project.frames[index].id), withBackground)

    // --- selection ---

    fun selectFrame(index: Int) {
        val i = index.coerceIn(0, project.frames.size - 1)
        if (i == project.currentFrame) return
        project.currentFrame = i
        repin()
        notify(Change.SELECTION)
    }

    fun selectLayer(index: Int) {
        val i = index.coerceIn(0, project.layers.size - 1)
        if (i == project.activeLayer) return
        project.activeLayer = i
        notify(Change.SELECTION)
    }

    /** Keeps the cells of the current frame in memory and preloads its neighbours. */
    private fun repin() {
        val f = project.currentFrame
        store.pin(project.layers.map { Project.cellKey(project.frames[f].id, it.id) })
        val keys = ArrayList<String>()
        val range = maxOf(project.onion.before, project.onion.after, 1)
        for (d in 1..range) {
            for (fi in intArrayOf(f - d, f + d)) {
                if (fi !in project.frames.indices) continue
                project.layers.forEach { keys += Project.cellKey(project.frames[fi].id, it.id) }
            }
        }
        Bg.render.execute { store.prefetch(keys) }
    }

    // --- structure edits (undoable) ---

    private inline fun structural(name: String, block: () -> Unit) {
        val before = project.snapshot()
        block()
        history.push(StructureCommand(name, before, project.snapshot()))
        renderVersion++
        unsaved = true
        repin()
        notify(Change.STRUCTURE, Change.SELECTION, Change.HISTORY)
    }

    fun addFrame() = insertFrame(project.currentFrame + 1)

    fun insertFrame(index: Int) = structural("Add Frame") {
        val i = index.coerceIn(0, project.frames.size)
        project.frames.add(i, Frame(Ids.next()))
        project.currentFrame = i
    }

    fun duplicateFrame(index: Int) = structural("Duplicate Frame") {
        val src = project.frames[index]
        val copy = Frame(Ids.next(), src.hold)
        for (l in project.layers) store.copy(Project.cellKey(src.id, l.id), Project.cellKey(copy.id, l.id))
        project.frames.add(index + 1, copy)
        project.currentFrame = index + 1
    }

    fun deleteFrame(index: Int): Boolean {
        if (project.frames.size <= 1) return false
        structural("Delete Frame") {
            project.frames.removeAt(index)
            project.currentFrame = project.currentFrame.coerceAtMost(project.frames.size - 1)
            if (index < project.currentFrame) project.currentFrame--
        }
        return true
    }

    fun moveFrame(from: Int, to: Int) {
        val t = to.coerceIn(0, project.frames.size - 1)
        if (from == t) return
        structural("Move Frame") {
            val f = project.frames.removeAt(from)
            project.frames.add(t, f)
            project.currentFrame = t
        }
    }

    fun setHold(index: Int, hold: Int) {
        val h = hold.coerceIn(1, 99)
        if (project.frames[index].hold == h) return
        structural("Frame Hold") { project.frames[index].hold = h }
    }

    fun addLayer(name: String? = null): Int {
        structural("Add Layer") {
            val i = project.activeLayer + 1
            project.layers.add(i, Layer(Ids.next(), name ?: nextLayerName()))
            project.activeLayer = i
        }
        return project.activeLayer
    }

    private fun nextLayerName(): String {
        var n = project.layers.size + 1
        while (project.layers.any { it.name == "Layer $n" }) n++
        return "Layer $n"
    }

    fun duplicateLayer(index: Int) = structural("Duplicate Layer") {
        val src = project.layers[index]
        val copy = src.copy().let { c ->
            Layer(Ids.next(), "${src.name} copy").also {
                it.visible = c.visible; it.opacity = c.opacity; it.blend = c.blend; it.alphaLock = c.alphaLock
            }
        }
        for (f in project.frames) store.copy(Project.cellKey(f.id, src.id), Project.cellKey(f.id, copy.id))
        project.layers.add(index + 1, copy)
        project.activeLayer = index + 1
    }

    fun deleteLayer(index: Int): Boolean {
        if (project.layers.size <= 1) return false
        structural("Delete Layer") {
            project.layers.removeAt(index)
            project.activeLayer = project.activeLayer.coerceAtMost(project.layers.size - 1)
            if (index < project.activeLayer) project.activeLayer--
        }
        return true
    }

    fun moveLayer(from: Int, to: Int) {
        val t = to.coerceIn(0, project.layers.size - 1)
        if (from == t) return
        structural("Move Layer") {
            val l = project.layers.removeAt(from)
            project.layers.add(t, l)
            project.activeLayer = t
        }
    }

    /**
     * Merges layer [index] into the layer below it. The result is a new layer, so
     * undo only has to restore the structure (the old cells stay in the store).
     */
    fun mergeDown(index: Int): Boolean {
        if (index <= 0) return false
        structural("Merge Down") {
            val upper = project.layers[index]
            val lower = project.layers[index - 1]
            val merged = Layer(Ids.next(), lower.name).also { it.blend = lower.blend }
            val paint = Paint(Paint.FILTER_BITMAP_FLAG)
            for (f in project.frames) {
                val lo = if (lower.visible) store.get(Project.cellKey(f.id, lower.id)) else null
                val up = if (upper.visible) store.get(Project.cellKey(f.id, upper.id)) else null
                if (lo == null && up == null) continue
                val out = Bitmap.createBitmap(project.width, project.height, Bitmap.Config.ARGB_8888)
                val c = Canvas(out)
                if (lo != null) {
                    paint.alpha = (lower.opacity * 255).toInt()
                    paint.blendMode = null
                    c.drawBitmap(lo, 0f, 0f, paint)
                }
                if (up != null) {
                    paint.alpha = (upper.opacity * 255).toInt()
                    paint.blendMode = upper.blend.toBlendMode()
                    c.drawBitmap(up, 0f, 0f, paint)
                }
                store.put(Project.cellKey(f.id, merged.id), out)
            }
            project.layers.removeAt(index)
            project.layers[index - 1] = merged
            project.activeLayer = index - 1
        }
        return true
    }

    // --- layer properties (not undoable, like most painting apps) ---

    fun setLayerVisible(index: Int, visible: Boolean) = layerChanged { project.layers[index].visible = visible }
    fun setLayerOpacity(index: Int, opacity: Float) = layerChanged { project.layers[index].opacity = opacity.coerceIn(0f, 1f) }
    fun setLayerBlend(index: Int, blend: LayerBlend) = layerChanged { project.layers[index].blend = blend }
    fun setAlphaLock(index: Int, locked: Boolean) = layerChanged { project.layers[index].alphaLock = locked }
    fun renameLayer(index: Int, name: String) = layerChanged { project.layers[index].name = name.ifBlank { "Layer" } }

    private inline fun layerChanged(block: () -> Unit) {
        block()
        renderVersion++
        unsaved = true
        notify(Change.STRUCTURE)
    }

    fun setBackground(color: Int, visible: Boolean) {
        project.backgroundColor = color or 0xFF000000.toInt()
        project.backgroundVisible = visible
        renderVersion++
        unsaved = true
        notify(Change.SETTINGS)
    }

    /** fps, play mode and onion settings: the caller changes [project] and then calls this. */
    fun settingsChanged() {
        unsaved = true
        repin()
        notify(Change.SETTINGS)
    }

    // --- pixel edits ---

    /**
     * Records a change the caller made to [key] inside [rect]; [before] holds the old pixels of
     * that rect (see [PixelCommand.copyRegion]).
     */
    fun recordPixelEdit(name: String, key: String, rect: Rect, before: Bitmap) {
        history.push(PixelCommand(name, key, Rect(rect), before))
        pixelsChanged(key)
        notify(Change.HISTORY)
    }

    /** Runs [edit] on the active cell's whole bitmap as one undo step. */
    fun editActiveCell(name: String, edit: (Bitmap) -> Unit) {
        val key = activeCellKey
        val cell = store.getOrCreate(key)
        val rect = Rect(0, 0, cell.width, cell.height)
        val before = PixelCommand.copyRegion(cell, rect)
        edit(cell)
        recordPixelEdit(name, key, rect, before)
    }

    fun clearActiveCell() {
        if (!store.hasContent(activeCellKey)) return
        editActiveCell("Clear") { it.eraseColor(Color.TRANSPARENT) }
    }

    fun flipActiveCell(horizontal: Boolean) {
        if (!store.hasContent(activeCellKey)) return
        editActiveCell(if (horizontal) "Flip Horizontal" else "Flip Vertical") { cell ->
            val copy = cell.copy(Bitmap.Config.ARGB_8888, false)
            cell.eraseColor(Color.TRANSPARENT)
            val m = Matrix()
            if (horizontal) m.setScale(-1f, 1f, cell.width / 2f, 0f) else m.setScale(1f, -1f, 0f, cell.height / 2f)
            Canvas(cell).drawBitmap(copy, m, null)
        }
    }

    private fun pixelsChanged(key: String) {
        store.markDirty(key)
        val frameId = Project.frameIdOf(key)
        frameVersions[frameId] = (frameVersions[frameId] ?: 0L) + 1
        unsaved = true
        notify(Change.PIXELS)
    }

    // --- undo / redo ---

    fun undo(): Command? = afterHistory(history.undo())
    fun redo(): Command? = afterHistory(history.redo())

    private fun afterHistory(c: Command?): Command? {
        if (c == null) return null
        // Show the frame the change happened on.
        c.cellKey?.let { key ->
            val fi = project.frameIndex(Project.frameIdOf(key))
            if (fi >= 0 && fi != project.currentFrame) {
                project.currentFrame = fi
                repin()
            }
        }
        unsaved = true
        notify(Change.STRUCTURE, Change.PIXELS, Change.SELECTION, Change.HISTORY)
        return c
    }

    override fun cellForUndo(key: String): Bitmap = store.getOrCreate(key)

    override fun onPixelsRestored(key: String) = pixelsChanged(key)

    override fun restoreStructure(s: Structure) {
        project.restore(s)
        renderVersion++
        repin()
    }

    // --- persistence ---

    /** Saves in the background; [done] runs on the main thread. */
    fun save(done: (() -> Unit)? = null) {
        project.modifiedAt = System.currentTimeMillis()
        val json = ProjectJson.toJson(project).toString()
        val thumbSpec = frameSpec(0)
        val id = project.id
        unsaved = false
        Bg.io.execute {
            try {
                store.flush()
                repo.writeJsonText(id, json)
                val scale = minOf(1f, 480f / maxOf(project.width, project.height))
                repo.writeThumbnail(id, Compositor.render(thumbSpec, store, scale))
            } catch (e: Exception) {
                Bg.post { unsaved = true }
            }
            done?.let { Bg.post(it) }
        }
    }

    /** Saves, deletes pixels no longer used by the project, and releases memory. */
    fun close(done: (() -> Unit)? = null) {
        val live = HashSet<String>()
        for (f in project.frames) for (l in project.layers) live += Project.cellKey(f.id, l.id)
        history.clear()
        save {
            Bg.io.execute {
                try {
                    store.collectGarbage(live)
                } finally {
                    store.close()
                }
                done?.let { Bg.post(it) }
            }
        }
    }
}
