# Inkframe — frame-by-frame animation for Android

A drawing and animation app in the spirit of Procreate's Animation Assist: a clean
full-screen canvas, pressure-sensitive brushes, layers, onion skinning and a timeline
along the bottom.

It is written in Kotlin against the plain Android framework (no AndroidX or Compose),
so the only build dependency is the Android Gradle plugin.

## Features

**Drawing**
- Brush engine with stamp-based brushes: Studio Pen, Technical Pen, Monoline, Dry Ink,
  6B Pencil, Sketch, Marker, Calligraphy, two airbrushes, Chalk and Charcoal.
- Pen pressure for size and opacity, StreamLine smoothing, start/end taper, texture,
  rotation jitter and scatter — all adjustable per brush (tap the selected brush).
- Eraser with its own brush, size and opacity. The pen's eraser end erases too.
- **QuickShape**: draw a line or loop and hold — it snaps to a straight line or ellipse.
  Keep holding and drag to adjust a line.
- Fill tool (flood fill) with threshold, "grow under lines" and all-layers reference, so
  you can color line art that is on another layer.
- Transform: move, scale, rotate and flip a layer's drawing, with a live preview.
- Eyedropper: touch and hold anywhere, or use the side-bar button.
- Color picker with saturation/brightness square, hue strip, hex entry, recent colors
  and a palette.
- Insert a photo as a new layer.

**Layers**
- Layers run through the whole animation (like an exposure sheet): add, duplicate,
  merge down, reorder, rename, hide, delete.
- Opacity, 15 blend modes (Multiply, Screen, Overlay, …) and alpha lock.

**Animation**
- Timeline of frame thumbnails: tap to select, tap again for options, touch and hold
  then drag to reorder, "+" to add.
- Per-frame hold (show a drawing for several ticks — "animating on twos").
- Onion skin: 0–6 frames either side, adjustable opacity, red/green tint, active layer
  or all layers.
- Playback at 1–60 fps in Loop, Ping-Pong or One Shot mode. Frames are pre-composited
  so playback stays smooth with many layers.

**Canvas and gestures**
- Two fingers: pan, pinch-zoom and rotate (snaps to right angles). Pinch in fast to fit.
- Two-finger tap = undo, three-finger tap = redo, four-finger tap = hide the interface.
- Palm rejection: once a pen is detected, fingers only navigate (configurable).
- Flip the canvas view to check proportions.
- Hover cursor for pens that support hover.

**Files**
- Projects are saved automatically. Long animations don't have to fit in memory: cell
  images are cached in RAM and paged to disk.
- Undo/redo for strokes, fills, transforms, and frame/layer changes.
- Export to **MP4** (H.264), **animated GIF**, a **ZIP of PNG frames**, or the current frame
  as PNG. Save to the device's gallery, share, or save to any folder.

## Building

Requirements: Android Studio (or JDK 17 + Android SDK with platform 35).

```sh
cd animation-app
./gradlew assembleDebug          # app/build/outputs/apk/debug/app-debug.apk
./gradlew testDebugUnitTest      # unit tests for the brush, shape, fill and GIF code
```

Or open the `animation-app` folder in Android Studio and press Run.

The GitHub Actions workflow `.github/workflows/animation-app.yml` builds the debug and
release APKs on every push that touches `animation-app/` and uploads them as the
`inkframe-apk` artifact. The release APK is signed with the debug key so it installs
directly; set up your own signing key before publishing it anywhere.

Minimum Android version: 10 (API 29).

## Code map

| Package | What it does |
| --- | --- |
| `model` | Project, layers and frames; JSON save format; `CellStore` (pixel cache with disk paging) |
| `brush` | Brush presets, stroke smoothing (`StrokePath`), stamp rendering (`StrokeEngine`), `QuickShape` |
| `tools` | Flood fill |
| `history` | Undo/redo commands |
| `render` | Frame compositing, blend modes |
| `editor` | Editor screen: `CanvasView` (drawing and gestures), `TimelineView`, playback, panels |
| `export` | GIF encoder (median-cut palette + LZW), MP4 encoder, PNG ZIP, sharing |
| `gallery` | Project gallery and new-project dialog |
| `ui` | Theme, line icons drawn in code, sliders, color picker, popovers |
