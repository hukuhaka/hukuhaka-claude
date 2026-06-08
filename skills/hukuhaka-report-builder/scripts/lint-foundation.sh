#!/usr/bin/env bash
# lint-foundation.sh — token contract check for foundation kits
# usage: scripts/lint-foundation.sh references/foundations/<kit>.css
# contract source: references/foundations/_schema.md
#   (keep REQUIRED_TOKENS below in sync with the _schema.md table)
set -uo pipefail

FILE="${1:?usage: lint-foundation.sh <kit.css>}"
if [ ! -f "$FILE" ]; then echo "FAIL: file not found: $FILE"; exit 1; fi

# Strip /* ... */ comments so provenance notes (e.g. "from #fafafa") are exempt.
STRIPPED="$(tr '\n' ' ' < "$FILE" | sed 's:/\*[^*]*\*/: :g')"

ERRORS=0
fail(){ echo "FAIL: $1"; ERRORS=$((ERRORS+1)); }

REQUIRED_TOKENS=(
  paper surface sunk ink ink-soft ink-mute hairline hairline-2
  dark-band dark-ink
  gain gain-soft loss loss-soft warn warn-soft warn-deep info
  accent accent-soft accent-2 accent-3
  sans mono serif
  w-display w-head w-body
  t-hero t-sub t-tile t-dxl t-dlg t-dmd t-lead t-body t-sm t-caption t-eye t-code
  space-1 space-2 space-3 space-4 space-5 space-6 space-7 space-8
  r-0 r-1 r-2 r-3 r-4
  e-1 e-2
)

for t in "${REQUIRED_TOKENS[@]}"; do
  if ! printf '%s' "$STRIPPED" | grep -q -- "--$t:"; then
    fail "missing required token --$t (see _schema.md)"
  fi
done

# Kit declarations live in comments — check the RAW file, not STRIPPED.
if ! grep -Eq '@kit-color-mode: (light|dark|both)' "$FILE"; then
  fail "missing/invalid '@kit-color-mode:' declaration (light|dark|both — see _schema.md Kit declarations)"
fi
if ! grep -Eq '@kit-brand: (none|wordmark|logo|watermark)' "$FILE"; then
  fail "missing/invalid '@kit-brand:' declaration (none|wordmark|logo|watermark — see _schema.md Kit declarations)"
fi

if printf '%s' "$STRIPPED" | grep -Eqi '#[0-9a-f]{3,8}|rgba?\(|hsla?\('; then
  fail "non-oklch color literal found (hex/rgb/hsl) — oklch() only"
fi

if printf '%s' "$STRIPPED" | grep -Eq "Inter['\",]"; then
  fail "Inter found in a font chain (forbidden — craft/typography.md)"
fi

SANS_DECL="$(printf '%s' "$STRIPPED" | grep -Eo -- '--sans:[^;]*' || true)"
if ! printf '%s' "$SANS_DECL" | grep -Eq 'sans-serif *$'; then
  fail "--sans chain must end with generic 'sans-serif'"
fi

MONO_DECL="$(printf '%s' "$STRIPPED" | grep -Eo -- '--mono:[^;]*' || true)"
if ! printf '%s' "$MONO_DECL" | grep -Eq 'monospace *$'; then
  fail "--mono chain must end with generic 'monospace'"
fi

if [ "$ERRORS" -eq 0 ]; then
  echo "OK: $FILE satisfies _schema.md contract (${#REQUIRED_TOKENS[@]} required tokens, oklch-only, font chains valid)"
  exit 0
else
  echo "$ERRORS error(s) in $FILE"
  exit 1
fi
