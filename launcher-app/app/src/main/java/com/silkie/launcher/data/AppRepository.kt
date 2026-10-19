package com.silkie.launcher.data

import android.app.ActivityOptions
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.LauncherActivityInfo
import android.content.pm.LauncherApps
import android.graphics.Rect
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.UserHandle
import android.os.UserManager
import android.view.View
import java.util.concurrent.Executors

/**
 * Installed, launchable apps across the user's profiles (including a work profile), merged with
 * the user's tweaks ([AppMeta]) and playtime. Listeners are told on the main thread when it changes.
 */
class AppRepository(private val context: Context, val meta: AppMeta, private val playtime: Playtime) {
    private val launcherApps = context.getSystemService(LauncherApps::class.java)!!
    private val userManager = context.getSystemService(UserManager::class.java)!!
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()

    private var infos: Map<String, LauncherActivityInfo> = emptyMap()
    private var stats: Map<String, Playtime.Stat> = emptyMap()
    var items: List<LibraryItem> = emptyList()
        private set
    var loaded = false
        private set

    private val listeners = mutableListOf<() -> Unit>()

    fun addListener(l: () -> Unit) { listeners += l }
    fun removeListener(l: () -> Unit) { listeners -= l }

    private val callback = object : LauncherApps.Callback() {
        override fun onPackageRemoved(packageName: String, user: UserHandle) = reload()
        override fun onPackageAdded(packageName: String, user: UserHandle) = reload()
        override fun onPackageChanged(packageName: String, user: UserHandle) = reload()
        override fun onPackagesAvailable(packageNames: Array<out String>, user: UserHandle, replacing: Boolean) = reload()
        override fun onPackagesUnavailable(packageNames: Array<out String>, user: UserHandle, replacing: Boolean) = reload()
    }

    init {
        launcherApps.registerCallback(callback, main)
    }

    /** Re-reads installed apps and playtime in the background. */
    fun reload() {
        worker.execute {
            val found = HashMap<String, LauncherActivityInfo>()
            for (user in launcherApps.profiles) {
                for (info in runCatching { launcherApps.getActivityList(null, user) }.getOrDefault(emptyList())) {
                    if (info.componentName.packageName == context.packageName) continue
                    found[keyOf(info.componentName, user)] = info
                }
            }
            val st = playtime.load()
            main.post {
                infos = found
                stats = st
                loaded = true
                rebuild()
            }
        }
    }

    /** Re-reads only playtime (cheap enough to do every time home is shown). */
    fun refreshPlaytime() {
        worker.execute {
            val st = playtime.load()
            main.post {
                stats = st
                rebuild()
            }
        }
    }

    /** Rebuilds [items] from the cached app list; listeners hear about it only if something changed. */
    fun rebuild() {
        val next = infos.map { (key, info) -> toItem(key, info) }.sortedBy { it.key }
        if (next == items) return
        items = next
        listeners.toList().forEach { it() }
    }

    private fun toItem(key: String, info: LauncherActivityInfo): LibraryItem {
        val m = meta[key]
        val pkg = info.componentName.packageName
        val s = stats[pkg]
        val detectedGame = info.applicationInfo.category == ApplicationInfo.CATEGORY_GAME
        return LibraryItem(
            key = key,
            packageName = pkg,
            label = m.name ?: info.label.toString(),
            isGame = m.game ?: detectedGame,
            favorite = m.favorite,
            hidden = m.hidden,
            collections = m.collections.toSet(),
            installTime = info.firstInstallTime,
            lastUsed = maxOf(m.lastLaunch, s?.lastUsed ?: 0L),
            playtimeMs = s?.totalMs ?: 0L,
            launchCount = m.launches,
        )
    }

    fun originalLabel(key: String): String = infos[key]?.label?.toString() ?: ""
    fun todayMs(pkg: String): Long = stats[pkg]?.todayMs ?: 0L
    fun todayGameMs(): Long = items.filter { it.isGame }.sumOf { todayMs(it.packageName) }
    fun item(key: String): LibraryItem? = items.firstOrNull { it.key == key }

    /** Full-resolution icon; call off the main thread. */
    fun loadIcon(key: String): Drawable? {
        val info = infos[key] ?: return null
        val density = context.resources.displayMetrics.densityDpi
        return if (info.user == Process.myUserHandle()) info.getIcon(density) else info.getBadgedIcon(density)
    }

    fun launch(key: String, from: View?): Boolean {
        val info = infos[key] ?: return false
        val opts = from?.let { ActivityOptions.makeScaleUpAnimation(it, 0, 0, it.width, it.height).toBundle() }
        val bounds = from?.let { v -> IntArray(2).also { v.getLocationOnScreen(it) }.let { Rect(it[0], it[1], it[0] + v.width, it[1] + v.height) } }
        return try {
            launcherApps.startMainActivity(info.componentName, info.user, bounds, opts)
            meta.update(key) {
                launches++
                lastLaunch = System.currentTimeMillis()
            }
            rebuild()
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }

    fun openAppInfo(key: String, from: View?) {
        val info = infos[key] ?: return
        val bounds = from?.let { v -> IntArray(2).also { v.getLocationOnScreen(it) }.let { Rect(it[0], it[1], it[0] + v.width, it[1] + v.height) } }
        runCatching { launcherApps.startAppDetailsActivity(info.componentName, info.user, bounds, null) }
    }

    fun isMainProfile(key: String) = infos[key]?.user?.let { it == Process.myUserHandle() } ?: true

    private fun keyOf(component: ComponentName, user: UserHandle): String {
        val base = component.flattenToShortString()
        return if (user == Process.myUserHandle()) base else "$base#${userManager.getSerialNumberForUser(user)}"
    }
}
