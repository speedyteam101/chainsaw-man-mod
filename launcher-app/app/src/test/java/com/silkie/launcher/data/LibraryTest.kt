package com.silkie.launcher.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LibraryTest {
    private fun item(label: String, game: Boolean = false, fav: Boolean = false, hidden: Boolean = false, playtime: Long = 0, last: Long = 0, installed: Long = 0, launches: Int = 0, cols: Set<String> = emptySet()) =
        LibraryItem(label.lowercase(), "pkg.$label", label, game, fav, hidden, cols, installed, last, playtime, launches)

    private val items = listOf(
        item("Minecraft", game = true, playtime = 5_000, last = 30, installed = 1),
        item("Stardew Valley", game = true, fav = true, playtime = 9_000, last = 10, installed = 3),
        item("Calculator", installed = 2),
        item("Secret Diary", hidden = true),
        item("RetroArch", game = true, cols = setOf("Retro"), launches = 4),
    )

    @Test
    fun filtersByShelf() {
        assertEquals(listOf("Minecraft", "Stardew Valley", "RetroArch"), Library.filter(items, Shelf.Games).map { it.label })
        assertEquals(listOf("Stardew Valley"), Library.filter(items, Shelf.Favorites).map { it.label })
        assertEquals(listOf("RetroArch"), Library.filter(items, Shelf.Collection("Retro")).map { it.label })
        assertEquals(listOf("Minecraft", "Stardew Valley"), Library.filter(items, Shelf.Recent).map { it.label })
        assertEquals(4, Library.filter(items, Shelf.All).size)
        assertEquals(5, Library.filter(items, Shelf.All, includeHidden = true).size)
    }

    @Test
    fun sortsEachWay() {
        assertEquals("Calculator", Library.sort(items, SortOrder.NAME).first().label)
        assertEquals("Stardew Valley", Library.sort(items, SortOrder.MOST_PLAYED).first().label)
        assertEquals("Minecraft", Library.sort(items, SortOrder.RECENT).first().label)
        assertEquals("Stardew Valley", Library.sort(items, SortOrder.NEWEST).first().label)
        // Ties in playtime fall back to launch count, then name.
        assertEquals("RetroArch", Library.sort(items, SortOrder.MOST_PLAYED)[2].label)
    }

    @Test
    fun scoresPrefixAboveWordAboveFuzzy() {
        val prefix = Library.score("Minecraft", "mine")
        val word = Library.score("Stardew Valley", "val")
        val initials = Library.score("Stardew Valley", "sv")
        val inside = Library.score("Minecraft", "craft")
        val fuzzy = Library.score("Minecraft", "mcft")
        assertTrue(prefix > word)
        assertTrue(word > initials)
        assertTrue(initials > inside)
        assertTrue(inside > fuzzy)
        assertTrue(fuzzy > 0)
        assertEquals(0, Library.score("Minecraft", "zelda"))
        assertEquals(1000, Library.score("Minecraft", " MINECRAFT "))
    }

    @Test
    fun searchSkipsHiddenAndBlank() {
        assertTrue(Library.search(items, "secret").isEmpty())
        assertTrue(Library.search(items, "   ").isEmpty())
        assertEquals("Stardew Valley", Library.search(items, "stardew").first().label)
    }

    @Test
    fun formatsTimes() {
        assertEquals("<1m", Library.formatPlaytime(30_000))
        assertEquals("12m", Library.formatPlaytime(12 * 60_000))
        assertEquals("2h 05m", Library.formatPlaytime(125 * 60_000L))
        assertEquals("never", Library.formatAgo(0, 1000))
        assertEquals("just now", Library.formatAgo(1000, 20_000))
        assertEquals("5 min ago", Library.formatAgo(0 + 1, 5 * 60_000L + 1))
        assertEquals("yesterday", Library.formatAgo(1, 30 * 3_600_000L))
        assertEquals("3 days ago", Library.formatAgo(1, 3 * 24 * 3_600_000L + 1))
    }
}
