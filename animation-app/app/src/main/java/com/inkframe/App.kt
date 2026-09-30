package com.inkframe

import android.app.ActivityManager
import android.app.Application
import android.content.ComponentCallbacks2
import android.content.Context
import android.content.SharedPreferences
import com.inkframe.brush.BrushSpec
import com.inkframe.brush.Brushes
import com.inkframe.model.ProjectRepository
import java.io.File

class App : Application() {
    lateinit var repo: ProjectRepository
        private set
    lateinit var prefs: Prefs
        private set

    /** Memory for cell bitmaps, playback frames and undo, scaled to the device's RAM. */
    var cellBudget = 0L
        private set
    var playbackBudget = 0L
        private set
    var historyBudget = 0L
        private set

    /** Called when the system is low on memory; the open editor frees caches. */
    var onLowMemory: (() -> Unit)? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        repo = ProjectRepository(File(filesDir, "projects"))
        prefs = Prefs(getSharedPreferences("inkframe", Context.MODE_PRIVATE))
        val info = ActivityManager.MemoryInfo()
        getSystemService(ActivityManager::class.java)?.getMemoryInfo(info)
        val total = info.totalMem.coerceAtLeast(1L shl 30)
        val mb = 1L shl 20
        cellBudget = (total / 8).coerceIn(160 * mb, 1024 * mb)
        playbackBudget = (total / 14).coerceIn(64 * mb, 512 * mb)
        historyBudget = (total / 24).coerceIn(48 * mb, 256 * mb)
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        @Suppress("DEPRECATION")
        if (level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW) onLowMemory?.invoke()
    }

    companion object {
        lateinit var instance: App
            private set
    }
}

enum class Tool { BRUSH, ERASER, FILL, TRANSFORM }

/** User preferences and the last used tool settings. */
class Prefs(private val sp: SharedPreferences) {
    var color: Int
        get() = sp.getInt("color", 0xFF1B1B1F.toInt())
        set(v) = sp.edit().putInt("color", v).apply()

    var fingerDrawing: Boolean
        get() = sp.getBoolean("fingerDrawing", true)
        set(v) = sp.edit().putBoolean("fingerDrawing", v).apply()

    var stylusSeen: Boolean
        get() = sp.getBoolean("stylusSeen", false)
        set(v) = sp.edit().putBoolean("stylusSeen", v).apply()

    var sidebarRight: Boolean
        get() = sp.getBoolean("sidebarRight", false)
        set(v) = sp.edit().putBoolean("sidebarRight", v).apply()

    var quickShape: Boolean
        get() = sp.getBoolean("quickShape", true)
        set(v) = sp.edit().putBoolean("quickShape", v).apply()

    var holdToPick: Boolean
        get() = sp.getBoolean("holdToPick", true)
        set(v) = sp.edit().putBoolean("holdToPick", v).apply()

    var fillTolerance: Float
        get() = sp.getFloat("fillTolerance", 0.12f)
        set(v) = sp.edit().putFloat("fillTolerance", v).apply()

    var fillSampleAll: Boolean
        get() = sp.getBoolean("fillSampleAll", true)
        set(v) = sp.edit().putBoolean("fillSampleAll", v).apply()

    var fillExpand: Int
        get() = sp.getInt("fillExpand", 1)
        set(v) = sp.edit().putInt("fillExpand", v).apply()

    var recentColors: List<Int>
        get() = sp.getString("recentColors", "")!!.split(',').mapNotNull { it.toIntOrNull() }
        set(v) = sp.edit().putString("recentColors", v.joinToString(",")).apply()

    fun pushRecentColor(c: Int) {
        recentColors = (listOf(c) + recentColors.filter { it != c }).take(16)
    }

    fun brushId(tool: Tool): String? = sp.getString("brush_${tool.name}", null)
    fun setBrushId(tool: Tool, id: String) = sp.edit().putString("brush_${tool.name}", id).apply()

    fun size(tool: Tool, brush: BrushSpec): Float = sp.getFloat("size_${tool.name}_${brush.id}", if (tool == Tool.ERASER) brush.defaultSize * 2.5f else brush.defaultSize)
    fun setSize(tool: Tool, brush: BrushSpec, v: Float) = sp.edit().putFloat("size_${tool.name}_${brush.id}", v).apply()

    fun opacity(tool: Tool, brush: BrushSpec): Float = sp.getFloat("opacity_${tool.name}_${brush.id}", if (tool == Tool.ERASER) 1f else brush.defaultOpacity)
    fun setOpacity(tool: Tool, brush: BrushSpec, v: Float) = sp.edit().putFloat("opacity_${tool.name}_${brush.id}", v).apply()

    /** A brush with the user's Brush Studio changes applied. */
    fun brush(id: String?): BrushSpec {
        val base = Brushes.byId(id) ?: Brushes.default
        val saved = sp.getString("tune_${base.id}", null) ?: return base
        val values = saved.split(',').mapNotNull { it.toFloatOrNull() }.toFloatArray()
        return base.withTunables(values)
    }

    fun saveTunables(b: BrushSpec) = sp.edit().putString("tune_${b.id}", b.tunables().joinToString(",")).apply()
    fun resetTunables(id: String) = sp.edit().remove("tune_$id").apply()
}
