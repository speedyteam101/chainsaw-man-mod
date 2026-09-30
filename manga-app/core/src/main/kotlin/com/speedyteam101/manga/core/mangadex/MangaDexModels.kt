package com.speedyteam101.manga.core.mangadex

import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.JsonTransformingSerializer

// Shapes follow the MangaDex API as modelled by the Hondana client (types_/manga.py, chapter.py, tags.py).

@Serializable
data class MdList<T>(
    val data: List<T> = emptyList(),
    val limit: Int = 0,
    val offset: Int = 0,
    val total: Int = 0,
)

@Serializable
data class MdSingle<T>(val data: T)

@Serializable
data class MdEntity<A>(
    val id: String,
    val type: String = "",
    val attributes: A? = null,
    val relationships: List<MdRelationship> = emptyList(),
)

@Serializable
data class MdRelationship(
    val id: String,
    val type: String,
    val attributes: MdRelationshipAttributes? = null,
)

/** Union of the few fields used from expanded relationships (cover_art, author, scanlation_group). */
@Serializable
data class MdRelationshipAttributes(
    val fileName: String? = null,
    val name: String? = null,
)

@Serializable
data class MdMangaAttributes(
    @Serializable(with = LocalizedString::class) val title: Map<String, String> = emptyMap(),
    val altTitles: List<@Serializable(with = LocalizedString::class) Map<String, String>> = emptyList(),
    @Serializable(with = LocalizedString::class) val description: Map<String, String> = emptyMap(),
    @Serializable(with = LocalizedString::class) val links: Map<String, String> = emptyMap(),
    val status: String? = null,
    val year: Int? = null,
    val contentRating: String? = null,
    val tags: List<MdEntity<MdTagAttributes>> = emptyList(),
)

@Serializable
data class MdTagAttributes(
    @Serializable(with = LocalizedString::class) val name: Map<String, String> = emptyMap(),
    val group: String? = null,
)

@Serializable
data class MdChapterAttributes(
    val title: String? = null,
    val volume: String? = null,
    val chapter: String? = null,
    val pages: Int = 0,
    val translatedLanguage: String? = null,
    val externalUrl: String? = null,
)

@Serializable
data class MdAtHome(val baseUrl: String, val chapter: MdAtHomeChapter)

@Serializable
data class MdAtHomeChapter(
    val hash: String,
    val data: List<String> = emptyList(),
    val dataSaver: List<String> = emptyList(),
)

/**
 * MangaDex serializes an empty localized string (or links map) as `[]` or `null`
 * instead of `{}`; treat anything that isn't an object as empty.
 */
object LocalizedString : JsonTransformingSerializer<Map<String, String>>(
    MapSerializer(String.serializer(), String.serializer()),
) {
    override fun transformDeserialize(element: JsonElement): JsonElement =
        if (element is JsonObject) {
            JsonObject(element.filterValues { it is JsonPrimitive && it.isString })
        } else {
            JsonObject(emptyMap())
        }
}
