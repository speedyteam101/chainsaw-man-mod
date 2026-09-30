package com.speedyteam101.manga

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.speedyteam101.manga.ui.MangaNavHost
import com.speedyteam101.manga.ui.theme.MangaTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val repository = (application as MangaApp).repository
        setContent {
            MangaTheme {
                MangaNavHost(repository)
            }
        }
    }
}
