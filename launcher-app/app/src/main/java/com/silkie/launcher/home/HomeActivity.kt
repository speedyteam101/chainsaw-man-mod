package com.silkie.launcher.home

import android.app.Activity
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.ColorDrawable
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.format.DateFormat
import android.view.GestureDetector
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.SoundEffectConstants
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import com.silkie.launcher.app
import com.silkie.launcher.data.LibraryItem
import com.silkie.launcher.data.Shelf
import com.silkie.launcher.mascot.MascotBrain
import com.silkie.launcher.mascot.MascotContext
import com.silkie.launcher.mascot.MascotEvent
import com.silkie.launcher.mascot.MascotLook
import com.silkie.launcher.mascot.MascotStage
import com.silkie.launcher.mascot.MascotView
import com.silkie.launcher.mascot.Mood
import com.silkie.launcher.settings.BackgroundStyle
import com.silkie.launcher.settings.ClockStyle
import com.silkie.launcher.settings.GestureAction
import com.silkie.launcher.settings.LayoutMode
import com.silkie.launcher.settings.MascotPosition
import com.silkie.launcher.settings.Prefs
import com.silkie.launcher.settings.SettingsActivity
import com.silkie.launcher.settings.Tab
import com.silkie.launcher.ui.Backdrop
import com.silkie.launcher.ui.ColorMath
import com.silkie.launcher.ui.Glyph
import com.silkie.launcher.ui.IconStyle
import com.silkie.launcher.ui.MATCH
import com.silkie.launcher.ui.Palette
import com.silkie.launcher.ui.SpeechBubble
import com.silkie.launcher.ui.WRAP
import com.silkie.launcher.ui.dp
import com.silkie.launcher.ui.feedback
import com.silkie.launcher.ui.focusHighlight
import com.silkie.launcher.ui.glyphButton
import com.silkie.launcher.ui.label
import com.silkie.launcher.ui.lp
import com.silkie.launcher.ui.rippleOver
import com.silkie.launcher.ui.rounded
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.abs
import kotlin.random.Random

/** One tab in the top bar. A null [shelf] is the Home tab. */
class TabSpec(val title: String, val shelf: Shelf?)

class HomeActivity : Activity() {
    val prefs: Prefs get() = app.prefs
    val repo get() = app.repo
    val icons get() = app.icons
    lateinit var pal: Palette
        private set
    lateinit var iconStyle: IconStyle
        private set

    private val handler = Handler(Looper.getMainLooper())
    private val brain = MascotBrain()
    private lateinit var pages: Pages
    lateinit var widgets: WidgetController
        private set

    private lateinit var root: FrameLayout
    private lateinit var backdrop: Backdrop
    private lateinit var content: LinearLayout
    private lateinit var tabRow: LinearLayout
    private lateinit var tabScroll: HorizontalScrollView
    private lateinit var compactClock: TextView
    private lateinit var batteryText: TextView
    private lateinit var pageHost: FrameLayout
    private lateinit var hintBar: LinearLayout
    private lateinit var buddy: MascotView
    private lateinit var buddyBubble: SpeechBubble
    private lateinit var buddyBox: LinearLayout
    private lateinit var search: SearchPanel

    /** The mascot and bubble on the Home tab's hero area (null when not shown). */
    var heroMascot: MascotView? = null
    var heroBubble: SpeechBubble? = null
    var bigClock: TextView? = null
    var bigDate: TextView? = null

    private var tabs = listOf<TabSpec>()
    private var tabIndex = 0
    private var currentPage: Page? = null
    private var appliedRevision = -1
    private var appliedMetaRevision = -1
    private var resumed = false
    private var pageDirty = false
    private var lowBatteryWarned = false
    private var wasCharging = false
    private var greeted = false
    private var launchedKey: String? = null
    private var launchedAt = 0L

    private val repoListener: () -> Unit = {
        if (resumed) rebuildPage(keepState = true) else pageDirty = true
        checkEvolution()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pages = Pages(this)
        widgets = WidgetController(this)
        buildShell()
        applySettings()
        selectTab(startTabIndex(), animate = false)
        repo.addListener(repoListener)
    }

    override fun onDestroy() {
        repo.removeListener(repoListener)
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onStart() {
        super.onStart()
        widgets.start()
    }

    override fun onStop() {
        widgets.stop()
        super.onStop()
    }

    override fun onResume() {
        super.onResume()
        resumed = true
        if (prefs.revision != appliedRevision || repo.meta.revision != appliedMetaRevision) {
            applySettings()
            rebuildPage(keepState = true)
        } else if (pageDirty) {
            rebuildPage(keepState = true)
        }
        pageDirty = false
        backdrop.running = true
        repo.refreshPlaytime()
        handler.post(tick)
        scheduleIdleChat()
        applySystemBars()

        val key = launchedKey
        if (key != null) {
            launchedKey = null
            val session = System.currentTimeMillis() - launchedAt
            val item = repo.item(key)
            if (item != null && item.isGame && session > 60_000 && prefs.mascotReacts) {
                handler.postDelayed({ mascotEvent(MascotEvent.WELCOME_BACK, item.label, session) }, 600)
            }
        } else if (!greeted) {
            greeted = true
            handler.postDelayed({ mascotEvent(MascotEvent.GREETING) }, 700)
        }
    }

    override fun onPause() {
        resumed = false
        backdrop.running = false
        handler.removeCallbacks(tick)
        handler.removeCallbacks(idleChat)
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Home pressed while already home: close overlays and go back to the first tab.
        if (search.isOpen) search.close()
        if (tabIndex != 0) selectTab(0) else currentPage?.scrollToTop()
    }

    // --- Shell ---------------------------------------------------------------------------------

    private fun buildShell() {
        root = FrameLayout(this)
        backdrop = Backdrop(this)
        root.addView(backdrop, FrameLayout.LayoutParams(MATCH, MATCH))

        content = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(content, FrameLayout.LayoutParams(MATCH, MATCH))

        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(8), dp(8), dp(4))
        }
        tabRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        tabScroll = HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
            addView(tabRow)
        }
        topBar.addView(tabScroll, lp(0, WRAP, 1f))
        compactClock = TextView(this)
        batteryText = TextView(this)
        topBar.addView(compactClock, lp(WRAP, WRAP).apply { leftMargin = dp(8); rightMargin = dp(10) })
        topBar.addView(batteryText, lp(WRAP, WRAP).apply { rightMargin = dp(6) })
        content.addView(topBar, lp(MATCH, WRAP))
        topBar.tag = "topbar"

        pageHost = FrameLayout(this).apply { clipChildren = false }
        content.addView(pageHost, lp(MATCH, 0, 1f))

        hintBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(6), dp(12), dp(10))
        }
        content.addView(hintBar, lp(MATCH, WRAP))

        buddyBox = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.BOTTOM
            clipChildren = false
        }
        buddy = MascotView(this)
        buddyBubble = SpeechBubble(this)
        buddy.setOnClickListener { mascotEvent(MascotEvent.TAP) }
        root.addView(buddyBox, FrameLayout.LayoutParams(WRAP, WRAP, Gravity.BOTTOM or Gravity.START))

        search = SearchPanel(this)
        root.addView(search, FrameLayout.LayoutParams(MATCH, MATCH))

        root.setOnApplyWindowInsetsListener { _, insets ->
            val r = systemInsets(insets)
            content.setPadding(r.left, r.top, r.right, r.bottom)
            search.setPadding(r.left, r.top, r.right, r.bottom)
            (buddyBox.layoutParams as FrameLayout.LayoutParams).bottomMargin = r.bottom + dp(if (prefs.showHints) 44 else 8)
            buddyBox.requestLayout()
            insets
        }
        setContentView(root)
        setupWindow()
    }

    @Suppress("DEPRECATION")
    private fun systemInsets(insets: WindowInsets): Rect =
        if (Build.VERSION.SDK_INT >= 30) {
            val i = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout() or WindowInsets.Type.ime())
            Rect(i.left, i.top, i.right, i.bottom)
        } else {
            Rect(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
        }

    @Suppress("DEPRECATION")
    private fun setupWindow() {
        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(false)
        } else {
            root.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        }
    }

    @Suppress("DEPRECATION")
    private fun applySystemBars() {
        val light = pal.isLight && prefs.bgStyle != BackgroundStyle.WALLPAPER && prefs.bgStyle != BackgroundStyle.IMAGE
        if (Build.VERSION.SDK_INT >= 30) {
            val c = window.insetsController ?: return
            val mask = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
            c.setSystemBarsAppearance(if (light) mask else 0, mask)
            if (prefs.hideStatusBar) {
                c.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                c.hide(WindowInsets.Type.statusBars())
            } else {
                c.show(WindowInsets.Type.statusBars())
            }
        } else {
            var flags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            if (light) flags = flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
            if (prefs.hideStatusBar) flags = flags or View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            root.systemUiVisibility = flags
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) applySystemBars()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        rebuildPage(keepState = true)
    }

    // --- Settings ------------------------------------------------------------------------------

    private fun applySettings() {
        pal = Palette(prefs)
        iconStyle = IconStyle.from(prefs, pal)
        appliedMetaRevision = repo.meta.revision

        if (prefs.bgStyle == BackgroundStyle.WALLPAPER) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WALLPAPER)
            window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WALLPAPER)
            window.setBackgroundDrawable(ColorDrawable(pal.bg))
        }
        backdrop.configure(prefs, pal)

        compactClock.apply {
            setTextColor(pal.text)
            typeface = pal.typefaceBold
            textSize = 15f * pal.fontScale
            visibility = if (prefs.clockStyle == ClockStyle.COMPACT) View.VISIBLE else View.GONE
        }
        batteryText.apply {
            setTextColor(pal.textDim)
            typeface = pal.typeface
            textSize = 13f * pal.fontScale
            visibility = if (prefs.showBattery) View.VISIBLE else View.GONE
        }
        // Top-bar buttons are rebuilt so they pick up the new colors.
        val topBar = tabScroll.parent as LinearLayout
        while (topBar.childCount > 3) topBar.removeViewAt(3)
        topBar.addView(glyphButton(pal, Glyph.SEARCH, "Search") { openSearch() })
        topBar.addView(glyphButton(pal, Glyph.SETTINGS, "Settings") { openSettings() })

        buildTabs()
        buildHints()
        styleBuddy()
        search.applyStyle()
        applySystemBars()
        updateClock()
        root.requestApplyInsets()
        appliedRevision = prefs.revision
    }

    private fun buildTabs() {
        val list = mutableListOf(TabSpec(Tab.HOME.title, null))
        if (prefs.showGamesTab) list += TabSpec(Tab.GAMES.title, Shelf.Games)
        if (prefs.showAppsTab) list += TabSpec(Tab.APPS.title, Shelf.All)
        if (prefs.showFavoritesTab) list += TabSpec(Tab.FAVORITES.title, Shelf.Favorites)
        if (prefs.showCollectionTabs) repo.meta.collections.forEach { list += TabSpec(it, Shelf.Collection(it)) }
        val previous = tabs.getOrNull(tabIndex)
        tabs = list
        tabIndex = tabs.indexOfFirst { it.title == previous?.title && it.shelf == previous.shelf }.coerceAtLeast(0)
        tabRow.removeAllViews()
        tabs.forEachIndexed { i, t ->
            val chip = label(pal, t.title, 15f, pal.text, bold = true).apply {
                gravity = Gravity.CENTER
                setPadding(dp(14), dp(8), dp(14), dp(8))
                isFocusable = true
                isClickable = true
                setOnClickListener { selectTab(i) }
            }
            chip.focusHighlight(pal, 1.05f, dp(100f))
            tabRow.addView(chip, lp(WRAP, WRAP).apply { rightMargin = dp(4) })
        }
        styleTabs()
    }

    private fun styleTabs() {
        for (i in 0 until tabRow.childCount) {
            val chip = tabRow.getChildAt(i) as TextView
            val sel = i == tabIndex
            chip.setTextColor(if (sel) pal.onAccent else pal.textDim)
            chip.background = rippleOver(pal.ripple, dp(100f), rounded(if (sel) pal.accent else Color.TRANSPARENT, dp(100f)))
        }
        tabRow.getChildAt(tabIndex)?.let { v -> tabScroll.post { tabScroll.smoothScrollTo(v.left - dp(24), 0) } }
    }

    private fun buildHints() {
        hintBar.removeAllViews()
        hintBar.visibility = if (prefs.showHints) View.VISIBLE else View.GONE
        val confirm = if (prefs.swapAB) "B" else "A"
        val back = if (prefs.swapAB) "A" else "B"
        val hints = listOf(confirm to "Open", back to "Back", "X" to "Options", "Y" to "Favorite", "L1 R1" to "Tabs", "≡" to "Settings")
        for ((key, text) in hints) {
            val badge = label(pal, key, 11f, pal.onAccent, bold = true).apply {
                gravity = Gravity.CENTER
                minWidth = dp(20)
                setPadding(dp(5), dp(2), dp(5), dp(2))
                background = rounded(ColorMath.withAlpha(pal.text, 0.75f), dp(100f))
                setTextColor(pal.bg)
            }
            hintBar.addView(badge)
            hintBar.addView(label(pal, text, 12f, pal.textDim), lp(WRAP, WRAP).apply { leftMargin = dp(5); rightMargin = dp(14) })
        }
    }

    private fun styleBuddy() {
        buddyBox.removeAllViews()
        val size = (dp(70) * prefs.mascotSize / 100f).toInt()
        val right = prefs.mascotPosition == MascotPosition.RIGHT
        (buddyBox.layoutParams as FrameLayout.LayoutParams).gravity = Gravity.BOTTOM or if (right) Gravity.END else Gravity.START
        buddyBubble.tailLeft = !right
        buddyBubble.style(pal)
        if (right) {
            buddyBox.addView(buddyBubble, lp(WRAP, WRAP).apply { bottomMargin = size / 2 })
            buddyBox.addView(buddy, lp(size, size).apply { rightMargin = dp(8) })
        } else {
            buddyBox.addView(buddy, lp(size, size).apply { leftMargin = dp(8) })
            buddyBox.addView(buddyBubble, lp(WRAP, WRAP).apply { bottomMargin = size / 2 })
        }
        styleMascot(buddy)
        updateBuddyVisibility()
    }

    fun styleMascot(m: MascotView) {
        m.look = currentLook()
        m.still = prefs.reduceMotion
        m.speed = prefs.animationSpeed / 100f
        m.mood = brain.mood(MascotEvent.IDLE, hour(), prefs.mascotSleeps)
    }

    fun currentLook() = MascotLook(
        stage = currentStage(),
        body = prefs.mascotBody,
        wings = prefs.mascotWings,
        cheeks = prefs.mascotCheeks,
        accent = pal.accent,
        eyes = prefs.mascotEyes,
        hat = prefs.mascotHat,
        accessory = prefs.mascotAccessory,
    )

    private fun currentStage(): MascotStage {
        if (prefs.mascotStage != MascotStage.AUTO) return prefs.mascotStage
        val items = repo.items
        return MascotBrain.stageFor(items.filter { it.isGame }.sumOf { it.playtimeMs }, items.sumOf { it.launchCount })
    }

    private fun checkEvolution() {
        if (!repo.loaded || prefs.mascotStage != MascotStage.AUTO) return
        val stage = currentStage()
        val last = MascotStage.entries.firstOrNull { it.name == prefs.lastStage }
        if (last == stage) return
        prefs.lastStage = stage.name
        heroMascot?.let { styleMascot(it) }
        styleMascot(buddy)
        if (last != null && stage.ordinal > last.ordinal) {
            activeMascot()?.celebrate()
            mascotEvent(MascotEvent.EVOLVED)
        }
    }

    private fun updateBuddyVisibility() {
        val onHome = tabs.getOrNull(tabIndex)?.shelf == null
        buddyBox.visibility = if (prefs.mascotBuddy && prefs.mascotPosition != MascotPosition.HIDDEN && !onHome) View.VISIBLE else View.GONE
    }

    // --- Tabs and pages ------------------------------------------------------------------------

    private fun startTabIndex(): Int {
        val want = when (prefs.startTab) {
            Tab.HOME -> null
            Tab.GAMES -> Shelf.Games
            Tab.APPS -> Shelf.All
            Tab.FAVORITES -> Shelf.Favorites
        }
        return tabs.indexOfFirst { it.shelf == want }.coerceAtLeast(0)
    }

    fun selectTab(i: Int, animate: Boolean = true) {
        val from = tabIndex
        tabIndex = i.coerceIn(0, tabs.size - 1)
        styleTabs()
        updateBuddyVisibility()
        rebuildPage(keepState = false)
        val page = currentPage?.view ?: return
        if (animate && from != tabIndex && !prefs.reduceMotion) {
            page.alpha = 0f
            page.translationX = dp(if (tabIndex > from) 32f else -32f)
            page.animate().alpha(1f).translationX(0f).setDuration(prefs.duration(200)).start()
        }
    }

    fun selectShelf(shelf: Shelf) {
        val i = tabs.indexOfFirst { it.shelf == shelf }
        if (i >= 0) selectTab(i) else Toast.makeText(this, "Turn on the ${shelf.title} tab in settings", Toast.LENGTH_SHORT).show()
    }

    private fun switchTab(delta: Int) {
        if (tabs.size < 2) return
        selectTab((tabIndex + delta + tabs.size) % tabs.size)
        content.feedback(prefs, if (delta > 0) SoundEffectConstants.NAVIGATION_RIGHT else SoundEffectConstants.NAVIGATION_LEFT)
    }

    fun rebuildPage(keepState: Boolean) {
        if (!::pal.isInitialized) return
        val old = currentPage
        val focusedKey = (currentFocus as? AppTile)?.item?.key
        val scrollY = old?.scroller?.scrollY ?: 0
        val scrollX = old?.carousel?.scrollX ?: 0
        heroMascot = null
        heroBubble = null
        bigClock = null
        bigDate = null
        val tab = tabs.getOrNull(tabIndex) ?: return
        val page = if (tab.shelf == null) pages.home() else pages.library(tab.shelf)
        pageHost.removeAllViews()
        pageHost.addView(page.view, FrameLayout.LayoutParams(MATCH, MATCH))
        currentPage = page
        updateClock()
        if (keepState) {
            page.view.post {
                page.scroller?.scrollTo(0, scrollY)
                page.carousel?.scrollTo(scrollX, 0)
                if (focusedKey != null) page.findTile(focusedKey)?.requestFocus()
            }
        }
    }

    // --- Apps ----------------------------------------------------------------------------------

    fun launch(item: LibraryItem, from: View?) {
        from?.feedback(prefs)
        if (!repo.launch(item.key, from)) {
            Toast.makeText(this, "Couldn't open ${item.label}", Toast.LENGTH_SHORT).show()
            return
        }
        // Counting a launch isn't a change the screen needs to restyle for.
        appliedMetaRevision = repo.meta.revision
        launchedKey = item.key
        launchedAt = System.currentTimeMillis()
        if (prefs.mascotReacts) mascotEvent(if (item.isGame) MascotEvent.LAUNCH_GAME else MascotEvent.LAUNCH_APP, item.label)
    }

    /** A setting changed from the home screen itself (sort, layout) that only needs the page rebuilt. */
    fun settingsTweaked() {
        appliedRevision = prefs.revision
        rebuildPage(keepState = false)
    }

    fun toggleFavorite(item: LibraryItem) {
        val fav = !item.favorite
        repo.meta.update(item.key) { favorite = fav }
        appliedMetaRevision = repo.meta.revision
        repo.rebuild()
        if (fav && prefs.mascotReacts) mascotEvent(MascotEvent.FAVORITE_ADDED, item.label)
        else Toast.makeText(this, "Removed from favorites", Toast.LENGTH_SHORT).show()
    }

    /** Called after the options dialog changes something that affects tabs (collections). */
    fun metaChanged() {
        appliedMetaRevision = repo.meta.revision
        buildTabs()
        repo.rebuild()
    }

    fun onTileFocused(tile: AppTile) {
        val loc = IntArray(2)
        tile.getLocationOnScreen(loc)
        val x = (loc[0] + tile.width / 2f) / resources.displayMetrics.widthPixels * 2 - 1
        activeMascot()?.lookToward(x)
        currentPage?.onFocus?.invoke(tile)
        if (prefs.sounds) tile.playSoundEffect(SoundEffectConstants.NAVIGATION_DOWN)
    }

    fun openSettings() {
        startActivity(Intent(this, SettingsActivity::class.java))
    }

    fun openSearch(initial: String = "") {
        search.open(initial)
    }

    /** Small helper used by pages and the search panel to show an app tile with its icon. */
    fun makeTile(item: LibraryItem, spec: TileSpec): AppTile {
        val tile = AppTile(this, pal, spec)
        tile.bind(item)
        val cached = icons.cached(item.key, spec.iconPx, iconStyle)
        if (cached != null) setIcon(tile, cached) else {
            tile.showPlaceholder()
            icons.request(item.key, spec.iconPx, iconStyle, { repo.loadIcon(item.key) }) { bmp ->
                if (tile.item?.key == item.key) setIcon(tile, bmp)
            }
        }
        tile.setOnClickListener { launch(item, tile) }
        tile.setOnLongClickListener {
            it.feedback(prefs)
            AppOptions(this, item).show()
            true
        }
        tile.onFocused = { onTileFocused(it) }
        return tile
    }

    private fun setIcon(tile: AppTile, bmp: Bitmap) {
        tile.icon.background = null
        tile.icon.setImageBitmap(bmp)
    }

    fun tileSpec(kind: TileKind): TileSpec {
        val base = prefs.iconSize
        val iconDp = when (kind) {
            TileKind.GRID -> base
            TileKind.LIST -> minOf(base, 52)
            TileKind.CARD -> (base * 1.8f).toInt()
        }
        return TileSpec(
            kind = kind,
            iconPx = dp(iconDp),
            showLabel = prefs.showLabels,
            labelSp = prefs.labelSize.toFloat(),
            lines = if (prefs.twoLineLabels) 2 else 1,
            showPlaytime = prefs.showPlaytimeOnTiles,
            focusScale = prefs.focusScale / 100f,
            animMs = prefs.duration(140),
        )
    }

    // --- Mascot --------------------------------------------------------------------------------

    private fun activeMascot(): MascotView? {
        if (prefs.mascotPosition == MascotPosition.HIDDEN) return null
        heroMascot?.let { if (it.isShown) return it }
        return if (buddyBox.visibility == View.VISIBLE) buddy else null
    }

    private fun activeBubble(): SpeechBubble? {
        heroMascot?.let { if (it.isShown) return heroBubble }
        return if (buddyBox.visibility == View.VISIBLE) buddyBubble else null
    }

    fun mascotEvent(event: MascotEvent, appLabel: String? = null, sessionMs: Long = 0) {
        val m = activeMascot() ?: return
        val h = hour()
        m.mood = brain.mood(event, h, prefs.mascotSleeps)
        when (event) {
            MascotEvent.TAP, MascotEvent.FAVORITE_ADDED -> m.poke()
            MascotEvent.LAUNCH_GAME, MascotEvent.WELCOME_BACK -> m.cheer()
            MascotEvent.EVOLVED -> m.celebrate()
            else -> Unit
        }
        if (event == MascotEvent.TAP) m.feedback(prefs)
        if (prefs.mascotBubbles && brain.shouldSpeak(event, prefs.mascotChattiness)) {
            val ctx = MascotContext(
                hour = h,
                name = prefs.mascotName,
                appLabel = appLabel,
                todayPlayMs = repo.todayGameMs(),
                battery = batteryLevel(),
                gameCount = repo.items.count { it.isGame && !it.hidden },
                stage = currentStage(),
                sessionMs = sessionMs,
            )
            val bubble = activeBubble()
            val ms = bubble?.say(brain.line(event, ctx), instant = prefs.reduceMotion) ?: 0L
            m.talk(ms)
        }
        handler.removeCallbacks(calmDown)
        handler.postDelayed(calmDown, 3500)
    }

    private val calmDown = Runnable {
        val mood = brain.mood(MascotEvent.IDLE, hour(), prefs.mascotSleeps)
        heroMascot?.mood = mood
        buddy.mood = mood
    }

    private val idleChat = Runnable {
        if (resumed && !search.isOpen) mascotEvent(MascotEvent.IDLE)
        scheduleIdleChat()
    }

    private fun scheduleIdleChat() {
        handler.removeCallbacks(idleChat)
        val base = when (prefs.mascotChattiness) {
            com.silkie.launcher.mascot.Chattiness.QUIET -> return
            com.silkie.launcher.mascot.Chattiness.NORMAL -> 90_000L
            com.silkie.launcher.mascot.Chattiness.CHATTY -> 40_000L
        }
        handler.postDelayed(idleChat, base + Random.nextLong(base / 2))
    }

    fun mascotMood(): Mood = brain.mood(MascotEvent.IDLE, hour(), prefs.mascotSleeps)

    private fun hour() = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)

    // --- Clock and battery ---------------------------------------------------------------------

    private var tickCount = 0
    private val tick = object : Runnable {
        override fun run() {
            updateClock()
            if (tickCount++ % 15 == 0) checkBattery()
            handler.postDelayed(this, 1000L - System.currentTimeMillis() % 1000L)
        }
    }

    private fun updateClock() {
        if (!::pal.isInitialized) return
        val now = Date()
        val pattern = (if (prefs.clock24h) "HH:mm" else "h:mm") + if (prefs.clockSeconds) ":ss" else ""
        val time = SimpleDateFormat(pattern, Locale.getDefault()).format(now)
        compactClock.text = time
        bigClock?.text = time
        bigDate?.text = SimpleDateFormat(DateFormat.getBestDateTimePattern(Locale.getDefault(), "EEEEMMMMd"), Locale.getDefault()).format(now)
        if (prefs.showBattery) {
            val level = batteryLevel()
            batteryText.text = if (isCharging()) "$level% ⚡" else "$level%"
        }
    }

    private fun batteryLevel(): Int =
        getSystemService(BatteryManager::class.java)?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)?.coerceIn(0, 100) ?: 100

    private fun isCharging(): Boolean = getSystemService(BatteryManager::class.java)?.isCharging ?: false

    private fun checkBattery() {
        val level = batteryLevel()
        val charging = isCharging()
        if (charging && !wasCharging && tickCount > 1) mascotEvent(MascotEvent.CHARGING)
        wasCharging = charging
        if (!charging && level <= 15 && !lowBatteryWarned) {
            lowBatteryWarned = true
            mascotEvent(MascotEvent.LOW_BATTERY)
        }
        if (charging || level > 20) lowBatteryWarned = false
    }

    // --- Input ---------------------------------------------------------------------------------

    private var downOnScrollableRow = false
    private var downOnClickable = false
    private var downCanScrollUp = false
    private var downCanScrollDown = false

    // Lazy: the detector needs the Activity's resources, which don't exist until onCreate.
    private val gestures by lazy { GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
        override fun onDown(e: MotionEvent): Boolean {
            downOnScrollableRow = hit(root, e.rawX.toInt(), e.rawY.toInt()) { it is HorizontalScrollView }
            downOnClickable = hit(root, e.rawX.toInt(), e.rawY.toInt()) { it.isClickable || it.isLongClickable || it is EditText }
            val sc = currentPage?.scroller
            downCanScrollUp = sc?.canScrollVertically(-1) ?: false
            downCanScrollDown = sc?.canScrollVertically(1) ?: false
            return true
        }

        override fun onFling(e1: MotionEvent?, e2: MotionEvent, vx: Float, vy: Float): Boolean {
            if (search.isOpen || e1 == null) return false
            val dx = e2.x - e1.x
            val dy = e2.y - e1.y
            if (abs(dx) > abs(dy) * 1.5f && abs(dx) > dp(90)) {
                if (prefs.swipeTabs && !downOnScrollableRow) {
                    switchTab(if (dx < 0) 1 else -1)
                    return true
                }
            } else if (abs(dy) > abs(dx) * 1.5f && abs(dy) > dp(90)) {
                if (dy < 0 && !downCanScrollDown) return runGesture(prefs.swipeUp)
                if (dy > 0 && !downCanScrollUp) return runGesture(prefs.swipeDown)
            }
            return false
        }

        override fun onDoubleTap(e: MotionEvent): Boolean = !downOnClickable && runGesture(prefs.doubleTap)

        override fun onLongPress(e: MotionEvent) {
            if (!downOnClickable && !search.isOpen) runGesture(prefs.longPress)
        }
    }) }

    /** True when a visible view under the screen point matches [test]. */
    private fun hit(v: View, x: Int, y: Int, test: (View) -> Boolean): Boolean {
        if (!v.isShown) return false
        val r = Rect()
        if (!v.getGlobalVisibleRect(r) || !r.contains(x, y)) return false
        if (v !== root && v !== content && v !== pageHost && test(v)) return true
        if (v is ViewGroup) for (i in v.childCount - 1 downTo 0) if (hit(v.getChildAt(i), x, y, test)) return true
        return false
    }

    private fun runGesture(action: GestureAction): Boolean {
        when (action) {
            GestureAction.NONE -> return false
            GestureAction.SEARCH -> openSearch()
            GestureAction.APPS -> selectShelf(Shelf.All)
            GestureAction.GAMES -> selectShelf(Shelf.Games)
            GestureAction.FAVORITES -> selectShelf(Shelf.Favorites)
            GestureAction.SETTINGS -> openSettings()
            GestureAction.MASCOT -> mascotEvent(MascotEvent.TAP)
            GestureAction.LAYOUT -> {
                prefs.layoutMode = LayoutMode.entries[(prefs.layoutMode.ordinal + 1) % LayoutMode.entries.size]
                settingsTweaked()
                Toast.makeText(this, prefs.layoutMode.title, Toast.LENGTH_SHORT).show()
            }
        }
        return true
    }

    override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
        if (!search.isOpen) gestures.onTouchEvent(ev)
        return super.dispatchTouchEvent(ev)
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val code = event.keyCode
        val confirm = if (prefs.swapAB) KeyEvent.KEYCODE_BUTTON_B else KeyEvent.KEYCODE_BUTTON_A
        val cancel = if (prefs.swapAB) KeyEvent.KEYCODE_BUTTON_A else KeyEvent.KEYCODE_BUTTON_B
        val typing = currentFocus is EditText

        // Back (key, gesture or the controller's B button) never leaves the home screen.
        if (code == cancel || code == KeyEvent.KEYCODE_BACK) {
            if (event.action == KeyEvent.ACTION_UP && !event.isCanceled) goBack()
            return true
        }
        if (search.isOpen && typing && code != confirm) return super.dispatchKeyEvent(event)

        val handled = when (code) {
            confirm -> {
                if (event.action == KeyEvent.ACTION_UP) {
                    val f = currentFocus
                    when {
                        search.isOpen && typing -> search.launchFirst()
                        f == null -> focusFirst()
                        else -> f.performClick()
                    }
                }
                true
            }
            KeyEvent.KEYCODE_BUTTON_L1 -> { if (event.action == KeyEvent.ACTION_UP) switchTab(-1); true }
            KeyEvent.KEYCODE_BUTTON_R1 -> { if (event.action == KeyEvent.ACTION_UP) switchTab(1); true }
            KeyEvent.KEYCODE_BUTTON_L2 -> { if (event.action == KeyEvent.ACTION_UP) currentPage?.page(-1); true }
            KeyEvent.KEYCODE_BUTTON_R2 -> { if (event.action == KeyEvent.ACTION_UP) currentPage?.page(1); true }
            KeyEvent.KEYCODE_BUTTON_X -> {
                if (event.action == KeyEvent.ACTION_UP) (currentFocus as? AppTile)?.item?.let { AppOptions(this, it).show() }
                true
            }
            KeyEvent.KEYCODE_BUTTON_Y -> {
                if (event.action == KeyEvent.ACTION_UP) (currentFocus as? AppTile)?.item?.let { toggleFavorite(it) }
                true
            }
            KeyEvent.KEYCODE_BUTTON_START, KeyEvent.KEYCODE_MENU -> { if (event.action == KeyEvent.ACTION_UP) openSettings(); true }
            KeyEvent.KEYCODE_BUTTON_SELECT, KeyEvent.KEYCODE_SEARCH -> { if (event.action == KeyEvent.ACTION_UP) openSearch(); true }
            else -> false
        }
        if (handled) return true

        if (event.action == KeyEvent.ACTION_DOWN && prefs.typeToSearch && !search.isOpen && !typing &&
            event.isPrintingKey && code != KeyEvent.KEYCODE_SPACE && event.unicodeChar != 0
        ) {
            openSearch(event.unicodeChar.toChar().toString())
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    private fun focusFirst() {
        currentPage?.firstFocusable()?.requestFocus()
    }

    private fun goBack() {
        when {
            search.isOpen -> search.close()
            widgets.editing -> { widgets.editing = false; rebuildPage(keepState = true) }
            tabIndex != 0 -> selectTab(0)
            else -> currentPage?.scrollToTop()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        widgets.onActivityResult(requestCode, resultCode, data)
    }

    fun statusText(): String {
        val items = repo.items.filter { !it.hidden }
        val games = items.count { it.isGame }
        val today = repo.todayGameMs()
        val parts = mutableListOf("$games games", "${items.size - games} apps")
        if (today > 0) parts += "${com.silkie.launcher.data.Library.formatPlaytime(today)} played today"
        return parts.joinToString("  ·  ")
    }
}
