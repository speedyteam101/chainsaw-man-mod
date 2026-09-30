package com.speedyteam101.manga.core.jikan

import com.speedyteam101.manga.core.net.ApiException
import com.speedyteam101.manga.core.net.Http
import com.speedyteam101.manga.core.net.getText
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient

/**
 * Minimal client for the Jikan v4 API (unofficial MyAnimeList API).
 * Jikan allows 3 requests/second and 60/minute, so calls are spaced out.
 */
class JikanApi(
    private val client: OkHttpClient,
    private val baseUrl: HttpUrl = "https://api.jikan.moe/v4/".toHttpUrl(),
    private val minIntervalMs: Long = 400,
) {
    private val gate = Mutex()
    private var lastCall = 0L

    suspend fun mangaGenres(): List<JikanGenre> =
        get<JikanList<JikanGenre>>(url("genres/manga").build()).data

    suspend fun searchManga(
        query: String?,
        page: Int,
        excludedGenreIds: Collection<Int>,
        limit: Int = 25,
    ): JikanList<JikanManga> {
        val url = url("manga")
            .addQueryParameter("page", page.toString())
            .addQueryParameter("limit", limit.toString())
            .addQueryParameter("sfw", "true")
            .addQueryParameter("order_by", "members")
            .addQueryParameter("sort", "desc")
        if (!query.isNullOrBlank()) url.addQueryParameter("q", query.trim())
        if (excludedGenreIds.isNotEmpty()) {
            url.addQueryParameter("genres_exclude", excludedGenreIds.sorted().joinToString(","))
        }
        return get(url.build())
    }

    suspend fun manga(malId: Int): JikanManga =
        get<JikanSingle<JikanManga>>(url("manga/$malId").build()).data

    suspend fun externalLinks(malId: Int): List<JikanExternalLink> =
        get<JikanList<JikanExternalLink>>(url("manga/$malId/external").build()).data

    private fun url(path: String): HttpUrl.Builder = baseUrl.newBuilder().addPathSegments(path)

    private suspend inline fun <reified T> get(url: HttpUrl): T {
        val body = throttled {
            try {
                client.getText(url)
            } catch (e: ApiException) {
                if (e.code != 429) throw e
                delay(1500) // rate limited: wait once and retry
                client.getText(url)
            }
        }
        return Http.json.decodeFromString<T>(body)
    }

    private suspend fun <R> throttled(block: suspend () -> R): R = gate.withLock {
        val wait = lastCall + minIntervalMs - System.currentTimeMillis()
        if (wait > 0) delay(wait)
        try {
            block()
        } finally {
            lastCall = System.currentTimeMillis()
        }
    }
}
