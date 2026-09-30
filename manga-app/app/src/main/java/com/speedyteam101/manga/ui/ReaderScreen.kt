package com.speedyteam101.manga.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import coil3.compose.AsyncImage
import com.speedyteam101.manga.core.ChapterItem
import com.speedyteam101.manga.core.MangaRepository
import kotlinx.coroutines.launch

class ReaderViewModel(
    private val repo: MangaRepository,
    private val mangaId: String,
    private val chapterId: String,
) : ViewModel() {
    var pages by mutableStateOf<Load<List<String>>>(Load.Loading)
        private set
    var label by mutableStateOf("")
        private set
    var next by mutableStateOf<ChapterItem?>(null)
        private set

    init {
        load()
        viewModelScope.launch {
            val chapters = loadCatching { repo.chapters(mangaId) }.valueOrNull ?: return@launch
            val index = chapters.indexOfFirst { it.id == chapterId }
            if (index < 0) return@launch
            val current = chapters[index]
            label = current.label
            // Skip other groups' versions of the same chapter and chapters hosted off-site.
            next = chapters.drop(index + 1).firstOrNull {
                it.externalUrl == null && (it.chapter != current.chapter || it.volume != current.volume)
            }
        }
    }

    /** Page URLs expire after ~15 minutes, so reloading asks MangaDex for fresh ones. */
    fun load() {
        pages = Load.Loading
        viewModelScope.launch { pages = loadCatching { repo.pageUrls(chapterId) } }
    }
}

@Composable
fun ReaderScreen(
    repo: MangaRepository,
    mangaId: String,
    chapterId: String,
    onBack: () -> Unit,
    onOpenChapter: (String) -> Unit,
) {
    val vm = viewModel { ReaderViewModel(repo, mangaId, chapterId) }
    DetailScaffold(title = vm.label, onBack = onBack) { modifier ->
        when (val state = vm.pages) {
            Load.Loading -> LoadingState(modifier)
            is Load.Failed -> ErrorState(state.message, vm::load, modifier)
            is Load.Ready -> {
                if (state.value.isEmpty()) {
                    ErrorState("This chapter has no pages on MangaDex.", vm::load, modifier)
                } else {
                    LazyColumn(modifier.fillMaxSize()) {
                        itemsIndexed(state.value, key = { index, _ -> index }) { index, url ->
                            PageImage(url, index, onReload = vm::load)
                        }
                        item {
                            val next = vm.next
                            Box(Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
                                if (next != null) {
                                    Button(onClick = { onOpenChapter(next.id) }) { Text("Next: ${next.label}") }
                                } else {
                                    Text("End of the available chapters.")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PageImage(url: String, index: Int, onReload: () -> Unit) {
    var loaded by remember(url) { mutableStateOf(false) }
    var failed by remember(url) { mutableStateOf(false) }
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        AsyncImage(
            model = url,
            contentDescription = "Page ${index + 1}",
            contentScale = ContentScale.FillWidth,
            // Reserve space until the image arrives so the list doesn't load every page at once.
            modifier = if (loaded) Modifier.fillMaxWidth() else Modifier.fillMaxWidth().height(480.dp),
            onSuccess = {
                loaded = true
                failed = false
            },
            onError = { failed = true },
        )
        when {
            failed -> TextButton(onClick = onReload) { Text("Page ${index + 1} failed to load. Tap to reload.") }
            !loaded -> CircularProgressIndicator()
        }
    }
}
