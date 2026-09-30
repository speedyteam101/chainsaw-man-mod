package com.speedyteam101.manga.core

import com.speedyteam101.manga.core.jikan.JikanApi
import com.speedyteam101.manga.core.jikan.JikanManga
import com.speedyteam101.manga.core.mangadex.MangaDexApi
import com.speedyteam101.manga.core.mangadex.MdEntity
import com.speedyteam101.manga.core.mangadex.MdMangaAttributes
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Combines the two sources:
 *  - Jikan (MyAnimeList) for a near-complete catalog to browse (metadata only),
 *  - MangaDex for titles that can actually be read in the app.
 *
 * Romance is removed twice: the IDs of romance genres/tags are sent to each API as
 * exclusions, and every result is checked again on the client with [RomanceFilter].
 */
class MangaRepository(
    private val jikan: JikanApi,
    private val mangaDex: MangaDexApi,
) {
    private val jikanExcluded = Cached {
        jikan.mangaGenres().filter { RomanceFilter.isRomance(it.name) }.map { it.malId }.toSet()
    }
    private val mdExcluded = Cached {
        mangaDex.tags()
            .filter { tag -> tag.attributes?.name?.values?.any(RomanceFilter::isRomance) == true }
            .map { it.id }
            .toSet()
    }
    private val chapterCache = mutableMapOf<String, List<ChapterItem>>()
    private val chapterLock = Mutex()

    // ---- Catalog (Jikan / MyAnimeList) ----

    suspend fun discover(query: String?, page: Int): CatalogPage {
        val result = jikan.searchManga(query, page, jikanExcluded.get())
        val items = result.data
            .filterNot { RomanceFilter.anyRomance(it.allGenreNames) }
            .distinctBy { it.malId }
            .map { it.toCatalogItem() }
        return CatalogPage(items, result.pagination?.hasNextPage == true)
    }

    /** Returns null when the title turns out to be romance. */
    suspend fun catalogItem(malId: Int): CatalogItem? {
        val manga = jikan.manga(malId)
        return if (RomanceFilter.anyRomance(manga.allGenreNames)) null else manga.toCatalogItem()
    }

    suspend fun officialLinks(malId: Int): List<ExternalLink> =
        jikan.externalLinks(malId)
            .filter { it.url.startsWith("http") }
            .distinctBy { it.url }
            .map { ExternalLink(it.name.ifBlank { it.url }, it.url) }

    /**
     * Finds the MangaDex entry for a MyAnimeList title. Only accepts an entry whose
     * MangaDex "mal" link equals [CatalogItem.malId], so a same-named but different
     * series is never picked.
     */
    suspend fun findOnMangaDex(item: CatalogItem): MdTitle? {
        val excluded = mdExcluded.get()
        val queries = listOfNotNull(item.title, item.titleEnglish).distinct()
        for (query in queries) {
            val hit = mangaDex.searchManga(query, offset = 0, excludedTagIds = excluded, limit = 20).data
                .firstOrNull { it.attributes?.links?.get("mal")?.trim() == item.malId.toString() }
            if (hit != null) return hit.toMdTitle().takeUnless { RomanceFilter.anyRomance(it.tags) }
        }
        return null
    }

    // ---- Reading (MangaDex) ----

    suspend fun browseMangaDex(query: String?, offset: Int): MdPage {
        val result = mangaDex.searchManga(query, offset, mdExcluded.get())
        val items = result.data.map { it.toMdTitle() }.filterNot { RomanceFilter.anyRomance(it.tags) }
        val next = result.offset + result.data.size
        return MdPage(items, next.takeIf { result.data.isNotEmpty() && it < result.total })
    }

    /** Returns null when the title turns out to be romance. */
    suspend fun mangaDexTitle(id: String): MdTitle? =
        mangaDex.manga(id).toMdTitle().takeUnless { RomanceFilter.anyRomance(it.tags) }

    suspend fun chapters(mangaId: String, refresh: Boolean = false): List<ChapterItem> = chapterLock.withLock {
        if (!refresh) chapterCache[mangaId]?.let { return it }
        val all = mutableListOf<ChapterItem>()
        var offset = 0
        var requests = 0
        while (requests < MAX_FEED_REQUESTS) {
            if (requests > 0) delay(250) // stay well under MangaDex's rate limit
            val page = mangaDex.feed(mangaId, offset)
            requests++
            page.data.mapTo(all) { chapter ->
                val attrs = chapter.attributes
                ChapterItem(
                    id = chapter.id,
                    volume = attrs?.volume,
                    chapter = attrs?.chapter,
                    title = attrs?.title,
                    pages = attrs?.pages ?: 0,
                    group = chapter.relationships.firstOrNull { it.type == "scanlation_group" }?.attributes?.name,
                    externalUrl = attrs?.externalUrl,
                )
            }
            offset = page.offset + page.data.size
            if (page.data.isEmpty() || offset >= page.total) break
        }
        chapterCache[mangaId] = all
        all
    }

    suspend fun pageUrls(chapterId: String, dataSaver: Boolean = false): List<String> {
        val server = mangaDex.atHome(chapterId)
        val quality = if (dataSaver) "data-saver" else "data"
        val files = if (dataSaver) server.chapter.dataSaver else server.chapter.data
        return files.map { "${server.baseUrl.trimEnd('/')}/$quality/${server.chapter.hash}/$it" }
    }

    private class Cached<T : Any>(private val load: suspend () -> T) {
        private val lock = Mutex()
        private var value: T? = null
        suspend fun get(): T = lock.withLock { value ?: load().also { value = it } }
    }

    companion object {
        private const val MAX_FEED_REQUESTS = 40
    }
}

internal fun JikanManga.toCatalogItem() = CatalogItem(
    malId = malId,
    title = title,
    titleEnglish = titleEnglish?.takeIf { it.isNotBlank() && it != title },
    coverUrl = images?.jpg?.largeImageUrl ?: images?.jpg?.imageUrl,
    synopsis = synopsis,
    genres = allGenreNames,
    authors = authors.map { it.name },
    type = type,
    status = status,
    chapters = chapters,
    score = score,
    url = url,
)

internal fun MdEntity<MdMangaAttributes>.toMdTitle(): MdTitle {
    val attrs = attributes
    val title = attrs?.title?.let { it["en"] ?: it.values.firstOrNull() }
        ?: attrs?.altTitles?.firstNotNullOfOrNull { it["en"] }
        ?: "Untitled"
    val cover = relationships.firstOrNull { it.type == "cover_art" }?.attributes?.fileName
    return MdTitle(
        id = id,
        title = title,
        coverUrl = cover?.let { MangaDexApi.coverUrl(id, it) },
        description = attrs?.description?.let { it["en"] ?: it.values.firstOrNull() },
        tags = attrs?.tags.orEmpty().mapNotNull { tag -> tag.attributes?.name?.let { it["en"] ?: it.values.firstOrNull() } },
        authors = relationships.filter { it.type == "author" }.mapNotNull { it.attributes?.name }.distinct(),
        status = attrs?.status,
        year = attrs?.year,
        malId = attrs?.links?.get("mal")?.trim()?.toIntOrNull(),
    )
}
