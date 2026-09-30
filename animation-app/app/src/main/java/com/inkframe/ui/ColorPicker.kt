package com.inkframe.ui

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.GridLayout
import android.widget.LinearLayout

/** Saturation/brightness square with a hue strip below it. */
@SuppressLint("ViewConstructor")
class HsvPickerView(context: Context, initial: Int, private val onColor: (Int, Boolean) -> Unit) : View(context) {
    private val hsv = FloatArray(3)
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val square = RectF()
    private val hueBar = RectF()
    private var dragging = 0 // 1 = square, 2 = hue
    private var squareShaderHue = -1f
    private var satShader: Shader? = null
    private var valShader: Shader? = null
    private var hueShader: Shader? = null

    init {
        setColor(initial)
    }

    fun setColor(c: Int) {
        Color.colorToHSV(c, hsv)
        invalidate()
    }

    val color: Int get() = Color.HSVToColor(hsv)

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val w = resolveSize(dp(280), widthMeasureSpec)
        setMeasuredDimension(w, (w * 0.62f).toInt() + dp(46))
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        val pad = dp(10f)
        square.set(pad, pad, w - pad, h - dp(46f))
        hueBar.set(pad, h - dp(30f), w - pad, h - dp(12f))
        squareShaderHue = -1f
        hueShader = LinearGradient(
            hueBar.left, 0f, hueBar.right, 0f,
            intArrayOf(0xFFFF0000.toInt(), 0xFFFFFF00.toInt(), 0xFF00FF00.toInt(), 0xFF00FFFF.toInt(), 0xFF0000FF.toInt(), 0xFFFF00FF.toInt(), 0xFFFF0000.toInt()),
            null, Shader.TileMode.CLAMP,
        )
        valShader = LinearGradient(0f, square.top, 0f, square.bottom, 0x00000000, 0xFF000000.toInt(), Shader.TileMode.CLAMP)
    }

    override fun onDraw(canvas: Canvas) {
        if (squareShaderHue != hsv[0]) {
            squareShaderHue = hsv[0]
            satShader = LinearGradient(
                square.left, 0f, square.right, 0f,
                Color.WHITE, Color.HSVToColor(floatArrayOf(hsv[0], 1f, 1f)), Shader.TileMode.CLAMP,
            )
        }
        val r = dp(10f)
        paint.style = Paint.Style.FILL
        paint.shader = satShader
        canvas.drawRoundRect(square, r, r, paint)
        paint.shader = valShader
        canvas.drawRoundRect(square, r, r, paint)
        paint.shader = hueShader
        canvas.drawRoundRect(hueBar, hueBar.height() / 2, hueBar.height() / 2, paint)
        paint.shader = null

        // Square thumb.
        val sx = square.left + square.width() * hsv[1]
        val sy = square.top + square.height() * (1f - hsv[2])
        drawThumb(canvas, sx, sy, color)
        // Hue thumb.
        val hx = hueBar.left + hueBar.width() * (hsv[0] / 360f)
        drawThumb(canvas, hx, hueBar.centerY(), Color.HSVToColor(floatArrayOf(hsv[0], 1f, 1f)))
    }

    private fun drawThumb(canvas: Canvas, x: Float, y: Float, fillColor: Int) {
        paint.style = Paint.Style.FILL
        paint.color = fillColor
        canvas.drawCircle(x, y, dp(11f), paint)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = dp(3f)
        paint.color = Color.WHITE
        canvas.drawCircle(x, y, dp(11f), paint)
        paint.strokeWidth = dp(1f)
        paint.color = 0x66000000
        canvas.drawCircle(x, y, dp(12.5f), paint)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(e: MotionEvent): Boolean {
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                parent?.requestDisallowInterceptTouchEvent(true)
                dragging = if (e.y > square.bottom + dp(4f)) 2 else 1
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                onColor(color, true)
                dragging = 0
                return true
            }
        }
        if (dragging == 1) {
            hsv[1] = ((e.x - square.left) / square.width()).coerceIn(0f, 1f)
            hsv[2] = 1f - ((e.y - square.top) / square.height()).coerceIn(0f, 1f)
        } else if (dragging == 2) {
            hsv[0] = (((e.x - hueBar.left) / hueBar.width()).coerceIn(0f, 1f) * 360f).coerceAtMost(359.9f)
        }
        invalidate()
        onColor(color, false)
        return true
    }
}

/** Filled circle swatch; tap to pick. */
@SuppressLint("ViewConstructor")
class Swatch(context: Context, val color: Int, private val sizeDp: Int = 30) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

    var picked = false
        set(v) {
            field = v
            invalidate()
        }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(dp(sizeDp), dp(sizeDp))
    }

    override fun onDraw(canvas: Canvas) {
        val r = width / 2f - dp(3f)
        paint.style = Paint.Style.FILL
        paint.color = color
        canvas.drawCircle(width / 2f, height / 2f, r, paint)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = dp(1f)
        paint.color = 0x33FFFFFF
        canvas.drawCircle(width / 2f, height / 2f, r, paint)
        if (picked) {
            paint.strokeWidth = dp(2f)
            paint.color = Color.WHITE
            canvas.drawCircle(width / 2f, height / 2f, r + dp(2f), paint)
        }
    }
}

object Palettes {
    val default = longArrayOf(
        0xFF000000, 0xFF3A3A3C, 0xFF7C7C80, 0xFFBDBDC2, 0xFFFFFFFF, 0xFFF2E6D8,
        0xFFE53935, 0xFFFF7043, 0xFFFFB300, 0xFFFDD835, 0xFF7CB342, 0xFF2E7D32,
        0xFF26A69A, 0xFF29B6F6, 0xFF1E88E5, 0xFF3949AB, 0xFF8E24AA, 0xFFD81B60,
        0xFF6D4C41, 0xFFA1887F, 0xFFFFCCBC, 0xFFFFE0B2, 0xFFE1BEE7, 0xFFB3E5FC,
    ).map { it.toInt() }.toIntArray()
}

/**
 * The full color panel: current/previous comparison, HSV picker, hex entry,
 * recent colors and a default palette.
 */
@SuppressLint("ViewConstructor")
class ColorPanel(
    context: Context,
    initial: Int,
    recent: List<Int>,
    private val onColor: (Int, Boolean) -> Unit,
) : LinearLayout(context) {
    private val previous = initial
    private val compareNew = View(context)
    private val hexField = EditText(context)
    private var updatingHex = false
    private val picker = HsvPickerView(context, initial) { c, final -> changed(c, final, fromPicker = true) }

    init {
        orientation = VERTICAL
        setPadding(dp(8), dp(8), dp(8), dp(12))

        val header = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(10), dp(2), dp(6), dp(6))
        }
        header.addView(context.label("Color", 17f, Theme.text, bold = true), LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        // Old | new comparison pill, like the color well of pro apps.
        val compare = LinearLayout(context).apply {
            orientation = HORIZONTAL
            background = rounded(Theme.panelRaised, dp(8f))
            clipToOutline = true
        }
        val old = View(context).apply {
            background = rounded(previous, 0f)
            setOnClickListener { setColor(previous, true) }
        }
        compareNew.background = rounded(initial, 0f)
        compare.addView(old, LayoutParams(dp(36), dp(26)))
        compare.addView(compareNew, LayoutParams(dp(36), dp(26)))
        header.addView(compare)
        addView(header)

        addView(picker, LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))

        hexField.apply {
            setTextColor(Theme.text)
            textSize = 15f
            typeface = android.graphics.Typeface.MONOSPACE
            background = rounded(Theme.panelRaised, dp(8f))
            setPadding(dp(12), dp(8), dp(12), dp(8))
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS or InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
            imeOptions = EditorInfo.IME_ACTION_DONE
            isSingleLine = true
            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
                override fun afterTextChanged(s: Editable?) {
                    if (updatingHex) return
                    parseHex(s?.toString())?.let { changed(it, true, fromPicker = false) }
                }
            })
        }
        val hexRow = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(10), dp(4), dp(10), dp(4))
        }
        hexRow.addView(context.label("Hex", 14f, Theme.textDim), LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        hexRow.addView(hexField, LayoutParams(dp(120), ViewGroup.LayoutParams.WRAP_CONTENT))
        addView(hexRow)

        if (recent.isNotEmpty()) {
            addView(context.sectionTitle("Recent"))
            addView(swatchGrid(recent.toIntArray()))
        }
        addView(context.sectionTitle("Palette"))
        addView(swatchGrid(Palettes.default))
        updateHex(initial)
    }

    private fun swatchGrid(colors: IntArray): View {
        val grid = GridLayout(context)
        grid.columnCount = 8
        grid.setPadding(dp(6), 0, dp(6), 0)
        for (c in colors) {
            val s = Swatch(context, c, 34)
            s.setOnClickListener { setColor(c, true) }
            grid.addView(s)
        }
        return grid
    }

    private fun setColor(c: Int, final: Boolean) {
        picker.setColor(c)
        changed(c, final, fromPicker = false)
    }

    private fun changed(c: Int, final: Boolean, fromPicker: Boolean) {
        compareNew.background = rounded(c, 0f)
        if (fromPicker || !hexField.hasFocus()) updateHex(c)
        if (!fromPicker) picker.setColor(c)
        onColor(c, final)
    }

    private fun updateHex(c: Int) {
        updatingHex = true
        hexField.setText(String.format("%06X", c and 0xFFFFFF))
        updatingHex = false
    }

    companion object {
        fun parseHex(s: String?): Int? {
            val t = s?.trim()?.removePrefix("#") ?: return null
            if (t.length != 6) return null
            return t.toLongOrNull(16)?.let { (0xFF000000 or it).toInt() }
        }
    }
}
