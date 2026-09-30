package com.speedyteam101.manga.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.speedyteam101.manga.core.CatalogItem
import com.speedyteam101.manga.core.MangaRepository
import com.speedyteam101.manga.core.MdTitle

/** Browse the whole MyAnimeList catalog (metadata only), romance removed. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DiscoverScreen(repo: MangaRepository, onOpen: (Int) -> Unit) {
    val vm = viewModel {
        PagedListViewModel<CatalogItem>(firstCursor = 1, keyOf = { it.malId }) { query, page ->
            val result = repo.discover(query, page)
            PageResult(result.items, if (result.hasMore) page + 1 else null)
        }
    }
    Scaffold(topBar = { TopAppBar(title = { Text("Discover") }) }) { padding ->
        Column(Modifier.padding(padding)) {
            SearchField(vm.query, "Search all manga", vm::search)
            SourceNote("Catalog from MyAnimeList (via Jikan). Romance, Boys Love and Girls Love are hidden.")
            PagedCoverGrid(
                vm = vm,
                emptyMessage = "No results.",
                title = { it.title },
                cover = { it.coverUrl },
                subtitle = { item -> listOfNotNull(item.type, item.score?.let { "★ %.2f".format(it) }).joinToString(" · ") },
                onClick = { onOpen(it.malId) },
            )
        }
    }
}

/** Browse titles that can be read in the app (MangaDex, English chapters), romance removed. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReadableScreen(repo: MangaRepository, onOpen: (String) -> Unit) {
    val vm = viewModel {
        PagedListViewModel<MdTitle>(firstCursor = 0, keyOf = { it.id }) { query, offset ->
            val result = repo.browseMangaDex(query, offset)
            PageResult(result.items, result.nextOffset)
        }
    }
    Scaffold(topBar = { TopAppBar(title = { Text("Read") }) }) { padding ->
        Column(Modifier.padding(padding)) {
            SearchField(vm.query, "Search readable manga", vm::search)
            SourceNote("Readable in the app via MangaDex (English). Romance, Boys' Love and Girls' Love are hidden.")
            PagedCoverGrid(
                vm = vm,
                emptyMessage = "No results.",
                title = { it.title },
                cover = { it.coverUrl },
                subtitle = { item -> listOfNotNull(item.year?.toString(), item.status).joinToString(" · ") },
                onClick = { onOpen(it.id) },
            )
        }
    }
}

@Composable
fun SourceNote(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 2.dp),
    )
}
