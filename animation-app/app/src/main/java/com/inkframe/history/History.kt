package com.inkframe.history

import android.graphics.Bitmap
import android.graphics.BlendMode
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import com.inkframe.model.Structure

/** What commands need from the document to undo or redo themselves. */
interface HistoryHost {
    fun cellForUndo(key: String): Bitmap
    fun onPixelsRestored(key: String)
    fun restoreStructure(s: Structure)
}

abstract class Command(val name: String) {
    abstract fun undo(host: HistoryHost)
    abstract fun redo(host: HistoryHost)
    open val bytes: Long get() = 0L
    /** The cell this command changed, so undo can show where it happened. */
    open val cellKey: String? get() = null
}

/** Pixel change inside [rect] of one cell. Only the old pixels are kept until undo. */
class PixelCommand(name: String, private val key: String, private val rect: Rect, private var before: Bitmap) : Command(name) {
    private var after: Bitmap? = null

    override val cellKey: String get() = key

    override fun undo(host: HistoryHost) {
        val cell = host.cellForUndo(key)
        after = copyRegion(cell, rect)
        paste(cell, before, rect)
        host.onPixelsRestored(key)
    }

    override fun redo(host: HistoryHost) {
        val cell = host.cellForUndo(key)
        val a = after ?: return
        before = copyRegion(cell, rect)
        paste(cell, a, rect)
        host.onPixelsRestored(key)
    }

    override val bytes: Long
        get() = before.allocationByteCount.toLong() + (after?.allocationByteCount ?: 0)

    companion object {
        private val srcPaint = Paint().apply { blendMode = BlendMode.SRC }

        fun copyRegion(src: Bitmap, r: Rect): Bitmap {
            val out = Bitmap.createBitmap(r.width(), r.height(), Bitmap.Config.ARGB_8888)
            Canvas(out).drawBitmap(src, r, Rect(0, 0, r.width(), r.height()), null)
            return out
        }

        fun paste(dst: Bitmap, region: Bitmap, r: Rect) {
            Canvas(dst).drawBitmap(region, r.left.toFloat(), r.top.toFloat(), srcPaint)
        }
    }
}

/** Adding, removing, reordering or changing frames and layers. */
class StructureCommand(name: String, private val before: Structure, private val after: Structure) : Command(name) {
    override fun undo(host: HistoryHost) = host.restoreStructure(before)
    override fun redo(host: HistoryHost) = host.restoreStructure(after)
}

class CompoundCommand(name: String, private val parts: List<Command>) : Command(name) {
    override fun undo(host: HistoryHost) {
        for (i in parts.indices.reversed()) parts[i].undo(host)
    }

    override fun redo(host: HistoryHost) {
        for (c in parts) c.redo(host)
    }

    override val bytes: Long get() = parts.sumOf { it.bytes }
    override val cellKey: String? get() = parts.lastOrNull { it.cellKey != null }?.cellKey
}

/** Undo/redo stacks limited by step count and by the memory held in pixel snapshots. */
class History(private val host: HistoryHost, private val maxBytes: Long, private val maxSteps: Int = 150) {
    private val undoStack = ArrayDeque<Command>()
    private val redoStack = ArrayDeque<Command>()
    private var group: MutableList<Command>? = null
    private var groupName = ""

    val canUndo get() = undoStack.isNotEmpty()
    val canRedo get() = redoStack.isNotEmpty()
    val undoName get() = undoStack.lastOrNull()?.name
    val redoName get() = redoStack.lastOrNull()?.name

    /** Commands pushed until [endGroup] become a single undo step. */
    fun beginGroup(name: String) {
        group = ArrayList()
        groupName = name
    }

    fun endGroup() {
        val g = group ?: return
        group = null
        when (g.size) {
            0 -> Unit
            1 -> push(g[0])
            else -> push(CompoundCommand(groupName, g))
        }
    }

    fun push(c: Command) {
        group?.let {
            it += c
            return
        }
        undoStack.addLast(c)
        redoStack.clear()
        trim()
    }

    fun undo(): Command? {
        val c = undoStack.removeLastOrNull() ?: return null
        c.undo(host)
        redoStack.addLast(c)
        return c
    }

    fun redo(): Command? {
        val c = redoStack.removeLastOrNull() ?: return null
        c.redo(host)
        undoStack.addLast(c)
        trim()
        return c
    }

    fun clear() {
        undoStack.clear()
        redoStack.clear()
    }

    private fun trim() {
        while (undoStack.size > maxSteps) undoStack.removeFirst()
        var total = undoStack.sumOf { it.bytes } + redoStack.sumOf { it.bytes }
        while (total > maxBytes && undoStack.size > 1) {
            total -= undoStack.removeFirst().bytes
        }
    }
}
