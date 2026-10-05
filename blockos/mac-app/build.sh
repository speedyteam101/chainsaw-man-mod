#!/usr/bin/env bash
# Builds the BlockOS app with Electron and zips it.
#
#   ./build.sh                    # Mac: Apple Silicon (arm64) and Intel (x64)
#   ./build.sh --mac arm64        # Mac, one architecture
#   ./build.sh --win x64 arm64    # Windows (build this on Windows, e.g. GitHub's windows runner,
#                                 # so the .exe gets its icon; elsewhere it needs Wine)
#
# Mac builds are signed ad hoc with codesign on a Mac, or with rcodesign
# (https://github.com/indygreg/apple-platform-rs) if it's on the PATH.
# Output: build/BlockOS-mac-<arch>.zip or build/BlockOS-windows-<arch>.zip
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
BUILD="$HERE/build"
PLATFORM=darwin
case "${1:-}" in
  --mac) PLATFORM=darwin; shift ;;
  --win) PLATFORM=win32; shift ;;
esac
if [ $# -gt 0 ]; then ARCHES=("$@"); elif [ "$PLATFORM" = win32 ]; then ARCHES=(x64 arm64); else ARCHES=(arm64 x64); fi
ELECTRON_VERSION="$(node -p "require('$HERE/package.json').devDependencies.electron")"

cd "$HERE"
[ -d node_modules/@electron/packager ] || npm install --no-audit --no-fund

# Stage the app: main.js, a minimal package.json, and the desktop with only the games
# listed in the catalog (unfinished game folders are left out).
STAGE="$BUILD/stage"
rm -rf "${BUILD:?}"
mkdir -p "$STAGE/shell/games"
cp main.js "$ROOT/multiplayer/relay.js" "$STAGE/"
node -e '
  const p = require("./package.json");
  delete p.devDependencies; delete p.scripts;
  require("fs").writeFileSync(process.argv[1], JSON.stringify(p, null, 2));
' "$STAGE/package.json"
(cd "$STAGE" && npm install --omit=dev --no-audit --no-fund --silent)   # the game server's "ws" library
(cd "$ROOT/shell" && cp -R index.html style.css app.js avatar.js assets "$STAGE/shell/")
cp "$ROOT/shell/games/catalog.js" "$ROOT/shell/games/kit.js" "$ROOT/shell/games/kit.css" "$ROOT/shell/games/kit3d.js" "$STAGE/shell/games/"
cp -R "$ROOT/shell/games/lib" "$STAGE/shell/games/lib"
node -e '
  global.window = {};
  require(process.argv[1]);
  console.log(window.BLOCKOS_GAMES.map((g) => g.id).join("\n"));
' "$ROOT/shell/games/catalog.js" | while read -r id; do
  cp -R "$ROOT/shell/games/$id" "$STAGE/shell/games/$id"
done

for arch in "${ARCHES[@]}"; do
  echo "==> Packaging BlockOS for $PLATFORM $arch"
  if [ "$PLATFORM" = win32 ]; then
    npx --no-install electron-packager "$STAGE" BlockOS \
      --platform=win32 --arch="$arch" --electron-version="$ELECTRON_VERSION" \
      --icon="$HERE/BlockOS.ico" --app-copyright="BlockOS" \
      --win32metadata.CompanyName="BlockOS" --win32metadata.ProductName="BlockOS" \
      --win32metadata.FileDescription="BlockOS" \
      --no-asar --out="$BUILD" --overwrite --quiet
    # Zip as a folder called "BlockOS" with BlockOS.exe inside.
    rm -rf "$BUILD/win-$arch"
    mkdir -p "$BUILD/win-$arch"
    mv "$BUILD/BlockOS-win32-$arch" "$BUILD/win-$arch/BlockOS"
    ZIP="$BUILD/BlockOS-windows-$arch.zip"
    if command -v 7z >/dev/null 2>&1; then
      (cd "$BUILD/win-$arch" && 7z a -tzip -bd -y "$ZIP" BlockOS >/dev/null)
    else
      (cd "$BUILD/win-$arch" && zip -qry "$ZIP" BlockOS)
    fi
    echo "    $ZIP"
    continue
  fi

  npx --no-install electron-packager "$STAGE" BlockOS \
    --platform=darwin --arch="$arch" --electron-version="$ELECTRON_VERSION" \
    --icon="$ROOT/mac/BlockOS.icns" --app-bundle-id=io.github.speedyteam101.blockos \
    --app-category-type=public.app-category.games --app-copyright="BlockOS" \
    --no-asar --out="$BUILD" --overwrite --quiet
  APP="$BUILD/BlockOS-darwin-$arch/BlockOS.app"

  # Apple Silicon Macs refuse to run apps without a valid signature, so sign ad hoc.
  if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP"
  elif command -v rcodesign >/dev/null 2>&1; then
    rcodesign sign "$APP" >/dev/null 2>&1
  else
    echo "warning: no codesign/rcodesign found; the $arch app is unsigned and may not open" >&2
  fi

  if command -v ditto >/dev/null 2>&1; then
    ditto -c -k --keepParent "$APP" "$BUILD/BlockOS-mac-$arch.zip"   # the macOS way; keeps signatures intact
  else
    (cd "$BUILD/BlockOS-darwin-$arch" && zip -qry "$BUILD/BlockOS-mac-$arch.zip" BlockOS.app)
  fi
  echo "    $BUILD/BlockOS-mac-$arch.zip"
done
