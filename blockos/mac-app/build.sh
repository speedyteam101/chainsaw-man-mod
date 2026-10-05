#!/usr/bin/env bash
# Builds BlockOS.app for macOS (Apple Silicon and Intel) and zips each one.
# Runs on macOS or Linux; needs Node.js. Signs the app ad hoc with codesign on a Mac,
# or with rcodesign (https://github.com/indygreg/apple-platform-rs) if it's on the PATH.
#
#   ./build.sh               # both arm64 and x64
#   ./build.sh arm64         # just one
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
BUILD="$HERE/build"
if [ $# -gt 0 ]; then ARCHES=("$@"); else ARCHES=(arm64 x64); fi
ELECTRON_VERSION="$(node -p "require('$HERE/package.json').devDependencies.electron")"

cd "$HERE"
[ -d node_modules/@electron/packager ] || npm install --no-audit --no-fund

# Stage the app: main.js, a minimal package.json, and the desktop with only the games
# listed in the catalog (unfinished game folders are left out).
STAGE="$BUILD/stage"
rm -rf "${BUILD:?}"
mkdir -p "$STAGE/shell/games"
cp main.js "$STAGE/"
node -e '
  const p = require("./package.json");
  delete p.devDependencies; delete p.scripts;
  require("fs").writeFileSync(process.argv[1], JSON.stringify(p, null, 2));
' "$STAGE/package.json"
(cd "$ROOT/shell" && cp -R index.html style.css app.js avatar.js assets "$STAGE/shell/")
cp "$ROOT/shell/games/catalog.js" "$ROOT/shell/games/kit.js" "$ROOT/shell/games/kit.css" "$STAGE/shell/games/"
node -e '
  global.window = {};
  require(process.argv[1]);
  console.log(window.BLOCKOS_GAMES.map((g) => g.id).join("\n"));
' "$ROOT/shell/games/catalog.js" | while read -r id; do
  cp -R "$ROOT/shell/games/$id" "$STAGE/shell/games/$id"
done

for arch in "${ARCHES[@]}"; do
  echo "==> Packaging BlockOS for $arch"
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

  (cd "$BUILD/BlockOS-darwin-$arch" && zip -qry "$BUILD/BlockOS-mac-$arch.zip" BlockOS.app)
  echo "    $BUILD/BlockOS-mac-$arch.zip"
done
