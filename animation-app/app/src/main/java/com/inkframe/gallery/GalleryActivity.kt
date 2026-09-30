package com.inkframe.gallery

import android.app.Activity
import android.app.AlertDialog
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.text.InputType
import android.util.LruCache
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.GridView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.PopupMenu
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.TextView
import com.inkframe.App
import com.inkframe.editor.EditorActivity
import com.inkframe.model.Project
import com.inkframe.model.ProjectSummary
import com.inkframe.ui.Segmented
import com.inkframe.ui.Theme
import com.inkframe.ui.dp
import com.inkframe.ui.label
import com.inkframe.ui.pillButton
import com.inkframe.ui.rounded
import com.inkframe.ui.sectionTitle
import com.inkframe.ui.toggleRow
import com.inkframe.util.Bg
import java.text.DateFormat
import java.util.Date

/** The start screen: every animation as a card, plus "New". */
class GalleryActivity : Activity() {
    private val app get() = application as App
    private var projects: List<ProjectSummary> = emptyList()
    private lateinit var grid: GridView
    private lateinit var empty: TextView
    private val adapter = Adapter()
    private val thumbs = object : LruCache<String, Bitmap>(24 shl 20) {
        override fun sizeOf(key: String, value: Bitmap) = value.allocationByteCount
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Theme.workspace
        window.navigationBarColor = Theme.workspace
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Theme.workspace)
            fitsSystemWindows = true
        }
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(20), dp(18), dp(16), dp(10))
        }
        header.addView(label("Inkframe", 28f, Theme.text, bold = true), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        header.addView(pillButton("+  New") { showNewProject() })
        root.addView(header)

        val body = FrameLayout(this)
        grid = GridView(this).apply {
            adapter = this@GalleryActivity.adapter
            columnWidth = dp(168)
            numColumns = GridView.AUTO_FIT
            stretchMode = GridView.STRETCH_COLUMN_WIDTH
            horizontalSpacing = dp(14)
            verticalSpacing = dp(18)
            setPadding(dp(16), dp(8), dp(16), dp(24))
            clipToPadding = false
            selector = rounded(0, 0f)
            setOnItemClickListener { _, _, pos, _ -> EditorActivity.open(this@GalleryActivity, projects[pos].id) }
            setOnItemLongClickListener { _, view, pos, _ ->
                showMenu(view, projects[pos])
                true
            }
        }
        empty = label("Tap  + New  to start your first animation.", 16f, Theme.textDim).apply {
            gravity = Gravity.CENTER
            visibility = View.GONE
        }
        body.addView(grid, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        body.addView(empty, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        root.addView(body, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        setContentView(root)
    }

    override fun onResume() {
        super.onResume()
        reload()
    }

    private fun reload() {
        Bg.io.execute {
            val list = app.repo.list()
            Bg.post {
                projects = list
                thumbs.evictAll()
                adapter.notifyDataSetChanged()
                empty.visibility = if (list.isEmpty()) View.VISIBLE else View.GONE
            }
        }
    }

    private fun dialog() = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert)

    private fun showMenu(anchor: View, p: ProjectSummary) {
        PopupMenu(this, anchor).apply {
            menu.add(0, 1, 0, "Rename")
            menu.add(0, 2, 1, "Duplicate")
            menu.add(0, 3, 2, "Delete")
            setOnMenuItemClickListener { item ->
                when (item.itemId) {
                    1 -> rename(p)
                    2 -> Bg.io.execute {
                        app.repo.duplicate(p.id)
                        Bg.post { reload() }
                    }
                    3 -> dialog().setTitle("Delete “${p.name}”?")
                        .setMessage("This animation will be deleted permanently.")
                        .setPositiveButton("Delete") { _, _ ->
                            Bg.io.execute {
                                app.repo.delete(p.id)
                                Bg.post { reload() }
                            }
                        }
                        .setNegativeButton("Cancel", null)
                        .show()
                }
                true
            }
            show()
        }
    }

    private fun textField(text: String, hint: String = "", number: Boolean = false) = EditText(this).apply {
        setText(text)
        this.hint = hint
        setSelectAllOnFocus(true)
        inputType = if (number) InputType.TYPE_CLASS_NUMBER else InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
    }

    private fun rename(p: ProjectSummary) {
        val field = textField(p.name)
        val wrap = LinearLayout(this).apply {
            setPadding(dp(20), dp(8), dp(20), 0)
            addView(field, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        dialog().setTitle("Rename").setView(wrap)
            .setPositiveButton("Rename") { _, _ ->
                val name = field.text.toString().trim().ifEmpty { p.name }
                Bg.io.execute {
                    app.repo.rename(p.id, name)
                    Bg.post { reload() }
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private class Preset(val label: String, val width: Int, val height: Int)

    private fun showNewProject() {
        val dm = resources.displayMetrics
        val screenW = maxOf(dm.widthPixels, dm.heightPixels).coerceAtMost(Project.MAX_SIDE)
        val screenH = minOf(dm.widthPixels, dm.heightPixels).coerceAtMost(Project.MAX_SIDE)
        val presets = listOf(
            Preset("HD 1920 × 1080", 1920, 1080),
            Preset("HD 1280 × 720", 1280, 720),
            Preset("Square 1080 × 1080", 1080, 1080),
            Preset("Vertical 1080 × 1920", 1080, 1920),
            Preset("Portrait 1080 × 1350", 1080, 1350),
            Preset("Screen size $screenW × $screenH", screenW, screenH),
            Preset("Custom", 0, 0),
        )
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(4), dp(16), dp(8))
        }
        val name = textField("Animation ${projects.size + 1}", "Name")
        box.addView(name)
        box.addView(sectionTitle("Canvas size"))
        val group = RadioGroup(this)
        val customRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            visibility = View.GONE
        }
        val cw = textField("1600", "Width", number = true)
        val ch = textField("1200", "Height", number = true)
        customRow.addView(cw, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        customRow.addView(label(" × ", 16f), LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        customRow.addView(ch, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        presets.forEachIndexed { i, p ->
            group.addView(RadioButton(this).apply {
                id = View.generateViewId()
                text = p.label
                tag = i
                setTextColor(Theme.text)
                textSize = 15f
                isChecked = i == 0
            })
        }
        var selected = 0
        group.setOnCheckedChangeListener { g, id ->
            selected = g.findViewById<View>(id)?.tag as? Int ?: 0
            customRow.visibility = if (presets[selected].width == 0) View.VISIBLE else View.GONE
        }
        box.addView(group)
        box.addView(customRow)
        box.addView(sectionTitle("Frames per second"))
        val fpsOptions = intArrayOf(8, 12, 15, 24, 30)
        var fps = 12
        box.addView(Segmented(this, fpsOptions.map { it.toString() }, 1) { fps = fpsOptions[it] })
        var transparent = false
        box.addView(toggleRow("Transparent background", false) { transparent = it })

        dialog().setTitle("New animation").setView(ScrollView(this).apply { addView(box) })
            .setPositiveButton("Create") { _, _ ->
                val preset = presets[selected]
                val w = if (preset.width > 0) preset.width else cw.text.toString().toIntOrNull() ?: 1600
                val h = if (preset.height > 0) preset.height else ch.text.toString().toIntOrNull() ?: 1200
                val title = name.text.toString().trim().ifEmpty { "Animation" }
                Bg.io.execute {
                    val p = app.repo.create(
                        title,
                        w.coerceIn(16, Project.MAX_SIDE),
                        h.coerceIn(16, Project.MAX_SIDE),
                        fps,
                        0xFFFFFFFF.toInt(),
                        !transparent,
                    )
                    Bg.post { EditorActivity.open(this, p.id) }
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private inner class Adapter : BaseAdapter() {
        override fun getCount() = projects.size
        override fun getItem(position: Int) = projects[position]
        override fun getItemId(position: Int) = position.toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
            val card = (convertView as? Card) ?: Card()
            card.bind(projects[position])
            return card
        }
    }

    private inner class Card : LinearLayout(this@GalleryActivity) {
        private val frame = FrameLayout(context).apply {
            background = rounded(Theme.panel, dp(12f))
            clipToOutline = true
        }
        private val image = ImageView(context).apply { scaleType = ImageView.ScaleType.FIT_CENTER }
        private val title = label("", 15f, Theme.text, bold = true).apply { maxLines = 1 }
        private val info = label("", 12f, Theme.textDim).apply { maxLines = 1 }
        private var boundId: String? = null

        init {
            orientation = VERTICAL
            frame.addView(image, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            addView(frame, LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(130)))
            addView(title, LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(8) })
            addView(info, LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(3) })
        }

        fun bind(p: ProjectSummary) {
            boundId = p.id
            title.text = p.name
            val date = DateFormat.getDateInstance(DateFormat.MEDIUM).format(Date(p.modifiedAt))
            info.text = "${p.frameCount} frame${if (p.frameCount == 1) "" else "s"} · ${p.width}×${p.height} · $date"
            val key = p.thumbnail.path + p.thumbnail.lastModified()
            val cached = thumbs.get(key)
            image.setImageBitmap(cached)
            if (cached == null && p.thumbnail.exists()) {
                Bg.io.execute {
                    val bmp = BitmapFactory.decodeFile(p.thumbnail.path)
                    Bg.post {
                        if (bmp != null) {
                            thumbs.put(key, bmp)
                            if (boundId == p.id) image.setImageBitmap(bmp)
                        }
                    }
                }
            }
        }
    }
}
