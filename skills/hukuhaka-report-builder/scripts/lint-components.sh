#!/usr/bin/env bash
# lint-components.sh — token purity + drift checks for component fragments
# usage: scripts/lint-components.sh [components-dir]
# policy: colors must be var(--...), color-mix(in oklch, var(--...)),
#         or currentColor. Literal oklch()/hex/rgb()/hsl() fail.
#         A class defined in two fragment <style> blocks = drift signal.
set -uo pipefail

DIR="${1:-references/components}"
if [ ! -d "$DIR" ]; then echo "FAIL: dir not found: $DIR"; exit 1; fi

ERRORS=0
fail(){ echo "FAIL: $1"; ERRORS=$((ERRORS+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FILES=()
for f in "$DIR"/*.html "$DIR"/_base.css; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in spec-sheet.html) continue;; esac
  FILES+=("$f")
done

for f in "${FILES[@]}"; do
  name="$(basename "$f")"

  # CSS surface = <style> blocks + inline style="" + SVG fill=/stroke= attrs
  if [[ "$f" == *.css ]]; then
    cp "$f" "$TMP/$name.css"
  else
    sed -n '/<style>/,/<\/style>/p' "$f" > "$TMP/$name.css"
    grep -oE 'style="[^"]*"' "$f" >> "$TMP/$name.css" || true
    grep -oE '(fill|stroke)="[^"]*"' "$f" >> "$TMP/$name.css" || true
  fi
  CSS="$(cat "$TMP/$name.css")"

  # 1. literal colors forbidden
  if printf '%s' "$CSS" | grep -Eqi '#[0-9a-f]{3,8}|rgba?\(|hsla?\(|oklch\('; then
    fail "$name: literal color (hex/rgb/hsl/oklch()) — use var(--...) / color-mix(in oklch, var(--...)) / currentColor"
  fi

  # 2. header contract (fragments only)
  if [[ "$f" == *.html ]]; then
    grep -q '^component:' "$f" || fail "$name: missing 'component:' header line"
    grep -q '^craft:' "$f"     || fail "$name: missing 'craft:' header line"
  fi

  # collect rb- class DEFINITIONS (style blocks only, not markup usage)
  if [[ "$f" == *.css ]]; then
    grep -oE '\.rb-[a-z0-9-]+' "$f" | sort -u | sed 's/^\.//' > "$TMP/$name.defs" || true
  else
    sed -n '/<style>/,/<\/style>/p' "$f" | grep -oE '\.rb-[a-z0-9-]+' | sort -u | sed 's/^\.//' > "$TMP/$name.defs" || true
  fi
done

# 3. cross-file duplicate class definitions
cat "$TMP"/*.defs 2>/dev/null | sort | uniq -d > "$TMP/dups" || true
if [ -s "$TMP/dups" ]; then
  while read -r d; do
    where="$(grep -l "^$d\$" "$TMP"/*.defs | xargs -n1 basename | sed 's/\.defs$//' | tr '\n' ' ')"
    fail "class .$d defined in multiple files: $where"
  done < "$TMP/dups"
fi

if [ "$ERRORS" -eq 0 ]; then
  echo "OK: ${#FILES[@]} files pass (token purity, headers, no cross-file class definitions)"
  exit 0
else
  echo "$ERRORS error(s)"
  exit 1
fi
