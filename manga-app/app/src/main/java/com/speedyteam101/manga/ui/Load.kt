package com.speedyteam101.manga.ui

import com.speedyteam101.manga.core.net.ApiException
import java.io.IOException
import java.net.UnknownHostException
import kotlin.coroutines.cancellation.CancellationException

sealed interface Load<out T> {
    data object Loading : Load<Nothing>
    data class Failed(val message: String) : Load<Nothing>
    data class Ready<T>(val value: T) : Load<T>
}

val <T> Load<T>.valueOrNull: T?
    get() = (this as? Load.Ready<T>)?.value

suspend fun <T> loadCatching(block: suspend () -> T): Load<T> =
    try {
        Load.Ready(block())
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        Load.Failed(e.userMessage())
    }

fun Throwable.userMessage(): String = when (this) {
    is ApiException ->
        if (code == 429) "Too many requests. Wait a few seconds and try again." else message ?: "Server error $code"
    is UnknownHostException -> "No internet connection."
    is IOException -> "Network error: ${message ?: javaClass.simpleName}"
    else -> message ?: javaClass.simpleName
}
