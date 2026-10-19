# Silkie — a game-first home screen for Android

A home-screen launcher in the spirit of handheld front ends such as Cocoon: big, controller-friendly
tabs for your games and apps, a "continue playing" card, playtime, widgets, and a lot of ways to
make it look the way you want. It has a mascot, **Silkie** the silk moth, who lives on the home
screen, reacts to what you do and grows up as you play.

Like Inkframe, it's Kotlin against the plain Android framework (no AndroidX or Compose), so the
only build dependency is the Android Gradle plugin. Everything, the mascot included, is drawn in
code.

## Features

**Home screen**
- Tabs along the top: Home, Games, Apps, Favorites, plus one per collection you create.
- Home tab: big clock and date, Silkie with a speech bubble, a *Continue playing* card for your
  last game, and shelves for *Jump back in*, Favorites, Games and Apps.
- Android widgets on the Home tab (add, reorder, resize, remove).
- Library tabs in **grid**, **list** or **carousel** layout, sorted by name, most played,
  recently played or newest.
- Search across every app (or start typing on a keyboard); falls back to a web search.
- Games are detected from the category an app declares for itself (`appCategory="game"`); many
  games set it, some don't, so you can mark anything as a game or not.

**Per-app options** (long-press, or X on a controller): favorite, mark as game / app, add to
collections, rename, hide, app info, uninstall.

**Controller and keyboard**
- D-pad / stick to move, A open, B back, X options, Y favorite, L1/R1 tabs, L2/R2 page,
  Start settings, Select search. Option to swap A and B (Nintendo-style layout).
- Focused tiles zoom and get an accent ring; a hint bar shows the buttons.

**Playtime** — per-app play time from Android's usage stats (grant *Usage access* in
Settings › Library and playtime). These numbers are what Android reports, so treat them as
approximate. Without access, Silkie still counts launches made from the launcher.

**Silkie, the mascot**
- Three life stages — caterpillar, cocoon, moth — chosen by you or grown automatically with
  your game playtime (or launches).
- Blinks, bobs, flutters, looks toward the app you've selected, hops and shows hearts when
  tapped, cheers when you start a game, says "welcome back" with your session length, falls
  asleep at night (with floating z's), and comments on low battery and charging.
- Customize: name, body / wing / cheek colors, 6 eye styles, 11 hats (beanie, crown, wizard,
  party hat, headphones, bow, flower, cap, horns, halo), 6 accessories (scarf, glasses,
  sunglasses, bow tie, game controller), size, position, chattiness, speech bubbles, a small
  corner buddy on the other tabs.

**Customization**
- 12 theme presets (Moonlight, AMOLED, Retro Pocket, Sakura, Forest, Ocean, Paper, Synthwave,
  Chainsaw, Snowfall, Sunset, Mint) and every color editable (picker with swatches, HSV sliders
  and hex).
- Backgrounds: solid, gradient (any angle), glow, dots, grid, animated retro horizon, your own
  picture (with blur on Android 12+), or the system wallpaper; adjustable dim.
- Ambient effects: drifting silk, fireflies, snow, bubbles, sparkles, petals — with an amount
  slider.
- Cards: flat, outlined, glass or raised; corner roundness; 9 fonts; text size.
- Icons: 10 shapes (squircle, circle, rounded, square, teardrop, hexagon, octagon, clover,
  diamond, original) applied to adaptive icons properly, themed (monochrome) icons on
  Android 13+, plates for old-style icons, outline, black-and-white; icon size, labels on/off,
  label size, two-line labels, spacing, focus zoom, grid columns.
- Clock: large / compact / hidden, 12/24 h, seconds, date, battery; hide the status bar.
- Gestures: swipe up, swipe down, double tap and long press on empty space can each open
  search, a tab, settings, switch layout or poke the mascot; swipe sideways for tabs.
- Motion: reduce motion, animation speed, vibration, navigation sounds.
- Backup and restore all settings and app tweaks to a JSON file; reset to defaults.

## Building

Requirements: Android Studio (or JDK 17 + Android SDK with platform 35).

```sh
cd launcher-app
./gradlew assembleDebug          # app/build/outputs/apk/debug/app-debug.apk
./gradlew testDebugUnitTest      # unit tests for search/sorting, the mascot's brain and colors
```

The GitHub Actions workflow `.github/workflows/launcher-app.yml` builds the debug and release
APKs on every push that touches `launcher-app/` and uploads them as the `silkie-apk` artifact.
The release APK is signed with the debug key so it installs directly; set up your own signing
key before publishing it anywhere.

After installing, press Home and pick Silkie (or use the banner at the top of Silkie's settings).
Minimum Android version: 10 (API 29).

## Code map

| Package | What it does |
| --- | --- |
| `data` | Installed apps via `LauncherApps` (work profile included), per-app tweaks (`AppMeta`), playtime (`Playtime`), filtering / sorting / fuzzy search (`Library`) |
| `home` | Home screen activity (tabs, controller keys, gestures), pages (home, grid, list, carousel), app tiles, options menu, search, widget host |
| `mascot` | `MascotView` (the drawing and animation) and `MascotBrain` (moods, lines, growing up) |
| `settings` | `Prefs` (every option), theme presets, the settings screen |
| `ui` | Palette, icon shapes and rendering, backgrounds and ambient effects, speech bubble, line icons, color picker |
