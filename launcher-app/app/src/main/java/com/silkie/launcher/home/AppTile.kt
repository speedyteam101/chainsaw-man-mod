package com.silkie.launcher.home

import android.content.Context
import android.graphics.Color
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.silkie.launcher.data.Library
import com.silkie.launcher.data.LibraryItem
import com.silkie.launcher.ui.ColorMath
import com.silkie.launcher.ui.Palette
import com.silkie.launcher.ui.Glyph
import com.silkie.launcher.ui.GlyphDrawable
import com.silkie.launcher.ui.WRAP
import com.silkie.launcher.ui.cardBackground
import com.silkie.launcher.ui.dp
import com.silkie.launcher.ui.label
import com.silkie.launcher.ui.lp
import com.silkie.launcher.ui.rippleOver
import com.silkie.launcher.ui.rounded

enum class TileKind { GRID, LIST, CARD }

/** How tiles look; built once per page from the settings. */
class TileSpec(
    val kind: TileKind,
    val iconPx: Int,
    val showLabel: Boolean,
    val labelSp: Float,
    val lines: Int,
    val showPlaytime: Boolean,
    val focusScale: Float,
    val animMs: Long,
)

/** One app on screen: icon, name and (optionally) playtime. Focusable for controllers. */
class AppTile(context: Context, val pal: Palette, val spec: TileSpec) : LinearLayout(context) {
    val icon = ImageView(context)
    private val name: TextView
    private val sub: TextView?
    private val star = View(context)
    var item: LibraryItem? = null
        private set

    var onFocused: ((AppTile) -> Unit)? = null

    init {
        isFocusable = true
        isClickable = true
        isLongClickable = true
        clipChildren = false
        clipToPadding = false
        val pad = dp(if (spec.kind == TileKind.CARD) 14 else 6)
        setPadding(pad, pad, pad, pad)
        when (spec.kind) {
            TileKind.LIST -> {
                orientation = HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                background = rippleOver(pal.ripple, dp(pal.corner))
            }
            TileKind.CARD -> {
                orientation = VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                background = context.cardBackground(pal)
            }
            TileKind.GRID -> {
                orientation = VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                background = rippleOver(pal.ripple, dp(pal.corner))
            }
        }
        addView(icon, lp(spec.iconPx, spec.iconPx))

        name = context.label(pal, "", spec.labelSp, pal.text, bold = spec.kind == TileKind.CARD).apply {
            maxLines = spec.lines
            ellipsize = TextUtils.TruncateAt.END
            if (spec.kind != TileKind.LIST) gravity = Gravity.CENTER_HORIZONTAL
        }
        sub = if (spec.showPlaytime || spec.kind == TileKind.LIST) context.label(pal, "", spec.labelSp - 2f, pal.textDim).apply {
            maxLines = 1
            if (spec.kind != TileKind.LIST) gravity = Gravity.CENTER_HORIZONTAL
        } else null

        if (spec.kind == TileKind.LIST) {
            val texts = LinearLayout(context).apply { orientation = VERTICAL }
            texts.addView(name)
            sub?.let { texts.addView(it, lp(WRAP, WRAP).apply { topMargin = dp(3) }) }
            addView(texts, lp(0, WRAP, 1f).apply { leftMargin = dp(14) })
            star.background = GlyphDrawable(Glyph.STAR_FILLED, pal.accent)
            addView(star, lp(dp(18), dp(18)).apply { rightMargin = dp(8) })
        } else if (spec.showLabel || spec.kind == TileKind.CARD) {
            addView(name, lp(if (spec.kind == TileKind.CARD) spec.iconPx + dp(8) else spec.iconPx + dp(16), WRAP).apply { topMargin = dp(6) })
            sub?.let { addView(it, lp(spec.iconPx + dp(16), WRAP).apply { topMargin = dp(2) }) }
        }

        setOnFocusChangeListener { _, has ->
            val s = if (has) spec.focusScale else 1f
            animate().scaleX(s).scaleY(s).translationZ(if (has) dp(6f) else 0f).setDuration(spec.animMs).start()
            foreground = if (has) rounded(Color.TRANSPARENT, dp(pal.corner), pal.accent, dp(2)) else null
            if (has) onFocused?.invoke(this)
        }
    }

    fun bind(item: LibraryItem) {
        this.item = item
        name.text = item.label
        contentDescription = item.label
        star.visibility = if (item.favorite) VISIBLE else GONE
        sub?.text = when {
            item.playtimeMs > 0 -> Library.formatPlaytime(item.playtimeMs)
            spec.kind == TileKind.LIST && item.isGame -> "Game"
            spec.kind == TileKind.LIST -> "App"
            else -> ""
        }
        sub?.visibility = if (sub?.text.isNullOrEmpty() && spec.kind != TileKind.LIST) GONE else VISIBLE
    }

    /** A placeholder while the real icon renders. */
    fun showPlaceholder() {
        icon.setImageDrawable(null)
        icon.background = rounded(ColorMath.withAlpha(pal.text, 0.08f), spec.iconPx * 0.3f)
    }
}
