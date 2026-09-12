#!/usr/bin/env bash
set -euo pipefail
ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SOURCE="$ROOT/Irfaali/Resources/AppIconSource.jpg"
ICON_DIR="$ROOT/Irfaali/Resources/Assets.xcassets/AppIcon.appiconset"
OUT="$ICON_DIR/AppIcon-1024.png"
mkdir -p "$ICON_DIR"
if ! command -v sips >/dev/null 2>&1; then
  echo "sips is required on macOS to prepare the app icon" >&2
  exit 1
fi
sips -s format png -z 1024 1024 "$SOURCE" --out "$OUT" >/dev/null
echo "Prepared $OUT"
