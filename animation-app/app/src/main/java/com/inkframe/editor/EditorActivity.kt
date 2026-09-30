package com.inkframe.editor

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BlendMode
import android.graphics.Canvas
import android.graphics.ImageDecoder
import android.graphics.Paint
import android.graphics.Rect
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import com.inkframe.App
import com.inkframe.Tool
import com.inkframe.brush.BrushSpec
import com.inkframe.brush.StrokeEngine
import com.inkframe.history.PixelCommand
import com.inkframe.model.CellStore
import com.inkframe.render.Compositor
import com.inkframe.tools.FloodFill
import com.inkframe.ui.ColorButton
import com.inkframe.ui.Icon
import com.inkframe.ui.IconButton
import com.inkframe.ui.SideSlider
import com.inkframe.ui.Theme
import com.inkframe.ui.dp
import com.inkframe.ui.label
import com.inkframe.ui.percent
import com.inkframe.ui.rounded
import com.inkframe.ui.textButton
import com.inkframe.util.Bg
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * The editor: canvas in the middle, tools along the top, size/opacity/undo on the side,
 * and the animation timeline at the bottom.
 */
class EditorActivity : Activity(), CanvasHost, Document.Listener, Player.Listener, TimelineView.Callbacks {

    private val app get() = application as App
    private val prefs get() = app.prefs

    override lateinit var doc: Document
        private set
    private var loaded = false

    lateinit var canvasView: CanvasView
        private set
    lateinit var timeline: TimelineView
        private set
    private lateinit var player: Player
    lateinit var panels: Panels
        private set

    private lateinit var root: FrameLayout
    private lateinit var topBar: LinearLayout
    private lateinit var sideBar: LinearLayout
    private lateinit var bottomBar: LinearLayout
    private lateinit var transformBar: LinearLayout
    private lateinit var hintView: TextView
    private lateinit var bubbleView: TextView
    private lateinit var frameLabel: TextView
    private lateinit var sizeSlider: SideSlider
    private lateinit var opacitySlider: SideSlider
    private lateinit var undoButton: IconButton
    private lateinit var redoButton: IconButton
    private lateinit var pickButton: IconButton
    private lateinit var playButton: IconButton
    private lateinit var colorButton: ColorButton
    private val toolButtons = HashMap<Tool, IconButton>()
    lateinit var layersButton: IconButton
        private set
    lateinit var actionsButton: IconButton
        private set
    lateinit var settingsButton: View
        private set
    lateinit var exportButton: View
        private set

    override var tool = Tool.BRUSH
        private set
    var color = 0xFF1B1B1F.toInt()
        private set
    private val brushes = HashMap<Tool, BrushSpec>()
    /** Display cutout (camera hole) insets; the bars are padded to stay clear of it. */
    private val cutout = Rect()
    private var fullscreen = false
    private var fillBusy = false
    private val hideHint = Runnable { hintView.animate().alpha(0f).setDuration(250).start() }

    // --- lifecycle ---

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.statusBarColor = Theme.workspace
        window.navigationBarColor = Theme.workspace
        root = FrameLayout(this)
        root.setBackgroundColor(Theme.workspace)
        root.addView(ProgressBar(this), FrameLayout.LayoutParams(dp(48), dp(48), Gravity.CENTER))
        setContentView(root)
        hideSystemBars()

        val id = intent.getStringExtra(EXTRA_PROJECT_ID)
        if (id == null) {
            finish()
            return
        }
        color = prefs.color
        Bg.io.execute {
            val project = try {
                app.repo.load(id)
            } catch (e: Exception) {
                null
            }
            Bg.post {
                if (isFinishing || isDestroyed) return@post
                if (project == null) {
                    finish()
                    return@post
                }
                val store = CellStore(app.repo.cellsDir(project.id), project.width, project.height, app.cellBudget)
                doc = Document(project, app.repo, store, app.historyBudget)
                buildUi()
                loaded = true
            }
        }
    }

    override fun onPause() {
        super.onPause()
        if (!loaded) return
        if (player.isPlaying) player.stop()
        applyTransform()
        // Saving here (not only in onDestroy) queues the save before the gallery reloads its list.
        if (doc.unsaved) doc.save()
    }

    override fun onDestroy() {
        super.onDestroy()
        if (!loaded) return
        app.onLowMemory = null
        if (isFinishing) doc.close()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) hideSystemBars()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (loaded && player.isPlaying) {
            player.stop()
            return
        }
        if (loaded && canvasView.transform != null) {
            cancelTransform()
            return
        }
        @Suppress("DEPRECATION")
        super.onBackPressed()
    }

    private fun hideSystemBars() {
        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let {
                it.hide(WindowInsets.Type.systemBars())
                it.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN)
        }
    }

    // --- UI construction ---

    private fun buildUi() {
        root.removeAllViews()
        brushes[Tool.BRUSH] = prefs.brush(prefs.brushId(Tool.BRUSH))
        brushes[Tool.ERASER] = prefs.brush(prefs.brushId(Tool.ERASER) ?: "monoline")

        canvasView = CanvasView(this, this)
        root.addView(canvasView, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))

        player = Player(doc, app.playbackBudget, this)
        timeline = TimelineView(this, doc, this)
        panels = Panels(this)

        buildTopBar()
        buildSideBar()
        buildBottomBar()
        buildTransformBar()

        hintView = label("", 14f, Theme.text, bold = true).apply {
            background = rounded(0xE6303035.toInt(), dp(18f))
            setPadding(dp(16), dp(9), dp(16), dp(9))
            alpha = 0f
        }
        root.addView(hintView, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply {
            topMargin = dp(64)
        })
        bubbleView = label("", 15f, Theme.text, bold = true).apply {
            background = rounded(0xF0303035.toInt(), dp(12f))
            setPadding(dp(14), dp(8), dp(14), dp(8))
            visibility = View.GONE
        }
        root.addView(bubbleView, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER_VERTICAL or if (prefs.sidebarRight) Gravity.END else Gravity.START).apply {
            marginStart = dp(64)
            marginEnd = dp(64)
        })

        root.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ -> updateSafeInsets() }
        root.setOnApplyWindowInsetsListener { _, insets ->
            val c = insets.displayCutout
            cutout.set(c?.safeInsetLeft ?: 0, c?.safeInsetTop ?: 0, c?.safeInsetRight ?: 0, c?.safeInsetBottom ?: 0)
            applyCutout()
            insets
        }
        root.requestApplyInsets()
        doc.addListener(this)
        app.onLowMemory = {
            doc.store.trim()
            player.clear()
            timeline.thumbs.clear()
        }
        selectTool(Tool.BRUSH)
        refreshAll()
    }

    private fun buildTopBar() {
        topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(Theme.bar)
            setPadding(dp(6), 0, dp(6), 0)
            elevation = dp(4f)
            isClickable = true
        }
        val gallery = IconButton(this, Icon.GALLERY).apply { setOnClickListener { finish() } }
        actionsButton = IconButton(this, Icon.ACTIONS).apply { setOnClickListener { panels.showActions(it) } }
        val transformBtn = IconButton(this, Icon.TRANSFORM).apply {
            setOnClickListener { selectTool(if (tool == Tool.TRANSFORM) Tool.BRUSH else Tool.TRANSFORM) }
        }
        toolButtons[Tool.TRANSFORM] = transformBtn
        topBar.addView(gallery)
        topBar.addView(actionsButton)
        topBar.addView(transformBtn)
        topBar.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))

        val brush = IconButton(this, Icon.BRUSH).apply { setOnClickListener { toolTapped(Tool.BRUSH, it) } }
        val eraser = IconButton(this, Icon.ERASER).apply { setOnClickListener { toolTapped(Tool.ERASER, it) } }
        val fill = IconButton(this, Icon.FILL).apply { setOnClickListener { toolTapped(Tool.FILL, it) } }
        toolButtons[Tool.BRUSH] = brush
        toolButtons[Tool.ERASER] = eraser
        toolButtons[Tool.FILL] = fill
        layersButton = IconButton(this, Icon.LAYERS).apply { setOnClickListener { panels.showLayers(it) } }
        colorButton = ColorButton(this).apply {
            color = this@EditorActivity.color
            setOnClickListener { panels.showColor(it) }
        }
        topBar.addView(brush)
        topBar.addView(eraser)
        topBar.addView(fill)
        topBar.addView(layersButton)
        topBar.addView(colorButton)
        root.addView(topBar, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52), Gravity.TOP))
    }

    private fun buildSideBar() {
        sideBar = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = rounded(Theme.bar, dp(22f))
            setPadding(dp(3), dp(10), dp(3), dp(6))
            elevation = dp(4f)
            isClickable = true
        }
        sizeSlider = SideSlider(this, { v -> "${sizeFromSlider(v).roundToInt()} px" }) { v ->
            val b = currentBrush() ?: return@SideSlider
            prefs.setSize(tool, b, sizeFromSlider(v))
        }
        opacitySlider = SideSlider(this, { v -> percent(v) }) { v ->
            val b = currentBrush() ?: return@SideSlider
            prefs.setOpacity(tool, b, v.coerceAtLeast(0.01f))
        }
        val bubble: (String?) -> Unit = { text ->
            if (text == null) bubbleView.visibility = View.GONE else {
                bubbleView.text = text
                bubbleView.visibility = View.VISIBLE
            }
        }
        sizeSlider.bubbleHost = bubble
        opacitySlider.bubbleHost = bubble
        pickButton = IconButton(this, Icon.EYEDROPPER, 40).apply {
            setOnClickListener {
                canvasView.eyedropperArmed = !canvasView.eyedropperArmed
                active = canvasView.eyedropperArmed
                if (active) showHint("Touch the canvas to pick a color")
            }
        }
        undoButton = IconButton(this, Icon.UNDO, 40).apply { setOnClickListener { undo() } }
        redoButton = IconButton(this, Icon.REDO, 40).apply { setOnClickListener { redo() } }
        sideBar.addView(sizeSlider)
        sideBar.addView(pickButton)
        sideBar.addView(opacitySlider)
        sideBar.addView(View(this), LinearLayout.LayoutParams(1, dp(6)))
        sideBar.addView(undoButton)
        sideBar.addView(redoButton)
        root.addView(sideBar, sideBarParams())
        sizeSideBar()
    }

    /** Side-bar slider height in dp, chosen so the whole bar fits between the top bar and the timeline. */
    private var sliderDp = 150

    private fun availableSideDp(): Int {
        val d = resources.displayMetrics.density
        return resources.configuration.screenHeightDp - 52 - 136 - ((cutout.top + cutout.bottom) / d).toInt()
    }

    private fun sideBarHeightDp() = 2 * sliderDp + 142

    private fun sideBarParams() = FrameLayout.LayoutParams(
        dp(46), ViewGroup.LayoutParams.WRAP_CONTENT,
        Gravity.TOP or if (prefs.sidebarRight) Gravity.END else Gravity.START,
    ).apply {
        leftMargin = dp(6) + cutout.left
        rightMargin = dp(6) + cutout.right
        // Centred in the space between the top bar (52dp) and the timeline (136dp).
        topMargin = dp(52) + cutout.top + dp(maxOf(0, (availableSideDp() - sideBarHeightDp()) / 2))
    }

    /** Shrinks the side-bar sliders on short screens (landscape phones) so the bar always fits. */
    private fun sizeSideBar() {
        sliderDp = ((availableSideDp() - 142 - 8) / 2).coerceIn(36, 150)
        for (s in listOf(sizeSlider, opacitySlider)) {
            s.layoutParams = LinearLayout.LayoutParams(dp(36), dp(sliderDp))
        }
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        if (loaded) placeSideBar()
    }

    private fun applyCutout() {
        topBar.setPadding(dp(6) + cutout.left, cutout.top, dp(6) + cutout.right, 0)
        topBar.layoutParams.height = dp(52) + cutout.top
        bottomBar.setPadding(cutout.left, 0, cutout.right, cutout.bottom)
        (hintView.layoutParams as FrameLayout.LayoutParams).topMargin = dp(64) + cutout.top
        placeSideBar()
        root.requestLayout()
    }

    fun placeSideBar() {
        sizeSideBar()
        sideBar.layoutParams = sideBarParams()
        (bubbleView.layoutParams as FrameLayout.LayoutParams).gravity =
            Gravity.CENTER_VERTICAL or if (prefs.sidebarRight) Gravity.END else Gravity.START
        bubbleView.requestLayout()
    }

    private fun buildBottomBar() {
        bottomBar = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Theme.bar)
            elevation = dp(4f)
            isClickable = true
        }
        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(6), dp(2), dp(6), 0)
        }
        exportButton = textButton("Export") { panels.showExport() }
        settingsButton = textButton("Settings") { panels.showAnimationSettings(it) }
        frameLabel = label("", 12f, Theme.textDim).apply { gravity = Gravity.CENTER }
        playButton = IconButton(this, Icon.PLAY).apply { setOnClickListener { togglePlay() } }
        val add = textButton("Add Frame") { addFrame() }
        controls.addView(exportButton)
        controls.addView(settingsButton)
        controls.addView(frameLabel, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        controls.addView(playButton)
        controls.addView(add)
        bottomBar.addView(controls, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(44)))
        bottomBar.addView(timeline, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(92)))
        root.addView(bottomBar, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM))
    }

    private fun buildTransformBar() {
        transformBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = rounded(Theme.bar, dp(24f))
            setPadding(dp(6), dp(2), dp(6), dp(2))
            elevation = dp(6f)
            visibility = View.GONE
            isClickable = true
        }
        fun btn(icon: Icon, action: () -> Unit) = IconButton(this, icon).apply { setOnClickListener { action() } }
        transformBar.addView(btn(Icon.FLIP_H) { canvasView.transform?.flip(true); canvasView.invalidate() })
        transformBar.addView(btn(Icon.FLIP_V) { canvasView.transform?.flip(false); canvasView.invalidate() })
        transformBar.addView(btn(Icon.ROTATE) { canvasView.transform?.rotate90(); canvasView.invalidate() })
        transformBar.addView(textButton("Reset") { canvasView.transform?.reset(); canvasView.invalidate() })
        transformBar.addView(btn(Icon.CLOSE) { cancelTransform() })
        transformBar.addView(btn(Icon.CHECK) { selectTool(Tool.BRUSH) }.apply { active = true })
        root.addView(transformBar, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL).apply {
            bottomMargin = dp(148)
        })
    }

    private fun updateSafeInsets() {
        val top = if (topBar.visibility == View.VISIBLE) topBar.height else 0
        val bottom = if (bottomBar.visibility == View.VISIBLE) bottomBar.height else 0
        val r = Rect(0, top, 0, bottom)
        if (r != canvasView.safeInsets) canvasView.safeInsets.set(r)
    }

    // --- tools ---

    private fun toolTapped(t: Tool, anchor: View) {
        if (tool == t) {
            when (t) {
                Tool.BRUSH, Tool.ERASER -> panels.showBrushes(anchor, t)
                Tool.FILL -> panels.showFillSettings(anchor)
                Tool.TRANSFORM -> Unit
            }
        } else {
            selectTool(t)
        }
    }

    fun selectTool(t: Tool) {
        if (tool == Tool.TRANSFORM && t != Tool.TRANSFORM) applyTransform()
        if (t == Tool.TRANSFORM && !startTransform()) return
        tool = t
        for ((k, b) in toolButtons) b.active = k == t
        refreshSideBar()
    }

    fun currentBrush(): BrushSpec? = when (tool) {
        Tool.BRUSH, Tool.ERASER -> brushes[tool]
        else -> null
    }

    fun brushFor(t: Tool): BrushSpec = brushes[t] ?: prefs.brush(null)

    fun setBrush(t: Tool, b: BrushSpec) {
        brushes[t] = b
        prefs.setBrushId(t, b.id)
        refreshSideBar()
    }

    private fun sizeFromSlider(v: Float): Float {
        val max = currentBrush()?.maxSize ?: 400f
        return 1f + (max - 1f) * v * v
    }

    private fun sliderFromSize(size: Float): Float {
        val max = currentBrush()?.maxSize ?: 400f
        return sqrt(((size - 1f) / (max - 1f)).coerceIn(0f, 1f))
    }

    fun refreshSideBar() {
        val b = currentBrush()
        val enabled = b != null
        sizeSlider.isEnabled = enabled
        opacitySlider.isEnabled = enabled
        sizeSlider.alpha = if (enabled) 1f else 0.35f
        opacitySlider.alpha = if (enabled) 1f else 0.35f
        if (b != null) {
            sizeSlider.value = sliderFromSize(prefs.size(tool, b))
            opacitySlider.value = prefs.opacity(tool, b)
        }
    }

    fun setColor(c: Int, final: Boolean) {
        color = c or 0xFF000000.toInt()
        colorButton.color = color
        if (final) {
            prefs.color = color
            prefs.pushRecentColor(color)
        }
    }

    // --- CanvasHost ---

    override val fingerDrawing get() = prefs.fingerDrawing
    override val quickShapeEnabled get() = prefs.quickShape
    override val holdToPick get() = prefs.holdToPick
    override val isPlaying get() = player.isPlaying

    override fun drawBlockedReason(): String? = if (!doc.activeLayer.visible) "The layer is hidden" else null

    override fun strokeStyle(eraser: Boolean): StrokeStyle {
        val t = if (eraser) Tool.ERASER else Tool.BRUSH
        val b = brushFor(t)
        return StrokeStyle(
            brush = b,
            size = prefs.size(t, b),
            opacity = prefs.opacity(t, b),
            color = color,
            erase = eraser,
            alphaLock = doc.activeLayer.alphaLock,
        )
    }

    override fun onStrokeFinished(engine: StrokeEngine, style: StrokeStyle) {
        val key = doc.activeCellKey
        val rect = StrokeEngine.clampRect(engine.dirty, doc.project.width, doc.project.height) ?: return
        if (style.erase && !doc.store.hasContent(key)) return
        val cell = doc.store.getOrCreate(key)
        val before = PixelCommand.copyRegion(cell, rect)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG).apply {
            alpha = (style.opacity * 255).roundToInt()
            blendMode = when {
                style.erase -> BlendMode.DST_OUT
                style.alphaLock -> BlendMode.SRC_ATOP
                else -> BlendMode.SRC_OVER
            }
        }
        engine.layer.drawTo(Canvas(cell), paint)
        doc.recordPixelEdit(if (style.erase) "Erase" else "Stroke", key, rect, before)
    }

    override fun onFill(x: Int, y: Int) {
        if (fillBusy) return
        if (!doc.activeLayer.visible) return showHint("The layer is hidden")
        val w = doc.project.width
        val h = doc.project.height
        val key = doc.activeCellKey
        val cell = doc.store.getOrCreate(key)
        val target = IntArray(w * h)
        cell.getPixels(target, 0, w, 0, 0, w, h)
        val reference = if (prefs.fillSampleAll) {
            val merged = Compositor.render(doc.frameSpec(doc.project.currentFrame, withBackground = false), doc.store, 1f)
            IntArray(w * h).also { merged.getPixels(it, 0, w, 0, 0, w, h) }
        } else {
            target.copyOf()
        }
        val fillColor = color
        val tolerance = (prefs.fillTolerance * 255).roundToInt()
        val expand = prefs.fillExpand
        fillBusy = true
        Bg.render.execute {
            val bounds = FloodFill.fill(target, reference, w, h, x, y, fillColor, tolerance, expand)
            Bg.post {
                fillBusy = false
                if (bounds == null || isDestroyed) return@post
                val rect = Rect(bounds.left, bounds.top, bounds.right, bounds.bottom)
                val live = doc.store.getOrCreate(key)
                val before = PixelCommand.copyRegion(live, rect)
                live.setPixels(target, rect.top * w + rect.left, w, rect.left, rect.top, rect.width(), rect.height())
                doc.recordPixelEdit("Fill", key, rect, before)
            }
        }
    }

    override fun onColorPicked(color: Int) {
        setColor(color, true)
    }

    override fun onEyedropperDone() {
        pickButton.active = false
    }

    override fun onUndoGesture() = undo()
    override fun onRedoGesture() = redo()

    override fun onToggleFullscreen() {
        fullscreen = !fullscreen
        val v = if (fullscreen) View.GONE else View.VISIBLE
        topBar.visibility = v
        sideBar.visibility = v
        bottomBar.visibility = v
        showHint(if (fullscreen) "Four-finger tap to show the interface" else "Interface shown")
    }

    override fun onStylusDetected() {
        if (prefs.stylusSeen) return
        prefs.stylusSeen = true
        prefs.fingerDrawing = false
        showHint("Pen detected: fingers now pan and zoom. Change this in Actions ▸ Preferences.")
    }

    override fun onTouchWhilePlaying() {
        player.stop()
    }

    override fun showHint(text: String) {
        hintView.removeCallbacks(hideHint)
        hintView.text = text
        hintView.animate().cancel()
        hintView.alpha = 1f
        hintView.postDelayed(hideHint, if (text.length > 40) 3200L else 1600L)
    }

    // --- actions ---

    fun undo() {
        if (player.isPlaying) player.stop()
        if (canvasView.transform != null) return cancelTransform()
        val c = doc.undo()
        showHint(c?.let { "Undo ${it.name}" } ?: "Nothing to undo")
    }

    fun redo() {
        if (player.isPlaying) player.stop()
        applyTransform()
        val c = doc.redo()
        showHint(c?.let { "Redo ${it.name}" } ?: "Nothing to redo")
    }

    fun addFrame() {
        if (player.isPlaying) player.stop()
        applyTransform()
        doc.addFrame()
    }

    fun togglePlay() {
        if (player.isPlaying) {
            player.stop()
            return
        }
        applyTransform()
        val s = canvasView.scale
        player.play((doc.project.width * s).roundToInt(), (doc.project.height * s).roundToInt())
        playButton.icon = Icon.PAUSE
    }

    /** Starts moving the active cell's contents. Returns false when there is nothing to move. */
    private fun startTransform(): Boolean {
        if (!doc.activeLayer.visible) {
            showHint("The layer is hidden")
            return false
        }
        val key = doc.activeCellKey
        val cell = doc.store.get(key)
        val bounds = cell?.let { TransformSession.contentBounds(it) }
        if (cell == null || bounds == null) {
            showHint("Nothing to transform on this layer")
            return false
        }
        val source = cell.copy(Bitmap.Config.ARGB_8888, false)
        canvasView.transform = TransformSession(key, source, bounds)
        transformBar.visibility = View.VISIBLE
        showHint("Drag to move · pinch to scale and rotate")
        return true
    }

    /** Commits a pending transform as one undo step. */
    fun applyTransform() {
        val t = canvasView.transform ?: return
        canvasView.transform = null
        transformBar.visibility = View.GONE
        if (tool == Tool.TRANSFORM) {
            tool = Tool.BRUSH
            for ((k, b) in toolButtons) b.active = k == Tool.BRUSH
            refreshSideBar()
        }
        if (t.matrix.isIdentity) return
        val w = doc.project.width
        val h = doc.project.height
        val rect = t.affectedRect(w, h) ?: return
        val cell = doc.store.getOrCreate(t.key)
        val before = PixelCommand.copyRegion(cell, rect)
        cell.eraseColor(0)
        Canvas(cell).drawBitmap(t.source, t.matrix, Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG))
        doc.recordPixelEdit("Transform", t.key, rect, before)
    }

    private fun cancelTransform() {
        canvasView.transform = null
        transformBar.visibility = View.GONE
        tool = Tool.TRANSFORM
        selectTool(Tool.BRUSH)
    }

    /** Adds a picture as a new layer on the current frame, then lets the user place it. */
    fun importImage(uri: Uri) {
        val w = doc.project.width
        val h = doc.project.height
        val resolver = contentResolver
        showHint("Importing…")
        Bg.io.execute {
            val bmp = try {
                val src = ImageDecoder.createSource(resolver, uri)
                ImageDecoder.decodeBitmap(src) { decoder, info, _ ->
                    decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                    val s = minOf(1f, minOf(w / info.size.width.toFloat(), h / info.size.height.toFloat()))
                    decoder.setTargetSize(
                        (info.size.width * s).roundToInt().coerceAtLeast(1),
                        (info.size.height * s).roundToInt().coerceAtLeast(1),
                    )
                }
            } catch (e: Exception) {
                null
            } catch (e: OutOfMemoryError) {
                null
            }
            Bg.post {
                if (isDestroyed) return@post
                if (bmp == null) return@post showHint("Could not open that image")
                applyTransform()
                doc.history.beginGroup("Insert Photo")
                doc.addLayer("Photo")
                doc.editActiveCell("Insert Photo") { cell ->
                    Canvas(cell).drawBitmap(bmp, (w - bmp.width) / 2f, (h - bmp.height) / 2f, Paint(Paint.FILTER_BITMAP_FLAG))
                }
                doc.history.endGroup()
                selectTool(Tool.TRANSFORM)
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK || !loaded) return
        val uri = data?.data ?: return
        when (requestCode) {
            REQUEST_IMPORT -> importImage(uri)
            REQUEST_SAVE_FILE -> panels.onSaveFileChosen(uri)
        }
    }

    // --- Document.Listener ---

    override fun onDocumentChanged(change: Document.Change) {
        when (change) {
            Document.Change.STRUCTURE, Document.Change.SELECTION -> {
                val t = canvasView.transform
                if (t != null && t.key != doc.activeCellKey) {
                    canvasView.transform = null
                    transformBar.visibility = View.GONE
                    if (tool == Tool.TRANSFORM) selectTool(Tool.BRUSH)
                }
                timeline.ensureVisible(doc.project.currentFrame)
                refreshAll()
            }
            Document.Change.PIXELS, Document.Change.SETTINGS -> refreshAll()
            Document.Change.HISTORY -> refreshHistory()
        }
    }

    private fun refreshHistory() {
        undoButton.isEnabled = doc.history.canUndo
        redoButton.isEnabled = doc.history.canRedo
    }

    fun refreshAll() {
        refreshHistory()
        val p = doc.project
        frameLabel.text = "Frame ${p.currentFrame + 1} of ${p.frames.size}  ·  ${p.fps} fps"
        canvasView.invalidate()
        timeline.invalidate()
    }

    // --- TimelineView.Callbacks ---

    override fun onFrameSelected(index: Int) {
        if (player.isPlaying) player.stop()
        applyTransform()
        doc.selectFrame(index)
    }

    override fun onCurrentFrameTapped(index: Int, anchorX: Float) {
        if (player.isPlaying) player.stop()
        panels.showFrameOptions(timeline, index)
    }

    override fun onAddFrameTapped() = addFrame()

    override fun onFrameMoved(from: Int, to: Int) {
        applyTransform()
        doc.moveFrame(from, to)
    }

    // --- Player.Listener ---

    override fun onPlaybackFrame(index: Int, bitmap: Bitmap?) {
        if (bitmap != null) canvasView.playbackFrame = bitmap
        timeline.playingIndex = index
        frameLabel.text = "Frame ${index + 1} of ${doc.project.frames.size}  ·  ${doc.project.fps} fps"
    }

    override fun onPreparing(progress: Float) {
        frameLabel.text = "Preparing ${percent(progress)}"
    }

    override fun onPlaybackStopped() {
        val last = timeline.playingIndex
        canvasView.playbackFrame = null
        timeline.playingIndex = -1
        playButton.icon = Icon.PLAY
        if (last >= 0) doc.selectFrame(last)
        refreshAll()
    }

    companion object {
        const val EXTRA_PROJECT_ID = "project_id"
        const val REQUEST_IMPORT = 10
        const val REQUEST_SAVE_FILE = 11

        fun open(context: Context, projectId: String) {
            context.startActivity(Intent(context, EditorActivity::class.java).putExtra(EXTRA_PROJECT_ID, projectId))
        }
    }
}
