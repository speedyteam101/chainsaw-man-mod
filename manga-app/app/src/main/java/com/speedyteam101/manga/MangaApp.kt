package com.speedyteam101.manga

import android.app.Application
import coil3.ImageLoader
import coil3.PlatformContext
import coil3.SingletonImageLoader
import coil3.network.okhttp.OkHttpNetworkFetcherFactory
import com.speedyteam101.manga.core.MangaRepository
import com.speedyteam101.manga.core.jikan.JikanApi
import com.speedyteam101.manga.core.mangadex.MangaDexApi
import com.speedyteam101.manga.core.net.Http

class MangaApp : Application(), SingletonImageLoader.Factory {
    private val httpClient by lazy { Http.newClient() }

    val repository by lazy { MangaRepository(JikanApi(httpClient), MangaDexApi(httpClient)) }

    // Images go through the same OkHttp client so they carry the app's User-Agent.
    override fun newImageLoader(context: PlatformContext): ImageLoader =
        ImageLoader.Builder(context)
            .components { add(OkHttpNetworkFetcherFactory(httpClient)) }
            .build()
}
