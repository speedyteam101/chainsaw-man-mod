package com.silkie.launcher.home

import android.content.res.Configuration
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import com.silkie.launcher.data.Library
import com.silkie.launcher.data.LibraryItem
import com.silkie.launcher.data.Shelf
import com.silkie.launcher.data.SortOrder
import com.silkie.launcher.mascot.MascotEvent
import com.silkie.launcher.mascot.MascotView
import com.silkie.launcher.settings.ClockStyle
import com.silkie.launcher.settings.LayoutMode
import com.silkie.launcher.settings.MascotPosition
import com.silkie.launcher.ui.Glyph
import com.silkie.launcher.ui.MATCH
import com.silkie.launcher.ui.SpeechBubble
import com.silkie.launcher.ui.WRAP
import com.silkie.launcher.ui.cardBackground
import com.silkie.launcher.ui.dialog
import com.silkie.launcher.ui.dp
import com.silkie.launcher.ui.focusHighlight
import com.silkie.launcher.ui.glyphButton
import com.silkie.launcher.ui.label
import com.silkie.launcher.ui.lp
import com.silkie.launcher.ui.pillButton
import com.silkie.launcher.ui.rippleOver

/** A built tab page and the hooks the activity needs (focus, scrolling, paging). */
class Page(val view: View) {
    var scroller: ScrollView? = null
    var carousel: HorizontalScrollView? = null
    val tiles = mutableListOf<AppTile>()
    var extraFocusable: View? = null
    var onFocus: ((AppTile) -> Unit)? = null

    fun findTile(key: String) = tiles.firstOrNull { it.item?.key == key }
    fun firstFocusable(): View? = tiles.firstOrNull() ?: extraFocusable

    fun scrollToTop() {
        scroller?.smoothScrollTo(0, 0)
        carousel?.smoothScrollTo(0, 0)
    }

    fun page(dir: Int) {
        scroller?.pageScroll(if (dir > 0) View.FOCUS_DOWN else View.FOCUS_UP)
        carousel?.pageScroll(if (dir > 0) View.FOCUS_RIGHT else View.FOCUS_LEFT)
    }
}

/** Builds the Home tab and the library tabs (grid, list or carousel). */
class Pages(private val a: HomeActivity) {
    private val pal get() = a.pal
    private val prefs get() = a.prefs
    private val landscape get() = a.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

    // --- Home ----------------------------------------------------------------------------------

    fun home(): Page {
        val scroll = ScrollView(a).apply {
            isVerticalScrollBarEnabled = false
            clipToPadding = false
            isFillViewport = true
        }
        val page = Page(scroll)
        page.scroller = scroll
        val col = LinearLayout(a).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(a.dp(16), a.dp(4), a.dp(16), a.dp(24))
            clipChildren = false
            clipToPadding = false
        }
        scroll.addView(col)

        col.addView(hero(page), lp(MATCH, WRAP))

        val items = a.repo.items
        val n = prefs.shelfLength
        if (prefs.showRecentShelf) {
            shelf(col, page, "Jump back in", Shelf.Recent, Library.sort(Library.filter(items, Shelf.Recent), SortOrder.RECENT).take(n))
        }
        if (prefs.showFavoritesShelf) {
            shelf(col, page, "Favorites", Shelf.Favorites, Library.sort(Library.filter(items, Shelf.Favorites), prefs.sortOrder).take(n))
        }
        if (prefs.showGamesShelf) {
            shelf(col, page, "Games", Shelf.Games, Library.sort(Library.filter(items, Shelf.Games), prefs.sortOrder).take(n))
        }
        if (prefs.showAppsShelf) {
            shelf(col, page, "Apps", Shelf.All, Library.sort(Library.filter(items, Shelf.All), prefs.sortOrder).take(n))
        }
        if (prefs.showWidgets) col.addView(a.widgets.section(), lp(MATCH, WRAP).apply { topMargin = a.dp(18) })
        return page
    }

    private fun hero(page: Page): View {
        val showMascot = prefs.mascotPosition != MascotPosition.HIDDEN
        val clock = if (prefs.clockStyle == ClockStyle.LARGE) clockBlock() else null
        val card = if (prefs.showHero) continueCard(page) else null
        val mascot = if (showMascot) mascotBlock() else null

        if (landscape) {
            val left = LinearLayout(a).apply { orientation = LinearLayout.VERTICAL }
            clock?.let { left.addView(it) }
            card?.let { left.addView(it, lp(MATCH, WRAP).apply { topMargin = a.dp(14) }) }
            val row = LinearLayout(a).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                clipChildren = false
            }
            val mascotFirst = prefs.mascotPosition == MascotPosition.LEFT
            if (mascot != null && mascotFirst) row.addView(mascot, lp(0, WRAP, 0.9f))
            row.addView(left, lp(0, WRAP, 1.1f).apply { if (mascot != null) { if (mascotFirst) leftMargin = a.dp(16) else rightMargin = a.dp(16) } })
            if (mascot != null && !mascotFirst) row.addView(mascot, lp(0, WRAP, 0.9f))
            return row
        }
        val colView = LinearLayout(a).apply {
            orientation = LinearLayout.VERTICAL
            clipChildren = false
        }
        clock?.let { colView.addView(it) }
        mascot?.let { colView.addView(it, lp(MATCH, WRAP).apply { topMargin = a.dp(6) }) }
        card?.let { colView.addView(it, lp(MATCH, WRAP).apply { topMargin = a.dp(10) }) }
        return colView
    }

    private fun clockBlock(): View {
        val c = LinearLayout(a).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(a.dp(4), a.dp(8), a.dp(4), 0)
        }
        val time = a.label(pal, "", 58f, pal.text, bold = true)
        c.addView(time)
        a.bigClock = time
        if (prefs.showDate) {
            val date = a.label(pal, "", 17f, pal.textDim)
            c.addView(date, lp(WRAP, WRAP).apply { topMargin = a.dp(4) })
            a.bigDate = date
        }
        if (prefs.showStats) {
            c.addView(a.label(pal, a.statusText(), 13f, pal.textDim), lp(WRAP, WRAP).apply { topMargin = a.dp(8) })
        }
        return c
    }

    private fun mascotBlock(): View {
        val right = prefs.mascotPosition == MascotPosition.RIGHT
        val size = (a.dp(if (landscape) 150 else 130) * prefs.mascotSize / 100f).toInt()
        val mascot = MascotView(a)
        a.styleMascot(mascot)
        mascot.setOnClickListener { a.mascotEvent(MascotEvent.TAP) }
        mascot.focusHighlight(pal, 1.04f, size / 2f)
        val bubble = SpeechBubble(a).apply {
            tailLeft = !right
            style(pal)
        }
        a.heroMascot = mascot
        a.heroBubble = bubble
        val row = LinearLayout(a).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL or if (right) Gravity.END else Gravity.START
            clipChildren = false
        }
        if (right) {
            row.addView(bubble, lp(WRAP, WRAP))
            row.addView(mascot, lp(size, size))
        } else {
            row.addView(mascot, lp(size, size))
            row.addView(bubble, lp(WRAP, WRAP))
        }
        return row
    }

    private fun continueCard(page: Page): View {
        val items = a.repo.items.filter { !it.hidden }
        val last = items.filter { it.isGame && it.lastUsed > 0 }.maxByOrNull { it.lastUsed }
            ?: items.filter { it.lastUsed > 0 }.maxByOrNull { it.lastUsed }
        val card = LinearLayout(a).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(a.dp(14), a.dp(14), a.dp(14), a.dp(14))
            background = a.cardBackground(pal)
            if (pal.cardStyle == com.silkie.launcher.settings.CardStyle.RAISED) elevation = a.dp(6f)
        }
        if (last == null) {
            val texts = LinearLayout(a).apply { orientation = LinearLayout.VERTICAL }
            texts.addView(a.label(pal, "Welcome to ${prefs.mascotName}'s nest", 17f, pal.text, bold = true))
            texts.addView(
                a.label(pal, "Your last game will show up here. Tap the mascot to say hi!", 13f, pal.textDim).apply { maxLines = 3 },
                lp(WRAP, WRAP).apply { topMargin = a.dp(4) },
            )
            card.addView(texts, lp(0, WRAP, 1f))
            val browse = a.pillButton(pal, "Browse games") { a.selectShelf(Shelf.Games) }
            card.addView(browse, lp(WRAP, WRAP).apply { leftMargin = a.dp(10) })
            page.extraFocusable = browse
            return card
        }
        val tile = a.makeTile(last, a.tileSpec(TileKind.GRID).let { TileSpec(TileKind.GRID, a.dp(64), false, 12f, 1, false, it.focusScale, it.animMs) })
        page.tiles += tile
        card.addView(tile)
        val texts = LinearLayout(a).apply { orientation = LinearLayout.VERTICAL }
        texts.addView(a.label(pal, if (last.isGame) "CONTINUE PLAYING" else "LAST USED", 11f, pal.accent, bold = true))
        texts.addView(
            a.label(pal, last.label, 20f, pal.text, bold = true).apply { maxLines = 1; ellipsize = TextUtils.TruncateAt.END },
            lp(WRAP, WRAP).apply { topMargin = a.dp(3) },
        )
        val bits = mutableListOf<String>()
        if (last.playtimeMs > 0) bits += "${Library.formatPlaytime(last.playtimeMs)} played"
        bits += Library.formatAgo(last.lastUsed, System.currentTimeMillis())
        texts.addView(a.label(pal, bits.joinToString(" · "), 13f, pal.textDim), lp(WRAP, WRAP).apply { topMargin = a.dp(3) })
        card.addView(texts, lp(0, WRAP, 1f).apply { leftMargin = a.dp(12) })
        card.addView(a.pillButton(pal, if (last.isGame) "Play" else "Open") { a.launch(last, tile) }, lp(WRAP, WRAP).apply { leftMargin = a.dp(10) })
        return card
    }

    private fun shelf(col: LinearLayout, page: Page, title: String, shelf: Shelf, items: List<LibraryItem>) {
        if (items.isEmpty()) return
        val header = LinearLayout(a).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        header.addView(a.label(pal, title, 18f, pal.text, bold = true), lp(0, WRAP, 1f))
        if (shelf != Shelf.Recent) {
            val more = a.label(pal, "See all ›", 13f, pal.accent, bold = true).apply {
                setPadding(a.dp(10), a.dp(6), a.dp(10), a.dp(6))
                background = rippleOver(pal.ripple, a.dp(100f))
                isFocusable = true
                isClickable = true
                setOnClickListener { a.selectShelf(shelf) }
            }
            more.focusHighlight(pal, 1.05f, a.dp(100f))
            header.addView(more)
        }
        col.addView(header, lp(MATCH, WRAP).apply { topMargin = a.dp(20) })

        val row = LinearLayout(a).apply {
            orientation = LinearLayout.HORIZONTAL
            clipChildren = false
            clipToPadding = false
            setPadding(a.dp(4), a.dp(8), a.dp(4), a.dp(8))
        }
        val spec = a.tileSpec(TileKind.GRID)
        for (item in items) {
            val tile = a.makeTile(item, spec)
            page.tiles += tile
            row.addView(tile, lp(WRAP, WRAP).apply { rightMargin = a.dp(prefs.tileSpacing) })
        }
        val hs = HorizontalScrollView(a).apply {
            isHorizontalScrollBarEnabled = false
            clipChildren = false
            clipToPadding = false
            addView(row)
        }
        col.addView(hs, lp(MATCH, WRAP))
    }

    // --- Library -------------------------------------------------------------------------------

    fun library(shelf: Shelf): Page {
        val items = Library.sort(Library.filter(a.repo.items, shelf), prefs.sortOrder)
        val root = LinearLayout(a).apply {
            orientation = LinearLayout.VERTICAL
            clipChildren = false
        }
        val page = Page(root)

        val header = LinearLayout(a).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(a.dp(18), a.dp(6), a.dp(10), a.dp(4))
        }
        header.addView(a.label(pal, shelf.title, 24f, pal.text, bold = true))
        header.addView(a.label(pal, "${items.size}", 14f, pal.textDim), lp(0, WRAP, 1f).apply { leftMargin = a.dp(10) })
        header.addView(a.glyphButton(pal, Glyph.SORT, "Sort: ${prefs.sortOrder.title}") { chooseSort() })
        val layoutGlyph = when (prefs.layoutMode) {
            LayoutMode.GRID -> Glyph.GRID
            LayoutMode.LIST -> Glyph.LIST
            LayoutMode.CAROUSEL -> Glyph.CAROUSEL
        }
        header.addView(a.glyphButton(pal, layoutGlyph, "Layout: ${prefs.layoutMode.title}") { cycleLayout() })
        root.addView(header, lp(MATCH, WRAP))

        if (items.isEmpty()) {
            root.addView(empty(shelf), lp(MATCH, 0, 1f))
            return page
        }
        val body = when (prefs.layoutMode) {
            LayoutMode.GRID -> grid(page, items)
            LayoutMode.LIST -> list(page, items)
            LayoutMode.CAROUSEL -> carousel(page, items)
        }
        root.addView(body, lp(MATCH, 0, 1f))
        return page
    }

    private fun grid(page: Page, items: List<LibraryItem>): View {
        val spec = a.tileSpec(TileKind.GRID)
        val scroll = ScrollView(a).apply {
            isVerticalScrollBarEnabled = false
            clipToPadding = false
        }
        page.scroller = scroll
        val col = LinearLayout(a).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(a.dp(10), a.dp(6), a.dp(10), a.dp(24))
            clipChildren = false
        }
        scroll.addView(col)
        val usable = a.resources.displayMetrics.widthPixels - a.dp(40)
        val cell = spec.iconPx + a.dp(16) + a.dp(prefs.tileSpacing)
        val columns = if (prefs.gridColumns > 0) prefs.gridColumns else (usable / cell).coerceIn(3, 12)
        items.chunked(columns).forEach { chunk ->
            val row = LinearLayout(a).apply {
                orientation = LinearLayout.HORIZONTAL
                clipChildren = false
            }
            for (i in 0 until columns) {
                val cellView = FrameLayout(a).apply { clipChildren = false }
                chunk.getOrNull(i)?.let { item ->
                    val tile = a.makeTile(item, spec)
                    page.tiles += tile
                    cellView.addView(tile, FrameLayout.LayoutParams(WRAP, WRAP, Gravity.CENTER_HORIZONTAL))
                }
                row.addView(cellView, lp(0, WRAP, 1f))
            }
            col.addView(row, lp(MATCH, WRAP).apply { bottomMargin = a.dp(prefs.tileSpacing) })
        }
        return scroll
    }

    private fun list(page: Page, items: List<LibraryItem>): View {
        val spec = a.tileSpec(TileKind.LIST)
        val scroll = ScrollView(a).apply { isVerticalScrollBarEnabled = false; clipToPadding = false }
        page.scroller = scroll
        val col = LinearLayout(a).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(a.dp(12), a.dp(4), a.dp(12), a.dp(24))
            clipChildren = false
        }
        scroll.addView(col)
        // Two columns when there's room (landscape handhelds, tablets).
        val columns = if (a.resources.configuration.screenWidthDp >= 720) 2 else 1
        items.chunked(columns).forEach { chunk ->
            val row = LinearLayout(a).apply { orientation = LinearLayout.HORIZONTAL }
            for (i in 0 until columns) {
                val item = chunk.getOrNull(i)
                if (item == null) {
                    row.addView(View(a), lp(0, 1, 1f))
                    continue
                }
                val tile = a.makeTile(item, spec)
                page.tiles += tile
                row.addView(tile, lp(0, WRAP, 1f).apply { setMargins(a.dp(2), a.dp(2), a.dp(2), a.dp(2)) })
            }
            col.addView(row, lp(MATCH, WRAP))
        }
        return scroll
    }

    private fun carousel(page: Page, items: List<LibraryItem>): View {
        val spec = a.tileSpec(TileKind.CARD)
        val root = LinearLayout(a).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            clipChildren = false
        }
        val cardW = spec.iconPx + a.dp(36)
        val side = (a.resources.displayMetrics.widthPixels - cardW) / 2
        val row = LinearLayout(a).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            clipChildren = false
            clipToPadding = false
            setPadding(side, a.dp(24), side, a.dp(24))
        }
        val hs = HorizontalScrollView(a).apply {
            isHorizontalScrollBarEnabled = false
            clipChildren = false
            clipToPadding = false
            addView(row)
        }
        page.carousel = hs

        val title = a.label(pal, "", 26f, pal.text, bold = true).apply { gravity = Gravity.CENTER; maxLines = 1; ellipsize = TextUtils.TruncateAt.END }
        val detail = a.label(pal, "", 14f, pal.textDim).apply { gravity = Gravity.CENTER }
        fun show(item: LibraryItem) {
            title.text = item.label
            val bits = mutableListOf(if (item.isGame) "Game" else "App")
            if (item.playtimeMs > 0) bits += "${Library.formatPlaytime(item.playtimeMs)} played"
            if (item.lastUsed > 0) bits += "last played ${Library.formatAgo(item.lastUsed, System.currentTimeMillis())}"
            if (item.favorite) bits += "★ favorite"
            detail.text = bits.joinToString("  ·  ")
        }

        for (item in items) {
            val tile = a.makeTile(item, spec)
            page.tiles += tile
            row.addView(tile, lp(cardW, WRAP).apply { setMargins(a.dp(prefs.tileSpacing), 0, a.dp(prefs.tileSpacing), 0) })
        }
        page.onFocus = { tile ->
            tile.item?.let { show(it) }
            if (tile.parent === row) hs.smoothScrollTo(tile.left + tile.width / 2 - hs.width / 2, 0)
        }
        show(items.first())

        root.addView(View(a), lp(1, 0, 1f))
        root.addView(hs, lp(MATCH, WRAP))
        root.addView(title, lp(MATCH, WRAP).apply { setMargins(a.dp(24), a.dp(4), a.dp(24), 0) })
        root.addView(detail, lp(MATCH, WRAP).apply { setMargins(a.dp(24), a.dp(6), a.dp(24), 0) })
        root.addView(View(a), lp(1, 0, 1f))
        return root
    }

    private fun empty(shelf: Shelf): View {
        val msg = when {
            !a.repo.loaded -> "Loading your apps…"
            shelf == Shelf.Favorites -> "No favorites yet.\nLong-press an app (or press Y) to add one."
            shelf == Shelf.Games -> "No games found.\nLong-press any app and choose \"Mark as game\"."
            shelf is Shelf.Collection -> "This collection is empty.\nLong-press an app and choose \"Collections…\"."
            else -> "Nothing here."
        }
        val col = LinearLayout(a).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }
        if (prefs.mascotPosition != MascotPosition.HIDDEN) {
            val m = MascotView(a)
            a.styleMascot(m)
            m.mood = com.silkie.launcher.mascot.Mood.CURIOUS
            m.setOnClickListener { m.poke() }
            col.addView(m, lp(a.dp(110), a.dp(110)))
        }
        col.addView(a.label(pal, msg, 15f, pal.textDim).apply { gravity = Gravity.CENTER }, lp(WRAP, WRAP).apply { topMargin = a.dp(10) })
        return col
    }

    private fun chooseSort() {
        val orders = SortOrder.entries
        a.dialog(pal)
            .setTitle("Sort by")
            .setSingleChoiceItems(orders.map { it.title }.toTypedArray(), prefs.sortOrder.ordinal) { d, which ->
                prefs.sortOrder = orders[which]
                d.dismiss()
                a.settingsTweaked()
            }
            .show()
    }

    private fun cycleLayout() {
        prefs.layoutMode = LayoutMode.entries[(prefs.layoutMode.ordinal + 1) % LayoutMode.entries.size]
        a.settingsTweaked()
    }
}
