# Manga (No Romance)

An Android app (Kotlin + Jetpack Compose) for browsing and reading manga, with
**romance filtered out everywhere**.

## Where the manga comes from

The app doesn't bundle any manga. It uses two public APIs:

| Tab | Source | What you get |
| --- | --- | --- |
| **Discover** | [Jikan](https://jikan.moe) (unofficial MyAnimeList API) | A near-complete manga catalog to browse and search: covers, synopsis, genres, score, and official/external links. Metadata only, no reading. |
| **Read** | [MangaDex](https://mangadex.org) public API | Titles with English chapters that can be read inside the app. |

On a Discover title, the app looks the series up on MangaDex. It only accepts
the MangaDex entry whose MyAnimeList link matches the title's MAL ID. If that
entry exists, a **Read chapters** button appears. Otherwise the page shows the
official links.

Chapters that MangaDex lists as hosted by an official publisher (they have an
`externalUrl`) open in the browser.

Please respect the rights of creators and publishers. Much of MangaDex is fan
scanlations, and many licensed series aren't available there. Where a series
has an official release, support it.

## How romance is removed

`core/src/main/kotlin/.../RomanceFilter.kt` defines the hidden genres/tags:
**Romance, Boys Love, Girls Love** (to change this, edit `EXCLUDED_NAMES`).

Romance is removed twice:

1. **On the server.** The app looks up the IDs of those genres (Jikan `/genres/manga`) and tags
   (MangaDex `/manga/tag`) by name. It then sends them as exclusions: `genres_exclude=` on Jikan,
   `excludedTags[]=` with `excludedTagsMode=OR` on MangaDex.
2. **On the client.** Every result, detail page and MangaDex match is checked again.
   Anything with a romance genre/tag is dropped.

Other defaults: adult content is excluded (Jikan `sfw=true`; MangaDex `contentRating[]` = safe,
suggestive), and chapters are English only (`MangaDexApi.LANGUAGE`).

## Project layout

- `core/`: pure Kotlin/JVM module containing the API clients, the romance filter and the repository.
  It has unit tests (MockWebServer with canned JSON) and builds without the Android SDK:
  `./gradlew -PcoreOnly=true :core:test`
- `app/`: the Android app (Compose, Navigation, Coil 3 for images). Screens:
  Discover, Read, catalog detail, MangaDex title + chapter list, and a vertical-scroll reader.

## Building

Requires JDK 17+ and the Android SDK (API 35).

```
./gradlew :app:assembleDebug
```

The APK ends up in `app/build/outputs/apk/debug/`. GitHub Actions (`.github/workflows/manga-app.yml` at the repository root)
runs the tests and builds the debug APK on every push, and uploads it as the
`manga-no-romance-debug-apk` artifact.

## API etiquette

- Jikan allows about 3 requests/second and 60/minute. The client spaces calls 400 ms apart and retries once on HTTP 429.
- MangaDex asks clients to send an identifying `User-Agent` (set in `core/.../net/Http.kt`).
  Page image URLs from `/at-home/server` expire after about 15 minutes. The reader re-fetches them when you tap reload.
