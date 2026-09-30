package com.speedyteam101.manga.ui

import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.speedyteam101.manga.core.MangaRepository

private object Routes {
    const val DISCOVER = "discover"
    const val READ = "read"
    const val CATALOG = "catalog/{malId}"
    const val MANGADEX = "md/{mdId}"
    const val READER = "reader/{mdId}/{chapterId}"

    fun catalog(malId: Int) = "catalog/$malId"
    fun mangaDex(mdId: String) = "md/$mdId"
    fun reader(mdId: String, chapterId: String) = "reader/$mdId/$chapterId"
}

private data class Tab(val route: String, val label: String, val icon: ImageVector)

private val tabs = listOf(
    Tab(Routes.DISCOVER, "Discover", Icons.Filled.Home),
    Tab(Routes.READ, "Read", Icons.Filled.PlayArrow),
)

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MangaNavHost(repo: MangaRepository) {
    val nav = rememberNavController()
    val backStack by nav.currentBackStackEntryAsState()
    val route = backStack?.destination?.route

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        bottomBar = {
            if (tabs.any { it.route == route }) {
                NavigationBar {
                    tabs.forEach { tab ->
                        NavigationBarItem(
                            selected = route == tab.route,
                            onClick = {
                                nav.navigate(tab.route) {
                                    popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = { Icon(tab.icon, contentDescription = null) },
                            label = { Text(tab.label) },
                        )
                    }
                }
            }
        },
    ) { padding ->
        NavHost(
            navController = nav,
            startDestination = Routes.DISCOVER,
            modifier = Modifier.padding(padding).consumeWindowInsets(padding),
        ) {
            composable(Routes.DISCOVER) {
                DiscoverScreen(repo, onOpen = { nav.navigate(Routes.catalog(it)) })
            }
            composable(Routes.READ) {
                ReadableScreen(repo, onOpen = { nav.navigate(Routes.mangaDex(it)) })
            }
            composable(
                Routes.CATALOG,
                arguments = listOf(navArgument("malId") { type = NavType.IntType }),
            ) { entry ->
                CatalogDetailScreen(
                    repo = repo,
                    malId = entry.arguments?.getInt("malId") ?: 0,
                    onBack = { nav.popBackStack() },
                    onRead = { nav.navigate(Routes.mangaDex(it)) },
                )
            }
            composable(Routes.MANGADEX) { entry ->
                val mdId = entry.arguments?.getString("mdId").orEmpty()
                MdDetailScreen(
                    repo = repo,
                    id = mdId,
                    onBack = { nav.popBackStack() },
                    onReadChapter = { nav.navigate(Routes.reader(mdId, it)) },
                )
            }
            composable(Routes.READER) { entry ->
                val mdId = entry.arguments?.getString("mdId").orEmpty()
                ReaderScreen(
                    repo = repo,
                    mangaId = mdId,
                    chapterId = entry.arguments?.getString("chapterId").orEmpty(),
                    onBack = { nav.popBackStack() },
                    onOpenChapter = { next ->
                        nav.navigate(Routes.reader(mdId, next)) {
                            popUpTo(Routes.READER) { inclusive = true }
                        }
                    },
                )
            }
        }
    }
}
