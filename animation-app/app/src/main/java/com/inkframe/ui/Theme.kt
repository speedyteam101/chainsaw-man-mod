package com.inkframe.ui

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.TextView

/** The dark, minimal look: near-black chrome, soft grey text and one blue accent. */
object Theme {
    const val workspace = 0xFF141416.toInt()
    const val bar = 0xF01E1E21.toInt()
    const val panel = 0xFF26262A.toInt()
    const val panelRaised = 0xFF303035.toInt()
    const val divider = 0xFF3A3A40.toInt()
    const val text = 0xFFEDEDF0.toInt()
    const val textDim = 0xFF9A9AA3.toInt()
    const val accent = 0xFF2F8BFF.toInt()
    const val accentDim = 0x332F8BFF
    const val danger = 0xFFFF5A5F.toInt()
    const val onionBefore = 0xFFFF3B47.toInt()
    const val onionAfter = 0xFF2BD96B.toInt()
    const val ripple = 0x33FFFFFF

    val bold: Typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
    val regular: Typeface = Typeface.create("sans-serif", Typeface.NORMAL)
}

fun Context.dp(v: Float): Float = v * resources.displayMetrics.density
fun Context.dp(v: Int): Int = (v * resources.displayMetrics.density + 0.5f).toInt()
fun View.dp(v: Float): Float = context.dp(v)
fun View.dp(v: Int): Int = context.dp(v)

fun rounded(color: Int, radius: Float, strokeColor: Int = 0, strokeWidth: Int = 0): GradientDrawable =
    GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        cornerRadius = radius
        setColor(color)
        if (strokeWidth > 0) setStroke(strokeWidth, strokeColor)
    }

fun oval(color: Int): GradientDrawable = GradientDrawable().apply {
    shape = GradientDrawable.OVAL
    setColor(color)
}

/** Ripple feedback bounded by a rounded rect (or unbounded circle when [radius] < 0). */
fun rippleBackground(radius: Float, content: Drawable? = null): Drawable {
    val mask = if (radius < 0) null else rounded(Color.WHITE, radius)
    return RippleDrawable(ColorStateList.valueOf(Theme.ripple), content, mask)
}

fun Context.label(text: String, sizeSp: Float = 14f, color: Int = Theme.text, bold: Boolean = false): TextView =
    TextView(this).apply {
        this.text = text
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        setTextColor(color)
        typeface = if (bold) Theme.bold else Theme.regular
        includeFontPadding = false
    }

/** A text button with a ripple, e.g. "Export" in the timeline bar. */
fun Context.textButton(text: String, sizeSp: Float = 14f, color: Int = Theme.text, onClick: (View) -> Unit): TextView =
    label(text, sizeSp, color, bold = true).apply {
        gravity = Gravity.CENTER
        val h = dp(12)
        val v = dp(8)
        setPadding(h, v, h, v)
        background = rippleBackground(dp(10f))
        isClickable = true
        isFocusable = true
        setOnClickListener(onClick)
    }

/** A filled pill button for primary actions. */
fun Context.pillButton(text: String, fill: Int = Theme.accent, onClick: (View) -> Unit): TextView =
    label(text, 15f, Color.WHITE, bold = true).apply {
        gravity = Gravity.CENTER
        setPadding(dp(18), dp(11), dp(18), dp(11))
        background = rippleBackground(dp(22f), rounded(fill, dp(22f)))
        isClickable = true
        setOnClickListener(onClick)
    }

fun Context.dividerView(): View = View(this).apply { background = ColorDrawable(Theme.divider) }
