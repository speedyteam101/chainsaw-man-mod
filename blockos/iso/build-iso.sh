#!/usr/bin/env bash
# Builds a bootable BlockOS live ISO. Needs Docker (Docker Desktop on a Mac).
#
#   ./build-iso.sh            # ISO for this Mac's chip (arm64 on Apple Silicon, amd64 on Intel)
#   ./build-iso.sh amd64      # force an architecture (slow when emulated)
#
# The ISO lands in iso/out/. Building downloads roughly 1 GB of Debian packages.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
ARCH="${1:-}"

if [ -z "$ARCH" ]; then
  case "$(uname -m)" in
    arm64|aarch64) ARCH=arm64 ;;
    x86_64|amd64) ARCH=amd64 ;;
    *) echo "Unknown CPU $(uname -m); pass arm64 or amd64" >&2; exit 1 ;;
  esac
fi
case "$ARCH" in arm64|amd64) ;; *) echo "Architecture must be arm64 or amd64" >&2; exit 1 ;; esac

command -v docker >/dev/null 2>&1 || { echo "Docker is required: https://docs.docker.com/desktop/" >&2; exit 1; }

mkdir -p "$HERE/out"
echo "Building BlockOS for $ARCH (this takes a while)..."
# live-build mounts /proc, /dev etc. inside its chroot, which needs a privileged container.
docker run --rm --privileged --platform "linux/$ARCH" \
  -e ARCH="$ARCH" -e DIST="${DIST:-trixie}" \
  -v "$ROOT:/blockos:ro" -v "$HERE/out:/out" \
  debian:trixie bash /blockos/iso/lb-build.sh
echo "Done: $(ls "$HERE"/out/*.iso)"
