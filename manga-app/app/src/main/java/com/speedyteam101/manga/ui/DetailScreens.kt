package com.speedyteam101.manga.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import coil3.compose.AsyncImage
import com.speedyteam101.manga.core.CatalogItem
import com.speedyteam101.manga.core.ChapterItem
import com.speedyteam101.manga.core.ExternalLink
import com.speedyteam101.manga.core.MangaRepository
import com.speedyteam101.manga.core.MdTitle
import kotlinx.coroutines.launch

// ---------------- Catalog (MyAnimeList) detail ----------------

class CatalogDetailViewModel(private val repo: MangaRepository, private val malId: Int) : ViewModel() {
    var item by mutableStateOf<Load<CatalogItem?>>(Load.Loading)
        private set
    var links by mutableStateOf<List<ExternalLink>>(emptyList())
        private set
    var readable by mutableStateOf<Load<MdTitle?>>(Load.Loading)
        private set

    init {
        load()
    }

    fun load() {
        item = Load.Loading
        readable = Load.Loading
        viewModelScope.launch {
            val loaded = loadCatching { repo.catalogItem(malId) }
            item = loaded
            val catalogItem = loaded.valueOrNull ?: return@launch
            links = loadCatching { repo.officialLinks(malId) }.valueOrNull.orEmpty()
            readable = loadCatching { repo.findOnMangaDex(catalogItem) }
        }
    }

    fun retryReadable() {
        val catalogItem = item.valueOrNull ?: return
        readable = Load.Loading
        viewModelScope.launch { readable = loadCatching { repo.findOnMangaDex(catalogItem) } }
    }
}

@Composable
fun CatalogDetailScreen(repo: MangaRepository, malId: Int, onBack: () -> Unit, onRead: (String) -> Unit) {
    val vm = viewModel { CatalogDetailViewModel(repo, malId) }
    val open = rememberSafeUriOpener()
    DetailScaffold(title = vm.item.valueOrNull?.title ?: "", onBack = onBack) { modifier ->
        when (val state = vm.item) {
            Load.Loading -> LoadingState(modifier)
            is Load.Failed -> ErrorState(state.message, vm::load, modifier)
            is Load.Ready -> {
                val manga = state.value
                if (manga == null) {
                    MessageState("This title is tagged as romance, so it's hidden.", modifier)
                } else {
                    LazyColumn(modifier.fillMaxSize()) {
                        item {
                            Header(
                                coverUrl = manga.coverUrl,
                                title = manga.title,
                                lines = listOfNotNull(
                                    manga.titleEnglish,
                                    manga.authors.takeIf { it.isNotEmpty() }?.joinToString(", "),
                                    listOfNotNull(manga.type, manga.status, manga.chapters?.let { "$it ch." })
                                        .joinToString(" · "),
                                    manga.score?.let { "Score ★ %.2f".format(it) },
                                ),
                                genres = manga.genres,
                            )
                        }
                        item { ReadableSection(vm.readable, onRead, vm::retryReadable) }
                        item { Synopsis(manga.synopsis) }
                        item { SectionTitle("Official & external links") }
                        items(vm.links, key = { it.url }) { link ->
                            ListItem(
                                headlineContent = { Text(link.name) },
                                supportingContent = { Text(link.url, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                                modifier = Modifier.clickable { open(link.url) },
                            )
                        }
                        manga.url?.let { url ->
                            item {
                                ListItem(
                                    headlineContent = { Text("View on MyAnimeList") },
                                    modifier = Modifier.clickable { open(url) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ReadableSection(state: Load<MdTitle?>, onRead: (String) -> Unit, onRetry: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
        when (state) {
            Load.Loading -> Row(verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                Spacer(Modifier.width(12.dp))
                Text("Checking whether it can be read in the app…")
            }
            is Load.Failed -> Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Couldn't check MangaDex: ${state.message}", Modifier.weight(1f))
                TextButton(onClick = onRetry) { Text("Retry") }
            }
            is Load.Ready -> {
                val md = state.value
                if (md == null) {
                    Text(
                        "Not readable in the app (no English MangaDex entry). Try the official links below.",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                } else {
                    Button(onClick = { onRead(md.id) }, modifier = Modifier.fillMaxWidth()) {
                        Text("Read chapters")
                    }
                }
            }
        }
    }
}

// ---------------- MangaDex title + chapter list ----------------

class MdDetailViewModel(private val repo: MangaRepository, private val id: String) : ViewModel() {
    var title by mutableStateOf<Load<MdTitle?>>(Load.Loading)
        private set
    var chapters by mutableStateOf<Load<List<ChapterItem>>>(Load.Loading)
        private set

    init {
        load()
    }

    fun load() {
        title = Load.Loading
        chapters = Load.Loading
        viewModelScope.launch {
            val loaded = loadCatching { repo.mangaDexTitle(id) }
            title = loaded
            if (loaded.valueOrNull != null) loadChapters(refresh = false)
        }
    }

    fun retryChapters() {
        chapters = Load.Loading
        viewModelScope.launch { loadChapters(refresh = true) }
    }

    private suspend fun loadChapters(refresh: Boolean) {
        chapters = loadCatching { repo.chapters(id, refresh) }
    }
}

@Composable
fun MdDetailScreen(repo: MangaRepository, id: String, onBack: () -> Unit, onReadChapter: (String) -> Unit) {
    val vm = viewModel { MdDetailViewModel(repo, id) }
    val open = rememberSafeUriOpener()
    var newestFirst by rememberSaveable { mutableStateOf(false) }
    DetailScaffold(title = vm.title.valueOrNull?.title ?: "", onBack = onBack) { modifier ->
        when (val state = vm.title) {
            Load.Loading -> LoadingState(modifier)
            is Load.Failed -> ErrorState(state.message, vm::load, modifier)
            is Load.Ready -> {
                val md = state.value
                if (md == null) {
                    MessageState("This title is tagged as romance, so it's hidden.", modifier)
                } else {
                    LazyColumn(modifier.fillMaxSize()) {
                        item {
                            Header(
                                coverUrl = md.coverUrl,
                                title = md.title,
                                lines = listOfNotNull(
                                    md.authors.takeIf { it.isNotEmpty() }?.joinToString(", "),
                                    listOfNotNull(md.year?.toString(), md.status).joinToString(" · "),
                                ),
                                genres = md.tags,
                            )
                        }
                        item { Synopsis(md.description) }
                        item {
                            Row(
                                Modifier.fillMaxWidth().padding(end = 8.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                SectionTitle("Chapters (English)", Modifier.weight(1f))
                                TextButton(onClick = { newestFirst = !newestFirst }) {
                                    Text(if (newestFirst) "Oldest first" else "Newest first")
                                }
                            }
                        }
                        when (val list = vm.chapters) {
                            Load.Loading -> item { LoadingState(Modifier.height(120.dp)) }
                            is Load.Failed -> item { ErrorState(list.message, vm::retryChapters) }
                            is Load.Ready -> {
                                val ordered = if (newestFirst) list.value.asReversed() else list.value
                                if (ordered.isEmpty()) {
                                    item { Text("No English chapters available.", Modifier.padding(16.dp)) }
                                }
                                items(ordered, key = { it.id }) { chapter ->
                                    ChapterRow(chapter) {
                                        val external = chapter.externalUrl
                                        if (external != null) open(external) else onReadChapter(chapter.id)
                                    }
                                    HorizontalDivider()
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
private fun ChapterRow(chapter: ChapterItem, onClick: () -> Unit) {
    val details = listOfNotNull(
        chapter.group,
        if (chapter.externalUrl != null) "Official site ↗" else null,
    ).joinToString(" · ")
    val supporting: (@Composable () -> Unit)? = if (details.isNotEmpty()) {
        { Text(details) }
    } else {
        null
    }
    ListItem(
        headlineContent = { Text(chapter.label, maxLines = 2, overflow = TextOverflow.Ellipsis) },
        supportingContent = supporting,
        modifier = Modifier.clickable(onClick = onClick),
    )
}

// ---------------- Shared pieces ----------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DetailScaffold(title: String, onBack: () -> Unit, content: @Composable (Modifier) -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding -> content(Modifier.padding(padding)) }
}

@Composable
private fun Header(coverUrl: String?, title: String, lines: List<String>, genres: List<String>) {
    Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        AsyncImage(
            model = coverUrl,
            contentDescription = title,
            contentScale = ContentScale.Crop,
            modifier = Modifier.width(120.dp).height(180.dp),
        )
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = MaterialTheme.typography.titleLarge)
            lines.filter { it.isNotBlank() }.forEach { Text(it, style = MaterialTheme.typography.bodyMedium) }
            if (genres.isNotEmpty()) {
                Text(
                    genres.joinToString(" · "),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

@Composable
private fun Synopsis(text: String?) {
    if (text.isNullOrBlank()) return
    var expanded by rememberSaveable { mutableStateOf(false) }
    Text(
        text.trim(),
        style = MaterialTheme.typography.bodyMedium,
        maxLines = if (expanded) Int.MAX_VALUE else 6,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier
            .fillMaxWidth()
            .clickable { expanded = !expanded }
            .padding(horizontal = 16.dp, vertical = 8.dp),
    )
}

@Composable
private fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        style = MaterialTheme.typography.titleMedium,
        modifier = modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 4.dp),
    )
}
