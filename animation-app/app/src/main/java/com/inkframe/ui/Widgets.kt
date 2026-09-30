package com.inkframe.ui

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.drawable.ColorDrawable
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.ScrollView
import android.widget.Switch
import android.widget.TextView
import kotlin.math.roundToInt

/** Square toolbar button showing a line icon; highlighted in the accent color when [active]. */
class IconButton(context: Context, icon: Icon, private val sizeDp: Int = 44) : View(context) {
    private var drawable = IconDrawable(icon, Theme.text)

    var icon: Icon
        get() = drawable.icon
        set(value) {
            if (value == drawable.icon) return
            drawable = IconDrawable(value, drawable.color)
            contentDescription = value.name.lowercase().replace('_', ' ')
            invalidate()
        }

    var active = false
        set(value) {
            field = value
            updateColor()
        }

    init {
        background = rippleBackground(-1f)
        isClickable = true
        isFocusable = true
        contentDescription = icon.name.lowercase().replace('_', ' ')
    }

    override fun setEnabled(enabled: Boolean) {
        super.setEnabled(enabled)
        updateColor()
    }

    private fun updateColor() {
        drawable.color = when {
            !isEnabled -> 0x55FFFFFF
            active -> Theme.accent
            else -> Theme.text
        }
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val s = dp(sizeDp)
        setMeasuredDimension(resolveSize(s, widthMeasureSpec), resolveSize(s, heightMeasureSpec))
    }

    override fun onDraw(canvas: Canvas) {
        val s = dp(24)
        val l = (width - s) / 2
        val t = (height - s) / 2
        drawable.setBounds(l, t, l + s, t + s)
        drawable.draw(canvas)
    }
}

/** The round color well in the top bar. */
class ColorButton(context: Context) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

    var color: Int = Color.BLACK
        set(value) {
            field = value
            invalidate()
        }

    init {
        background = rippleBackground(-1f)
        isClickable = true
        contentDescription = "color"
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val s = dp(44)
        setMeasuredDimension(resolveSize(s, widthMeasureSpec), resolveSize(s, heightMeasureSpec))
    }

    override fun onDraw(canvas: Canvas) {
        val cx = width / 2f
        val cy = height / 2f
        paint.style = Paint.Style.FILL
        paint.color = color
        canvas.drawCircle(cx, cy, dp(12f), paint)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = dp(2f)
        paint.color = Theme.text
        canvas.drawCircle(cx, cy, dp(13f), paint)
    }
}

/**
 * Horizontal slider with a label and a value readout, used in all panels.
 * [format] turns the 0..1 position into the displayed value text.
 */
@SuppressLint("ViewConstructor")
class Slider(
    context: Context,
    private val title: String,
    initial: Float,
    private val format: (Float) -> String,
    private val onChange: (Float) -> Unit,
) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val rect = RectF()

    /** Called once when the finger lifts; use it for work that should not run on every move. */
    var onCommit: ((Float) -> Unit)? = null

    var value = initial.coerceIn(0f, 1f)
        set(v) {
            field = v.coerceIn(0f, 1f)
            invalidate()
        }

    init {
        paint.textSize = dp(13f)
        paint.typeface = Theme.regular
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(
            resolveSize(dp(260), widthMeasureSpec),
            resolveSize(dp(54), heightMeasureSpec),
        )
    }

    private val trackLeft get() = dp(10f)
    private val trackRight get() = width - dp(10f)

    override fun onDraw(canvas: Canvas) {
        paint.style = Paint.Style.FILL
        paint.color = Theme.textDim
        paint.textAlign = Paint.Align.LEFT
        canvas.drawText(title, trackLeft, dp(18f), paint)
        paint.color = Theme.text
        paint.textAlign = Paint.Align.RIGHT
        canvas.drawText(format(value), trackRight, dp(18f), paint)

        val cy = dp(37f)
        val th = dp(4f)
        rect.set(trackLeft, cy - th / 2, trackRight, cy + th / 2)
        paint.color = Theme.divider
        canvas.drawRoundRect(rect, th, th, paint)
        val x = trackLeft + (trackRight - trackLeft) * value
        rect.right = x
        paint.color = Theme.accent
        canvas.drawRoundRect(rect, th, th, paint)
        paint.color = Color.WHITE
        canvas.drawCircle(x, cy, dp(9f), paint)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(e: MotionEvent): Boolean {
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> parent?.requestDisallowInterceptTouchEvent(true)
            MotionEvent.ACTION_MOVE -> Unit
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                onCommit?.invoke(value)
                return true
            }
            else -> return true
        }
        value = (e.x - trackLeft) / (trackRight - trackLeft)
        onChange(value)
        return true
    }
}

/**
 * The tall pill slider in the side bar (brush size and opacity).
 * Shows a bubble with the value while dragging.
 */
@SuppressLint("ViewConstructor")
class SideSlider(
    context: Context,
    private val format: (Float) -> String,
    private val onChange: (Float) -> Unit,
) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val rect = RectF()
    var bubbleHost: ((String?) -> Unit)? = null
    private var downY = 0f
    private var downValue = 0f

    var value = 0.5f
        set(v) {
            field = v.coerceIn(0f, 1f)
            invalidate()
        }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(resolveSize(dp(36), widthMeasureSpec), resolveSize(dp(150), heightMeasureSpec))
    }

    override fun onDraw(canvas: Canvas) {
        val w = dp(10f)
        val cx = width / 2f
        val top = dp(10f)
        val bottom = height - dp(10f)
        rect.set(cx - w / 2, top, cx + w / 2, bottom)
        paint.color = 0xFF4A4A52.toInt()
        canvas.drawRoundRect(rect, w, w, paint)
        val y = bottom - (bottom - top) * value
        rect.set(cx - dp(13f), y - dp(8f), cx + dp(13f), y + dp(8f))
        paint.color = Color.WHITE
        canvas.drawRoundRect(rect, dp(8f), dp(8f), paint)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(e: MotionEvent): Boolean {
        val span = height - dp(20f)
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                parent?.requestDisallowInterceptTouchEvent(true)
                downY = e.y
                downValue = value
                val thumbY = height - dp(10f) - span * value
                // Tapping away from the thumb jumps there; dragging the thumb moves relatively.
                if (kotlin.math.abs(e.y - thumbY) > dp(24f)) {
                    downValue = ((height - dp(10f) - e.y) / span).coerceIn(0f, 1f)
                    value = downValue
                    onChange(value)
                }
                bubbleHost?.invoke(format(value))
            }
            MotionEvent.ACTION_MOVE -> {
                value = downValue + (downY - e.y) / span
                onChange(value)
                bubbleHost?.invoke(format(value))
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> bubbleHost?.invoke(null)
        }
        return true
    }
}

/** A row of mutually exclusive text options. */
@SuppressLint("ViewConstructor")
class Segmented(context: Context, options: List<String>, selected: Int, onSelect: (Int) -> Unit) : LinearLayout(context) {
    private val items = ArrayList<TextView>()

    var selected = selected
        set(v) {
            field = v
            refresh()
        }

    init {
        orientation = HORIZONTAL
        background = rounded(Theme.panelRaised, dp(10f))
        setPadding(dp(3), dp(3), dp(3), dp(3))
        options.forEachIndexed { i, text ->
            val tv = context.label(text, 13f, Theme.text, bold = true).apply {
                gravity = Gravity.CENTER
                setPadding(dp(8), dp(8), dp(8), dp(8))
                setOnClickListener {
                    this@Segmented.selected = i
                    onSelect(i)
                }
            }
            items += tv
            addView(tv, LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        }
        refresh()
    }

    private fun refresh() {
        items.forEachIndexed { i, tv ->
            tv.background = if (i == selected) rounded(Theme.accent, dp(8f)) else null
            tv.setTextColor(if (i == selected) Color.WHITE else Theme.textDim)
        }
    }
}

/** "−  3  +" control for small integers such as frame hold. */
@SuppressLint("ViewConstructor")
class Stepper(context: Context, title: String, value: Int, private val min: Int, private val max: Int, onChange: (Int) -> Unit) :
    LinearLayout(context) {
    private val valueView = context.label("", 15f, Theme.text, bold = true)

    var value = value
        set(v) {
            field = v.coerceIn(min, max)
            valueView.text = field.toString()
        }

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setPadding(dp(10), dp(4), dp(4), dp(4))
        addView(context.label(title, 14f, Theme.text), LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        val minus = IconButton(context, Icon.MINUS, 38).apply {
            setOnClickListener { this@Stepper.value -= 1; onChange(this@Stepper.value) }
        }
        val plus = IconButton(context, Icon.PLUS, 38).apply {
            setOnClickListener { this@Stepper.value += 1; onChange(this@Stepper.value) }
        }
        valueView.gravity = Gravity.CENTER
        addView(minus)
        addView(valueView, LayoutParams(dp(34), ViewGroup.LayoutParams.WRAP_CONTENT))
        addView(plus)
        this.value = value
    }
}

@Suppress("UseSwitchCompatOrMaterialCode")
fun Context.toggleRow(title: String, checked: Boolean, onChange: (Boolean) -> Unit): View {
    val row = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setPadding(dp(10), dp(6), dp(6), dp(6))
    }
    row.addView(label(title, 14f), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
    val sw = Switch(this).apply {
        isChecked = checked
        setOnCheckedChangeListener { _, c -> onChange(c) }
    }
    row.addView(sw)
    row.setOnClickListener { sw.toggle() }
    return row
}

/** A tappable row with an icon and text, used for menus inside popovers. */
fun Context.menuRow(icon: Icon?, title: String, destructive: Boolean = false, onClick: () -> Unit): View {
    val color = if (destructive) Theme.danger else Theme.text
    val row = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setPadding(dp(12), dp(11), dp(12), dp(11))
        background = rippleBackground(dp(10f))
        isClickable = true
        setOnClickListener { onClick() }
    }
    if (icon != null) {
        val iv = View(this)
        iv.background = IconDrawable(icon, color)
        row.addView(iv, LinearLayout.LayoutParams(dp(22), dp(22)).apply { marginEnd = dp(14) })
    }
    row.addView(label(title, 15f, color), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
    return row
}

fun Context.sectionTitle(text: String): TextView = label(text.uppercase(), 11f, Theme.textDim, bold = true).apply {
    letterSpacing = 0.08f
    setPadding(dp(10), dp(12), dp(10), dp(6))
}

fun Context.vertical(padding: Int = 8): LinearLayout = LinearLayout(this).apply {
    orientation = LinearLayout.VERTICAL
    val p = dp(padding)
    setPadding(p, p, p, p)
}

fun LinearLayout.addFull(v: View, heightPx: Int = ViewGroup.LayoutParams.WRAP_CONTENT): View {
    addView(v, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, heightPx))
    return v
}

/**
 * Floating panel anchored to a toolbar button, like the popovers of desktop-class
 * drawing apps. Dismisses on outside touch.
 */
object Popover {
    fun show(
        anchor: View,
        content: View,
        widthDp: Int = 300,
        maxHeightDp: Int = 560,
        focusable: Boolean = false,
        scroll: Boolean = true,
        onDismiss: (() -> Unit)? = null,
    ): PopupWindow {
        val ctx = anchor.context
        val root = anchor.rootView
        val screenW = root.width
        val screenH = root.height
        val margin = ctx.dp(8)
        val width = minOf(ctx.dp(widthDp), screenW - margin * 2)

        val container = FrameLayout(ctx)
        container.background = rounded(Theme.panel, ctx.dp(16f), Theme.divider, ctx.dp(1))
        container.elevation = ctx.dp(16f)
        container.clipToOutline = true
        if (scroll) {
            val sv = ScrollView(ctx)
            sv.isVerticalScrollBarEnabled = false
            sv.addView(content)
            container.addView(sv, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        } else {
            container.addView(content)
        }

        val loc = IntArray(2)
        anchor.getLocationInWindow(loc)
        val below = screenH - (loc[1] + anchor.height) - margin * 2
        val above = loc[1] - margin * 2
        val showBelow = below >= above
        val maxH = minOf(ctx.dp(maxHeightDp), if (showBelow) below else above)
        container.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(maxH, View.MeasureSpec.AT_MOST),
        )
        val h = minOf(container.measuredHeight, maxH)

        val popup = PopupWindow(container, width, h, focusable)
        popup.isOutsideTouchable = true
        popup.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        popup.elevation = ctx.dp(16f)
        popup.setOnDismissListener { onDismiss?.invoke() }

        val x = (loc[0] + anchor.width / 2 - width / 2).coerceIn(margin, maxOf(margin, screenW - width - margin))
        val y = if (showBelow) loc[1] + anchor.height + margin / 2 else loc[1] - h - margin / 2
        popup.showAtLocation(root, Gravity.NO_GRAVITY, x, y)
        anchor.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
        return popup
    }
}

fun percent(v: Float) = "${(v * 100).roundToInt()}%"
