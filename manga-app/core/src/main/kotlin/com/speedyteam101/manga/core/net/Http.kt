package com.speedyteam101.manga.core.net

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.util.concurrent.TimeUnit

class ApiException(val code: Int, message: String) : IOException(message)

object Http {
    /** MangaDex asks clients to send an identifying User-Agent. */
    const val USER_AGENT = "MangaNoRomance/1.0 (Android; +https://github.com/speedyteam101)"

    val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        explicitNulls = false
    }

    fun newClient(): OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .addInterceptor { chain ->
            chain.proceed(chain.request().newBuilder().header("User-Agent", USER_AGENT).build())
        }
        .build()
}

internal suspend fun OkHttpClient.getText(url: HttpUrl): String = withContext(Dispatchers.IO) {
    newCall(Request.Builder().url(url).get().build()).execute().use { response ->
        if (!response.isSuccessful) {
            throw ApiException(response.code, "HTTP ${response.code} from ${url.host}${url.encodedPath}")
        }
        response.body?.string() ?: throw ApiException(response.code, "Empty response from ${url.host}")
    }
}
