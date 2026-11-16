#!/usr/bin/env bash
# Headless validation. Exit 0 = green, 1 = red, 2 = Godot not found (nothing ran).
#   tools/validate.sh          fast: import + load all + boot
#   tools/validate.sh --full   fast + GUT unit tests + smoke scenes
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source tools/godot-version.env
TAG="${GODOT_VERSION}-${GODOT_RELEASE}"
FULL=0; [[ "${1:-}" == "--full" ]] && FULL=1

find_godot() {
  if [[ -n "${GODOT:-}" ]]; then echo "$GODOT"; return; fi
  local d="${GODOT_INSTALL_DIR:-$ROOT/.toolchain/godot-$TAG}"
  for c in "$d/Godot_v${TAG}_linux.x86_64" "$d/Godot_v${TAG}_linux.arm64" "$d/Godot.app/Contents/MacOS/Godot"; do
    [[ -x "$c" ]] && { echo "$c"; return; }
  done
  command -v godot 2>/dev/null || command -v godot4 2>/dev/null || true
}
G="$(find_godot)"
if [[ -z "$G" ]]; then
  echo "validate: Godot $TAG not found. Run tools/install_godot.sh or set GODOT=..." >&2
  exit 2
fi
VER="$("$G" --headless --version 2>/dev/null | head -1)"
[[ "$VER" == "$GODOT_VERSION"* ]] || echo "validate: WARNING engine is '$VER', pinned $TAG" >&2

LOGDIR="$ROOT/.godot/validate-logs"; mkdir -p "$LOGDIR"
ERR_PATTERN='SCRIPT ERROR|Parse Error|^ERROR:|USER ERROR|Failed to load|Cannot open file'
FAILED=0

step() { # step <name> <timeout_s> <args...>
  local name="$1" t="$2"; shift 2
  local log="$LOGDIR/$name.log"
  printf '  %-18s' "$name"
  timeout "$t" "$G" --headless --path "$ROOT" "$@" >"$log" 2>&1
  local rc=$?
  if [[ $rc -ne 0 ]] || grep -Eq "$ERR_PATTERN" "$log"; then
    echo "FAIL (exit $rc) — $log"; grep -En "$ERR_PATTERN" "$log" | head -20; FAILED=1; return 1
  fi
  echo "ok"
}

echo "validate: $VER ($([[ $FULL == 1 ]] && echo full || echo fast))"
step import    300 --import || true
step load-all  120 res://tools/ci/validator.tscn || true
step boot       60 --quit-after 120 || true

if [[ $FULL == 1 ]]; then
  if [[ -f addons/gut/gut_cmdln.gd ]]; then
    step unit 300 -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit || true
  else
    printf '  %-18s%s\n' unit "SKIP (GUT not vendored in addons/gut)"
  fi
  shopt -s nullglob
  smokes=(tests/smoke/*.tscn)
  [[ ${#smokes[@]} -eq 0 ]] && printf '  %-18s%s\n' smoke "SKIP (no smoke scenes yet)"
  for s in "${smokes[@]}"; do
    n="smoke-$(basename "$s" .tscn)"
    if step "$n" 120 "res://$s"; then
      grep -q "SMOKE PASS" "$LOGDIR/$n.log" || { echo "    $n: no 'SMOKE PASS' line"; FAILED=1; }
    fi
  done
fi

[[ $FAILED == 0 ]] && echo "validate: GREEN" || echo "validate: RED"
exit $FAILED
