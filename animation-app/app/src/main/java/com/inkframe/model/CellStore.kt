package com.inkframe.model

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Pixel storage for every cell of a project.
 *
 * Bitmaps are kept in an LRU cache limited to [budgetBytes]. When a cell falls out of the
 * cache it is written to `<dir>/<key>.png` on a background thread, so long animations
 * work without holding every drawing in memory. Cells of the frame being edited are
 * pinned and never evicted.
 *
 * Thread safety: every method may be called from any thread. Only the main thread draws
 * into cell bitmaps; other threads only read them (to render thumbnails, playback and exports).
 */
class CellStore(private val dir: File, val width: Int, val height: Int, private val budgetBytes: Long) {

    private class Entry(val bitmap: Bitmap) {
        @Volatile var dirty = false
    }

    private val lock = Any()
    private val cache = LinkedHashMap<String, Entry>(64, 0.75f, true)
    private val pendingWrites = HashMap<String, Bitmap>()
    private val onDisk = HashSet<String>()
    private val pinned = HashSet<String>()
    private val versions = HashMap<String, Int>()
    private var cachedBytes = 0L
    private val writer = Executors.newSingleThreadExecutor { r -> Thread(r, "cell-writer").apply { isDaemon = true } }

    init {
        dir.mkdirs()
        dir.listFiles()?.forEach { f ->
            when {
                f.name.endsWith(".tmp") -> f.delete()
                f.name.endsWith(".png") -> onDisk += f.name.removeSuffix(".png")
            }
        }
    }

    private fun fileOf(key: String) = File(dir, "$key.png")

    fun hasContent(key: String): Boolean = synchronized(lock) {
        key in cache || key in pendingWrites || key in onDisk
    }

    /** The cell bitmap, or null when the cell has never been drawn on. Never modify the result from a background thread. */
    fun get(key: String): Bitmap? {
        while (true) {
            val version: Int
            synchronized(lock) {
                cache[key]?.let { return it.bitmap }
                pendingWrites[key]?.let { return adoptPending(key, it) }
                if (key !in onDisk) return null
                version = versions[key] ?: 0
            }
            // Decode outside the lock so a slow read never blocks the UI thread.
            val decoded = decode(key)
            synchronized(lock) {
                cache[key]?.let { return it.bitmap }
                pendingWrites[key]?.let { return adoptPending(key, it) }
                if ((versions[key] ?: 0) == version) {
                    if (decoded == null) return null
                    insert(key, Entry(decoded))
                    return decoded
                }
                // The cell changed while we were decoding; try again.
            }
        }
    }

    /** The cell bitmap, created empty when needed. Call [markDirty] after drawing into it. */
    fun getOrCreate(key: String): Bitmap {
        get(key)?.let { return it }
        synchronized(lock) {
            cache[key]?.let { return it.bitmap }
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            insert(key, Entry(bmp))
            bump(key)
            return bmp
        }
    }

    fun markDirty(key: String) {
        synchronized(lock) {
            cache[key]?.dirty = true
            bump(key)
        }
    }

    /** Replaces the cell's pixels with [bitmap] (which the store now owns). */
    fun put(key: String, bitmap: Bitmap) {
        synchronized(lock) {
            cache.remove(key)?.let { cachedBytes -= it.bitmap.allocationByteCount }
            val e = Entry(bitmap)
            e.dirty = true
            insert(key, e)
            bump(key)
        }
    }

    /** Copies the pixels of [from] into a new cell [to]. Does nothing if [from] is empty. */
    fun copy(from: String, to: String) {
        val src = get(from) ?: return
        val copy = src.copy(Bitmap.Config.ARGB_8888, true) ?: return
        put(to, copy)
    }

    /** Keeps these cells in memory (the frame being edited). */
    fun pin(keys: Collection<String>) {
        synchronized(lock) {
            pinned.clear()
            pinned.addAll(keys)
        }
    }

    /** Loads cells on the calling (background) thread so later [get] calls are instant. */
    fun prefetch(keys: Collection<String>) {
        for (k in keys) {
            if (cachedBytes > budgetBytes * 3 / 4) return
            get(k)
        }
    }

    fun version(key: String): Int = synchronized(lock) { versions[key] ?: 0 }

    /** Writes every changed cell to disk and waits for queued writes. Call from a background thread. */
    fun flush() {
        val toWrite = ArrayList<Pair<String, Bitmap>>()
        synchronized(lock) {
            for ((k, e) in cache) {
                if (e.dirty) {
                    e.dirty = false
                    toWrite += k to e.bitmap
                }
            }
        }
        for ((k, b) in toWrite) write(k, b)
        writer.submit {}.get(2, TimeUnit.MINUTES)
    }

    /** Drops cached cells that are not pinned (writing changed ones first). */
    fun trim() {
        synchronized(lock) { evict(0L) }
    }

    /** Deletes cells that no longer belong to the project. Call when the project is closed, after [flush]. */
    fun collectGarbage(live: Set<String>) {
        writer.submit {}.get(2, TimeUnit.MINUTES)
        synchronized(lock) {
            val deadCached = cache.keys.filter { it !in live }
            for (k in deadCached) cache.remove(k)?.let { cachedBytes -= it.bitmap.allocationByteCount }
            val deadFiles = onDisk.filter { it !in live }
            for (k in deadFiles) {
                fileOf(k).delete()
                onDisk.remove(k)
            }
        }
    }

    fun close() {
        writer.shutdown()
    }

    // --- internals (call with lock held) ---

    private fun bump(key: String) {
        versions[key] = (versions[key] ?: 0) + 1
    }

    /** A cell that is being written after eviction was requested again: bring it back into the cache. */
    private fun adoptPending(key: String, bitmap: Bitmap): Bitmap {
        val e = Entry(bitmap)
        e.dirty = true
        insert(key, e)
        return bitmap
    }

    private fun insert(key: String, e: Entry) {
        cache.put(key, e)?.let { cachedBytes -= it.bitmap.allocationByteCount }
        cachedBytes += e.bitmap.allocationByteCount
        evict(budgetBytes)
    }

    private fun evict(limit: Long) {
        if (cachedBytes <= limit) return
        val it = cache.entries.iterator()
        while (cachedBytes > limit && it.hasNext()) {
            val (k, e) = it.next()
            if (k in pinned) continue
            it.remove()
            cachedBytes -= e.bitmap.allocationByteCount
            if (e.dirty) {
                pendingWrites[k] = e.bitmap
                writer.execute {
                    write(k, e.bitmap)
                    synchronized(lock) {
                        if (pendingWrites[k] === e.bitmap) pendingWrites.remove(k)
                    }
                }
            }
        }
    }

    private fun write(key: String, bitmap: Bitmap) {
        try {
            ProjectRepository.writeAtomically(fileOf(key)) { f ->
                f.outputStream().buffered().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            }
            synchronized(lock) { onDisk += key }
        } catch (e: Exception) {
            // Keep the pixels in memory so nothing is lost; the next flush retries.
            synchronized(lock) {
                if (key !in cache) {
                    val entry = Entry(bitmap)
                    entry.dirty = true
                    cache[key] = entry
                    cachedBytes += bitmap.allocationByteCount
                } else {
                    cache[key]?.dirty = true
                }
            }
        }
    }

    private fun decode(key: String): Bitmap? {
        val opts = BitmapFactory.Options().apply {
            inMutable = true
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = try {
            BitmapFactory.decodeFile(fileOf(key).path, opts)
        } catch (e: OutOfMemoryError) {
            null
        } ?: return null
        if (decoded.width == width && decoded.height == height && decoded.isMutable &&
            decoded.config == Bitmap.Config.ARGB_8888
        ) {
            return decoded
        }
        // Defensive: never hand out a cell of the wrong size or format.
        val fixed = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        Canvas(fixed).drawBitmap(decoded, null, Rect(0, 0, width, height), Paint(Paint.FILTER_BITMAP_FLAG))
        return fixed
    }
}
