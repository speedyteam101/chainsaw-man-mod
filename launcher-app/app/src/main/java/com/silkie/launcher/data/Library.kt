package com.silkie.launcher.data

import java.util.Locale

/** One launchable app as the library sees it. Plain data, so sorting and search are unit-testable. */
data class LibraryItem(
    val key: String,
    val packageName: String,
    val label: String,
    val isGame: Boolean,
    val favorite: Boolean = false,
    val hidden: Boolean = false,
    val collections: Set<String> = emptySet(),
    val installTime: Long = 0L,
    val lastUsed: Long = 0L,
    val playtimeMs: Long = 0L,
    val launchCount: Int = 0,
)

enum class SortOrder(val title: String) {
    NAME("Name"),
    MOST_PLAYED("Most played"),
    RECENT("Recently played"),
    NEWEST("Newest installed"),
}

/** What a library page shows. */
sealed class Shelf(val title: String) {
    data object All : Shelf("Apps")
    data object Games : Shelf("Games")
    data object Favorites : Shelf("Favorites")
    data object Recent : Shelf("Recent")
    class Collection(val name: String) : Shelf(name) {
        override fun equals(other: Any?) = other is Collection && other.name == name
        override fun hashCode() = name.hashCode()
    }
}

object Library {
    fun filter(items: List<LibraryItem>, shelf: Shelf, includeHidden: Boolean = false): List<LibraryItem> =
        items.filter { item ->
            (includeHidden || !item.hidden) && when (shelf) {
                Shelf.All -> true
                Shelf.Games -> item.isGame
                Shelf.Favorites -> item.favorite
                Shelf.Recent -> item.lastUsed > 0
                is Shelf.Collection -> shelf.name in item.collections
            }
        }

    fun sort(items: List<LibraryItem>, order: SortOrder): List<LibraryItem> {
        val byName = compareBy<LibraryItem, String>(String.CASE_INSENSITIVE_ORDER) { it.label }
        val cmp = when (order) {
            SortOrder.NAME -> byName
            SortOrder.MOST_PLAYED -> compareByDescending<LibraryItem> { it.playtimeMs }
                .thenByDescending { it.launchCount }
                .then(byName)
            SortOrder.RECENT -> compareByDescending<LibraryItem> { it.lastUsed }.then(byName)
            SortOrder.NEWEST -> compareByDescending<LibraryItem> { it.installTime }.then(byName)
        }
        return items.sortedWith(cmp)
    }

    /**
     * Fuzzy match score for search; 0 means no match. Prefix matches beat word-start matches,
     * which beat substring matches, which beat letters found in order ("mc" -> "Minecraft").
     */
    fun score(label: String, query: String): Int {
        val q = normalize(query)
        if (q.isEmpty()) return 1
        val l = normalize(label)
        if (l == q) return 1000
        if (l.startsWith(q)) return 800 - l.length
        val words = l.split(' ', '-', '_', '.', ':').filter { it.isNotEmpty() }
        if (words.any { it.startsWith(q) }) return 600 - l.length
        val initials = words.joinToString("") { it.take(1) }
        if (initials.startsWith(q)) return 500 - l.length
        if (l.contains(q)) return 400 - l.indexOf(q)
        var i = 0
        for (ch in l) {
            if (i < q.length && ch == q[i]) i++
        }
        return if (i == q.length && q.length >= 2) 100 - (l.length - q.length).coerceAtMost(99) else 0
    }

    fun search(items: List<LibraryItem>, query: String, limit: Int = 40): List<LibraryItem> {
        if (query.isBlank()) return emptyList()
        return items.asSequence()
            .filter { !it.hidden }
            .map { it to score(it.label, query) }
            .filter { it.second > 0 }
            .sortedWith(compareByDescending<Pair<LibraryItem, Int>> { it.second }.thenByDescending { it.first.launchCount })
            .take(limit)
            .map { it.first }
            .toList()
    }

    private fun normalize(s: String) = s.trim().lowercase(Locale.ROOT)

    /** "2h 05m", "12m", "<1m" — playtime for tiles and cards. */
    fun formatPlaytime(ms: Long): String {
        val minutes = ms / 60_000
        return when {
            minutes < 1 -> "<1m"
            minutes < 60 -> "${minutes}m"
            else -> "%dh %02dm".format(Locale.ROOT, minutes / 60, minutes % 60)
        }
    }

    /** "just now", "5 min ago", "3 h ago", "yesterday", "4 days ago". */
    fun formatAgo(then: Long, now: Long): String {
        if (then <= 0) return "never"
        val minutes = (now - then).coerceAtLeast(0) / 60_000
        return when {
            minutes < 1 -> "just now"
            minutes < 60 -> "$minutes min ago"
            minutes < 24 * 60 -> "${minutes / 60} h ago"
            minutes < 48 * 60 -> "yesterday"
            else -> "${minutes / (24 * 60)} days ago"
        }
    }
}
