#!/bin/bash
set -euo pipefail

BACKEND_URL="https://access-gateway-87wc.onrender.com/"
RAW_BASE="https://raw.githubusercontent.com/ogarkm/access-gateway/main"
TARGET_DIR="${ACCESS_GATE_DIR:-$HOME/AccessGate}"
TARGET_FILE="$TARGET_DIR/index.html"

mkdir -p "$TARGET_DIR"
tmp="$(mktemp "$TARGET_DIR/.index.XXXXXX.html")"
trap 'rm -f "$tmp"' EXIT

echo "Downloading latest Access Gate client..."
curl -fsSL --retry 3 --connect-timeout 10 "$RAW_BASE/static/index.html" -o "$tmp"

grep -q '<title>Access Gate</title>' "$tmp" || {
  echo "Downloaded file did not look like Access Gate."
  exit 1
}

# Keep this variable documented alongside the downloaded client.
# The HTML itself points at the production backend.
mv "$tmp" "$TARGET_FILE"

echo "Installed: $TARGET_FILE"
echo "Backend:   $BACKEND_URL"

case "$(uname -s)" in
  Darwin)
    open "$TARGET_FILE"
    ;;
  Linux)
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$TARGET_FILE" >/dev/null 2>&1 &
    else
      echo "Open this file manually: $TARGET_FILE"
    fi
    ;;
  *)
    echo "Open this file manually: $TARGET_FILE"
    ;;
esac
