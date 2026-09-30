package com.speedyteam101.manga.core

/**
 * Decides what counts as "romance". Both sources use slightly different
 * spellings (MyAnimeList: "Boys Love", MangaDex: "Boys' Love"), so names are
 * normalized before comparing.
 */
object RomanceFilter {
    /** Normalized genre/tag names that are hidden everywhere in the app. */
    val EXCLUDED_NAMES: Set<String> = setOf("romance", "boys love", "girls love")

    fun normalize(name: String): String =
        name.lowercase()
            .replace("'", "")
            .replace("’", "")
            .replace(Regex("\\s+"), " ")
            .trim()

    fun isRomance(name: String): Boolean = normalize(name) in EXCLUDED_NAMES

    fun anyRomance(names: Iterable<String>): Boolean = names.any(::isRomance)
}
