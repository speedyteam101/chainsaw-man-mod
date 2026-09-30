package com.inkframe.export

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.MatrixCursor
import android.graphics.Bitmap
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.provider.OpenableColumns
import com.inkframe.model.CellStore
import com.inkframe.render.Compositor
import com.inkframe.render.FrameSpec
import com.inkframe.util.Bg
import java.io.File
import java.io.FileNotFoundException
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

enum class ExportFormat(val label: String, val extension: String, val mime: String) {
    MP4("MP4 video", "mp4", "video/mp4"),
    GIF("Animated GIF", "gif", "image/gif"),
    PNG_SEQUENCE("PNG frames (ZIP)", "zip", "application/zip"),
    PNG_FRAME("Current frame (PNG)", "png", "image/png"),
}

class ExportJob(
    val format: ExportFormat,
    val name: String,
    /** One spec per drawing, captured on the main thread. */
    val specs: List<FrameSpec>,
    val holds: IntArray,
    val fps: Int,
    val scale: Float,
    /** How many times the animation repeats in a video (short loops are hard to watch once). */
    val repeat: Int,
    val currentFrame: Int,
)

/** Renders a project to a file in the cache directory. */
object Exporter {

    fun exportDir(context: Context) = File(context.cacheDir, "exports").apply { mkdirs() }

    /**
     * Runs on the export thread. [progress] (0..1) and [done] are called on the main thread;
     * [done] receives the file, or null and an error message.
     */
    fun run(context: Context, store: CellStore, job: ExportJob, progress: (Float) -> Unit, done: (File?, String?) -> Unit): () -> Unit {
        val cancelFlag = java.util.concurrent.atomic.AtomicBoolean(false)
        val cancelled = { cancelFlag.get() }
        Bg.export.execute {
            val dir = exportDir(context)
            dir.listFiles()?.forEach { it.delete() }
            val safeName = job.name.replace(Regex("[^A-Za-z0-9 _-]"), "").trim().ifEmpty { "Animation" }
            val file = File(dir, "$safeName.${job.format.extension}")
            try {
                when (job.format) {
                    ExportFormat.MP4 -> mp4(store, job, file, cancelled) { p -> Bg.post { progress(p) } }
                    ExportFormat.GIF -> gif(store, job, file, cancelled) { p -> Bg.post { progress(p) } }
                    ExportFormat.PNG_SEQUENCE -> pngZip(store, job, file, cancelled) { p -> Bg.post { progress(p) } }
                    ExportFormat.PNG_FRAME -> {
                        val bmp = Compositor.render(job.specs[job.currentFrame], store, job.scale)
                        file.outputStream().buffered().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    }
                }
                if (cancelled()) {
                    file.delete()
                    Bg.post { done(null, null) }
                } else {
                    Bg.post { done(file, null) }
                }
            } catch (e: Throwable) {
                file.delete()
                val msg = when (e) {
                    is OutOfMemoryError -> "Not enough memory. Try a smaller export size."
                    else -> e.message ?: e.javaClass.simpleName
                }
                Bg.post { done(null, msg) }
            }
        }
        return { cancelFlag.set(true) }
    }

    private fun pixels(store: CellStore, spec: FrameSpec, scale: Float, w: Int, h: Int): IntArray {
        val bmp = Compositor.render(spec, store, scale)
        val src = if (bmp.width == w && bmp.height == h) bmp else Bitmap.createScaledBitmap(bmp, w, h, true)
        val px = IntArray(w * h)
        src.getPixels(px, 0, w, 0, 0, w, h)
        return px
    }

    private fun size(job: ExportJob): Pair<Int, Int> {
        val s = job.specs[0]
        return Pair((s.width * job.scale).toInt().coerceAtLeast(1), (s.height * job.scale).toInt().coerceAtLeast(1))
    }

    private fun mp4(store: CellStore, job: ExportJob, file: File, cancelled: () -> Boolean, progress: (Float) -> Unit) {
        val (w, h) = size(job)
        val enc = Mp4Encoder(file, w, h, job.fps)
        try {
            // Video has no transparency: put a white page behind a hidden background.
            val specs = job.specs.map { if (it.background == null) FrameSpec(it.frameId, it.version, it.width, it.height, -1, it.layers) else it }
            // Keep converted frames for repeats when they fit in memory; otherwise render again.
            val frameBytes = enc.width.toLong() * enc.height * 3 / 2
            val keep = job.repeat > 1 && frameBytes * specs.size < (96L shl 20)
            val kept = arrayOfNulls<YuvFrame>(specs.size)
            val total = job.holds.sum() * job.repeat
            var done = 0
            repeat(job.repeat) {
                for ((i, spec) in specs.withIndex()) {
                    if (cancelled()) return
                    val frame = kept[i] ?: run {
                        val px = pixels(store, spec, job.scale, w, h)
                        val sized = if (enc.width == w && enc.height == h) px else crop(px, w, enc.width, enc.height)
                        enc.toYuv(sized).also { if (keep) kept[i] = it }
                    }
                    repeat(job.holds[i]) {
                        enc.addFrame(frame)
                        done++
                    }
                    progress(done / total.toFloat())
                }
            }
            enc.finish()
        } catch (e: Throwable) {
            enc.release()
            throw e
        }
    }

    private fun crop(px: IntArray, srcW: Int, w: Int, h: Int): IntArray {
        val out = IntArray(w * h)
        for (y in 0 until h) System.arraycopy(px, y * srcW, out, y * w, w)
        return out
    }

    private fun gif(store: CellStore, job: ExportJob, file: File, cancelled: () -> Boolean, progress: (Float) -> Unit) {
        val (w, h) = size(job)
        val delays = GifEncoder.delays(job.holds, job.fps)
        file.outputStream().buffered(1 shl 16).use { out ->
            val gif = GifEncoder(out, w, h)
            for ((i, spec) in job.specs.withIndex()) {
                if (cancelled()) return
                gif.addFrame(pixels(store, spec, job.scale, w, h), delays[i])
                progress((i + 1f) / job.specs.size)
            }
            gif.finish()
        }
    }

    private fun pngZip(store: CellStore, job: ExportJob, file: File, cancelled: () -> Boolean, progress: (Float) -> Unit) {
        val total = job.holds.sum()
        var tick = 0
        ZipOutputStream(file.outputStream().buffered(1 shl 16)).use { zip ->
            for ((i, spec) in job.specs.withIndex()) {
                if (cancelled()) return
                val bmp = Compositor.render(spec, store, job.scale)
                val bytes = java.io.ByteArrayOutputStream()
                bmp.compress(Bitmap.CompressFormat.PNG, 100, bytes)
                // One image per tick, so held frames keep their timing in video editors.
                repeat(job.holds[i]) {
                    tick++
                    zip.putNextEntry(ZipEntry(String.format("frame_%04d.png", tick)))
                    zip.write(bytes.toByteArray())
                    zip.closeEntry()
                }
                progress(tick / total.toFloat())
            }
        }
    }

    /** Copies [file] into the shared Pictures/Movies/Downloads collection. Returns the display folder. */
    fun saveToGallery(context: Context, file: File, format: ExportFormat): String {
        val resolver = context.contentResolver
        val (collection, folder) = when (format) {
            ExportFormat.MP4 -> MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY) to "Movies/Inkframe"
            ExportFormat.GIF, ExportFormat.PNG_FRAME -> MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY) to "Pictures/Inkframe"
            ExportFormat.PNG_SEQUENCE -> MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY) to "Download/Inkframe"
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, file.name)
            put(MediaStore.MediaColumns.MIME_TYPE, format.mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, folder)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(collection, values) ?: throw java.io.IOException("Could not create the file")
        try {
            resolver.openOutputStream(uri)?.use { out -> file.inputStream().use { it.copyTo(out) } }
                ?: throw java.io.IOException("Could not write the file")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        return folder
    }

    fun copyTo(context: Context, file: File, target: Uri) {
        context.contentResolver.openOutputStream(target)?.use { out -> file.inputStream().use { it.copyTo(out) } }
            ?: throw java.io.IOException("Could not write the file")
    }

    fun shareIntent(context: Context, file: File, format: ExportFormat): Intent {
        val uri = ExportProvider.uriFor(context, file)
        return Intent.createChooser(
            Intent(Intent.ACTION_SEND).apply {
                type = format.mime
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            },
            "Share animation",
        )
    }
}

/** Serves exported files to other apps for sharing, read-only, from the exports folder only. */
class ExportProvider : ContentProvider() {
    override fun onCreate() = true

    private fun fileFor(uri: Uri): File {
        val ctx = context ?: throw FileNotFoundException()
        val dir = Exporter.exportDir(ctx).canonicalFile
        val name = uri.lastPathSegment ?: throw FileNotFoundException()
        val f = File(dir, name).canonicalFile
        if (f.parentFile != dir || !f.exists()) throw FileNotFoundException(name)
        return f
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor =
        ParcelFileDescriptor.open(fileFor(uri), ParcelFileDescriptor.MODE_READ_ONLY)

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor {
        val f = fileFor(uri)
        val cols = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val cursor = MatrixCursor(cols)
        cursor.addRow(cols.map { c ->
            when (c) {
                OpenableColumns.DISPLAY_NAME -> f.name
                OpenableColumns.SIZE -> f.length()
                else -> null
            }
        }.toTypedArray())
        return cursor
    }

    override fun getType(uri: Uri): String? {
        val ext = uri.lastPathSegment?.substringAfterLast('.', "") ?: return null
        return ExportFormat.entries.firstOrNull { it.extension == ext }?.mime
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) = 0

    companion object {
        fun uriFor(context: Context, file: File): Uri =
            Uri.Builder().scheme("content").authority("${context.packageName}.exports").appendPath(file.name).build()
    }
}
