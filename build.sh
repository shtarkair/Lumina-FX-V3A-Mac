#!/bin/bash
# Lumina FX - Pre-compile JSX to eliminate Babel loading delay
# Usage: ./build.sh [source.html]
# Output: lighting-app.html (what the server serves)

set -e
cd "$(dirname "$0")"

SRC="${1:-lighting-app-V2A.html}"
OUT="lighting-app.html"
TMP_JSX=".tmp-app.jsx"
TMP_JS=".tmp-app.js"

echo "Building $SRC → $OUT ..."

# 1. Extract JSX from between <script type="text/babel"> and </script>
JSX_START=$(grep -n 'type="text/babel"' "$SRC" | head -1 | cut -d: -f1)
JSX_END=$(tail -n +"$JSX_START" "$SRC" | grep -n '</script>' | head -1 | cut -d: -f1)
JSX_END=$((JSX_START + JSX_END - 1))
sed -n "$((JSX_START + 1)),$((JSX_END - 1))p" "$SRC" > "$TMP_JSX"

echo "  Extracted $(wc -l < "$TMP_JSX" | tr -d ' ') lines of JSX"

# 2. Compile JSX → JS using Babel
npx babel --presets @babel/preset-react "$TMP_JSX" -o "$TMP_JS" 2>&1

echo "  Compiled to JS ($(wc -c < "$TMP_JS" | tr -d ' ') bytes)"

# 3. Build final HTML: everything before babel script + compiled JS + everything after
# Get line numbers
BABEL_SCRIPT_LINE=$(grep -n '<script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>' "$SRC" | head -1 | cut -d: -f1)
JSX_START_LINE=$(grep -n '<script type="text/babel">' "$SRC" | head -1 | cut -d: -f1)
JSX_END_LINE=$(tail -n +$JSX_START_LINE "$SRC" | grep -n '</script>' | head -1 | cut -d: -f1)
JSX_END_LINE=$((JSX_START_LINE + JSX_END_LINE - 1))

# Part 1: everything before the babel standalone script line (skip it)
head -n $((BABEL_SCRIPT_LINE - 1)) "$SRC" > "$OUT"

# Part 2: compiled JS as regular script (no type="text/babel", no Babel standalone needed)
echo '  <script>' >> "$OUT"
cat "$TMP_JS" >> "$OUT"
echo '' >> "$OUT"
echo '  </script>' >> "$OUT"

# Part 3: everything after the closing </script> of the babel block
tail -n +$((JSX_END_LINE + 1)) "$SRC" >> "$OUT"

# Cleanup
rm -f "$TMP_JSX" "$TMP_JS"

echo "  Done! → $OUT ($(wc -c < "$OUT" | tr -d ' ') bytes)"
echo "  Babel standalone removed — page loads instantly"
