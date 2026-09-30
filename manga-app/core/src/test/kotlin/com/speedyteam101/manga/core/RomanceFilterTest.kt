package com.speedyteam101.manga.core

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class RomanceFilterTest {
    @Test
    fun matchesBothSourcesSpellings() {
        assertTrue(RomanceFilter.isRomance("Romance"))
        assertTrue(RomanceFilter.isRomance("Boys Love"))      // MyAnimeList
        assertTrue(RomanceFilter.isRomance("Boys' Love"))     // MangaDex
        assertTrue(RomanceFilter.isRomance("Girls’ Love"))
        assertTrue(RomanceFilter.isRomance("  girls   love "))
    }

    @Test
    fun keepsOtherGenres() {
        assertFalse(RomanceFilter.isRomance("Action"))
        assertFalse(RomanceFilter.isRomance("Romantic Subtext"))
        assertFalse(RomanceFilter.anyRomance(listOf("Action", "Horror", "Shounen")))
        assertTrue(RomanceFilter.anyRomance(listOf("Action", "Romance")))
    }
}
