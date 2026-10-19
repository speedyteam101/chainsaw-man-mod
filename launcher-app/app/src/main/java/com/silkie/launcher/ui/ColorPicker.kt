package com.silkie.launcher.ui

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.SeekBar
import kotlin.math.roundToInt

/** A color dialog: quick swatches, hue/saturation/brightness sliders and a hex field. */
object ColorPicker {
    private val swatches = intArrayOf(
        0xFFFFFFFF.toInt(), 0xFFF3EEF8.toInt(), 0xFFB0B0B8.toInt(), 0xFF6B6B75.toInt(), 0xFF2A2A30.toInt(), 0xFF141218.toInt(), 0xFF000000.toInt(), 0xFFFFF4E6.toInt(),
        0xFFFF5A5F.toInt(), 0xFFFF7A1A.toInt(), 0xFFFFB86B.toInt(), 0xFFFFD54F.toInt(), 0xFFC6E377.toInt(), 0xFF7BD389.toInt(), 0xFF14A37F.toInt(), 0xFF4FC3F7.toInt(),
        0xFF3A6EA5.toInt(), 0xFF5C6BC0.toInt(), 0xFF9575CD.toInt(), 0xFFBA68C8.toInt(), 0xFFE85D9A.toInt(), 0xFFFF9EB5.toInt(), 0xFFFFD9A8.toInt(), 0xFF8D6E63.toInt(),
        0xFF2B2140.toInt(), 0xFF1F3B2C.toInt(), 0xFF0B3D63.toInt(), 0xFF3B120C.toInt(), 0xFF3D0E4F.toInt(), 0xFF0F380F.toInt(), 0xFFECE6D8.toInt(), 0xFFFFF0F5.toInt(),
    )

    fun show(context: Context, pal: Palette, title: String, initial: Int, onPick: (Int) -> Unit) {
        var color = initial or 0xFF000000.toInt()
        var updating = false
        val c = context

        val preview = View(c)
        val hex = EditText(c).apply {
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
            isSingleLine = true
            textSize = 16f
            setTextColor(pal.text)
        }
        val hue = SeekBar(c).apply { max = 360 }
        val sat = SeekBar(c).apply { max = 100 }
        val value = SeekBar(c).apply { max = 100 }

        fun refresh(from: View?) {
            updating = true
            preview.background = GradientDrawable().apply {
                cornerRadius = c.dp(12f)
                setColor(color)
                setStroke(c.dp(1), ColorMath.withAlpha(pal.text, 0.3f))
            }
            if (from !== hex) hex.setText(ColorMath.toHex(color))
            if (from == null || from === hex) {
                val hsv = ColorMath.toHsv(color)
                hue.progress = hsv[0].roundToInt()
                sat.progress = (hsv[1] * 100).roundToInt()
                value.progress = (hsv[2] * 100).roundToInt()
            }
            updating = false
        }

        val listener = object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean) {
                if (updating) return
                color = ColorMath.fromHsv(hue.progress.toFloat(), sat.progress / 100f, value.progress / 100f)
                refresh(seekBar)
            }
            override fun onStartTrackingTouch(seekBar: SeekBar) = Unit
            override fun onStopTrackingTouch(seekBar: SeekBar) = Unit
        }
        hue.setOnSeekBarChangeListener(listener)
        sat.setOnSeekBarChangeListener(listener)
        value.setOnSeekBarChangeListener(listener)
        hex.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: Editable?) {
                if (updating) return
                ColorMath.parseHex(s.toString())?.let {
                    color = it or 0xFF000000.toInt()
                    refresh(hex)
                }
            }
        })

        val col = LinearLayout(c).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(c.dp(20), c.dp(8), c.dp(20), c.dp(8))
        }
        col.addView(c.row(preview.apply { layoutParams = lp(c.dp(56), c.dp(40)) }, hex.apply { layoutParams = lp(0, WRAP, 1f).apply { leftMargin = c.dp(12) } }))

        val perRow = 8
        swatches.toList().chunked(perRow).forEach { chunk ->
            val r = LinearLayout(c).apply { orientation = LinearLayout.HORIZONTAL }
            chunk.forEach { sw ->
                val v = View(c).apply {
                    background = rippleOver(pal.ripple, -1f, GradientDrawable().apply {
                        shape = GradientDrawable.OVAL
                        setColor(sw)
                        setStroke(c.dp(1), ColorMath.withAlpha(Color.GRAY, 0.5f))
                    })
                    isFocusable = true
                    isClickable = true
                    contentDescription = ColorMath.toHex(sw)
                    setOnClickListener {
                        color = sw
                        refresh(null)
                    }
                }
                v.focusHighlight(pal, 1.15f, c.dp(100f))
                r.addView(v, lp(0, c.dp(30), 1f).apply { setMargins(c.dp(3), c.dp(3), c.dp(3), c.dp(3)) })
            }
            col.addView(r, lp(MATCH, WRAP).apply { topMargin = c.dp(4) })
        }

        for ((name, bar) in listOf("Hue" to hue, "Saturation" to sat, "Brightness" to value)) {
            col.addView(c.label(pal, name, 13f, pal.textDim), lp(WRAP, WRAP).apply { topMargin = c.dp(12) })
            col.addView(bar, lp(MATCH, WRAP))
        }
        refresh(null)

        c.dialog(pal)
            .setTitle(title)
            .setView(ScrollView(c).apply { addView(col) })
            .setPositiveButton("Use color") { _, _ -> onPick(color) }
            .setNegativeButton("Cancel", null)
            .show()
        hex.gravity = Gravity.CENTER_VERTICAL
    }
}
