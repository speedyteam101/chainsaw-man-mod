package com.speedyteam101.manga.ui

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/** One page of results plus the cursor for the next page (null when there are no more). */
data class PageResult<T>(val items: List<T>, val next: Int?)

/** Search + infinite scrolling over a cursor-paged source (page numbers or offsets). */
class PagedListViewModel<T>(
    private val firstCursor: Int,
    private val keyOf: (T) -> Any,
    private val load: suspend (query: String?, cursor: Int) -> PageResult<T>,
) : ViewModel() {
    var query by mutableStateOf("")
        private set
    var items by mutableStateOf<List<T>>(emptyList())
        private set
    var isLoading by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set
    var endReached by mutableStateOf(false)
        private set

    private var next: Int? = firstCursor
    private var job: Job? = null
    private var generation = 0

    init {
        loadMore()
    }

    fun keyFor(item: T): Any = keyOf(item)

    fun search(newQuery: String) {
        query = newQuery.trim()
        job?.cancel()
        generation++
        items = emptyList()
        next = firstCursor
        endReached = false
        error = null
        isLoading = false
        loadMore()
    }

    fun retry() {
        error = null
        loadMore()
    }

    fun loadMore() {
        val cursor = next ?: return
        if (isLoading || error != null) return
        isLoading = true
        val myGeneration = generation
        job = viewModelScope.launch {
            try {
                var current: Int? = cursor
                var attempts = 0
                // A page can come back empty after romance filtering; fetch on so the list keeps growing.
                do {
                    val page = load(query.ifBlank { null }, current!!)
                    attempts++
                    if (myGeneration != generation) return@launch
                    val before = items.size
                    items = (items + page.items).distinctBy(keyOf)
                    current = page.next
                    next = page.next
                    endReached = page.next == null
                } while (items.size == before && current != null && attempts < 3)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (myGeneration == generation) error = e.userMessage()
            } finally {
                if (myGeneration == generation) isLoading = false
            }
        }
    }
}
