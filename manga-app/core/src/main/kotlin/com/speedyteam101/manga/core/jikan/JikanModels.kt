package com.speedyteam101.manga.core.jikan

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Field names follow the Jikan v4 OpenAPI spec (jikan-me/jikan-rest, storage/api-docs/api-docs.json).

@Serializable
data class JikanList<T>(
    val data: List<T> = emptyList(),
    val pagination: JikanPagination? = null,
)

@Serializable
data class JikanSingle<T>(val data: T)

@Serializable
data class JikanPagination(
    @SerialName("has_next_page") val hasNextPage: Boolean = false,
    @SerialName("last_visible_page") val lastVisiblePage: Int? = null,
)

@Serializable
data class JikanManga(
    @SerialName("mal_id") val malId: Int,
    val url: String? = null,
    val images: JikanImages? = null,
    val title: String = "",
    @SerialName("title_english") val titleEnglish: String? = null,
    val type: String? = null,
    val chapters: Int? = null,
    val status: String? = null,
    val score: Double? = null,
    val synopsis: String? = null,
    val authors: List<JikanNamed> = emptyList(),
    val genres: List<JikanNamed> = emptyList(),
    @SerialName("explicit_genres") val explicitGenres: List<JikanNamed> = emptyList(),
    val themes: List<JikanNamed> = emptyList(),
    val demographics: List<JikanNamed> = emptyList(),
) {
    val allGenreNames: List<String>
        get() = (genres + explicitGenres + themes + demographics).map { it.name }
}

@Serializable
data class JikanImages(val jpg: JikanImageSet? = null)

@Serializable
data class JikanImageSet(
    @SerialName("image_url") val imageUrl: String? = null,
    @SerialName("large_image_url") val largeImageUrl: String? = null,
)

@Serializable
data class JikanNamed(
    @SerialName("mal_id") val malId: Int = 0,
    val name: String = "",
)

@Serializable
data class JikanGenre(
    @SerialName("mal_id") val malId: Int,
    val name: String,
)

@Serializable
data class JikanExternalLink(val name: String = "", val url: String = "")
