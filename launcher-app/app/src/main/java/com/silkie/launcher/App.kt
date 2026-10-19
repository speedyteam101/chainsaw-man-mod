package com.silkie.launcher

import android.app.Application
import android.content.Context
import com.silkie.launcher.data.AppMeta
import com.silkie.launcher.data.AppRepository
import com.silkie.launcher.data.Playtime
import com.silkie.launcher.settings.Prefs
import com.silkie.launcher.ui.IconRenderer

class App : Application() {
    lateinit var prefs: Prefs
        private set
    lateinit var repo: AppRepository
        private set
    lateinit var playtime: Playtime
        private set
    val icons = IconRenderer()

    override fun onCreate() {
        super.onCreate()
        prefs = Prefs(getSharedPreferences("settings", MODE_PRIVATE))
        playtime = Playtime(this)
        repo = AppRepository(this, AppMeta(getSharedPreferences("apps", MODE_PRIVATE)), playtime)
        repo.reload()
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level >= TRIM_MEMORY_BACKGROUND) icons.clear()
    }
}

val Context.app: App get() = applicationContext as App
