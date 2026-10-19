package com.silkie.launcher.ui

import android.app.AlertDialog
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.SoundEffectConstants
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.silkie.launcher.settings.CardStyle
import com.silkie.launcher.settings.Prefs

/** Colors and type resolved from the user's theme settings. Rebuilt whenever settings change. */
class Palette(p: Prefs) {
    val bg = p.bgColor
    val bg2 = p.bgColor2
    val card = p.cardColor
    val text = p.textColor
    val accent = p.accentColor
    val textDim = ColorMath.withAlpha(text, 0.62f)
    val onAccent = ColorMath.readableOn(accent)
    val isLight = ColorMath.isLight(bg)
    val cardStyle = p.cardStyle
    val corner = p.cornerRadius.toFloat()
    val divider = ColorMath.withAlpha(text, 0.12f)
    val ripple = ColorMath.withAlpha(text, 0.18f)

    /** Card fill: glass cards are see-through so the background shows. */
    val cardFill: Int = when (cardStyle) {
        CardStyle.GLASS -> ColorMath.withAlpha(card, 0.62f)
        CardStyle.OUTLINED -> ColorMath.withAlpha(card, 0.35f)
        else -> card
    }
    val cardRaised = ColorMath.mix(card, text, 0.08f)

    val typeface: Typeface = Typeface.create(p.font.family, Typeface.NORMAL)
    val typefaceBold: Typeface = Typeface.create(p.font.family, Typeface.BOLD)
    val fontScale = p.fontScale / 100f
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
fun rippleOver(color: Int, radius: Float, content: Drawable? = null): Drawable {
    val mask = if (radius < 0) null else rounded(Color.WHITE, radius)
    return RippleDrawable(ColorStateList.valueOf(color), content, mask)
}

/** A card background in the current card style. */
fun Context.cardBackground(pal: Palette, radius: Float = dp(pal.corner)): Drawable {
    val stroke = if (pal.cardStyle == CardStyle.OUTLINED || pal.cardStyle == CardStyle.GLASS) dp(1) else 0
    val strokeColor = if (pal.cardStyle == CardStyle.OUTLINED) ColorMath.withAlpha(pal.text, 0.22f) else ColorMath.withAlpha(pal.text, 0.08f)
    return rippleOver(pal.ripple, radius, rounded(pal.cardFill, radius, strokeColor, stroke))
}

fun Context.label(pal: Palette, text: CharSequence, sizeSp: Float = 14f, color: Int = pal.text, bold: Boolean = false): TextView =
    TextView(this).apply {
        this.text = text
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp * pal.fontScale)
        setTextColor(color)
        typeface = if (bold) pal.typefaceBold else pal.typeface
        includeFontPadding = false
    }

/** A pill button, e.g. "Play" on the hero card. */
fun Context.pillButton(pal: Palette, text: String, filled: Boolean = true, onClick: (View) -> Unit): TextView =
    label(pal, text, 14f, if (filled) pal.onAccent else pal.text, bold = true).apply {
        gravity = Gravity.CENTER
        setPadding(dp(18), dp(10), dp(18), dp(10))
        val fill = if (filled) pal.accent else ColorMath.withAlpha(pal.text, 0.1f)
        background = rippleOver(pal.ripple, dp(100f), rounded(fill, dp(100f)))
        isClickable = true
        isFocusable = true
        focusHighlight(pal)
        setOnClickListener(onClick)
    }

/** Accent ring and a little pop while focused by a controller or keyboard. */
fun View.focusHighlight(pal: Palette, scale: Float = 1.06f, radius: Float = -1f) {
    val r = if (radius < 0) dp(pal.corner) else radius
    setOnFocusChangeListener { v, has ->
        v.animate().scaleX(if (has) scale else 1f).scaleY(if (has) scale else 1f).setDuration(120).start()
        v.foreground = if (has) rounded(Color.TRANSPARENT, r, pal.accent, dp(2)) else null
    }
}

fun View.feedback(prefs: Prefs, sound: Int = SoundEffectConstants.CLICK) {
    if (prefs.haptics) performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
    if (prefs.sounds) playSoundEffect(sound)
}

fun Context.row(vararg children: View, gravity: Int = Gravity.CENTER_VERTICAL): LinearLayout =
    LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        this.gravity = gravity
        children.forEach { addView(it) }
    }

fun Context.column(vararg children: View): LinearLayout =
    LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        children.forEach { addView(it) }
    }

fun lp(w: Int, h: Int, weight: Float = 0f) = LinearLayout.LayoutParams(w, h, weight)
const val MATCH = LinearLayout.LayoutParams.MATCH_PARENT
const val WRAP = LinearLayout.LayoutParams.WRAP_CONTENT

fun Context.dialog(pal: Palette): AlertDialog.Builder = AlertDialog.Builder(
    this,
    if (pal.isLight) android.R.style.Theme_Material_Light_Dialog_Alert else android.R.style.Theme_Material_Dialog_Alert,
)
