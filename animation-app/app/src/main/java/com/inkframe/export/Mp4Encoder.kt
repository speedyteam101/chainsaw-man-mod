package com.inkframe.export

import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.io.IOException

/**
 * H.264 MP4 writer fed with ARGB frames. Frames go through YUV input buffers (not a
 * Surface) so the timestamps, and therefore the timing, are exact.
 */
class Mp4Encoder(private val file: File, width: Int, height: Int, private val fps: Int) {
    val width: Int
    val height: Int
    private val codec: MediaCodec
    private val muxer: MediaMuxer
    private var track = -1
    private var muxerStarted = false
    private var frameIndex = 0L
    private val info = MediaCodec.BufferInfo()

    init {
        var w = width and 1.inv()
        var h = height and 1.inv()
        var c: MediaCodec? = null
        var lastError: Exception? = null
        // Some encoders only accept sizes that are multiples of 16; try the exact size first.
        for (align in intArrayOf(2, 16)) {
            w = (width / align) * align
            h = (height / align) * align
            if (w < 16 || h < 16) continue
            val candidate = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
            try {
                val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, w, h).apply {
                    setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
                    setInteger(MediaFormat.KEY_BIT_RATE, (w.toLong() * h * fps * 0.2).toLong().coerceIn(1_500_000L, 24_000_000L).toInt())
                    setInteger(MediaFormat.KEY_FRAME_RATE, fps)
                    setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
                }
                candidate.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                c = candidate
                break
            } catch (e: Exception) {
                lastError = e
                candidate.release()
            }
        }
        codec = c ?: throw IOException("This device cannot encode video at ${width}x$height", lastError)
        this.width = w
        this.height = h
        codec.start()
        muxer = MediaMuxer(file.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    }

    /** Converts [argb] ([width] x [height], opaque) once; the result can be queued many times. */
    fun toYuv(argb: IntArray): YuvFrame = YuvFrame.from(argb, width, height)

    fun addFrame(frame: YuvFrame) {
        var index: Int
        while (true) {
            index = codec.dequeueInputBuffer(10_000)
            if (index >= 0) break
            drain(false)
        }
        val image = codec.getInputImage(index) ?: throw IOException("Encoder has no input image")
        frame.writeTo(image)
        val pts = frameIndex * 1_000_000L / fps
        codec.queueInputBuffer(index, 0, width * height * 3 / 2, pts, 0)
        frameIndex++
        drain(false)
    }

    fun finish() {
        try {
            var index: Int
            while (true) {
                index = codec.dequeueInputBuffer(10_000)
                if (index >= 0) break
                drain(false)
            }
            codec.queueInputBuffer(index, 0, 0, frameIndex * 1_000_000L / fps, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            drain(true)
        } finally {
            release()
        }
    }

    fun release() {
        try { codec.stop() } catch (e: Exception) { }
        try { codec.release() } catch (e: Exception) { }
        try { if (muxerStarted) muxer.stop() } catch (e: Exception) { }
        try { muxer.release() } catch (e: Exception) { }
    }

    private fun drain(endOfStream: Boolean) {
        var idle = 0
        while (true) {
            val out = codec.dequeueOutputBuffer(info, 10_000)
            when {
                out == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream || ++idle > 500) return
                }
                out == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    track = muxer.addTrack(codec.outputFormat)
                    muxer.start()
                    muxerStarted = true
                }
                out >= 0 -> {
                    val buf = codec.getOutputBuffer(out)
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                    if (buf != null && info.size > 0 && muxerStarted) {
                        buf.position(info.offset)
                        buf.limit(info.offset + info.size)
                        muxer.writeSampleData(track, buf, info)
                    }
                    codec.releaseOutputBuffer(out, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }
            }
        }
    }
}

/** A frame in BT.601 limited-range YUV 4:2:0, ready to copy into encoder input images. */
class YuvFrame(val width: Int, val height: Int, val y: ByteArray, val u: ByteArray, val v: ByteArray) {

    fun writeTo(image: Image) {
        val planes = image.planes
        val yp = planes[0]
        val yb = yp.buffer
        if (yp.pixelStride == 1) {
            for (row in 0 until height) {
                yb.position(row * yp.rowStride)
                yb.put(y, row * width, width)
            }
        } else {
            for (row in 0 until height) for (col in 0 until width) {
                yb.put(row * yp.rowStride + col * yp.pixelStride, y[row * width + col])
            }
        }
        val cw = width / 2
        val ch = height / 2
        val up = planes[1]
        val vp = planes[2]
        val ub = up.buffer
        val vb = vp.buffer
        for (row in 0 until ch) {
            for (col in 0 until cw) {
                val i = row * cw + col
                ub.put(row * up.rowStride + col * up.pixelStride, u[i])
                vb.put(row * vp.rowStride + col * vp.pixelStride, v[i])
            }
        }
    }

    companion object {
        fun from(argb: IntArray, width: Int, height: Int): YuvFrame {
            val y = ByteArray(width * height)
            val cw = width / 2
            val ch = height / 2
            val u = ByteArray(cw * ch)
            val v = ByteArray(cw * ch)
            for (i in 0 until width * height) {
                val c = argb[i]
                val r = (c shr 16) and 0xFF
                val g = (c shr 8) and 0xFF
                val b = c and 0xFF
                y[i] = (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).coerceIn(16, 235).toByte()
            }
            for (row in 0 until ch) {
                for (col in 0 until cw) {
                    var r = 0
                    var g = 0
                    var b = 0
                    for (dy in 0..1) for (dx in 0..1) {
                        val c = argb[(row * 2 + dy) * width + col * 2 + dx]
                        r += (c shr 16) and 0xFF
                        g += (c shr 8) and 0xFF
                        b += c and 0xFF
                    }
                    r /= 4; g /= 4; b /= 4
                    val i = row * cw + col
                    u[i] = (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).coerceIn(16, 240).toByte()
                    v[i] = (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).coerceIn(16, 240).toByte()
                }
            }
            return YuvFrame(width, height, y, u, v)
        }
    }
}
