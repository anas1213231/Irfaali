#!/usr/bin/env bash
set -euo pipefail
ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SOURCE="$ROOT/Irfaali/Resources/AppIconSource.b64"
ICON_DIR="$ROOT/Irfaali/Resources/Assets.xcassets/AppIcon.appiconset"
TMP="$ICON_DIR/AppIconSource.jpg"
OUT="$ICON_DIR/AppIcon-1024.png"
mkdir -p "$ICON_DIR"
python3 - "$SOURCE" "$TMP" <<'PY'
import base64, pathlib, sys
source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
pathlib.Path(sys.argv[2]).write_bytes(base64.b64decode(source))
PY
if command -v sips >/dev/null 2>&1; then
  sips -z 1024 1024 "$TMP" --out "$OUT" >/dev/null
else
  echo "sips is required on macOS to prepare the app icon" >&2
  exit 1
fi
rm -f "$TMP"
echo "Prepared $OUT"
