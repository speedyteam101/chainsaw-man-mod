package com.silkie.launcher.data

import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/** The user's per-app tweaks: rename, hide, favorite, game/app override, collections, launch history. */
class AppMeta(private val sp: SharedPreferences) {
    class Entry(
        var name: String? = null,
        var hidden: Boolean = false,
        var favorite: Boolean = false,
        /** null = detect automatically, true/false = user override. */
        var game: Boolean? = null,
        val collections: MutableSet<String> = linkedSetOf(),
        var launches: Int = 0,
        var lastLaunch: Long = 0L,
    ) {
        val isDefault get() = name == null && !hidden && !favorite && game == null && collections.isEmpty() && launches == 0
    }

    private val entries = HashMap<String, Entry>()
    val collections = mutableListOf<String>()
    var revision = 0
        private set

    init {
        reload()
    }

    private fun reload() {
        entries.clear()
        collections.clear()
        sp.getString("collections", null)?.let { s ->
            runCatching { JSONArray(s) }.getOrNull()?.let { a -> for (i in 0 until a.length()) collections += a.getString(i) }
        }
        for ((k, v) in sp.all) {
            if (!k.startsWith("app:") || v !is String) continue
            val o = runCatching { JSONObject(v) }.getOrNull() ?: continue
            entries[k.removePrefix("app:")] = Entry(
                name = o.optString("name").ifEmpty { null },
                hidden = o.optBoolean("hidden"),
                favorite = o.optBoolean("fav"),
                game = if (o.has("game")) o.getBoolean("game") else null,
                collections = o.optJSONArray("cols")?.let { a -> (0 until a.length()).mapTo(linkedSetOf()) { a.getString(it) } } ?: linkedSetOf(),
                launches = o.optInt("launches"),
                lastLaunch = o.optLong("last"),
            )
        }
    }

    operator fun get(key: String): Entry = entries[key] ?: Entry()

    fun update(key: String, block: Entry.() -> Unit) {
        val e = entries.getOrPut(key) { Entry() }
        e.block()
        save(key, e)
    }

    private fun save(key: String, e: Entry) {
        revision++
        if (e.isDefault) {
            entries.remove(key)
            sp.edit().remove("app:$key").apply()
            return
        }
        val o = JSONObject()
        e.name?.let { o.put("name", it) }
        if (e.hidden) o.put("hidden", true)
        if (e.favorite) o.put("fav", true)
        e.game?.let { o.put("game", it) }
        if (e.collections.isNotEmpty()) o.put("cols", JSONArray(e.collections.toList()))
        if (e.launches > 0) o.put("launches", e.launches)
        if (e.lastLaunch > 0) o.put("last", e.lastLaunch)
        sp.edit().putString("app:$key", o.toString()).apply()
    }

    fun addCollection(name: String): Boolean {
        val n = name.trim()
        if (n.isEmpty() || collections.any { it.equals(n, ignoreCase = true) }) return false
        collections += n
        saveCollections()
        return true
    }

    fun renameCollection(old: String, new: String): Boolean {
        val n = new.trim()
        val i = collections.indexOf(old)
        if (i < 0 || n.isEmpty() || collections.any { it != old && it.equals(n, ignoreCase = true) }) return false
        collections[i] = n
        for ((k, e) in entries.toList()) if (e.collections.remove(old)) { e.collections += n; save(k, e) }
        saveCollections()
        return true
    }

    fun deleteCollection(name: String) {
        collections.remove(name)
        for ((k, e) in entries.toList()) if (e.collections.remove(name)) save(k, e)
        saveCollections()
    }

    private fun saveCollections() {
        revision++
        sp.edit().putString("collections", JSONArray(collections).toString()).apply()
    }

    fun toJson(): JSONObject {
        val o = JSONObject()
        for ((k, v) in sp.all) if (v is String) o.put(k, v)
        return o
    }

    fun loadJson(o: JSONObject) {
        val e = sp.edit().clear()
        for (k in o.keys()) e.putString(k, o.getString(k))
        e.commit()
        reload()
        revision++
    }
}
