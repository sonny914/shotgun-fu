#!/usr/bin/env bash
# Fetch the pinned Godot build into .toolchain/ (or $GODOT_INSTALL_DIR) and verify SHA-512.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=godot-version.env
source "$ROOT/tools/godot-version.env"
TAG="${GODOT_VERSION}-${GODOT_RELEASE}"
DEST="${GODOT_INSTALL_DIR:-$ROOT/.toolchain/godot-$TAG}"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)  ZIP="Godot_v${TAG}_linux.x86_64.zip";  BIN="Godot_v${TAG}_linux.x86_64" ;;
  Linux-aarch64) ZIP="Godot_v${TAG}_linux.arm64.zip";   BIN="Godot_v${TAG}_linux.arm64" ;;
  Darwin-*)      ZIP="Godot_v${TAG}_macos.universal.zip"; BIN="Godot.app/Contents/MacOS/Godot" ;;
  *) echo "Unsupported platform: $(uname -s)-$(uname -m). Install Godot $TAG manually and set GODOT=/path/to/godot." >&2; exit 1 ;;
esac

if [[ -x "$DEST/$BIN" ]]; then
  echo "Godot $TAG already installed: $DEST/$BIN"
  exit 0
fi

BASE="https://github.com/godotengine/godot/releases/download/$TAG"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
echo "Downloading $ZIP ..."
curl -fsSL --retry 4 -o "$TMP/$ZIP" "$BASE/$ZIP"
curl -fsSL --retry 4 -o "$TMP/SHA512-SUMS.txt" "$BASE/SHA512-SUMS.txt"
(cd "$TMP" && grep " $ZIP\$" SHA512-SUMS.txt | sha512sum -c -) || { echo "SHA-512 mismatch for $ZIP" >&2; exit 1; }

mkdir -p "$DEST"
python3 -I -c 'import sys,zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$TMP/$ZIP" "$DEST"
chmod +x "$DEST/$BIN"
echo "Installed: $DEST/$BIN"
"$DEST/$BIN" --headless --version
