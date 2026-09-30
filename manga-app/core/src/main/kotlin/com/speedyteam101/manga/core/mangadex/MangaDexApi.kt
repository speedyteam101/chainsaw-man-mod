package com.speedyteam101.manga.core.mangadex

import com.speedyteam101.manga.core.net.Http
import com.speedyteam101.manga.core.net.getText
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient

/** Minimal client for the public MangaDex API (https://api.mangadex.org). */
class MangaDexApi(
    private val client: OkHttpClient,
    private val baseUrl: HttpUrl = "https://api.mangadex.org/".toHttpUrl(),
) {
    suspend fun tags(): List<MdEntity<MdTagAttributes>> =
        get<MdList<MdEntity<MdTagAttributes>>>(url("manga/tag").build()).data

    suspend fun searchManga(
        title: String?,
        offset: Int,
        excludedTagIds: Collection<String>,
        language: String = LANGUAGE,
        limit: Int = 24,
    ): MdList<MdEntity<MdMangaAttributes>> {
        val url = url("manga")
            .addQueryParameter("limit", limit.toString())
            .addQueryParameter("offset", offset.toString())
            .addQueryParameter("includes[]", "cover_art")
            .addQueryParameter("includes[]", "author")
            .addQueryParameter("availableTranslatedLanguage[]", language)
            .addQueryParameter("hasAvailableChapters", "true")
        SAFE_RATINGS.forEach { url.addQueryParameter("contentRating[]", it) }
        excludedTagIds.forEach { url.addQueryParameter("excludedTags[]", it) }
        if (excludedTagIds.isNotEmpty()) url.addQueryParameter("excludedTagsMode", "OR")
        if (title.isNullOrBlank()) {
            url.addQueryParameter("order[followedCount]", "desc")
        } else {
            url.addQueryParameter("title", title.trim())
            url.addQueryParameter("order[relevance]", "desc")
        }
        return get(url.build())
    }

    suspend fun manga(id: String): MdEntity<MdMangaAttributes> {
        val url = url("manga/$id")
            .addQueryParameter("includes[]", "cover_art")
            .addQueryParameter("includes[]", "author")
            .build()
        return get<MdSingle<MdEntity<MdMangaAttributes>>>(url).data
    }

    suspend fun feed(
        mangaId: String,
        offset: Int,
        language: String = LANGUAGE,
        limit: Int = 100,
    ): MdList<MdEntity<MdChapterAttributes>> {
        val url = url("manga/$mangaId/feed")
            .addQueryParameter("limit", limit.toString())
            .addQueryParameter("offset", offset.toString())
            .addQueryParameter("translatedLanguage[]", language)
            .addQueryParameter("order[volume]", "asc")
            .addQueryParameter("order[chapter]", "asc")
            .addQueryParameter("includes[]", "scanlation_group")
            .build()
        return get(url)
    }

    /** Page image URLs are `baseUrl/data/hash/file`; the baseUrl is only valid for ~15 minutes. */
    suspend fun atHome(chapterId: String): MdAtHome = get(url("at-home/server/$chapterId").build())

    private fun url(path: String): HttpUrl.Builder = baseUrl.newBuilder().addPathSegments(path)

    private suspend inline fun <reified T> get(url: HttpUrl): T =
        Http.json.decodeFromString<T>(client.getText(url))

    companion object {
        const val LANGUAGE = "en"
        val SAFE_RATINGS = listOf("safe", "suggestive")

        fun coverUrl(mangaId: String, fileName: String): String =
            "https://uploads.mangadex.org/covers/$mangaId/$fileName.256.jpg"
    }
}
