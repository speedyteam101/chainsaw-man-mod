package com.inkframe.editor

import android.graphics.Bitmap
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.RectF

/**
 * Moving, scaling and rotating the contents of the active cell. The original pixels are
 * kept in [source] and previewed through [matrix] until the change is applied.
 */
class TransformSession(val key: String, val source: Bitmap, val bounds: RectF) {
    val matrix = Matrix()

    fun center(): FloatArray {
        val c = floatArrayOf(bounds.centerX(), bounds.centerY())
        matrix.mapPoints(c)
        return c
    }

    fun flip(horizontal: Boolean) {
        val c = center()
        if (horizontal) matrix.postScale(-1f, 1f, c[0], c[1]) else matrix.postScale(1f, -1f, c[0], c[1])
    }

    fun rotate90() {
        val c = center()
        matrix.postRotate(90f, c[0], c[1])
    }

    fun reset() = matrix.reset()

    /** The four corners of the transformed content, for drawing the bounding box. */
    fun corners(): FloatArray {
        val pts = floatArrayOf(
            bounds.left, bounds.top, bounds.right, bounds.top,
            bounds.right, bounds.bottom, bounds.left, bounds.bottom,
        )
        matrix.mapPoints(pts)
        return pts
    }

    /** Area of the cell the transform changes: where the content was plus where it goes. */
    fun affectedRect(width: Int, height: Int): Rect? {
        val mapped = RectF(bounds)
        matrix.mapRect(mapped)
        mapped.union(bounds)
        val r = Rect(
            kotlin.math.floor(mapped.left).toInt() - 2,
            kotlin.math.floor(mapped.top).toInt() - 2,
            kotlin.math.ceil(mapped.right).toInt() + 2,
            kotlin.math.ceil(mapped.bottom).toInt() + 2,
        )
        if (!r.intersect(0, 0, width, height)) return null
        return r
    }

    companion object {
        /** Bounds of the non-transparent pixels, or null if the bitmap is empty. */
        fun contentBounds(b: Bitmap): RectF? {
            val w = b.width
            val h = b.height
            val row = IntArray(w)
            var minX = w
            var minY = h
            var maxX = -1
            var maxY = -1
            for (y in 0 until h) {
                b.getPixels(row, 0, w, 0, y, w, 1)
                var any = false
                for (x in 0 until w) {
                    if (row[x] ushr 24 != 0) {
                        any = true
                        if (x < minX) minX = x
                        if (x > maxX) maxX = x
                    }
                }
                if (any) {
                    if (y < minY) minY = y
                    maxY = y
                }
            }
            if (maxX < 0) return null
            return RectF(minX.toFloat(), minY.toFloat(), (maxX + 1).toFloat(), (maxY + 1).toFloat())
        }
    }
}
