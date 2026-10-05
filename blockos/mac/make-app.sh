#!/bin/bash
# Builds BlockOS.app on your Mac.
#
#   ./make-app.sh                 # puts BlockOS.app in ~/Applications
#   ./make-app.sh /Applications   # ...or another folder
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DEST="${1:-$HOME/Applications}"
APP="$DEST/BlockOS.app"

mkdir -p "$DEST"
if [ -d "$APP" ]; then
  echo "Replacing the old $APP"
  rm -rf "${APP:?}"
fi

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$HERE/Info.plist" "$APP/Contents/Info.plist"
cp "$HERE/BlockOS" "$APP/Contents/MacOS/BlockOS"
chmod 755 "$APP/Contents/MacOS/BlockOS"
cp "$HERE/BlockOS.icns" "$APP/Contents/Resources/BlockOS.icns"
cp -R "$ROOT/shell" "$APP/Contents/Resources/shell"

if command -v xattr >/dev/null 2>&1; then
  # Files from a downloaded ZIP carry a "quarantine" mark that makes macOS block the app.
  xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
fi
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "(couldn't sign the app; it should still open)"
fi

echo "Built $APP"
echo "Open it with:  open \"$APP\""
