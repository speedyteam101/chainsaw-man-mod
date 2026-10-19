package com.silkie.launcher.home

import android.app.SearchManager
import android.content.Intent
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import com.silkie.launcher.data.Library
import com.silkie.launcher.data.LibraryItem
import com.silkie.launcher.mascot.MascotEvent
import com.silkie.launcher.ui.ColorMath
import com.silkie.launcher.ui.Glyph
import com.silkie.launcher.ui.GlyphDrawable
import com.silkie.launcher.ui.MATCH
import com.silkie.launcher.ui.WRAP
import com.silkie.launcher.ui.dp
import com.silkie.launcher.ui.label
import com.silkie.launcher.ui.lp
import com.silkie.launcher.ui.pillButton
import com.silkie.launcher.ui.rounded

/** Full-screen search over every app, with "search the web" as a fallback. */
class SearchPanel(private val a: HomeActivity) : FrameLayout(a) {
    private val field = EditText(a)
    private val results = LinearLayout(a).apply {
        orientation = LinearLayout.VERTICAL
        clipChildren = false
    }
    private val scroll = ScrollView(a).apply {
        isVerticalScrollBarEnabled = false
        clipToPadding = false
        addView(results)
    }
    private var found = listOf<LibraryItem>()
    private var complainedFor = ""

    val isOpen get() = visibility == View.VISIBLE

    init {
        visibility = View.GONE
        isClickable = true // swallow touches meant for the page below
        val col = LinearLayout(a).apply { orientation = LinearLayout.VERTICAL }
        val bar = LinearLayout(a).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        bar.addView(View(a).apply { tag = "glyph" }, lp(a.dp(22), a.dp(22)).apply { leftMargin = a.dp(14) })
        field.apply {
            hint = "Search apps and games"
            isSingleLine = true
            imeOptions = EditorInfo.IME_ACTION_GO
            background = null
            setPadding(a.dp(12), a.dp(14), a.dp(12), a.dp(14))
            setOnEditorActionListener { _, actionId, event ->
                if (actionId == EditorInfo.IME_ACTION_GO || event?.keyCode == KeyEvent.KEYCODE_ENTER) {
                    launchFirst()
                    true
                } else false
            }
            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
                override fun afterTextChanged(s: Editable?) = update()
            })
        }
        bar.addView(field, lp(0, WRAP, 1f))
        bar.tag = "bar"
        col.addView(bar, lp(MATCH, WRAP).apply { setMargins(a.dp(16), a.dp(14), a.dp(16), a.dp(8)) })
        col.addView(scroll, lp(MATCH, 0, 1f))
        addView(col, LayoutParams(MATCH, MATCH))
    }

    fun applyStyle() {
        val pal = a.pal
        setBackgroundColor(ColorMath.withAlpha(pal.bg, 0.94f))
        field.setTextColor(pal.text)
        field.setHintTextColor(pal.textDim)
        field.typeface = pal.typeface
        field.textSize = 18f * pal.fontScale
        findViewWithTag<View>("bar")?.background = rounded(pal.cardRaised, a.dp(100f))
        findViewWithTag<View>("glyph")?.background = GlyphDrawable(Glyph.SEARCH, pal.textDim)
    }

    fun open(initial: String) {
        visibility = View.VISIBLE
        alpha = 0f
        animate().alpha(1f).setDuration(a.prefs.duration(150)).start()
        field.setText(initial)
        field.setSelection(field.text.length)
        field.requestFocus()
        update()
        post { a.getSystemService(InputMethodManager::class.java)?.showSoftInput(field, InputMethodManager.SHOW_IMPLICIT) }
    }

    fun close() {
        a.getSystemService(InputMethodManager::class.java)?.hideSoftInputFromWindow(field.windowToken, 0)
        field.setText("")
        visibility = View.GONE
        results.removeAllViews()
    }

    fun launchFirst() {
        val first = found.firstOrNull()
        if (first != null) {
            close()
            a.launch(first, null)
        } else if (field.text.isNotBlank()) {
            webSearch(field.text.toString())
        }
    }

    private fun webSearch(q: String) {
        val intent = Intent(Intent.ACTION_WEB_SEARCH).putExtra(SearchManager.QUERY, q)
        runCatching { a.startActivity(intent) }
        close()
    }

    private fun update() {
        val q = field.text.toString()
        results.removeAllViews()
        found = Library.search(a.repo.items, q)
        if (q.isBlank()) {
            results.addView(a.label(a.pal, "Type to find an app. Tip: on a keyboard you can just start typing on the home screen.", 14f, a.pal.textDim).apply {
                gravity = Gravity.CENTER
                setPadding(a.dp(24), a.dp(30), a.dp(24), 0)
            }, lp(MATCH, WRAP))
            return
        }
        val spec = a.tileSpec(TileKind.GRID)
        val columns = ((a.resources.displayMetrics.widthPixels - a.dp(32)) / (spec.iconPx + a.dp(28))).coerceIn(3, 10)
        found.chunked(columns).forEach { chunk ->
            val row = LinearLayout(a).apply { orientation = LinearLayout.HORIZONTAL; clipChildren = false }
            for (i in 0 until columns) {
                val cell = FrameLayout(a).apply { clipChildren = false }
                chunk.getOrNull(i)?.let { item ->
                    val tile = a.makeTile(item, spec)
                    tile.setOnClickListener {
                        close()
                        a.launch(item, null)
                    }
                    cell.addView(tile, LayoutParams(WRAP, WRAP, Gravity.CENTER_HORIZONTAL))
                }
                row.addView(cell, lp(0, WRAP, 1f))
            }
            results.addView(row, lp(MATCH, WRAP).apply { setMargins(a.dp(8), a.dp(4), a.dp(8), a.dp(4)) })
        }
        if (found.isEmpty() && q.trim().length >= 3 && q != complainedFor) {
            complainedFor = q
            a.mascotEvent(MascotEvent.SEARCH_EMPTY)
        }
        val web = a.pillButton(a.pal, "Search the web for “${q.trim()}”", filled = found.isEmpty()) { webSearch(q) }
        results.addView(web, lp(WRAP, WRAP).apply {
            gravity = Gravity.CENTER_HORIZONTAL
            topMargin = a.dp(18)
        })
    }
}
