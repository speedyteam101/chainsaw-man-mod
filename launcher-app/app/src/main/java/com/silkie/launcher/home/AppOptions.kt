package com.silkie.launcher.home

import android.content.Intent
import android.net.Uri
import android.text.InputType
import android.widget.EditText
import android.widget.Toast
import com.silkie.launcher.data.Library
import com.silkie.launcher.data.LibraryItem
import com.silkie.launcher.ui.dialog
import com.silkie.launcher.ui.dp
import com.silkie.launcher.ui.label

/** The long-press (or X button) menu for an app. */
class AppOptions(private val a: HomeActivity, private val item: LibraryItem) {
    private val meta get() = a.repo.meta

    fun show() {
        val actions = mutableListOf<Pair<String, () -> Unit>>()
        actions += (if (item.isGame) "Play" else "Open") to { a.launch(item, null) }
        actions += (if (item.favorite) "Remove from favorites" else "Add to favorites ★") to { a.toggleFavorite(item) }
        actions += (if (item.isGame) "Not a game (move to Apps)" else "Mark as game") to {
            meta.update(item.key) { game = !item.isGame }
            a.metaChanged()
        }
        actions += "Collections…" to { collections() }
        actions += "Rename…" to { rename() }
        actions += "Hide from library" to {
            meta.update(item.key) { hidden = true }
            a.metaChanged()
            Toast.makeText(a, "Hidden. Bring it back in Settings › Library.", Toast.LENGTH_LONG).show()
        }
        actions += "App info" to { a.repo.openAppInfo(item.key, null) }
        if (a.repo.isMainProfile(item.key)) actions += "Uninstall" to {
            runCatching { a.startActivity(Intent(Intent.ACTION_DELETE, Uri.fromParts("package", item.packageName, null))) }
        }

        val subtitle = buildList {
            add(if (item.isGame) "Game" else "App")
            if (item.playtimeMs > 0) add("${Library.formatPlaytime(item.playtimeMs)} played")
            if (item.launchCount > 0) add("opened ${item.launchCount}×")
        }.joinToString(" · ")

        val head = android.widget.LinearLayout(a).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(a.dp(24), a.dp(20), a.dp(24), a.dp(8))
            addView(a.label(a.pal, item.label, 20f, a.pal.text, bold = true))
            addView(a.label(a.pal, subtitle, 13f, a.pal.textDim).apply { setPadding(0, a.dp(4), 0, 0) })
        }
        a.dialog(a.pal)
            .setCustomTitle(head)
            .setItems(actions.map { it.first }.toTypedArray()) { _, which -> actions[which].second() }
            .show()
    }

    private fun rename() {
        val input = EditText(a).apply {
            setText(item.label)
            setSelection(text.length)
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_WORDS
            hint = a.repo.originalLabel(item.key)
        }
        val pad = a.dp(20)
        val box = android.widget.FrameLayout(a).apply { setPadding(pad, a.dp(8), pad, 0); addView(input) }
        a.dialog(a.pal)
            .setTitle("Rename")
            .setView(box)
            .setPositiveButton("Save") { _, _ ->
                val name = input.text.toString().trim()
                meta.update(item.key) { this.name = name.takeIf { it.isNotEmpty() && it != a.repo.originalLabel(item.key) } }
                a.metaChanged()
            }
            .setNeutralButton("Reset") { _, _ ->
                meta.update(item.key) { name = null }
                a.metaChanged()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun collections() {
        val names = meta.collections.toList()
        val checked = BooleanArray(names.size) { names[it] in item.collections }
        a.dialog(a.pal)
            .setTitle("Collections")
            .setMultiChoiceItems(names.toTypedArray(), checked) { _, which, isChecked -> checked[which] = isChecked }
            .setPositiveButton("Done") { _, _ ->
                meta.update(item.key) {
                    collections.clear()
                    names.forEachIndexed { i, n -> if (checked[i]) collections += n }
                }
                a.metaChanged()
            }
            .setNeutralButton("New collection…") { _, _ -> newCollection() }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun newCollection() {
        val input = EditText(a).apply {
            hint = "e.g. RPGs, Retro, Co-op"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_WORDS
        }
        val pad = a.dp(20)
        val box = android.widget.FrameLayout(a).apply { setPadding(pad, a.dp(8), pad, 0); addView(input) }
        a.dialog(a.pal)
            .setTitle("New collection")
            .setView(box)
            .setPositiveButton("Create") { _, _ ->
                val name = input.text.toString().trim()
                if (meta.addCollection(name)) {
                    meta.update(item.key) { collections += name }
                    a.metaChanged()
                    Toast.makeText(a, "\"$name\" now has its own tab", Toast.LENGTH_SHORT).show()
                } else {
                    Toast.makeText(a, "That name is empty or already used", Toast.LENGTH_SHORT).show()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }
}
