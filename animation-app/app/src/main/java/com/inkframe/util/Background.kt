package com.inkframe.util

import android.os.Handler
import android.os.Looper
import java.security.SecureRandom
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ThreadFactory
import java.util.concurrent.atomic.AtomicInteger

/** Shared threads. All model mutation happens on the main thread; these only read or write files and render. */
object Bg {
    private fun factory(name: String): ThreadFactory {
        val n = AtomicInteger()
        return ThreadFactory { r ->
            Thread(r, "$name-${n.incrementAndGet()}").apply {
                isDaemon = true
                priority = Thread.NORM_PRIORITY - 1
            }
        }
    }

    /** Ordered disk work: saving, loading and listing projects. */
    val io: ExecutorService = Executors.newSingleThreadExecutor(factory("io"))

    /** Rendering work: thumbnails, playback frames, fills. */
    val render: ExecutorService = Executors.newFixedThreadPool(2, factory("render"))

    /** Long jobs such as exports. */
    val export: ExecutorService = Executors.newSingleThreadExecutor(factory("export"))

    val main = Handler(Looper.getMainLooper())

    fun post(block: () -> Unit) {
        main.post(block)
    }
}

object Ids {
    private const val ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789"
    private val random = SecureRandom()

    /** Short random id made only of [a-z0-9], so it is safe in file names and never contains '_'. */
    fun next(length: Int = 12): String {
        val sb = StringBuilder(length)
        repeat(length) { sb.append(ALPHABET[random.nextInt(ALPHABET.length)]) }
        return sb.toString()
    }
}
