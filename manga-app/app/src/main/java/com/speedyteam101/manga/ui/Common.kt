package com.speedyteam101.manga.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.UriHandler
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage

@Composable
fun LoadingState(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
}

@Composable
fun ErrorState(message: String, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxWidth().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(message, textAlign = TextAlign.Center)
        Button(onClick = onRetry) { Text("Retry") }
    }
}

@Composable
fun MessageState(message: String, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
        Text(message, textAlign = TextAlign.Center)
    }
}

@Composable
fun SearchField(initial: String, placeholder: String, onSearch: (String) -> Unit, modifier: Modifier = Modifier) {
    var text by rememberSaveable { mutableStateOf(initial) }
    val focus = LocalFocusManager.current
    OutlinedTextField(
        value = text,
        onValueChange = { text = it },
        modifier = modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
        singleLine = true,
        placeholder = { Text(placeholder) },
        leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
        trailingIcon = {
            if (text.isNotEmpty()) {
                IconButton(onClick = { text = ""; onSearch("") }) {
                    Icon(Icons.Filled.Clear, contentDescription = "Clear search")
                }
            }
        },
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
        keyboardActions = KeyboardActions(onSearch = {
            onSearch(text)
            focus.clearFocus()
        }),
    )
}

@Composable
fun CoverCard(title: String, coverUrl: String?, subtitle: String?, onClick: () -> Unit) {
    Card(Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        AsyncImage(
            model = coverUrl,
            contentDescription = title,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxWidth().aspectRatio(2f / 3f),
        )
        Column(Modifier.padding(8.dp)) {
            Text(title, style = MaterialTheme.typography.titleSmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
            if (!subtitle.isNullOrBlank()) {
                Text(subtitle, style = MaterialTheme.typography.bodySmall, maxLines = 1)
            }
        }
    }
}

/** Cover grid backed by a [PagedListViewModel]; loads the next page near the end. */
@Composable
fun <T> PagedCoverGrid(
    vm: PagedListViewModel<T>,
    emptyMessage: String,
    title: (T) -> String,
    cover: (T) -> String?,
    subtitle: (T) -> String?,
    onClick: (T) -> Unit,
    modifier: Modifier = Modifier,
) {
    val items = vm.items
    val error = vm.error
    when {
        items.isEmpty() && error != null -> ErrorState(error, vm::retry, modifier)
        items.isEmpty() && vm.isLoading -> LoadingState(modifier)
        items.isEmpty() && vm.endReached -> MessageState(emptyMessage, modifier)
        else -> {
            val state = rememberLazyGridState()
            LaunchedEffect(state, items.size) {
                snapshotFlow { state.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0 }
                    .collect { last -> if (last >= items.size - 6) vm.loadMore() }
            }
            LazyVerticalGrid(
                columns = GridCells.Adaptive(minSize = 112.dp),
                state = state,
                modifier = modifier.fillMaxSize(),
                contentPadding = PaddingValues(12.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(items, key = { vm.keyFor(it) }) { item ->
                    CoverCard(title(item), cover(item), subtitle(item)) { onClick(item) }
                }
                if (vm.isLoading || error != null) {
                    item(span = { GridItemSpan(maxLineSpan) }) {
                        if (error != null) {
                            ErrorState(error, vm::retry)
                        } else {
                            Box(Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                                CircularProgressIndicator()
                            }
                        }
                    }
                }
            }
        }
    }
}

/** Opens a link in the browser; ignores devices without one instead of crashing. */
fun UriHandler.openSafely(url: String) {
    runCatching { openUri(url) }
}

@Composable
fun rememberSafeUriOpener(): (String) -> Unit {
    val handler = LocalUriHandler.current
    return remember(handler) { { url: String -> handler.openSafely(url) } }
}
