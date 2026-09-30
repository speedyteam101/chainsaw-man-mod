package com.inkframe.editor

import android.app.AlertDialog
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import com.inkframe.App
import com.inkframe.Tool
import com.inkframe.brush.BrushSpec
import com.inkframe.brush.Brushes
import com.inkframe.brush.StrokeEngine
import com.inkframe.export.ExportFormat
import com.inkframe.export.ExportJob
import com.inkframe.export.Exporter
import com.inkframe.model.LayerBlend
import com.inkframe.model.PlayMode
import com.inkframe.model.Project
import com.inkframe.ui.ColorPanel
import com.inkframe.ui.Icon
import com.inkframe.ui.IconButton
import com.inkframe.ui.IconDrawable
import com.inkframe.ui.Popover
import com.inkframe.ui.Segmented
import com.inkframe.ui.Slider
import com.inkframe.ui.Stepper
import com.inkframe.ui.Theme
import com.inkframe.ui.addFull
import com.inkframe.ui.dp
import com.inkframe.ui.label
import com.inkframe.ui.menuRow
import com.inkframe.ui.percent
import com.inkframe.ui.rippleBackground
import com.inkframe.ui.rounded
import com.inkframe.ui.sectionTitle
import com.inkframe.ui.toggleRow
import com.inkframe.ui.vertical
import com.inkframe.util.Bg
import java.io.File
import kotlin.math.roundToInt

/** All the popovers and dialogs of the editor. */
class Panels(private val a: EditorActivity) {
    private val doc get() = a.doc
    private val prefs get() = App.instance.prefs
    private val previews = HashMap<String, Bitmap>()
    private var lastExport: Pair<File, ExportFormat>? = null
    private var popup: PopupWindow? = null

    private fun show(anchor: View, content: View, widthDp: Int = 300, focusable: Boolean = true, onDismiss: (() -> Unit)? = null): PopupWindow {
        popup?.dismiss()
        return Popover.show(anchor, content, widthDp, focusable = focusable, onDismiss = onDismiss).also { popup = it }
    }

    private fun dismiss() {
        popup?.dismiss()
        popup = null
    }

    private fun header(title: String, action: View? = null): View {
        val row = LinearLayout(a).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(a.dp(10), a.dp(4), a.dp(4), a.dp(6))
        }
        row.addView(a.label(title, 17f, Theme.text, bold = true), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        if (action != null) row.addView(action)
        return row
    }

    private fun dialog() = AlertDialog.Builder(a, android.R.style.Theme_Material_Dialog_Alert)

    // --- brushes ---

    fun showBrushes(anchor: View, tool: Tool) {
        val box = a.vertical(8)
        box.addView(header(if (tool == Tool.ERASER) "Eraser" else "Brush Library"))
        val rows = ArrayList<Pair<BrushSpec, View>>()
        val images = HashMap<String, ImageView>()
        fun highlight() {
            val current = a.brushFor(tool).id
            for ((b, row) in rows) row.background = rippleBackground(a.dp(12f), if (b.id == current) rounded(Theme.accentDim, a.dp(12f)) else null)
        }
        for (base in Brushes.all) {
            val row = LinearLayout(a).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(a.dp(10), a.dp(4), a.dp(10), a.dp(4))
                isClickable = true
            }
            val img = ImageView(a).apply { scaleType = ImageView.ScaleType.FIT_CENTER }
            previews[base.id]?.let { img.setImageBitmap(it) }
            images[base.id] = img
            row.addView(a.label(base.name, 14f, Theme.text), LinearLayout.LayoutParams(a.dp(118), ViewGroup.LayoutParams.WRAP_CONTENT))
            row.addView(img, LinearLayout.LayoutParams(0, a.dp(44), 1f))
            row.setOnClickListener {
                if (a.brushFor(tool).id == base.id) {
                    showBrushStudio(anchor, tool)
                } else {
                    a.setBrush(tool, prefs.brush(base.id))
                    highlight()
                }
            }
            rows += base to row
            box.addFull(row)
        }
        highlight()
        box.addView(a.label("Tap the selected brush to adjust it.", 12f, Theme.textDim).apply {
            setPadding(a.dp(10), a.dp(8), a.dp(10), a.dp(4))
        })
        show(anchor, box, 330)
        renderPreviews(images)
    }

    private fun renderPreviews(images: Map<String, ImageView>) {
        val missing = Brushes.all.filter { it.id !in previews }.map { prefs.brush(it.id) }
        if (missing.isEmpty()) return
        val w = a.dp(170)
        val h = a.dp(44)
        Bg.render.execute {
            val engine = StrokeEngine(1, 1)
            for (b in missing) {
                val bmp = engine.renderPreview(b, Color.WHITE, w, h)
                Bg.post {
                    previews[b.id] = bmp
                    images[b.id]?.setImageBitmap(bmp)
                }
            }
        }
    }

    private fun showBrushStudio(anchor: View, tool: Tool) {
        var brush = a.brushFor(tool)
        val box = a.vertical(8)
        val preview = ImageView(a)
        val reset = a.label("Reset", 14f, Theme.accent, bold = true).apply {
            setPadding(a.dp(12), a.dp(8), a.dp(12), a.dp(8))
            background = rippleBackground(a.dp(10f))
        }
        box.addView(header(brush.name, reset))
        box.addFull(preview, a.dp(64))
        fun updatePreview() {
            val b = brush
            Bg.render.execute {
                val bmp = StrokeEngine(1, 1).renderPreview(b, Color.WHITE, a.dp(280), a.dp(64))
                Bg.post { preview.setImageBitmap(bmp) }
            }
        }
        fun apply(b: BrushSpec) {
            brush = b
            a.setBrush(tool, b)
            prefs.saveTunables(b)
            previews.remove(b.id)
        }
        val sliders = ArrayList<Pair<Slider, (BrushSpec) -> Float>>()
        fun slider(title: String, get: (BrushSpec) -> Float, set: (BrushSpec, Float) -> BrushSpec, fmt: (Float) -> String = { percent(it) }) {
            val s = Slider(a, title, get(brush), fmt) { v -> apply(set(brush, v)) }
            s.onCommit = { updatePreview() }
            sliders += s to get
            box.addFull(s)
        }
        box.addView(a.sectionTitle("Stroke"))
        slider("StreamLine", { it.streamline }, { b, v -> b.copy(streamline = v) })
        slider("Spacing", { (it.spacing - 0.01f) / 0.99f }, { b, v -> b.copy(spacing = 0.01f + v * 0.99f) }) { percent(0.01f + it * 0.99f) }
        slider("Taper start", { it.taperStart }, { b, v -> b.copy(taperStart = v) })
        slider("Taper end", { it.taperEnd }, { b, v -> b.copy(taperEnd = v) })
        box.addView(a.sectionTitle("Pressure"))
        slider("Pressure → size", { it.pressureSize }, { b, v -> b.copy(pressureSize = v) })
        slider("Pressure → opacity", { it.pressureOpacity }, { b, v -> b.copy(pressureOpacity = v) })
        box.addView(a.sectionTitle("Texture"))
        slider("Flow", { it.flow }, { b, v -> b.copy(flow = v.coerceAtLeast(0.02f)) })
        slider("Rotation jitter", { it.rotationJitter }, { b, v -> b.copy(rotationJitter = v) })
        slider("Scatter", { it.scatter / 2f }, { b, v -> b.copy(scatter = v * 2f) })
        reset.setOnClickListener {
            prefs.resetTunables(brush.id)
            val fresh = Brushes.byId(brush.id) ?: brush
            brush = fresh
            a.setBrush(tool, fresh)
            previews.remove(fresh.id)
            for ((s, get) in sliders) s.value = get(fresh)
            updatePreview()
        }
        updatePreview()
        show(anchor, box, 330)
    }

    fun showFillSettings(anchor: View) {
        val box = a.vertical(8)
        box.addView(header("Fill"))
        box.addFull(Slider(a, "Threshold", prefs.fillTolerance, { percent(it) }) { prefs.fillTolerance = it })
        box.addFull(Slider(a, "Grow under lines", prefs.fillExpand / 4f, { "${(it * 4).roundToInt()} px" }) {
            prefs.fillExpand = (it * 4).roundToInt()
        })
        box.addFull(a.toggleRow("Use all layers as reference", prefs.fillSampleAll) { prefs.fillSampleAll = it })
        box.addView(a.label("Tap an area to fill it with the current color. With all layers as reference, you can color lines on a separate layer.", 12f, Theme.textDim).apply {
            setPadding(a.dp(10), a.dp(8), a.dp(10), a.dp(4))
        })
        show(anchor, box)
    }

    // --- layers ---

    fun showLayers(anchor: View) {
        val box = a.vertical(8)
        val list = LinearLayout(a).apply { orientation = LinearLayout.VERTICAL }
        val add = IconButton(a, Icon.PLUS).apply {
            setOnClickListener { doc.addLayer() }
        }
        box.addView(header("Layers", add))
        box.addFull(list)
        box.addView(a.label("Layers run through every frame. Tap the selected layer for options.", 12f, Theme.textDim).apply {
            setPadding(a.dp(10), a.dp(8), a.dp(10), a.dp(4))
        })
        fun rebuild() {
            list.removeAllViews()
            val p = doc.project
            for (i in p.layers.indices.reversed()) list.addFull(layerRow(i, anchor))
        }
        rebuild()
        val listener = Document.Listener { c ->
            if (c == Document.Change.STRUCTURE || c == Document.Change.SELECTION || c == Document.Change.PIXELS) rebuild()
        }
        doc.addListener(listener)
        show(anchor, box, 320) { doc.removeListener(listener) }
    }

    private fun layerRow(index: Int, anchor: View): View {
        val p = doc.project
        val layer = p.layers[index]
        val active = index == p.activeLayer
        val row = LinearLayout(a).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(a.dp(8), a.dp(6), a.dp(4), a.dp(6))
            background = rippleBackground(a.dp(12f), if (active) rounded(Theme.accent, a.dp(12f)) else null)
            isClickable = true
        }
        val th = a.dp(40)
        val tw = (th * p.width / p.height.toFloat()).roundToInt().coerceIn(a.dp(28), a.dp(72))
        val thumb = ImageView(a).apply {
            background = rounded(if (p.backgroundVisible) p.backgroundColor else Color.WHITE, a.dp(4f), Theme.divider, a.dp(1))
            scaleType = ImageView.ScaleType.FIT_XY
            doc.store.get(Project.cellKey(doc.currentFrame.id, layer.id))?.let {
                setImageBitmap(Bitmap.createScaledBitmap(it, tw, th, true))
            }
        }
        row.addView(thumb, LinearLayout.LayoutParams(tw, th))
        val names = LinearLayout(a).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(a.dp(10), 0, a.dp(4), 0)
        }
        names.addView(a.label(layer.name, 15f, Theme.text, bold = true).apply { maxLines = 1 })
        val sub = buildList {
            if (layer.opacity < 1f) add(percent(layer.opacity))
            if (layer.blend != LayerBlend.NORMAL) add(layer.blend.label)
            if (layer.alphaLock) add("Alpha lock")
        }.joinToString(" · ")
        if (sub.isNotEmpty()) names.addView(a.label(sub, 12f, if (active) Color.WHITE else Theme.textDim))
        row.addView(names, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        val blend = a.label(layer.blend.short, 14f, Theme.text, bold = true).apply {
            gravity = Gravity.CENTER
            background = rippleBackground(a.dp(8f))
            setOnClickListener { showLayerBlend(this, index) }
        }
        row.addView(blend, LinearLayout.LayoutParams(a.dp(36), a.dp(36)))
        val eye = IconButton(a, if (layer.visible) Icon.EYE else Icon.EYE_OFF, 40).apply {
            setOnClickListener { doc.setLayerVisible(index, !layer.visible) }
        }
        row.addView(eye)
        row.setOnClickListener {
            if (index == doc.project.activeLayer) showLayerMenu(row, index) else doc.selectLayer(index)
        }
        return row
    }

    private var subPopup: PopupWindow? = null

    private fun showSub(anchor: View, content: View, widthDp: Int = 260) {
        subPopup?.dismiss()
        subPopup = Popover.show(anchor, content, widthDp)
    }

    private fun showLayerMenu(anchor: View, index: Int) {
        val p = doc.project
        val layer = p.layers[index]
        val box = a.vertical(6)
        fun item(icon: Icon, title: String, destructive: Boolean = false, action: () -> Unit) {
            box.addFull(a.menuRow(icon, title, destructive) {
                subPopup?.dismiss()
                action()
            })
        }
        item(Icon.RENAME, "Rename") { renameLayer(index) }
        item(Icon.ALPHA_LOCK, if (layer.alphaLock) "Alpha Lock: on" else "Alpha Lock: off") { doc.setAlphaLock(index, !layer.alphaLock) }
        item(Icon.DUPLICATE, "Duplicate") { a.applyTransform(); doc.duplicateLayer(index) }
        if (index > 0) item(Icon.MERGE, "Merge Down") { a.applyTransform(); doc.mergeDown(index) }
        if (index < p.layers.size - 1) item(Icon.CHEVRON_UP, "Move Up") { doc.moveLayer(index, index + 1) }
        if (index > 0) item(Icon.CHEVRON_DOWN, "Move Down") { doc.moveLayer(index, index - 1) }
        item(Icon.CLOSE, "Clear on this frame") { a.applyTransform(); doc.selectLayer(index); doc.clearActiveCell() }
        if (p.layers.size > 1) item(Icon.TRASH, "Delete", destructive = true) { a.applyTransform(); doc.deleteLayer(index) }
        showSub(anchor, box)
    }

    private fun showLayerBlend(anchor: View, index: Int) {
        val layer = doc.project.layers[index]
        val box = a.vertical(6)
        box.addFull(Slider(a, "Opacity", layer.opacity, { percent(it) }) { doc.setLayerOpacity(index, it) })
        box.addView(a.sectionTitle("Blend mode"))
        for (b in LayerBlend.entries) {
            val row = a.label(b.label, 15f, if (b == layer.blend) Theme.accent else Theme.text, bold = b == layer.blend).apply {
                setPadding(a.dp(12), a.dp(10), a.dp(12), a.dp(10))
                background = rippleBackground(a.dp(10f))
                setOnClickListener {
                    doc.setLayerBlend(index, b)
                    subPopup?.dismiss()
                }
            }
            box.addFull(row)
        }
        showSub(anchor, box, 240)
    }

    private fun renameLayer(index: Int) {
        val field = EditText(a).apply {
            setText(doc.project.layers[index].name)
            setSelectAllOnFocus(true)
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
        }
        val wrap = LinearLayout(a).apply {
            setPadding(a.dp(20), a.dp(8), a.dp(20), 0)
            addView(field, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        dialog().setTitle("Rename layer").setView(wrap)
            .setPositiveButton("Rename") { _, _ -> doc.renameLayer(index, field.text.toString().trim()) }
            .setNegativeButton("Cancel", null)
            .show()
    }

    // --- color ---

    fun showColor(anchor: View) {
        val panel = ColorPanel(a, a.color, prefs.recentColors) { c, final -> a.setColor(c, final) }
        show(anchor, panel, 320, focusable = true)
    }

    // --- actions ---

    fun showActions(anchor: View) {
        val box = a.vertical(6)
        box.addView(header("Actions"))
        fun item(icon: Icon, title: String, destructive: Boolean = false, action: () -> Unit) {
            box.addFull(a.menuRow(icon, title, destructive) {
                dismiss()
                action()
            })
        }
        box.addView(a.sectionTitle("Add"))
        item(Icon.IMAGE, "Insert a photo") {
            @Suppress("DEPRECATION")
            a.startActivityForResult(
                Intent(Intent.ACTION_GET_CONTENT).setType("image/*").addCategory(Intent.CATEGORY_OPENABLE),
                EditorActivity.REQUEST_IMPORT,
            )
        }
        box.addView(a.sectionTitle("Layer"))
        item(Icon.FLIP_H, "Flip layer horizontally") { a.applyTransform(); doc.flipActiveCell(true) }
        item(Icon.FLIP_V, "Flip layer vertically") { a.applyTransform(); doc.flipActiveCell(false) }
        item(Icon.CLOSE, "Clear layer on this frame", destructive = true) { a.applyTransform(); doc.clearActiveCell() }
        box.addView(a.sectionTitle("Canvas"))
        item(Icon.FIT, "Fit to screen") { a.canvasView.fitToScreen() }
        item(Icon.FLIP_H, if (a.canvasView.isMirrored) "Unflip canvas view" else "Flip canvas view") { a.canvasView.toggleMirror() }
        item(Icon.SETTINGS, "Background…") { showBackground() }
        box.addView(a.sectionTitle("Share"))
        item(Icon.EXPORT, "Export animation…") { showExport() }
        box.addView(a.sectionTitle("Preferences"))
        box.addFull(a.toggleRow("Draw with finger", prefs.fingerDrawing) { prefs.fingerDrawing = it })
        box.addFull(a.toggleRow("Side bar on the right", prefs.sidebarRight) {
            prefs.sidebarRight = it
            a.placeSideBar()
        })
        box.addFull(a.toggleRow("QuickShape (draw and hold)", prefs.quickShape) { prefs.quickShape = it })
        box.addFull(a.toggleRow("Touch and hold for eyedropper", prefs.holdToPick) { prefs.holdToPick = it })
        box.addView(a.sectionTitle("Help"))
        item(Icon.HELP, "Gestures and tips") { showHelp() }
        show(anchor, box, 310)
    }

    private fun showBackground() {
        val p = doc.project
        val box = LinearLayout(a).apply { orientation = LinearLayout.VERTICAL }
        var picked = p.backgroundColor
        var visible = p.backgroundVisible
        box.addView(a.toggleRow("Show background", visible) {
            visible = it
            doc.setBackground(picked, visible)
        })
        box.addView(ColorPanel(a, picked, emptyList()) { c, final ->
            picked = c
            if (final) doc.setBackground(picked, visible)
        })
        val scroll = ScrollView(a).apply { addView(box) }
        dialog().setTitle("Background").setView(scroll).setPositiveButton("Done") { _, _ -> doc.setBackground(picked, visible) }.show()
    }

    private fun showHelp() {
        val text = """
            Two-finger tap — undo
            Three-finger tap — redo
            Four-finger tap — hide or show the interface
            Pinch, twist and drag with two fingers — zoom, rotate and move the canvas
            Pinch in quickly — fit the canvas to the screen
            Touch and hold — eyedropper
            Draw and hold — QuickShape snaps to a line or ellipse (keep holding to adjust a line)
            Tap the selected brush — Brush Studio
            Tap the selected frame — frame options (hold, duplicate, delete)
            Touch and hold a frame, then drag — reorder frames
            Pen eraser end — erases while held
        """.trimIndent()
        val tv = a.label(text, 15f, Theme.text).apply {
            setLineSpacing(0f, 1.35f)
            setPadding(a.dp(24), a.dp(8), a.dp(24), a.dp(8))
        }
        dialog().setTitle("Gestures").setView(ScrollView(a).apply { addView(tv) }).setPositiveButton("Got it", null).show()
    }

    // --- animation ---

    fun showAnimationSettings(anchor: View) {
        val p = doc.project
        val box = a.vertical(8)
        box.addView(header("Animation"))
        box.addFull(Segmented(a, PlayMode.entries.map { it.label }, p.playMode.ordinal) {
            p.playMode = PlayMode.entries[it]
            doc.settingsChanged()
        })
        box.addFull(Slider(a, "Frames per second", (p.fps - 1) / 59f, { "${1 + (it * 59).roundToInt()}" }) {
            p.fps = 1 + (it * 59).roundToInt()
            doc.settingsChanged()
        })
        box.addView(a.sectionTitle("Onion skin"))
        box.addFull(a.toggleRow("Show onion skin", p.onion.enabled) {
            p.onion.enabled = it
            doc.settingsChanged()
        })
        box.addFull(Slider(a, "Onion skin frames", p.onion.before / 6f, { "${(it * 6).roundToInt()}" }) {
            val n = (it * 6).roundToInt()
            p.onion.before = n
            p.onion.after = n
            doc.settingsChanged()
        })
        box.addFull(Slider(a, "Onion skin opacity", p.onion.opacity, { percent(it) }) {
            p.onion.opacity = it
            doc.settingsChanged()
        })
        box.addFull(a.toggleRow("Color onion skins", p.onion.colored) {
            p.onion.colored = it
            doc.settingsChanged()
        })
        box.addFull(a.toggleRow("Show all layers", p.onion.allLayers) {
            p.onion.allLayers = it
            doc.settingsChanged()
        })
        show(anchor, box, 320)
    }

    fun showFrameOptions(anchor: View, index: Int) {
        val p = doc.project
        val box = a.vertical(6)
        box.addView(header("Frame ${index + 1}"))
        box.addFull(Stepper(a, "Hold (ticks)", p.frames[index].hold, 1, 24) { doc.setHold(index, it) })
        fun item(icon: Icon, title: String, destructive: Boolean = false, action: () -> Unit) {
            box.addFull(a.menuRow(icon, title, destructive) {
                dismiss()
                a.applyTransform()
                action()
            })
        }
        item(Icon.DUPLICATE, "Duplicate") { doc.duplicateFrame(index) }
        item(Icon.CHEVRON_LEFT, "Insert frame before") { doc.insertFrame(index) }
        item(Icon.CHEVRON_RIGHT, "Insert frame after") { doc.insertFrame(index + 1) }
        if (index > 0) item(Icon.CHEVRON_LEFT, "Move earlier") { doc.moveFrame(index, index - 1) }
        if (index < p.frames.size - 1) item(Icon.CHEVRON_RIGHT, "Move later") { doc.moveFrame(index, index + 1) }
        if (p.frames.size > 1) item(Icon.TRASH, "Delete frame", destructive = true) { doc.deleteFrame(index) }
        show(anchor, box, 280)
    }

    // --- export ---

    fun showExport() {
        val p = doc.project
        var format = ExportFormat.MP4
        var scale = 1f
        var repeat = 1
        val box = LinearLayout(a).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(a.dp(12), a.dp(4), a.dp(12), 0)
        }
        val formatRows = ArrayList<Pair<ExportFormat, TextView>>()
        val repeatTitle = a.sectionTitle("Repeat")
        val repeatControl = Segmented(a, listOf("1×", "2×", "4×", "8×"), 0) { repeat = intArrayOf(1, 2, 4, 8)[it] }
        fun refresh() {
            for ((f, tv) in formatRows) {
                val sel = f == format
                tv.setTextColor(if (sel) Theme.accent else Theme.text)
                tv.setCompoundDrawablesRelativeWithIntrinsicBounds(null, null, if (sel) IconDrawable(Icon.CHECK, Theme.accent).apply { setBounds(0, 0, a.dp(20), a.dp(20)) } else null, null)
            }
            val v = if (format == ExportFormat.MP4) View.VISIBLE else View.GONE
            repeatTitle.visibility = v
            repeatControl.visibility = v
        }
        box.addView(a.sectionTitle("Format"))
        for (f in ExportFormat.entries) {
            val tv = a.label(f.label, 16f).apply {
                setPadding(a.dp(10), a.dp(12), a.dp(10), a.dp(12))
                background = rippleBackground(a.dp(10f))
                setOnClickListener {
                    format = f
                    refresh()
                }
            }
            formatRows += f to tv
            box.addView(tv, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        box.addView(a.sectionTitle("Size"))
        val scales = floatArrayOf(1f, 0.5f, 0.25f)
        box.addView(Segmented(a, scales.map { "${(p.width * it).roundToInt()}×${(p.height * it).roundToInt()}" }, 0) { scale = scales[it] })
        box.addView(repeatTitle)
        box.addView(repeatControl)
        refresh()
        dialog().setTitle("Export").setView(ScrollView(a).apply { addView(box) })
            .setPositiveButton("Export") { _, _ -> runExport(format, scale, repeat) }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun runExport(format: ExportFormat, scale: Float, repeat: Int) {
        a.applyTransform()
        val p = doc.project
        val withBg = p.backgroundVisible
        val job = ExportJob(
            format = format,
            name = p.name,
            specs = p.frames.indices.map { doc.frameSpec(it, withBg) },
            holds = p.frames.map { it.hold }.toIntArray(),
            fps = p.fps,
            scale = scale,
            repeat = repeat,
            currentFrame = p.currentFrame,
        )
        val bar = ProgressBar(a, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 1000
            isIndeterminate = false
        }
        val wrap = LinearLayout(a).apply {
            setPadding(a.dp(24), a.dp(16), a.dp(24), a.dp(8))
            addView(bar, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        var cancel: (() -> Unit)? = null
        val progressDialog = dialog().setTitle("Exporting ${format.label}…").setView(wrap).setCancelable(false)
            .setNegativeButton("Cancel") { _, _ -> cancel?.invoke() }
            .show()
        cancel = Exporter.run(a, doc.store, job, { bar.progress = (it * 1000).roundToInt() }) { file, error ->
            if (progressDialog.isShowing) progressDialog.dismiss()
            if (a.isDestroyed) return@run
            when {
                file != null -> {
                    lastExport = file to format
                    showExportDone(file, format)
                }
                error != null -> dialog().setTitle("Export failed").setMessage(error).setPositiveButton("OK", null).show()
            }
        }
    }

    private fun showExportDone(file: File, format: ExportFormat) {
        val size = file.length()
        val sizeText = if (size > 1 shl 20) String.format("%.1f MB", size / 1048576.0) else "${size / 1024} KB"
        dialog().setTitle("Export ready")
            .setMessage("${file.name} · $sizeText")
            .setPositiveButton("Save to device") { _, _ -> saveToGallery(file, format) }
            .setNeutralButton("Share") { _, _ -> a.startActivity(Exporter.shareIntent(a, file, format)) }
            .setNegativeButton("Save as…") { _, _ ->
                @Suppress("DEPRECATION")
                a.startActivityForResult(
                    Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType(format.mime)
                        .putExtra(Intent.EXTRA_TITLE, file.name),
                    EditorActivity.REQUEST_SAVE_FILE,
                )
            }
            .show()
    }

    private fun saveToGallery(file: File, format: ExportFormat) {
        Bg.io.execute {
            val result = try {
                "Saved to " + Exporter.saveToGallery(a, file, format)
            } catch (e: Exception) {
                "Could not save: ${e.message}"
            }
            Bg.post { if (!a.isDestroyed) a.showHint(result) }
        }
    }

    fun onSaveFileChosen(uri: Uri) {
        val (file, _) = lastExport ?: return
        Bg.io.execute {
            val result = try {
                Exporter.copyTo(a, file, uri)
                "Saved"
            } catch (e: Exception) {
                "Could not save: ${e.message}"
            }
            Bg.post { if (!a.isDestroyed) a.showHint(result) }
        }
    }
}
