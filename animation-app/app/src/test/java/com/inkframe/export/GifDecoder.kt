package com.inkframe.export

/**
 * Minimal GIF reader used to check the encoder's output (JDK ImageIO is not on the
 * Android unit-test classpath). Supports what [GifEncoder] writes: local color tables,
 * graphic control extensions and full-size frames.
 */
class GifDecoder(private val data: ByteArray) {
    class Frame(val pixels: IntArray, val delayCs: Int)

    var width = 0
        private set
    var height = 0
        private set
    var loopCount = -1
        private set
    val frames = ArrayList<Frame>()
    private var pos = 0

    private fun u8() = data[pos++].toInt() and 0xFF
    private fun u16() = u8() or (u8() shl 8)

    fun decode(): GifDecoder {
        val sig = String(data, 0, 6, Charsets.US_ASCII)
        require(sig == "GIF89a" || sig == "GIF87a") { "not a GIF: $sig" }
        pos = 6
        width = u16()
        height = u16()
        val flags = u8()
        pos += 2
        var global: IntArray? = null
        if (flags and 0x80 != 0) global = readTable(1 shl ((flags and 7) + 1))
        var delay = 0
        var transparent = -1
        loop@ while (pos < data.size) {
            when (u8()) {
                0x21 -> {
                    val label = u8()
                    if (label == 0xF9) {
                        u8()
                        val f = u8()
                        delay = u16()
                        val t = u8()
                        transparent = if (f and 1 != 0) t else -1
                        u8()
                    } else if (label == 0xFF) {
                        val block = ByteArray(u8()).also { for (i in it.indices) it[i] = data[pos++] }
                        if (String(block, Charsets.US_ASCII).startsWith("NETSCAPE")) {
                            u8(); u8(); loopCount = u16(); u8()
                        } else {
                            skipBlocks()
                        }
                    } else {
                        skipBlocks()
                    }
                }
                0x2C -> {
                    val left = u16(); val top = u16(); val w = u16(); val h = u16()
                    require(left == 0 && top == 0 && w == width && h == height)
                    val f = u8()
                    val table = if (f and 0x80 != 0) readTable(1 shl ((f and 7) + 1)) else global!!
                    val indices = lzw(u8(), w * h)
                    val px = IntArray(w * h) { i ->
                        val idx = indices[i].toInt() and 0xFF
                        if (idx == transparent) 0 else table[idx]
                    }
                    frames += Frame(px, delay)
                    transparent = -1
                }
                0x3B -> break@loop
                else -> error("bad block at ${pos - 1}")
            }
        }
        return this
    }

    private fun readTable(n: Int) = IntArray(n) { (0xFF shl 24) or (u8() shl 16) or (u8() shl 8) or u8() }

    private fun skipBlocks() {
        while (true) {
            val n = u8()
            if (n == 0) return
            pos += n
        }
    }

    private fun lzw(minCodeSize: Int, count: Int): ByteArray {
        val bytes = java.io.ByteArrayOutputStream()
        while (true) {
            val n = u8()
            if (n == 0) break
            bytes.write(data, pos, n)
            pos += n
        }
        val src = bytes.toByteArray()
        val out = ByteArray(count)
        var outPos = 0
        val clear = 1 shl minCodeSize
        val eoi = clear + 1
        val prefix = IntArray(4096)
        val suffix = ByteArray(4096)
        val length = IntArray(4096)
        for (i in 0 until clear) { suffix[i] = i.toByte(); length[i] = 1; prefix[i] = -1 }
        var codeSize = minCodeSize + 1
        var next = eoi + 1
        var prev = -1
        var bitPos = 0
        val stack = ByteArray(4096)
        fun readCode(): Int {
            var code = 0
            for (b in 0 until codeSize) {
                val byte = src[(bitPos + b) shr 3].toInt()
                if ((byte shr ((bitPos + b) and 7)) and 1 != 0) code = code or (1 shl b)
            }
            bitPos += codeSize
            return code
        }
        while (bitPos + codeSize <= src.size * 8) {
            val code = readCode()
            if (code == clear) {
                codeSize = minCodeSize + 1
                next = eoi + 1
                prev = -1
                continue
            }
            if (code == eoi) break
            val first: Byte
            if (prev == -1) {
                out[outPos++] = suffix[code]
                prev = code
                continue
            }
            val known = code < next
            var c = if (known) code else prev
            var sp = 0
            while (c >= 0) { stack[sp++] = suffix[c]; c = prefix[c] }
            first = stack[sp - 1]
            while (sp > 0 && outPos < count) out[outPos++] = stack[--sp]
            if (!known && outPos < count) out[outPos++] = first
            if (next < 4096) {
                prefix[next] = prev
                suffix[next] = first
                length[next] = length[prev] + 1
                next++
                if (next == (1 shl codeSize) && codeSize < 12) codeSize++
            }
            prev = code
        }
        require(outPos == count) { "decoded $outPos of $count pixels" }
        return out
    }
}
