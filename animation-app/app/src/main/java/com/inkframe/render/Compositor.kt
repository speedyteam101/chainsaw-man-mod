package com.inkframe.render

import android.graphics.Bitmap
import android.graphics.BlendMode
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import com.inkframe.model.CellStore
import com.inkframe.model.LayerBlend
import com.inkframe.model.Project

fun LayerBlend.toBlendMode(): BlendMode? = when (this) {
    LayerBlend.NORMAL -> null
    LayerBlend.MULTIPLY -> BlendMode.MULTIPLY
    LayerBlend.SCREEN -> BlendMode.SCREEN
    LayerBlend.OVERLAY -> BlendMode.OVERLAY
    LayerBlend.ADD -> BlendMode.PLUS
    LayerBlend.DARKEN -> BlendMode.DARKEN
    LayerBlend.LIGHTEN -> BlendMode.LIGHTEN
    LayerBlend.COLOR_BURN -> BlendMode.COLOR_BURN
    LayerBlend.COLOR_DODGE -> BlendMode.COLOR_DODGE
    LayerBlend.SOFT_LIGHT -> BlendMode.SOFT_LIGHT
    LayerBlend.HARD_LIGHT -> BlendMode.HARD_LIGHT
    LayerBlend.DIFFERENCE -> BlendMode.DIFFERENCE
    LayerBlend.HUE -> BlendMode.HUE
    LayerBlend.COLOR -> BlendMode.COLOR
    LayerBlend.LUMINOSITY -> BlendMode.LUMINOSITY
}

/** One layer of a frame, captured on the main thread so it can be rendered on any thread. */
class LayerRender(val key: String, val opacity: Float, val blend: LayerBlend)

/** Everything needed to draw one frame, independent of later edits to the project structure. */
class FrameSpec(
    val frameId: String,
    val version: Long,
    val width: Int,
    val height: Int,
    val background: Int?,
    val layers: List<LayerRender>,
) {
    companion object {
        /** Call on the main thread. */
        fun of(project: Project, frameIndex: Int, version: Long, withBackground: Boolean = true): FrameSpec {
            val frame = project.frames[frameIndex]
            return FrameSpec(
                frame.id,
                version,
                project.width,
                project.height,
                if (withBackground && project.backgroundVisible) project.backgroundColor else null,
                project.layers.filter { it.visible && it.opacity > 0f }
                    .map { LayerRender(Project.cellKey(frame.id, it.id), it.opacity, it.blend) },
            )
        }
    }
}

object Compositor {

    /** Draws the frame onto [canvas], which must already be scaled to the frame's coordinate space. */
    fun draw(canvas: Canvas, spec: FrameSpec, store: CellStore, filter: Boolean = true) {
        spec.background?.let { canvas.drawColor(it) }
        val paint = Paint()
        paint.isFilterBitmap = filter
        for (l in spec.layers) {
            val bmp = store.get(l.key) ?: continue
            paint.alpha = (l.opacity * 255f + 0.5f).toInt().coerceIn(0, 255)
            paint.blendMode = l.blend.toBlendMode()
            canvas.drawBitmap(bmp, 0f, 0f, paint)
        }
    }

    /** Renders the frame into a new bitmap scaled by [scale]. */
    fun render(
        spec: FrameSpec,
        store: CellStore,
        scale: Float,
        config: Bitmap.Config = Bitmap.Config.ARGB_8888,
    ): Bitmap {
        val w = (spec.width * scale).toInt().coerceAtLeast(1)
        val h = (spec.height * scale).toInt().coerceAtLeast(1)
        val out = Bitmap.createBitmap(w, h, config)
        val c = Canvas(out)
        if (config == Bitmap.Config.RGB_565 && spec.background == null) c.drawColor(Color.WHITE)
        c.scale(w / spec.width.toFloat(), h / spec.height.toFloat())
        draw(c, spec, store, filter = true)
        return out
    }

    /** The color the user sees at a canvas pixel (all visible layers and the background). */
    fun sampleColor(spec: FrameSpec, store: CellStore, x: Int, y: Int): Int {
        val px = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        val c = Canvas(px)
        c.translate(-x.toFloat(), -y.toFloat())
        draw(c, spec, store, filter = false)
        return px.getPixel(0, 0)
    }
}
