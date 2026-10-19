package com.silkie.launcher.home

import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.Intent
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.Toast
import com.silkie.launcher.ui.Glyph
import com.silkie.launcher.ui.MATCH
import com.silkie.launcher.ui.WRAP
import com.silkie.launcher.ui.cardBackground
import com.silkie.launcher.ui.dialog
import com.silkie.launcher.ui.dp
import com.silkie.launcher.ui.glyphButton
import com.silkie.launcher.ui.label
import com.silkie.launcher.ui.lp
import com.silkie.launcher.ui.pillButton
import org.json.JSONArray
import org.json.JSONObject

/** Hosts Android home-screen widgets in a section of the Home tab. */
class WidgetController(private val a: HomeActivity) {
    private val manager = AppWidgetManager.getInstance(a)
    private val host = AppWidgetHost(a, HOST_ID)
    private var pendingId = -1

    /** Edit mode shows move / resize / remove buttons on each widget. */
    var editing = false

    private class Slot(val id: Int, var heightDp: Int)

    fun start() {
        runCatching { host.startListening() }
    }

    fun stop() {
        runCatching { host.stopListening() }
    }

    private fun load(): MutableList<Slot> {
        val out = mutableListOf<Slot>()
        val arr = runCatching { JSONArray(a.prefs.widgets) }.getOrNull() ?: return out
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            out += Slot(o.optInt("id", -1), o.optInt("h", 160))
        }
        return out
    }

    private fun save(list: List<Slot>) {
        val arr = JSONArray()
        list.forEach { arr.put(JSONObject().put("id", it.id).put("h", it.heightDp)) }
        a.prefs.widgets = arr.toString()
        a.settingsTweaked()
    }

    fun section(): View {
        val pal = a.pal
        val col = LinearLayout(a).apply { orientation = LinearLayout.VERTICAL }
        val header = LinearLayout(a).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        header.addView(a.label(pal, "Widgets", 18f, pal.text, bold = true), lp(0, WRAP, 1f))
        val slots = load()
        if (slots.isNotEmpty()) {
            header.addView(a.glyphButton(pal, Glyph.EDIT, if (editing) "Done editing" else "Edit widgets", 40) {
                editing = !editing
                a.rebuildPage(keepState = true)
            })
        }
        header.addView(a.glyphButton(pal, Glyph.PLUS, "Add widget", 40) { add() })
        col.addView(header, lp(MATCH, WRAP))

        if (slots.isEmpty()) {
            val hint = a.label(pal, "Add a clock, music player, calendar or any other widget here.", 13f, pal.textDim)
            col.addView(hint, lp(MATCH, WRAP).apply { topMargin = a.dp(4) })
            return col
        }

        var changed = false
        val it = slots.iterator()
        while (it.hasNext()) {
            val slot = it.next()
            val info = manager.getAppWidgetInfo(slot.id)
            if (info == null) {
                // The widget's app was uninstalled.
                runCatching { host.deleteAppWidgetId(slot.id) }
                it.remove()
                changed = true
                continue
            }
            val frame = FrameLayout(a).apply {
                background = a.cardBackground(pal)
                clipToOutline = true
                setPadding(a.dp(6), a.dp(6), a.dp(6), a.dp(6))
            }
            val hostView = runCatching { host.createView(a, slot.id, info) }.getOrNull()
            if (hostView != null) frame.addView(hostView, FrameLayout.LayoutParams(MATCH, MATCH))
            if (editing) frame.addView(editBar(slots, slot), FrameLayout.LayoutParams(WRAP, WRAP, Gravity.TOP or Gravity.END))
            col.addView(frame, lp(MATCH, a.dp(slot.heightDp)).apply { topMargin = a.dp(10) })
        }
        if (changed) a.prefs.widgets = JSONArray().also { arr -> slots.forEach { s -> arr.put(JSONObject().put("id", s.id).put("h", s.heightDp)) } }.toString()
        return col
    }

    private fun editBar(slots: MutableList<Slot>, slot: Slot): View {
        val pal = a.pal
        val bar = LinearLayout(a).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(a.dp(4), a.dp(4), a.dp(4), a.dp(4))
        }
        fun btn(text: String, action: () -> Unit) = a.pillButton(pal, text) { action() }.apply {
            setPadding(a.dp(12), a.dp(6), a.dp(12), a.dp(6))
        }
        val i = slots.indexOf(slot)
        if (i > 0) bar.addView(btn("↑") { slots.removeAt(i); slots.add(i - 1, slot); save(slots) })
        if (i < slots.size - 1) bar.addView(btn("↓") { slots.removeAt(i); slots.add(i + 1, slot); save(slots) }, lp(WRAP, WRAP).apply { leftMargin = a.dp(4) })
        bar.addView(btn("−") { slot.heightDp = (slot.heightDp - 40).coerceAtLeast(60); save(slots) }, lp(WRAP, WRAP).apply { leftMargin = a.dp(4) })
        bar.addView(btn("+") { slot.heightDp = (slot.heightDp + 40).coerceAtMost(600); save(slots) }, lp(WRAP, WRAP).apply { leftMargin = a.dp(4) })
        bar.addView(btn("✕") {
            runCatching { host.deleteAppWidgetId(slot.id) }
            slots.remove(slot)
            if (slots.isEmpty()) editing = false
            save(slots)
        }, lp(WRAP, WRAP).apply { leftMargin = a.dp(4) })
        return bar
    }

    private fun add() {
        val pm = a.packageManager
        val providers = manager.installedProviders
            .map { it to it.loadLabel(pm).toString() }
            .sortedBy { it.second.lowercase() }
        if (providers.isEmpty()) {
            Toast.makeText(a, "No widgets are installed", Toast.LENGTH_SHORT).show()
            return
        }
        val labels = providers.map { (info, label) ->
            val app = runCatching { pm.getApplicationLabel(pm.getApplicationInfo(info.provider.packageName, 0)).toString() }.getOrDefault("")
            if (app.isNotEmpty() && app != label) "$label  ($app)" else label
        }
        a.dialog(a.pal)
            .setTitle("Add a widget")
            .setItems(labels.toTypedArray()) { _, which -> pick(providers[which].first) }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun pick(info: AppWidgetProviderInfo) {
        val id = host.allocateAppWidgetId()
        if (manager.bindAppWidgetIdIfAllowed(id, info.provider)) {
            configure(id, info)
        } else {
            pendingId = id
            val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_BIND)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, info.provider)
            runCatching { a.startActivityForResult(intent, REQ_BIND) }.onFailure {
                host.deleteAppWidgetId(id)
                pendingId = -1
            }
        }
    }

    private fun configure(id: Int, info: AppWidgetProviderInfo) {
        if (info.configure == null) {
            commit(id)
            return
        }
        pendingId = id
        try {
            host.startAppWidgetConfigureActivityForResult(a, id, 0, REQ_CONFIGURE, null)
        } catch (e: Exception) {
            // Some widgets don't allow outside configuration; add them as they are.
            pendingId = -1
            commit(id)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, @Suppress("UNUSED_PARAMETER") data: Intent?) {
        if (requestCode != REQ_BIND && requestCode != REQ_CONFIGURE) return
        val id = pendingId
        pendingId = -1
        if (id == -1) return
        if (resultCode != Activity.RESULT_OK) {
            runCatching { host.deleteAppWidgetId(id) }
            return
        }
        if (requestCode == REQ_BIND) {
            val info = manager.getAppWidgetInfo(id) ?: return
            configure(id, info)
        } else {
            commit(id)
        }
    }

    private fun commit(id: Int) {
        val info = manager.getAppWidgetInfo(id)
        val density = a.resources.displayMetrics.density
        val h = ((info?.minHeight ?: 0) / density).toInt().let { if (it <= 0) 160 else it + 24 }.coerceIn(80, 400)
        val slots = load()
        slots += Slot(id, h)
        save(slots)
    }

    companion object {
        private const val HOST_ID = 0x51C1E
        private const val REQ_BIND = 41
        private const val REQ_CONFIGURE = 42
    }
}
