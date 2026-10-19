package com.silkie.launcher.data

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Process
import java.util.Calendar

/**
 * Per-app foreground time from Android's usage stats. Needs the user to grant "Usage access";
 * without it everything reads as zero and the launcher falls back to its own launch counts.
 * The numbers are whatever Android reports, so they are approximate.
 */
class Playtime(private val context: Context) {
    class Stat(val totalMs: Long, val todayMs: Long, val lastUsed: Long)

    fun hasAccess(): Boolean {
        val ops = context.getSystemService(AppOpsManager::class.java) ?: return false
        val mode = ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Package name → stats over the last year. Call off the main thread. */
    fun load(): Map<String, Stat> {
        if (!hasAccess()) return emptyMap()
        val usm = context.getSystemService(UsageStatsManager::class.java) ?: return emptyMap()
        val now = System.currentTimeMillis()
        val year = runCatching { usm.queryAndAggregateUsageStats(now - 365L * 24 * 3600_000, now) }.getOrNull().orEmpty()
        val today = runCatching { usm.queryAndAggregateUsageStats(startOfDay(now), now) }.getOrNull().orEmpty()
        val out = HashMap<String, Stat>()
        for ((pkg, s) in year) {
            out[pkg] = Stat(s.totalTimeInForeground, today[pkg]?.totalTimeInForeground ?: 0L, s.lastTimeUsed)
        }
        for ((pkg, s) in today) {
            if (pkg !in out) out[pkg] = Stat(s.totalTimeInForeground, s.totalTimeInForeground, s.lastTimeUsed)
        }
        return out
    }

    private fun startOfDay(now: Long): Long = Calendar.getInstance().apply {
        timeInMillis = now
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis
}
