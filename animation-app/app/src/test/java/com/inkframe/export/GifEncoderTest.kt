package com.inkframe.export

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.Random
import javax.imageio.ImageIO
import javax.imageio.ImageReader
import javax.imageio.metadata.IIOMetadataNode

class GifEncoderTest {

    private fun decodeAll(bytes: ByteArray): Pair<ImageReader, Int> {
        val reader = ImageIO.getImageReadersByFormatName("gif").next()
        reader.input = ImageIO.createImageInputStream(ByteArrayInputStream(bytes))
        return reader to reader.getNumImages(true)
    }

    @Test
    fun flatColorsRoundTripExactly() {
        val w = 37
        val h = 23
        val colors = intArrayOf(0xFFFF0000.toInt(), 0xFF00FF00.toInt(), 0xFF0000FF.toInt(), 0xFFFFFFFF.toInt(), 0xFF123456.toInt())
        val frames = (0 until 3).map { f -> IntArray(w * h) { i -> colors[(i / 7 + f) % colors.size] } }
        val out = ByteArrayOutputStream()
        val gif = GifEncoder(out, w, h)
        frames.forEach { gif.addFrame(it, 8) }
        gif.finish()

        val (reader, n) = decodeAll(out.toByteArray())
        assertEquals(3, n)
        for (f in 0 until 3) {
            val img = reader.read(f)
            val got = IntArray(w * h) { img.getRGB(it % w, it / w) }
            assertArrayEquals("frame $f", frames[f], got)
            val meta = reader.getImageMetadata(f).getAsTree("javax_imageio_gif_image_1.0") as IIOMetadataNode
            val gce = meta.getElementsByTagName("GraphicControlExtension").item(0) as IIOMetadataNode
            assertEquals("8", gce.getAttribute("delayTime"))
        }
    }

    @Test
    fun noisyImageSurvivesManyTableResets() {
        // Random pixels force the LZW table to fill and reset many times.
        val w = 256
        val h = 200
        val rnd = Random(3)
        val palette = IntArray(200) { (0xFF shl 24) or (it * 1237 and 0xFFFFFF) }
        // Keep palette colors distinct at 5 bits per channel so the quantizer maps them exactly.
        val distinct = palette.map { c -> c and 0xFFF8F8F8.toInt() }.distinct().take(180).toIntArray()
        val px = IntArray(w * h) { distinct[rnd.nextInt(distinct.size)] }
        val out = ByteArrayOutputStream()
        GifEncoder(out, w, h).apply { addFrame(px, 5); finish() }
        val (reader, n) = decodeAll(out.toByteArray())
        assertEquals(1, n)
        val img = reader.read(0)
        var mismatches = 0
        for (i in px.indices) if (img.getRGB(i % w, i / w) != px[i]) mismatches++
        assertEquals(0, mismatches)
    }

    @Test
    fun transparentPixelsBecomeTransparent() {
        val w = 8
        val h = 8
        val px = IntArray(w * h) { if (it < 32) 0 else 0xFF336699.toInt() }
        val out = ByteArrayOutputStream()
        GifEncoder(out, w, h).apply { addFrame(px, 10); finish() }
        val (reader, _) = decodeAll(out.toByteArray())
        val img = reader.read(0)
        assertEquals(0, img.getRGB(0, 0) ushr 24)
        assertEquals(0xFF336699.toInt(), img.getRGB(0, 7))
    }

    @Test
    fun manyColorsAreReducedTo256() {
        val w = 128
        val h = 128
        val px = IntArray(w * h) { i -> (0xFF shl 24) or ((i % 128) * 2 shl 16) or ((i / 128) * 2 shl 8) or 128 }
        val q = ColorQuantizer.quantize(px)
        assertTrue(q.palette.size <= 256)
        assertEquals(-1, q.transparentIndex)
        // Every pixel maps to a palette color close to the original.
        var worst = 0
        for (i in px.indices) {
            val a = px[i]
            val b = q.palette[q.indices[i].toInt() and 0xFF]
            val d = maxOf(
                kotlin.math.abs(((a shr 16) and 0xFF) - ((b shr 16) and 0xFF)),
                kotlin.math.abs(((a shr 8) and 0xFF) - ((b shr 8) and 0xFF)),
            )
            worst = maxOf(worst, d)
        }
        assertTrue("worst channel error $worst", worst <= 24)
    }

    @Test
    fun delaysKeepTotalDuration() {
        val d = GifEncoder.delays(IntArray(24) { 1 }, 24)
        assertEquals(100, d.sum(), )
        val slow = GifEncoder.delays(intArrayOf(1, 2, 3), 12)
        assertEquals(50, slow.sum())
        val fast = GifEncoder.delays(IntArray(60) { 1 }, 60)
        assertTrue(fast.all { it >= 2 })
    }
}
