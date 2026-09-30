package com.inkframe.model

import android.graphics.Bitmap
import com.inkframe.util.Ids
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException

/** What the gallery needs to show a project without loading it. */
class ProjectSummary(
    val id: String,
    val name: String,
    val width: Int,
    val height: Int,
    val frameCount: Int,
    val fps: Int,
    val modifiedAt: Long,
    val thumbnail: File,
)

object ProjectJson {
    private const val VERSION = 1

    fun toJson(p: Project): JSONObject = JSONObject().apply {
        put("version", VERSION)
        put("id", p.id)
        put("name", p.name)
        put("width", p.width)
        put("height", p.height)
        put("fps", p.fps)
        put("background", p.backgroundColor)
        put("backgroundVisible", p.backgroundVisible)
        put("playMode", p.playMode.name)
        put("currentFrame", p.currentFrame)
        put("activeLayer", p.activeLayer)
        put("createdAt", p.createdAt)
        put("modifiedAt", p.modifiedAt)
        put("onion", JSONObject().apply {
            put("enabled", p.onion.enabled)
            put("before", p.onion.before)
            put("after", p.onion.after)
            put("opacity", p.onion.opacity.toDouble())
            put("colored", p.onion.colored)
            put("allLayers", p.onion.allLayers)
        })
        put("layers", JSONArray().apply {
            p.layers.forEach { l ->
                put(JSONObject().apply {
                    put("id", l.id)
                    put("name", l.name)
                    put("visible", l.visible)
                    put("opacity", l.opacity.toDouble())
                    put("blend", l.blend.name)
                    put("alphaLock", l.alphaLock)
                })
            }
        })
        put("frames", JSONArray().apply {
            p.frames.forEach { f ->
                put(JSONObject().apply {
                    put("id", f.id)
                    put("hold", f.hold)
                })
            }
        })
    }

    fun fromJson(o: JSONObject): Project {
        val width = o.getInt("width").coerceIn(1, Project.MAX_SIDE)
        val height = o.getInt("height").coerceIn(1, Project.MAX_SIDE)
        val p = Project(o.getString("id"), o.optString("name", "Untitled"), width, height)
        p.fps = o.optInt("fps", 12).coerceIn(1, 60)
        p.backgroundColor = o.optInt("background", 0xFFFFFFFF.toInt())
        p.backgroundVisible = o.optBoolean("backgroundVisible", true)
        p.playMode = PlayMode.entries.firstOrNull { it.name == o.optString("playMode") } ?: PlayMode.LOOP
        p.createdAt = o.optLong("createdAt", System.currentTimeMillis())
        p.modifiedAt = o.optLong("modifiedAt", p.createdAt)
        o.optJSONObject("onion")?.let { on ->
            p.onion.enabled = on.optBoolean("enabled", true)
            p.onion.before = on.optInt("before", 1).coerceIn(0, 10)
            p.onion.after = on.optInt("after", 1).coerceIn(0, 10)
            p.onion.opacity = on.optDouble("opacity", 0.35).toFloat().coerceIn(0f, 1f)
            p.onion.colored = on.optBoolean("colored", true)
            p.onion.allLayers = on.optBoolean("allLayers", false)
        }
        val layers = o.getJSONArray("layers")
        for (i in 0 until layers.length()) {
            val lo = layers.getJSONObject(i)
            p.layers += Layer(lo.getString("id"), lo.optString("name", "Layer ${i + 1}")).apply {
                visible = lo.optBoolean("visible", true)
                opacity = lo.optDouble("opacity", 1.0).toFloat().coerceIn(0f, 1f)
                blend = LayerBlend.of(lo.optString("blend"))
                alphaLock = lo.optBoolean("alphaLock", false)
            }
        }
        val frames = o.getJSONArray("frames")
        for (i in 0 until frames.length()) {
            val fo = frames.getJSONObject(i)
            p.frames += Frame(fo.getString("id"), fo.optInt("hold", 1).coerceIn(1, 99))
        }
        if (p.layers.isEmpty()) p.layers += Layer(Ids.next(), "Layer 1")
        if (p.frames.isEmpty()) p.frames += Frame(Ids.next())
        p.currentFrame = o.optInt("currentFrame", 0).coerceIn(0, p.frames.size - 1)
        p.activeLayer = o.optInt("activeLayer", 0).coerceIn(0, p.layers.size - 1)
        return p
    }
}

/**
 * Projects live in `<root>/<id>/` with `project.json`, a `cells/` folder of PNGs
 * (one per non-empty cell) and `thumb.png` for the gallery.
 */
class ProjectRepository(val root: File) {
    init {
        root.mkdirs()
    }

    fun dirOf(id: String) = File(root, id)
    fun cellsDir(id: String) = File(dirOf(id), "cells")
    fun thumbnailOf(id: String) = File(dirOf(id), "thumb.png")
    private fun jsonOf(id: String) = File(dirOf(id), "project.json")

    fun list(): List<ProjectSummary> {
        val dirs = root.listFiles { f -> f.isDirectory } ?: return emptyList()
        return dirs.mapNotNull { dir ->
            try {
                val o = JSONObject(File(dir, "project.json").readText())
                ProjectSummary(
                    id = o.getString("id"),
                    name = o.optString("name", "Untitled"),
                    width = o.getInt("width"),
                    height = o.getInt("height"),
                    frameCount = o.getJSONArray("frames").length(),
                    fps = o.optInt("fps", 12),
                    modifiedAt = o.optLong("modifiedAt", dir.lastModified()),
                    thumbnail = File(dir, "thumb.png"),
                )
            } catch (e: Exception) {
                null
            }
        }.sortedByDescending { it.modifiedAt }
    }

    fun create(name: String, width: Int, height: Int, fps: Int, background: Int, backgroundVisible: Boolean): Project {
        val p = Project(Ids.next(), name, width.coerceIn(16, Project.MAX_SIDE), height.coerceIn(16, Project.MAX_SIDE))
        p.fps = fps
        p.backgroundColor = background
        p.backgroundVisible = backgroundVisible
        p.layers += Layer(Ids.next(), "Layer 1")
        p.frames += Frame(Ids.next())
        cellsDir(p.id).mkdirs()
        writeJson(p)
        return p
    }

    fun load(id: String): Project = ProjectJson.fromJson(JSONObject(jsonOf(id).readText()))

    /** Atomic write: a crash mid-save never leaves a half-written project.json. */
    fun writeJson(p: Project) {
        writeAtomically(jsonOf(p.id)) { it.writeText(ProjectJson.toJson(p).toString()) }
    }

    /** Writes JSON produced by [ProjectJson.toJson] on the main thread; safe to call from a background thread. */
    fun writeJsonText(id: String, text: String) {
        writeAtomically(jsonOf(id)) { it.writeText(text) }
    }

    fun writeThumbnail(id: String, bitmap: Bitmap) {
        writeAtomically(thumbnailOf(id)) { f ->
            f.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        }
    }

    fun rename(id: String, name: String) {
        val p = load(id)
        p.name = name
        writeJson(p)
    }

    fun delete(id: String) {
        dirOf(id).deleteRecursively()
    }

    fun duplicate(id: String): String {
        val newId = Ids.next()
        dirOf(id).copyRecursively(dirOf(newId))
        val p = ProjectJson.fromJson(JSONObject(jsonOf(newId).readText()))
        val copy = Project(newId, "${p.name} copy", p.width, p.height).also { c ->
            c.fps = p.fps
            c.backgroundColor = p.backgroundColor
            c.backgroundVisible = p.backgroundVisible
            c.playMode = p.playMode
            c.onion.copyFrom(p.onion)
            c.layers += p.layers
            c.frames += p.frames
            c.currentFrame = p.currentFrame
            c.activeLayer = p.activeLayer
        }
        writeJson(copy)
        return newId
    }

    companion object {
        fun writeAtomically(target: File, write: (File) -> Unit) {
            val tmp = File(target.parentFile, target.name + "." + Thread.currentThread().id + ".tmp")
            try {
                write(tmp)
                if (!tmp.renameTo(target)) {
                    target.delete()
                    if (!tmp.renameTo(target)) throw IOException("Could not write ${target.name}")
                }
            } finally {
                tmp.delete()
            }
        }
    }
}
