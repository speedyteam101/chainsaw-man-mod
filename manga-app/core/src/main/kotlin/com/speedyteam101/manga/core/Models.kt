package com.speedyteam101.manga.core

/** A title from the MyAnimeList catalog (via Jikan). Metadata only. */
data class CatalogItem(
    val malId: Int,
    val title: String,
    val titleEnglish: String?,
    val coverUrl: String?,
    val synopsis: String?,
    val genres: List<String>,
    val authors: List<String>,
    val type: String?,
    val status: String?,
    val chapters: Int?,
    val score: Double?,
    val url: String?,
)

data class CatalogPage(val items: List<CatalogItem>, val hasMore: Boolean)

data class ExternalLink(val name: String, val url: String)

/** A readable title on MangaDex. */
data class MdTitle(
    val id: String,
    val title: String,
    val coverUrl: String?,
    val description: String?,
    val tags: List<String>,
    val authors: List<String>,
    val status: String?,
    val year: Int?,
    val malId: Int?,
)

data class MdPage(val items: List<MdTitle>, val nextOffset: Int?)

data class ChapterItem(
    val id: String,
    val volume: String?,
    val chapter: String?,
    val title: String?,
    val pages: Int,
    val group: String?,
    /** Set for chapters hosted by an official publisher; open these in a browser. */
    val externalUrl: String?,
) {
    val label: String
        get() = buildString {
            if (!volume.isNullOrBlank()) append("Vol. ").append(volume).append(' ')
            append(if (chapter.isNullOrBlank()) "Oneshot" else "Ch. $chapter")
            if (!title.isNullOrBlank()) append(" – ").append(title)
        }
}
