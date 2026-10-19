package com.silkie.launcher.settings

import android.app.Activity
import android.app.role.RoleManager
import android.content.Intent
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowInsets
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast
import com.silkie.launcher.app
import com.silkie.launcher.data.Library
import com.silkie.launcher.data.SortOrder
import com.silkie.launcher.mascot.Chattiness
import com.silkie.launcher.mascot.MascotBrain
import com.silkie.launcher.mascot.MascotContext
import com.silkie.launcher.mascot.MascotEvent
import com.silkie.launcher.mascot.MascotLook
import com.silkie.launcher.mascot.MascotStage
import com.silkie.launcher.mascot.MascotView
import com.silkie.launcher.ui.ColorMath
import com.silkie.launcher.ui.ColorPicker
import com.silkie.launcher.ui.Glyph
import com.silkie.launcher.ui.GlyphDrawable
import com.silkie.launcher.ui.MATCH
import com.silkie.launcher.ui.Palette
import com.silkie.launcher.ui.SpeechBubble
import com.silkie.launcher.ui.WRAP
import com.silkie.launcher.ui.cardBackground
import com.silkie.launcher.ui.dialog
import com.silkie.launcher.ui.dp
import com.silkie.launcher.ui.focusHighlight
import com.silkie.launcher.ui.glyphButton
import com.silkie.launcher.ui.label
import com.silkie.launcher.ui.lp
import com.silkie.launcher.ui.rippleOver
import com.silkie.launcher.ui.rounded
import org.json.JSONObject
import java.util.Calendar
import kotlin.reflect.KMutableProperty0

/** All of Silkie's options, grouped into sections. Changes save immediately. */
class SettingsActivity : Activity() {
    private val prefs get() = app.prefs
    private lateinit var pal: Palette
    private lateinit var root: LinearLayout
    private lateinit var title: TextView
    private lateinit var scroll: ScrollView
    private lateinit var body: LinearLayout
    private var section: Section? = null
    private var preview: MascotView? = null
    private var previewBubble: SpeechBubble? = null
    private val brain = MascotBrain()

    private enum class Section(val title: String, val subtitle: String, val glyph: Glyph) {
        THEME("Theme", "Presets, colors, cards and fonts", Glyph.STAR),
        BACKGROUND("Background", "Gradient, patterns, picture, ambient effects", Glyph.WIDGET),
        LAYOUT("Library layout", "Grid, list or carousel, columns, tabs, sorting", Glyph.GRID),
        ICONS("Icons", "Shape, size, themed icons, labels", Glyph.APPS),
        HOME("Home tab", "Hero card, shelves, widgets, stats", Glyph.HOME),
        CLOCK("Clock and status bar", "Clock style, date, battery, hints", Glyph.CLOCK),
        MASCOT("Mascot", "Looks, outfit, personality", Glyph.STAR_FILLED),
        CONTROLS("Controls and motion", "Controller buttons, sounds, animations", Glyph.GAMEPAD),
        GESTURES("Gestures", "Swipes, double tap, long press", Glyph.CAROUSEL),
        LIBRARY("Library and playtime", "Hidden apps, collections, usage access", Glyph.LIST),
        BACKUP("Backup and reset", "Save or restore all settings", Glyph.SORT),
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(8), dp(8), dp(16), dp(8))
        }
        title = TextView(this)
        header.tag = "header"
        root.addView(header, lp(MATCH, WRAP))
        scroll = ScrollView(this).apply { isVerticalScrollBarEnabled = false; clipToPadding = false }
        body = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(4), dp(16), dp(32))
        }
        scroll.addView(body)
        root.addView(scroll, lp(MATCH, 0, 1f))
        root.setOnApplyWindowInsetsListener { v, insets ->
            val r = insets(insets)
            v.setPadding(r.left, r.top, r.right, r.bottom)
            insets
        }
        if (Build.VERSION.SDK_INT >= 30) window.setDecorFitsSystemWindows(false)
        setContentView(root)
        section = savedInstanceState?.getString("section")?.let { s -> Section.entries.firstOrNull { it.name == s } }
        render()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        section?.let { outState.putString("section", it.name) }
    }

    override fun onResume() {
        super.onResume()
        // Usage access and default-launcher status may have changed in system settings.
        if (section == Section.LIBRARY || section == null) render(keepScroll = true)
    }

    @Suppress("DEPRECATION")
    private fun insets(insets: WindowInsets): Rect =
        if (Build.VERSION.SDK_INT >= 30) {
            val i = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout() or WindowInsets.Type.ime())
            Rect(i.left, i.top, i.right, i.bottom)
        } else {
            Rect(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
        }

    // --- Rendering -----------------------------------------------------------------------------

    private fun render(keepScroll: Boolean = false) {
        val y = scroll.scrollY
        pal = Palette(prefs)
        window.setBackgroundDrawable(ColorDrawable(pal.bg))
        root.background = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(pal.bg, pal.bg2))
        @Suppress("DEPRECATION")
        if (Build.VERSION.SDK_INT >= 30) {
            val mask = android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
            window.insetsController?.setSystemBarsAppearance(if (pal.isLight) mask else 0, mask)
        } else {
            root.systemUiVisibility = if (pal.isLight) View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR else 0
        }

        val header = root.findViewWithTag<LinearLayout>("header")
        header.removeAllViews()
        if (section != null) header.addView(glyphButton(pal, Glyph.CHEVRON, "Back") { goBack() }.apply { rotation = 180f })
        title.apply {
            text = section?.title ?: "Silkie settings"
            setTextColor(pal.text)
            typeface = pal.typefaceBold
            textSize = 24f * pal.fontScale
        }
        header.addView(title, lp(0, WRAP, 1f).apply { leftMargin = dp(if (section == null) 8 else 4) })

        body.removeAllViews()
        preview = null
        previewBubble = null
        when (section) {
            null -> renderIndex()
            Section.THEME -> renderTheme()
            Section.BACKGROUND -> renderBackground()
            Section.LAYOUT -> renderLayout()
            Section.ICONS -> renderIcons()
            Section.HOME -> renderHome()
            Section.CLOCK -> renderClock()
            Section.MASCOT -> renderMascot()
            Section.CONTROLS -> renderControls()
            Section.GESTURES -> renderGestures()
            Section.LIBRARY -> renderLibrary()
            Section.BACKUP -> renderBackup()
        }
        scroll.post { scroll.scrollTo(0, if (keepScroll) y else 0) }
    }

    private fun open(s: Section?) {
        section = s
        render()
        body.getChildAt(0)?.let { first -> body.post { firstFocusable(first)?.requestFocus() } }
    }

    private fun firstFocusable(v: View): View? {
        if (v.isFocusable) return v
        if (v is android.view.ViewGroup) for (i in 0 until v.childCount) firstFocusable(v.getChildAt(i))?.let { return it }
        return null
    }

    private fun goBack() {
        if (section != null) open(null) else finish()
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val cancel = if (prefs.swapAB) KeyEvent.KEYCODE_BUTTON_A else KeyEvent.KEYCODE_BUTTON_B
        val confirm = if (prefs.swapAB) KeyEvent.KEYCODE_BUTTON_B else KeyEvent.KEYCODE_BUTTON_A
        if (event.keyCode == cancel || event.keyCode == KeyEvent.KEYCODE_BACK) {
            if (event.action == KeyEvent.ACTION_UP && !event.isCanceled) goBack()
            return true
        }
        if (event.keyCode == confirm) {
            if (event.action == KeyEvent.ACTION_UP) currentFocus?.performClick()
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    // --- Sections ------------------------------------------------------------------------------

    private fun renderIndex() {
        if (!isDefaultHome()) {
            val banner = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(16), dp(14), dp(16), dp(14))
                background = rippleOver(pal.ripple, dp(pal.corner), rounded(pal.accent, dp(pal.corner)))
                isFocusable = true
                isClickable = true
                setOnClickListener { requestDefaultHome() }
            }
            banner.addView(label(pal, "Make Silkie your home screen", 16f, pal.onAccent, bold = true))
            banner.addView(label(pal, "So the home button brings you here.", 13f, ColorMath.withAlpha(pal.onAccent, 0.8f)), lp(WRAP, WRAP).apply { topMargin = dp(3) })
            banner.focusHighlight(pal, 1.02f)
            body.addView(banner, lp(MATCH, WRAP).apply { bottomMargin = dp(12) })
        }
        for (s in Section.entries) {
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(14), dp(14), dp(14), dp(14))
                background = cardBackground(pal)
                isFocusable = true
                isClickable = true
                setOnClickListener { open(s) }
            }
            row.addView(View(this).apply { background = GlyphDrawable(s.glyph, pal.accent) }, lp(dp(24), dp(24)))
            val texts = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
            texts.addView(label(pal, s.title, 16f, pal.text, bold = true))
            texts.addView(label(pal, s.subtitle, 13f, pal.textDim), lp(WRAP, WRAP).apply { topMargin = dp(3) })
            row.addView(texts, lp(0, WRAP, 1f).apply { leftMargin = dp(14) })
            row.addView(View(this).apply { background = GlyphDrawable(Glyph.CHEVRON, pal.textDim) }, lp(dp(18), dp(18)))
            row.focusHighlight(pal, 1.02f)
            body.addView(row, lp(MATCH, WRAP).apply { bottomMargin = dp(8) })
        }
    }

    private fun renderTheme() {
        header("Presets")
        val perRow = if (resources.configuration.screenWidthDp >= 600) 4 else 2
        Presets.all.chunked(perRow).forEach { chunk ->
            val r = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
            for (i in 0 until perRow) {
                val p = chunk.getOrNull(i)
                if (p == null) {
                    r.addView(View(this), lp(0, 1, 1f))
                    continue
                }
                r.addView(presetCard(p), lp(0, dp(84), 1f).apply { setMargins(dp(4), dp(4), dp(4), dp(4)) })
            }
            body.addView(r, lp(MATCH, WRAP))
        }
        header("Colors")
        colorRow("Background", prefs::bgColor)
        colorRow("Background (second color)", prefs::bgColor2)
        colorRow("Cards", prefs::cardColor)
        colorRow("Text", prefs::textColor)
        colorRow("Accent", prefs::accentColor)
        header("Shapes and type")
        choiceRow("Card style", prefs::cardStyle, CardStyle.entries) { it.title }
        sliderRow("Corner roundness", prefs::cornerRadius, 0, 32) { "${it}dp" }
        choiceRow("Font", prefs::font, FontChoice.entries, restyle = true) { it.title }
        sliderRow("Text size", prefs::fontScale, 80, 140, step = 5, restyle = true) { "$it%" }
    }

    private fun presetCard(p: ThemePreset): View {
        val selected = prefs.themeName == p.name
        val card = FrameLayout(this).apply {
            val bg = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(p.bg, p.bg2)).apply {
                cornerRadius = dp(14f)
                if (selected) setStroke(dp(3), pal.accent) else setStroke(dp(1), ColorMath.withAlpha(pal.text, 0.15f))
            }
            background = rippleOver(pal.ripple, dp(14f), bg)
            isFocusable = true
            isClickable = true
            contentDescription = p.name
            setOnClickListener {
                p.applyTo(prefs)
                render(keepScroll = true)
            }
        }
        val inner = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(10), dp(12), dp(10))
        }
        inner.addView(TextView(this).apply {
            text = p.name
            setTextColor(p.text)
            textSize = 15f
            typeface = android.graphics.Typeface.create(p.font.family, android.graphics.Typeface.BOLD)
        })
        val dots = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        for (c in intArrayOf(p.card, p.accent, p.text)) {
            dots.addView(View(this).apply {
                background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(c); setStroke(dp(1), ColorMath.withAlpha(p.text, 0.3f)) }
            }, lp(dp(16), dp(16)).apply { rightMargin = dp(6) })
        }
        inner.addView(dots, lp(WRAP, WRAP).apply { topMargin = dp(10) })
        inner.addView(TextView(this).apply {
            text = p.ambient.title
            setTextColor(ColorMath.withAlpha(p.text, 0.7f))
            textSize = 11f
        }, lp(WRAP, WRAP).apply { topMargin = dp(6) })
        card.addView(inner)
        card.focusHighlight(pal, 1.04f, dp(14f))
        return card
    }

    private fun renderBackground() {
        header("Background")
        choiceRow("Style", prefs::bgStyle, BackgroundStyle.entries, restyle = true) { it.title }
        if (prefs.bgStyle == BackgroundStyle.IMAGE) {
            actionRow("Choose picture", if (prefs.bgImage.isEmpty()) "No picture chosen" else "Tap to pick another") { pickImage() }
            if (Build.VERSION.SDK_INT >= 31) sliderRow("Blur", prefs::bgBlur, 0, 60, step = 2) { if (it == 0) "Off" else "$it" }
        }
        if (prefs.bgStyle == BackgroundStyle.GRADIENT || prefs.bgStyle == BackgroundStyle.DOTS || prefs.bgStyle == BackgroundStyle.GRID) {
            sliderRow("Gradient angle", prefs::gradientAngle, 0, 355, step = 5) { "$it°" }
        }
        sliderRow("Dim", prefs::bgDim, 0, 90, step = 5) { "$it%" }
        colorRow("Background", prefs::bgColor)
        colorRow("Background (second color)", prefs::bgColor2)
        header("Ambient effect")
        choiceRow("Effect", prefs::ambient, Ambient.entries) { it.title }
        sliderRow("Amount", prefs::ambientDensity, 5, 100, step = 5) { "$it" }
        note("Ambient effects pause whenever an app is open, and turn off completely with \"Reduce motion\".")
    }

    private fun renderLayout() {
        header("Library pages")
        choiceRow("Layout", prefs::layoutMode, LayoutMode.entries) { it.title }
        sliderRow("Grid columns", prefs::gridColumns, 0, 12) { if (it == 0) "Automatic" else "$it" }
        sliderRow("Spacing", prefs::tileSpacing, 0, 32) { "${it}dp" }
        sliderRow("Focus zoom", prefs::focusScale, 100, 135) { "$it%" }
        choiceRow("Sort by", prefs::sortOrder, SortOrder.entries) { it.title }
        switchRow("Show playtime under icons", null, prefs::showPlaytimeOnTiles)
        header("Tabs")
        choiceRow("Start on", prefs::startTab, Tab.entries) { it.title }
        switchRow("Games tab", null, prefs::showGamesTab)
        switchRow("Apps tab", null, prefs::showAppsTab)
        switchRow("Favorites tab", null, prefs::showFavoritesTab)
        switchRow("A tab for each collection", null, prefs::showCollectionTabs)
    }

    private fun renderIcons() {
        header("Icons")
        choiceRow("Shape", prefs::iconShape, IconShape.entries) { it.title }
        sliderRow("Size", prefs::iconSize, 40, 120, step = 2) { "${it}dp" }
        if (Build.VERSION.SDK_INT >= 33) switchRow("Themed icons", "Uses the app's monochrome icon, tinted with your accent color, when it has one", prefs::themedIcons)
        switchRow("Plate behind old-style icons", "Lets icons that aren't adaptive fill the shape too", prefs::legacyIconPlate)
        switchRow("Outline", null, prefs::iconOutline)
        switchRow("Black and white", null, prefs::grayscaleIcons)
        header("Labels")
        switchRow("Show app names", null, prefs::showLabels)
        sliderRow("Name size", prefs::labelSize, 9, 18) { "${it}sp" }
        switchRow("Allow two lines", null, prefs::twoLineLabels)
    }

    private fun renderHome() {
        header("Home tab")
        switchRow("Continue-playing card", "Your most recent game, ready to resume", prefs::showHero)
        switchRow("\"Jump back in\" shelf", null, prefs::showRecentShelf)
        switchRow("Favorites shelf", null, prefs::showFavoritesShelf)
        switchRow("Games shelf", null, prefs::showGamesShelf)
        switchRow("Apps shelf", null, prefs::showAppsShelf)
        sliderRow("Apps per shelf", prefs::shelfLength, 4, 30) { "$it" }
        switchRow("Play stats line", "Number of games and today's playtime", prefs::showStats)
        switchRow("Widgets", "Add them with the + next to \"Widgets\" on the Home tab", prefs::showWidgets)
    }

    private fun renderClock() {
        header("Clock")
        choiceRow("Clock", prefs::clockStyle, ClockStyle.entries) { it.title }
        switchRow("24-hour time", null, prefs::clock24h)
        switchRow("Seconds", null, prefs::clockSeconds)
        switchRow("Date", null, prefs::showDate)
        switchRow("Battery level", null, prefs::showBattery)
        header("System")
        switchRow("Hide the status bar", "Swipe down from the top edge to see it briefly", prefs::hideStatusBar)
        switchRow("Controller button hints", "The A / B / X / Y bar along the bottom", prefs::showHints)
    }

    private fun renderMascot() {
        // Live preview
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(12), dp(12), dp(12))
            background = cardBackground(pal)
        }
        val m = MascotView(this)
        val bubble = SpeechBubble(this).apply { style(pal) }
        m.setOnClickListener {
            m.poke()
            val ctx = MascotContext(hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY), name = prefs.mascotName)
            m.talk(bubble.say(brain.line(MascotEvent.TAP, ctx)))
        }
        box.addView(m, lp(dp(140), dp(140)))
        box.addView(bubble, lp(WRAP, WRAP))
        body.addView(box, lp(MATCH, WRAP).apply { topMargin = dp(4) })
        preview = m
        previewBubble = bubble
        updatePreview()
        note("Tap the mascot to say hi.")

        header("Who")
        textRow("Name", prefs::mascotName)
        choiceRow("Life stage", prefs::mascotStage, MascotStage.entries) { it.title }
        if (prefs.mascotStage == MascotStage.AUTO) {
            note("Starts as a caterpillar, spins a cocoon after about ${MascotBrain.COCOON_AT_MS / 3_600_000} hours of games (or ${MascotBrain.COCOON_AT_LAUNCHES} launches) and becomes a moth after ${MascotBrain.MOTH_AT_MS / 3_600_000} hours (or ${MascotBrain.MOTH_AT_LAUNCHES} launches).")
        }
        choiceRow("Position", prefs::mascotPosition, MascotPosition.entries) { it.title }
        sliderRow("Size", prefs::mascotSize, 60, 160, step = 5) { "$it%" }
        switchRow("Corner buddy on other tabs", "A small mascot in the corner of the Games, Apps and other tabs", prefs::mascotBuddy)
        header("Looks")
        colorRow("Body", prefs::mascotBody)
        colorRow("Wings and spots", prefs::mascotWings)
        colorRow("Cheeks", prefs::mascotCheeks)
        choiceRow("Eyes", prefs::mascotEyes, MascotEyes.entries) { it.title }
        choiceRow("Hat", prefs::mascotHat, MascotHat.entries) { it.title }
        choiceRow("Accessory", prefs::mascotAccessory, MascotAccessory.entries) { it.title }
        note("Hats and accessories use your theme's accent color.")
        header("Personality")
        choiceRow("Chattiness", prefs::mascotChattiness, Chattiness.entries) { it.title }
        switchRow("Speech bubbles", null, prefs::mascotBubbles)
        switchRow("Reacts when you open things", null, prefs::mascotReacts)
        switchRow("Sleeps at night", "Between 11 pm and 6 am", prefs::mascotSleeps)
    }

    private fun updatePreview() {
        val m = preview ?: return
        val stage = if (prefs.mascotStage == MascotStage.AUTO) {
            val items = app.repo.items
            MascotBrain.stageFor(items.filter { it.isGame }.sumOf { it.playtimeMs }, items.sumOf { it.launchCount })
        } else prefs.mascotStage
        m.look = MascotLook(stage, prefs.mascotBody, prefs.mascotWings, prefs.mascotCheeks, pal.accent, prefs.mascotEyes, prefs.mascotHat, prefs.mascotAccessory)
        m.still = prefs.reduceMotion
        m.sizeFactor = 1f
    }

    private fun renderControls() {
        header("Controller")
        switchRow("Swap A and B", "Confirm with B and go back with A (Nintendo-style layout)", prefs::swapAB)
        note("A opens · B goes back · X shows options · Y toggles favorite · L1/R1 switch tabs · L2/R2 page up/down · Start opens settings · Select opens search.")
        switchRow("Type to search", "With a keyboard, start typing on the home screen to search", prefs::typeToSearch)
        header("Feedback")
        switchRow("Vibration", null, prefs::haptics)
        switchRow("Navigation sounds", "Uses the system's touch sounds", prefs::sounds)
        header("Motion")
        switchRow("Reduce motion", "Stops idle animations and ambient effects", prefs::reduceMotion)
        sliderRow("Animation speed", prefs::animationSpeed, 50, 200, step = 10) { "$it%" }
    }

    private fun renderGestures() {
        header("On the home screen")
        choiceRow("Swipe up", prefs::swipeUp, GestureAction.entries) { it.title }
        choiceRow("Swipe down", prefs::swipeDown, GestureAction.entries) { it.title }
        choiceRow("Double tap", prefs::doubleTap, GestureAction.entries) { it.title }
        choiceRow("Long press on empty space", prefs::longPress, GestureAction.entries) { it.title }
        switchRow("Swipe sideways to change tabs", null, prefs::swipeTabs)
    }

    private fun renderLibrary() {
        val playtime = app.playtime
        header("Playtime")
        val granted = playtime.hasAccess()
        actionRow(
            if (granted) "Usage access: on" else "Turn on playtime tracking",
            if (granted) "Playtime comes from Android's usage stats, so it's approximate." else "Grant \"Usage access\" to Silkie so it can show how long you've played.",
        ) {
            runCatching { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)) }
        }
        header("Library")
        val hiddenCount = app.repo.items.count { it.hidden }
        actionRow("Hidden apps", if (hiddenCount == 0) "None hidden" else "$hiddenCount hidden") { manageHidden() }
        actionRow("Collections", if (app.repo.meta.collections.isEmpty()) "None yet" else app.repo.meta.collections.joinToString(", ")) { manageCollections() }
        actionRow("Reload apps", "Re-scan installed apps and playtime") {
            app.repo.reload()
            Toast.makeText(this, "Reloading…", Toast.LENGTH_SHORT).show()
        }
        header("Home screen")
        actionRow(if (isDefaultHome()) "Silkie is your home screen" else "Make Silkie your home screen", "Choose which app the home button opens") { requestDefaultHome() }
    }

    private fun renderBackup() {
        header("Backup")
        actionRow("Save backup", "Writes every setting, collection and app tweak to a file") { createBackup() }
        actionRow("Restore backup", "Loads a file saved with \"Save backup\"") { openBackup() }
        header("Reset")
        actionRow("Reset all settings", "Theme, layout and mascot go back to defaults. Collections and app tweaks stay.") {
            dialog(pal)
                .setTitle("Reset all settings?")
                .setPositiveButton("Reset") { _, _ ->
                    prefs.reset()
                    render()
                }
                .setNegativeButton("Cancel", null)
                .show()
        }
        val version = runCatching { packageManager.getPackageInfo(packageName, 0).versionName }.getOrNull() ?: ""
        note("Silkie $version")
    }

    // --- Row builders --------------------------------------------------------------------------

    private fun header(text: String) {
        body.addView(label(pal, text.uppercase(), 12f, pal.accent, bold = true), lp(WRAP, WRAP).apply {
            topMargin = dp(20)
            bottomMargin = dp(6)
            leftMargin = dp(4)
        })
    }

    private fun note(text: String) {
        body.addView(label(pal, text, 12f, pal.textDim).apply { setLineSpacing(0f, 1.15f) }, lp(MATCH, WRAP).apply {
            setMargins(dp(4), dp(6), dp(4), dp(4))
        })
    }

    private fun baseRow(title: String, subtitle: String?, focusable: Boolean = true): Pair<LinearLayout, LinearLayout> {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(14), dp(12), dp(14), dp(12))
            background = cardBackground(pal)
            isFocusable = focusable
            isClickable = focusable
        }
        val texts = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        texts.addView(label(pal, title, 15f, pal.text))
        if (!subtitle.isNullOrEmpty()) texts.addView(label(pal, subtitle, 12f, pal.textDim).apply { setLineSpacing(0f, 1.1f) }, lp(WRAP, WRAP).apply { topMargin = dp(3) })
        row.addView(texts, lp(0, WRAP, 1f))
        if (focusable) row.focusHighlight(pal, 1.015f)
        body.addView(row, lp(MATCH, WRAP).apply { bottomMargin = dp(6) })
        return row to texts
    }

    private fun changed(restyle: Boolean) {
        updatePreview()
        if (restyle) render(keepScroll = true)
    }

    private fun switchRow(title: String, subtitle: String?, prop: KMutableProperty0<Boolean>) {
        val (row, _) = baseRow(title, subtitle)
        val sw = Switch(this).apply {
            isChecked = prop.get()
            isFocusable = false
            isClickable = false
            thumbTintList = android.content.res.ColorStateList(
                arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
                intArrayOf(pal.accent, ColorMath.mix(pal.text, pal.bg, 0.3f)),
            )
            trackTintList = android.content.res.ColorStateList(
                arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
                intArrayOf(ColorMath.withAlpha(pal.accent, 0.5f), ColorMath.withAlpha(pal.text, 0.25f)),
            )
        }
        row.addView(sw, lp(WRAP, WRAP).apply { leftMargin = dp(12) })
        row.setOnClickListener {
            prop.set(!prop.get())
            sw.isChecked = prop.get()
            changed(restyle = false)
        }
    }

    private fun sliderRow(title: String, prop: KMutableProperty0<Int>, min: Int, max: Int, step: Int = 1, restyle: Boolean = false, format: (Int) -> String) {
        val (row, texts) = baseRow(title, null, focusable = false)
        val value = label(pal, format(prop.get()), 14f, pal.accent, bold = true)
        row.addView(value, lp(WRAP, WRAP).apply { leftMargin = dp(12) })
        val bar = SeekBar(this).apply {
            this.max = (max - min) / step
            progress = (prop.get().coerceIn(min, max) - min) / step
            progressTintList = android.content.res.ColorStateList.valueOf(pal.accent)
            thumbTintList = android.content.res.ColorStateList.valueOf(pal.accent)
            progressBackgroundTintList = android.content.res.ColorStateList.valueOf(ColorMath.withAlpha(pal.text, 0.3f))
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar, p: Int, fromUser: Boolean) {
                    val v = min + p * step
                    value.text = format(v)
                    if (fromUser) {
                        prop.set(v)
                        updatePreview()
                    }
                }
                override fun onStartTrackingTouch(seekBar: SeekBar) = Unit
                override fun onStopTrackingTouch(seekBar: SeekBar) {
                    if (restyle) changed(restyle = true)
                }
            })
            setOnFocusChangeListener { _, has ->
                row.foreground = if (has) rounded(Color.TRANSPARENT, dp(pal.corner), pal.accent, dp(2)) else null
                if (!has && restyle) changed(restyle = true)
            }
        }
        texts.addView(bar, lp(MATCH, WRAP).apply { topMargin = dp(8) })
    }

    private fun <E : Enum<E>> choiceRow(title: String, prop: KMutableProperty0<E>, values: List<E>, restyle: Boolean = false, name: (E) -> String) {
        val (row, _) = baseRow(title, null)
        val value = label(pal, name(prop.get()), 14f, pal.accent, bold = true)
        row.addView(value, lp(WRAP, WRAP).apply { leftMargin = dp(12) })
        row.setOnClickListener {
            dialog(pal)
                .setTitle(title)
                .setSingleChoiceItems(values.map(name).toTypedArray(), values.indexOf(prop.get())) { d, which ->
                    prop.set(values[which])
                    value.text = name(values[which])
                    d.dismiss()
                    // Some choices show or hide other rows, so redraw the section.
                    changed(restyle = true)
                }
                .show()
        }
    }

    private fun colorRow(title: String, prop: KMutableProperty0<Int>) {
        val (row, _) = baseRow(title, null)
        val swatch = View(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(prop.get())
                setStroke(dp(1), ColorMath.withAlpha(pal.text, 0.4f))
            }
        }
        row.addView(label(pal, ColorMath.toHex(prop.get()), 13f, pal.textDim), lp(WRAP, WRAP).apply { leftMargin = dp(12); rightMargin = dp(10) })
        row.addView(swatch, lp(dp(28), dp(28)))
        row.setOnClickListener {
            ColorPicker.show(this, pal, title, prop.get()) { c ->
                prop.set(c)
                prefs.themeName = ""
                changed(restyle = true)
            }
        }
    }

    private fun textRow(title: String, prop: KMutableProperty0<String>) {
        val (row, _) = baseRow(title, null)
        row.addView(label(pal, prop.get(), 14f, pal.accent, bold = true), lp(WRAP, WRAP).apply { leftMargin = dp(12) })
        row.setOnClickListener {
            val input = EditText(this).apply {
                setText(prop.get())
                setSelection(text.length)
                inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_WORDS
            }
            val box = FrameLayout(this).apply { setPadding(dp(20), dp(8), dp(20), 0); addView(input) }
            dialog(pal)
                .setTitle(title)
                .setView(box)
                .setPositiveButton("Save") { _, _ ->
                    val v = input.text.toString().trim()
                    if (v.isNotEmpty()) prop.set(v.take(24))
                    changed(restyle = true)
                }
                .setNegativeButton("Cancel", null)
                .show()
        }
    }

    private fun actionRow(title: String, subtitle: String?, onClick: () -> Unit) {
        val (row, _) = baseRow(title, subtitle)
        row.addView(View(this).apply { background = GlyphDrawable(Glyph.CHEVRON, pal.textDim) }, lp(dp(18), dp(18)).apply { leftMargin = dp(10) })
        row.setOnClickListener { onClick() }
    }

    // --- Library management --------------------------------------------------------------------

    private fun manageHidden() {
        val repo = app.repo
        val items = Library.sort(repo.items, SortOrder.NAME)
        if (items.isEmpty()) return
        val checked = BooleanArray(items.size) { items[it].hidden }
        dialog(pal)
            .setTitle("Hidden apps")
            .setMultiChoiceItems(items.map { it.label }.toTypedArray(), checked) { _, which, isChecked -> checked[which] = isChecked }
            .setPositiveButton("Save") { _, _ ->
                items.forEachIndexed { i, item -> if (item.hidden != checked[i]) repo.meta.update(item.key) { hidden = checked[i] } }
                repo.rebuild()
                render(keepScroll = true)
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun manageCollections() {
        val meta = app.repo.meta
        val names = meta.collections.toList()
        dialog(pal)
            .setTitle("Collections")
            .setItems((names + "+ New collection").toTypedArray()) { _, which ->
                if (which == names.size) askName("New collection", "") { n ->
                    if (!meta.addCollection(n)) Toast.makeText(this, "That name is empty or already used", Toast.LENGTH_SHORT).show()
                    afterCollections()
                } else {
                    val name = names[which]
                    dialog(pal)
                        .setTitle(name)
                        .setItems(arrayOf("Rename", "Delete")) { _, action ->
                            if (action == 0) askName("Rename collection", name) { n ->
                                if (!meta.renameCollection(name, n)) Toast.makeText(this, "That name is empty or already used", Toast.LENGTH_SHORT).show()
                                afterCollections()
                            } else {
                                meta.deleteCollection(name)
                                afterCollections()
                            }
                        }
                        .show()
                }
            }
            .show()
    }

    private fun afterCollections() {
        app.repo.rebuild()
        render(keepScroll = true)
    }

    private fun askName(title: String, initial: String, done: (String) -> Unit) {
        val input = EditText(this).apply {
            setText(initial)
            setSelection(text.length)
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_WORDS
        }
        val box = FrameLayout(this).apply { setPadding(dp(20), dp(8), dp(20), 0); addView(input) }
        dialog(pal)
            .setTitle(title)
            .setView(box)
            .setPositiveButton("OK") { _, _ -> done(input.text.toString()) }
            .setNegativeButton("Cancel", null)
            .show()
    }

    // --- Default home, pictures and backups ----------------------------------------------------

    private fun isDefaultHome(): Boolean {
        val rm = getSystemService(RoleManager::class.java) ?: return false
        return rm.isRoleAvailable(RoleManager.ROLE_HOME) && rm.isRoleHeld(RoleManager.ROLE_HOME)
    }

    private fun requestDefaultHome() {
        val rm = getSystemService(RoleManager::class.java)
        if (rm != null && rm.isRoleAvailable(RoleManager.ROLE_HOME) && !rm.isRoleHeld(RoleManager.ROLE_HOME)) {
            runCatching { startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_HOME), REQ_HOME) }
                .onFailure { openHomeSettings() }
        } else {
            openHomeSettings()
        }
    }

    private fun openHomeSettings() {
        runCatching { startActivity(Intent(Settings.ACTION_HOME_SETTINGS)) }
    }

    private fun pickImage() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
        }
        runCatching { startActivityForResult(intent, REQ_IMAGE) }
    }

    private fun createBackup() {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, "silkie-backup.json")
        }
        runCatching { startActivityForResult(intent, REQ_SAVE) }
    }

    private fun openBackup() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
        }
        runCatching { startActivityForResult(intent, REQ_LOAD) }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_HOME) {
            render(keepScroll = true)
            return
        }
        val uri: Uri = data?.data ?: return
        if (resultCode != RESULT_OK) return
        when (requestCode) {
            REQ_IMAGE -> {
                runCatching { contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) }
                prefs.edit {
                    bgImage = uri.toString()
                    bgStyle = BackgroundStyle.IMAGE
                }
                render(keepScroll = true)
            }
            REQ_SAVE -> {
                val json = JSONObject()
                    .put("format", "silkie-backup")
                    .put("version", 1)
                    .put("settings", prefs.toJson())
                    .put("apps", app.repo.meta.toJson())
                val ok = runCatching {
                    contentResolver.openOutputStream(uri, "wt")!!.use { it.write(json.toString(2).toByteArray()) }
                }.isSuccess
                Toast.makeText(this, if (ok) "Backup saved" else "Couldn't save the backup", Toast.LENGTH_SHORT).show()
            }
            REQ_LOAD -> {
                val ok = runCatching {
                    val text = contentResolver.openInputStream(uri)!!.use { it.readBytes().toString(Charsets.UTF_8) }
                    val json = JSONObject(text)
                    require(json.optString("format") == "silkie-backup")
                    prefs.loadJson(json.getJSONObject("settings"))
                    app.repo.meta.loadJson(json.getJSONObject("apps"))
                    app.repo.rebuild()
                }.isSuccess
                Toast.makeText(this, if (ok) "Backup restored" else "That file isn't a Silkie backup", Toast.LENGTH_SHORT).show()
                render()
            }
        }
    }

    companion object {
        private const val REQ_IMAGE = 11
        private const val REQ_SAVE = 12
        private const val REQ_LOAD = 13
        private const val REQ_HOME = 14
    }
}
