package com.speedyteam101.manga.core

import com.speedyteam101.manga.core.jikan.JikanApi
import com.speedyteam101.manga.core.mangadex.MangaDexApi
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Exercises both clients against canned JSON shaped like the real APIs. */
class RepositoryTest {
    private val server = MockWebServer()
    private val requests = mutableListOf<RecordedRequest>()
    private lateinit var repo: MangaRepository

    @BeforeTest
    fun setUp() {
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                synchronized(requests) { requests += request }
                val path = request.requestUrl!!.encodedPath
                val body = when {
                    path == "/jikan/genres/manga" -> JIKAN_GENRES
                    path == "/jikan/manga" -> JIKAN_SEARCH
                    path == "/jikan/manga/2" -> JIKAN_ROMANCE_SINGLE
                    path == "/md/manga/tag" -> MD_TAGS
                    path == "/md/manga" -> MD_SEARCH
                    path.endsWith("/feed") -> MD_FEED
                    path.startsWith("/md/at-home/server/") -> MD_AT_HOME
                    else -> return MockResponse().setResponseCode(404)
                }
                return MockResponse().setBody(body).addHeader("Content-Type", "application/json")
            }
        }
        server.start()
        val client = OkHttpClient()
        repo = MangaRepository(
            JikanApi(client, server.url("/jikan/"), minIntervalMs = 0),
            MangaDexApi(client, server.url("/md/")),
        )
    }

    @AfterTest
    fun tearDown() = server.shutdown()

    private fun lastRequestTo(path: String) = synchronized(requests) {
        requests.last { it.requestUrl!!.encodedPath == path }.requestUrl!!
    }

    @Test
    fun discoverExcludesRomanceOnServerAndClient() = runTest {
        val page = repo.discover(query = "saw", page = 1)

        val url = lastRequestTo("/jikan/manga")
        assertEquals("22,26,28", url.queryParameter("genres_exclude"))
        assertEquals("saw", url.queryParameter("q"))
        assertEquals("true", url.queryParameter("sfw"))

        // The romance entry slipped through the server filter but is removed client-side.
        assertEquals(listOf(1), page.items.map { it.malId })
        assertEquals("https://example.test/large.jpg", page.items[0].coverUrl)
        assertTrue(page.hasMore)
    }

    @Test
    fun catalogItemHidesRomance() = runTest {
        assertNull(repo.catalogItem(2))
    }

    @Test
    fun mangaDexSearchSendsExcludedTags() = runTest {
        val page = repo.browseMangaDex(query = null, offset = 0)

        val url = lastRequestTo("/md/manga")
        assertEquals(
            listOf("tag-bl", "tag-gl", "tag-romance"),
            url.queryParameterValues("excludedTags[]").filterNotNull().sorted(),
        )
        assertEquals("OR", url.queryParameter("excludedTagsMode"))
        assertEquals(listOf("cover_art", "author"), url.queryParameterValues("includes[]"))
        assertEquals(listOf("safe", "suggestive"), url.queryParameterValues("contentRating[]"))
        assertEquals("desc", url.queryParameter("order[followedCount]"))

        // md-2 is tagged Romance and must be dropped; empty-array description must parse.
        assertEquals(listOf("md-1"), page.items.map { it.id })
        val title = page.items[0]
        assertEquals("Test Action Manga", title.title)
        assertEquals("https://uploads.mangadex.org/covers/md-1/cover.png.256.jpg", title.coverUrl)
        assertEquals(1, title.malId)
        assertEquals(listOf("Some Author"), title.authors)
        assertNull(title.description)
        assertEquals(2, page.nextOffset)
    }

    @Test
    fun findsMangaDexEntryByMalLink() = runTest {
        val item = repo.discover(query = null, page = 1).items.single()
        val match = repo.findOnMangaDex(item)
        assertNotNull(match)
        assertEquals("md-1", match.id)
    }

    @Test
    fun noMangaDexMatchWithoutMalLink() = runTest {
        val item = repo.discover(query = null, page = 1).items.single().copy(malId = 999)
        assertNull(repo.findOnMangaDex(item))
    }

    @Test
    fun chaptersAndPages() = runTest {
        val chapters = repo.chapters("md-1")
        assertEquals(2, chapters.size)
        assertEquals("Vol. 1 Ch. 1 – Start", chapters[0].label)
        assertEquals("Group A", chapters[0].group)
        assertEquals("https://publisher.example/ch2", chapters[1].externalUrl)

        val feedUrl = lastRequestTo("/md/manga/md-1/feed")
        assertEquals("en", feedUrl.queryParameter("translatedLanguage[]"))

        assertEquals(
            listOf("https://node.example/data/abc/p1.png", "https://node.example/data/abc/p2.png"),
            repo.pageUrls("ch-1"),
        )
        assertEquals(listOf("https://node.example/data-saver/abc/s1.jpg"), repo.pageUrls("ch-1", dataSaver = true))
    }

    private companion object {
        val JIKAN_GENRES = """
            {"data":[
              {"mal_id":1,"name":"Action","url":"u","count":1},
              {"mal_id":22,"name":"Romance","url":"u","count":1},
              {"mal_id":28,"name":"Boys Love","url":"u","count":1},
              {"mal_id":26,"name":"Girls Love","url":"u","count":1},
              {"mal_id":22,"name":"Romance","url":"u","count":1}
            ]}
        """.trimIndent()

        val JIKAN_SEARCH = """
            {"pagination":{"last_visible_page":5,"has_next_page":true,"current_page":1},
             "data":[
              {"mal_id":1,"url":"https://myanimelist.net/manga/1","title":"Test Action Manga","title_english":null,
               "images":{"jpg":{"image_url":"https://example.test/small.jpg","large_image_url":"https://example.test/large.jpg"}},
               "type":"Manga","chapters":null,"status":"Publishing","score":8.5,"synopsis":"Fights.",
               "authors":[{"mal_id":9,"type":"people","name":"Author, Some","url":"u"}],
               "genres":[{"mal_id":1,"type":"manga","name":"Action","url":"u"}],
               "explicit_genres":[],"themes":null,"demographics":[{"mal_id":27,"type":"manga","name":"Shounen","url":"u"}]},
              {"mal_id":2,"title":"Test Love Story","genres":[{"mal_id":22,"type":"manga","name":"Romance","url":"u"}]}
            ]}
        """.trimIndent()

        val JIKAN_ROMANCE_SINGLE = """
            {"data":{"mal_id":2,"title":"Test Love Story","themes":[],"genres":[{"mal_id":22,"name":"Romance"}]}}
        """.trimIndent()

        val MD_TAGS = """
            {"result":"ok","response":"collection","limit":100,"offset":0,"total":4,"data":[
              {"id":"tag-action","type":"tag","attributes":{"name":{"en":"Action"},"description":{},"group":"genre","version":1},"relationships":[]},
              {"id":"tag-romance","type":"tag","attributes":{"name":{"en":"Romance"},"description":[],"group":"genre","version":1},"relationships":[]},
              {"id":"tag-bl","type":"tag","attributes":{"name":{"en":"Boys' Love"},"description":[],"group":"genre","version":1},"relationships":[]},
              {"id":"tag-gl","type":"tag","attributes":{"name":{"en":"Girls' Love"},"description":[],"group":"genre","version":1},"relationships":[]}
            ]}
        """.trimIndent()

        val MD_SEARCH = """
            {"result":"ok","response":"collection","limit":24,"offset":0,"total":10,"data":[
              {"id":"md-1","type":"manga","attributes":{
                 "title":{"en":"Test Action Manga"},"altTitles":[{"ja":"テスト"}],"description":[],
                 "links":{"mal":"1","al":"5"},"status":"ongoing","year":2020,"contentRating":"safe",
                 "tags":[{"id":"tag-action","type":"tag","attributes":{"name":{"en":"Action"},"group":"genre"},"relationships":[]}]},
               "relationships":[
                 {"id":"a1","type":"author","attributes":{"name":"Some Author"}},
                 {"id":"a1","type":"artist","attributes":{"name":"Some Author"}},
                 {"id":"c1","type":"cover_art","attributes":{"fileName":"cover.png"}}]},
              {"id":"md-2","type":"manga","attributes":{
                 "title":{"ja-ro":"Koi"},"altTitles":[],"description":{"en":"Love."},"links":null,
                 "tags":[{"id":"tag-romance","type":"tag","attributes":{"name":{"en":"Romance"},"group":"genre"},"relationships":[]}]},
               "relationships":[]}
            ]}
        """.trimIndent()

        val MD_FEED = """
            {"result":"ok","response":"collection","limit":100,"offset":0,"total":2,"data":[
              {"id":"ch-1","type":"chapter","attributes":{"title":"Start","volume":"1","chapter":"1","pages":2,
                "translatedLanguage":"en","externalUrl":null},
               "relationships":[{"id":"g1","type":"scanlation_group","attributes":{"name":"Group A"}}]},
              {"id":"ch-2","type":"chapter","attributes":{"title":null,"volume":null,"chapter":"2","pages":0,
                "translatedLanguage":"en","externalUrl":"https://publisher.example/ch2"},"relationships":[]}
            ]}
        """.trimIndent()

        val MD_AT_HOME = """
            {"result":"ok","baseUrl":"https://node.example/","chapter":{"hash":"abc","data":["p1.png","p2.png"],"dataSaver":["s1.jpg"]}}
        """.trimIndent()
    }
}
