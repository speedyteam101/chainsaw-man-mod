package com.silkie.launcher.mascot

import kotlin.random.Random

/** Life stage of the mascot. With [MascotStage.AUTO] it grows the more you play. */
enum class MascotStage(val title: String) {
    AUTO("Grows as you play"),
    LARVA("Caterpillar"),
    COCOON("Cocoon"),
    MOTH("Moth"),
}

enum class Mood { HAPPY, EXCITED, SLEEPY, CURIOUS, PROUD }

enum class Chattiness(val title: String) {
    QUIET("Quiet: greetings only"),
    NORMAL("Normal"),
    CHATTY("Chatty"),
}

enum class MascotEvent {
    GREETING,
    TAP,
    LAUNCH_GAME,
    LAUNCH_APP,
    WELCOME_BACK,
    IDLE,
    FAVORITE_ADDED,
    SEARCH_EMPTY,
    LOW_BATTERY,
    CHARGING,
    EVOLVED,
}

data class MascotContext(
    val hour: Int,
    val name: String = "Silkie",
    val appLabel: String? = null,
    val todayPlayMs: Long = 0,
    val battery: Int = 100,
    val gameCount: Int = 0,
    val stage: MascotStage = MascotStage.MOTH,
    val sessionMs: Long = 0,
)

/**
 * Decides what the mascot says and how it feels. Pure Kotlin (no Android types) so it is unit-tested.
 */
class MascotBrain(private val random: Random = Random.Default) {

    fun isNight(hour: Int) = hour >= 23 || hour < 6

    fun mood(event: MascotEvent, hour: Int, sleepsAtNight: Boolean): Mood = when (event) {
        MascotEvent.LAUNCH_GAME, MascotEvent.TAP, MascotEvent.CHARGING, MascotEvent.WELCOME_BACK -> Mood.EXCITED
        MascotEvent.EVOLVED, MascotEvent.FAVORITE_ADDED -> Mood.PROUD
        MascotEvent.SEARCH_EMPTY -> Mood.CURIOUS
        else -> if (sleepsAtNight && isNight(hour)) Mood.SLEEPY else Mood.HAPPY
    }

    /** Whether to show a speech bubble for this event at the given chattiness. */
    fun shouldSpeak(event: MascotEvent, chattiness: Chattiness): Boolean = when (chattiness) {
        Chattiness.QUIET -> event == MascotEvent.GREETING || event == MascotEvent.TAP || event == MascotEvent.EVOLVED
        Chattiness.NORMAL -> event != MascotEvent.IDLE || random.nextInt(3) == 0
        Chattiness.CHATTY -> true
    }

    fun line(event: MascotEvent, ctx: MascotContext): String {
        val options = when (event) {
            MascotEvent.GREETING -> greeting(ctx.hour)
            MascotEvent.TAP -> TAP
            MascotEvent.LAUNCH_GAME -> LAUNCH_GAME
            MascotEvent.LAUNCH_APP -> LAUNCH_APP
            MascotEvent.WELCOME_BACK -> WELCOME_BACK
            MascotEvent.IDLE -> idle(ctx)
            MascotEvent.FAVORITE_ADDED -> FAVORITE
            MascotEvent.SEARCH_EMPTY -> SEARCH_EMPTY
            MascotEvent.LOW_BATTERY -> LOW_BATTERY
            MascotEvent.CHARGING -> CHARGING
            MascotEvent.EVOLVED -> evolved(ctx.stage)
        }
        return fill(options[random.nextInt(options.size)], ctx)
    }

    private fun greeting(hour: Int): List<String> = when (hour) {
        in 5..11 -> listOf("Good morning! Ready to play?", "Morning! I spun you a fresh home screen.", "Rise and shine! ☀")
        in 12..17 -> listOf("Good afternoon!", "Hey there! What are we playing?", "Afternoon! Pick something fun.")
        in 18..22 -> listOf("Good evening!", "Evening! One more game?", "The lamps are on. Perfect time to play.")
        else -> listOf("It's late… just one more?", "Zzz… oh! You're here.", "Night owl mode: on.")
    }

    private fun idle(ctx: MascotContext): List<String> {
        val lines = mutableListOf(
            "*flutters wings*",
            "I like it here.",
            "Press Y to make something a favorite!",
            "Tap me any time.",
            "Long-press an app for more options.",
        )
        if (ctx.todayPlayMs >= 60 * 60_000) lines += "You've played {today} today. Stretch break?"
        if (ctx.todayPlayMs in 1 until 60 * 60_000) lines += "{today} of play today. Nice!"
        if (ctx.gameCount > 0) lines += "You have {games} games. Pick one!"
        if (ctx.stage == MascotStage.LARVA) lines += "Play more and I'll grow… I think."
        if (ctx.stage == MascotStage.COCOON) lines += "Something's changing in here…"
        return lines
    }

    private fun evolved(stage: MascotStage): List<String> = when (stage) {
        MascotStage.COCOON -> listOf("I'm spinning a cocoon! See you soon…")
        MascotStage.MOTH -> listOf("Ta-da! I have wings now!")
        else -> listOf("I feel different!")
    }

    private fun fill(template: String, ctx: MascotContext): String = template
        .replace("{name}", ctx.name)
        .replace("{app}", ctx.appLabel ?: "that")
        .replace("{today}", formatShort(ctx.todayPlayMs))
        .replace("{games}", ctx.gameCount.toString())
        .replace("{battery}", ctx.battery.toString())
        .replace("{session}", formatShort(ctx.sessionMs))

    private fun formatShort(ms: Long): String {
        val m = ms / 60_000
        return if (m < 60) "${m}m" else "${m / 60}h ${m % 60}m"
    }

    companion object {
        /** Game playtime (or, without usage access, launches) needed to reach each stage. */
        const val COCOON_AT_MS = 2L * 60 * 60_000
        const val MOTH_AT_MS = 10L * 60 * 60_000
        const val COCOON_AT_LAUNCHES = 15
        const val MOTH_AT_LAUNCHES = 60

        fun stageFor(totalGameMs: Long, launches: Int): MascotStage = when {
            totalGameMs >= MOTH_AT_MS || launches >= MOTH_AT_LAUNCHES -> MascotStage.MOTH
            totalGameMs >= COCOON_AT_MS || launches >= COCOON_AT_LAUNCHES -> MascotStage.COCOON
            else -> MascotStage.LARVA
        }

        private val TAP = listOf("Hehe, that tickles!", "Hi hi!", "I'm {name}!", "*happy wiggle*", "Boop!", "♪ ♫")
        private val LAUNCH_GAME = listOf("Have fun in {app}!", "Go get 'em!", "{app}! Great pick.", "Good luck!", "I'll keep your seat warm.")
        private val LAUNCH_APP = listOf("Opening {app}…", "See you soon!", "On it!")
        private val WELCOME_BACK = listOf("Welcome back! {session} of {app}.", "You're back! How was {app}?", "{session} in {app}. Nice session!")
        private val FAVORITE = listOf("Added to favorites ★", "Ooh, a favorite!", "I'll keep {app} close.")
        private val SEARCH_EMPTY = listOf("Hmm, I can't find that.", "Nothing here… try another word?")
        private val LOW_BATTERY = listOf("Battery's at {battery}%. Snack time for your device?", "Low battery! Plug in soon.")
        private val CHARGING = listOf("Charging! Yum, electricity.", "Power up! ⚡")
    }
}
