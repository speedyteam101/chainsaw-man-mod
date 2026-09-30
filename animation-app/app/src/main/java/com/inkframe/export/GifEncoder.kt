package com.inkframe.export

import java.io.OutputStream

/**
 * Median-cut color quantizer for GIF frames. Pure Kotlin so it can be unit tested.
 *
 * Colors are binned to 5 bits per channel; each palette entry is the exact average of the
 * pixels it represents, so flat cartoon colors come out exact.
 */
object ColorQuantizer {

    class Result(val palette: IntArray, val indices: ByteArray, val transparentIndex: Int)

    fun quantize(argb: IntArray, maxColors: Int = 256): Result {
        val bins = 32 * 32 * 32
        val count = IntArray(bins)
        val sumR = LongArray(bins)
        val sumG = LongArray(bins)
        val sumB = LongArray(bins)
        var hasTransparent = false
        for (c in argb) {
            if ((c ushr 24) < 128) {
                hasTransparent = true
                continue
            }
            val r = (c shr 16) and 0xFF
            val g = (c shr 8) and 0xFF
            val b = c and 0xFF
            val bin = ((r shr 3) shl 10) or ((g shr 3) shl 5) or (b shr 3)
            count[bin]++
            sumR[bin] += r.toLong()
            sumG[bin] += g.toLong()
            sumB[bin] += b.toLong()
        }
        val limit = (if (hasTransparent) maxColors - 1 else maxColors).coerceIn(1, 256)
        val used = (0 until bins).filter { count[it] > 0 }.toIntArray()

        val boxes = ArrayList<IntArray>() // [lo, hi) ranges into `used`
        if (used.isNotEmpty()) boxes += intArrayOf(0, used.size)
        while (boxes.size < limit) {
            var best = -1
            var bestScore = 0.0
            for ((i, box) in boxes.withIndex()) {
                if (box[1] - box[0] < 2) continue
                val score = boxScore(used, count, box)
                if (score > bestScore) {
                    bestScore = score
                    best = i
                }
            }
            if (best < 0) break
            val box = boxes.removeAt(best)
            val split = splitBox(used, count, box)
            boxes += intArrayOf(box[0], split)
            boxes += intArrayOf(split, box[1])
        }

        val palette = IntArray(boxes.size + if (hasTransparent) 1 else 0)
        val lut = IntArray(bins)
        for ((pi, box) in boxes.withIndex()) {
            var n = 0L
            var r = 0L
            var g = 0L
            var b = 0L
            for (k in box[0] until box[1]) {
                val bin = used[k]
                n += count[bin]; r += sumR[bin]; g += sumG[bin]; b += sumB[bin]
                lut[bin] = pi
            }
            palette[pi] = (0xFF shl 24) or ((r / n).toInt() shl 16) or ((g / n).toInt() shl 8) or (b / n).toInt()
        }
        val transparentIndex = if (hasTransparent) boxes.size else -1
        if (hasTransparent) palette[transparentIndex] = 0

        val indices = ByteArray(argb.size)
        for (i in argb.indices) {
            val c = argb[i]
            indices[i] = if ((c ushr 24) < 128) {
                transparentIndex.toByte()
            } else {
                val bin = (((c shr 16) and 0xFF shr 3) shl 10) or (((c shr 8) and 0xFF shr 3) shl 5) or ((c and 0xFF) shr 3)
                lut[bin].toByte()
            }
        }
        return Result(palette, indices, transparentIndex)
    }

    private fun channel(bin: Int, axis: Int) = when (axis) {
        0 -> bin shr 10
        1 -> (bin shr 5) and 31
        else -> bin and 31
    }

    private fun boxScore(used: IntArray, count: IntArray, box: IntArray): Double {
        var n = 0L
        val min = intArrayOf(31, 31, 31)
        val max = intArrayOf(0, 0, 0)
        for (k in box[0] until box[1]) {
            val bin = used[k]
            n += count[bin]
            for (a in 0..2) {
                val v = channel(bin, a)
                if (v < min[a]) min[a] = v
                if (v > max[a]) max[a] = v
            }
        }
        val range = maxOf(max[0] - min[0], max[1] - min[1], max[2] - min[2]) + 1
        return Math.sqrt(n.toDouble()) * range
    }

    /** Sorts the box along its widest channel and returns the median split index. */
    private fun splitBox(used: IntArray, count: IntArray, box: IntArray): Int {
        val min = intArrayOf(31, 31, 31)
        val max = intArrayOf(0, 0, 0)
        for (k in box[0] until box[1]) {
            for (a in 0..2) {
                val v = channel(used[k], a)
                if (v < min[a]) min[a] = v
                if (v > max[a]) max[a] = v
            }
        }
        val axis = (0..2).maxBy { max[it] - min[it] }
        val slice = used.copyOfRange(box[0], box[1]).sortedBy { channel(it, axis) }
        for (k in slice.indices) used[box[0] + k] = slice[k]
        var total = 0L
        for (k in box[0] until box[1]) total += count[used[k]]
        var acc = 0L
        for (k in box[0] until box[1] - 1) {
            acc += count[used[k]]
            if (acc * 2 >= total) return k + 1
        }
        return box[1] - 1
    }
}

/**
 * Animated GIF writer (GIF89a, looping). Each frame gets its own palette.
 * Pure Kotlin so it can be unit tested.
 */
class GifEncoder(private val out: OutputStream, private val width: Int, private val height: Int, loopCount: Int = 0) {

    init {
        out.write("GIF89a".toByteArray(Charsets.US_ASCII))
        writeShort(width)
        writeShort(height)
        out.write(0) // no global color table
        out.write(0) // background color index
        out.write(0) // pixel aspect ratio
        // NETSCAPE2.0 application extension: loop forever (0) or n times.
        out.write(0x21); out.write(0xFF); out.write(11)
        out.write("NETSCAPE2.0".toByteArray(Charsets.US_ASCII))
        out.write(3); out.write(1)
        writeShort(loopCount)
        out.write(0)
    }

    /** Adds a frame of [width] x [height] ARGB pixels shown for [delayCs] hundredths of a second. */
    fun addFrame(argb: IntArray, delayCs: Int) {
        require(argb.size == width * height)
        val q = ColorQuantizer.quantize(argb)
        var bits = 1
        while ((1 shl bits) < q.palette.size) bits++

        // Graphic control extension.
        out.write(0x21); out.write(0xF9); out.write(4)
        val transparent = q.transparentIndex >= 0
        val disposal = if (transparent) 2 else 1
        out.write((disposal shl 2) or (if (transparent) 1 else 0))
        writeShort(delayCs.coerceIn(0, 65535))
        out.write(if (transparent) q.transparentIndex else 0)
        out.write(0)

        // Image descriptor with a local color table.
        out.write(0x2C)
        writeShort(0); writeShort(0)
        writeShort(width); writeShort(height)
        out.write(0x80 or (bits - 1))
        for (i in 0 until (1 shl bits)) {
            val c = if (i < q.palette.size) q.palette[i] else 0
            out.write((c shr 16) and 0xFF)
            out.write((c shr 8) and 0xFF)
            out.write(c and 0xFF)
        }
        val minCodeSize = maxOf(2, bits)
        out.write(minCodeSize)
        Lzw.encode(q.indices, minCodeSize, out)
    }

    fun finish() {
        out.write(0x3B)
        out.flush()
    }

    private fun writeShort(v: Int) {
        out.write(v and 0xFF)
        out.write((v shr 8) and 0xFF)
    }

    companion object {
        /**
         * GIF delays are whole hundredths of a second. Spreads the rounding over the animation so the
         * total length stays exact, and never goes below 2 (browsers slow smaller delays down to 10).
         */
        fun delays(holds: IntArray, fps: Int): IntArray {
            val out = IntArray(holds.size)
            var ticks = 0
            var lastCs = 0L
            for (i in holds.indices) {
                ticks += holds[i]
                val cs = Math.round(ticks * 100.0 / fps)
                out[i] = maxOf(2, (cs - lastCs).toInt())
                lastCs = cs
            }
            return out
        }
    }
}

/** GIF-flavoured LZW compression, written in 255-byte sub-blocks. */
object Lzw {
    private const val MAX_CODE = 4096
    private const val TABLE = 8192

    fun encode(indices: ByteArray, minCodeSize: Int, out: OutputStream) {
        val clear = 1 shl minCodeSize
        val eoi = clear + 1
        var next = eoi + 1
        var codeSize = minCodeSize + 1
        // Open-addressing table from (prefix code << 8 | byte) + 1 to code.
        val keys = IntArray(TABLE)
        val values = ShortArray(TABLE)

        val block = ByteArray(255)
        var blockLen = 0
        var bitBuf = 0L
        var bitCount = 0

        fun flushBlock() {
            if (blockLen > 0) {
                out.write(blockLen)
                out.write(block, 0, blockLen)
                blockLen = 0
            }
        }

        fun emit(code: Int) {
            bitBuf = bitBuf or (code.toLong() shl bitCount)
            bitCount += codeSize
            while (bitCount >= 8) {
                block[blockLen++] = (bitBuf and 0xFF).toByte()
                bitBuf = bitBuf ushr 8
                bitCount -= 8
                if (blockLen == 255) flushBlock()
            }
        }

        fun slot(key: Int): Int {
            var h = ((key * -0x61c88647) ushr 19) and (TABLE - 1)
            while (keys[h] != 0 && keys[h] != key) h = (h + 1) and (TABLE - 1)
            return h
        }

        emit(clear)
        if (indices.isNotEmpty()) {
            val mask = (1 shl minCodeSize) - 1
            var cur = indices[0].toInt() and mask
            for (i in 1 until indices.size) {
                val k = indices[i].toInt() and mask
                val key = ((cur shl 8) or k) + 1
                val s = slot(key)
                if (keys[s] == key) {
                    cur = values[s].toInt()
                    continue
                }
                emit(cur)
                if (next == MAX_CODE) {
                    emit(clear)
                    keys.fill(0)
                    next = eoi + 1
                    codeSize = minCodeSize + 1
                } else {
                    if (next >= (1 shl codeSize)) codeSize++
                    keys[s] = key
                    values[s] = next.toShort()
                    next++
                }
                cur = k
            }
            emit(cur)
        }
        emit(eoi)
        if (bitCount > 0) {
            block[blockLen++] = (bitBuf and 0xFF).toByte()
            if (blockLen == 255) flushBlock()
        }
        flushBlock()
        out.write(0) // block terminator
    }
}
