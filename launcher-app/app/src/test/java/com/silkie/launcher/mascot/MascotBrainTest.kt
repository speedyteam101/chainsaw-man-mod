package com.silkie.launcher.mascot

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

class MascotBrainTest {
    private val brain = MascotBrain(Random(1))

    @Test
    fun linesHaveNoLeftoverPlaceholders() {
        val ctx = MascotContext(hour = 14, name = "Mothy", appLabel = "Tetris", todayPlayMs = 90 * 60_000L, battery = 9, gameCount = 3, sessionMs = 25 * 60_000L)
        for (event in MascotEvent.entries) {
            repeat(30) {
                val line = brain.line(event, ctx)
                assertTrue(line.isNotBlank())
                assertFalse("unfilled placeholder in \"$line\"", line.contains('{') || line.contains('}'))
            }
        }
    }

    @Test
    fun greetingDependsOnTimeOfDay() {
        repeat(10) {
            val night = brain.line(MascotEvent.GREETING, MascotContext(hour = 2))
            assertFalse(night.startsWith("Good morning"))
        }
    }

    @Test
    fun sleepsAtNightOnlyWhenAllowed() {
        assertEquals(Mood.SLEEPY, brain.mood(MascotEvent.IDLE, 3, sleepsAtNight = true))
        assertEquals(Mood.HAPPY, brain.mood(MascotEvent.IDLE, 3, sleepsAtNight = false))
        assertEquals(Mood.HAPPY, brain.mood(MascotEvent.IDLE, 15, sleepsAtNight = true))
        assertEquals(Mood.EXCITED, brain.mood(MascotEvent.LAUNCH_GAME, 3, sleepsAtNight = true))
    }

    @Test
    fun quietMascotOnlyGreets() {
        assertTrue(brain.shouldSpeak(MascotEvent.GREETING, Chattiness.QUIET))
        assertFalse(brain.shouldSpeak(MascotEvent.IDLE, Chattiness.QUIET))
        assertFalse(brain.shouldSpeak(MascotEvent.LAUNCH_GAME, Chattiness.QUIET))
        assertTrue(brain.shouldSpeak(MascotEvent.IDLE, Chattiness.CHATTY))
        assertTrue(brain.shouldSpeak(MascotEvent.LAUNCH_GAME, Chattiness.NORMAL))
    }

    @Test
    fun growsWithPlaytimeOrLaunches() {
        assertEquals(MascotStage.LARVA, MascotBrain.stageFor(0, 0))
        assertEquals(MascotStage.COCOON, MascotBrain.stageFor(MascotBrain.COCOON_AT_MS, 0))
        assertEquals(MascotStage.COCOON, MascotBrain.stageFor(0, MascotBrain.COCOON_AT_LAUNCHES))
        assertEquals(MascotStage.MOTH, MascotBrain.stageFor(MascotBrain.MOTH_AT_MS, 0))
        assertEquals(MascotStage.MOTH, MascotBrain.stageFor(0, MascotBrain.MOTH_AT_LAUNCHES))
    }
}
