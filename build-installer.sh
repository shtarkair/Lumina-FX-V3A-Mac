#!/bin/bash
# ============================================================
# Lumina FX — Professional macOS Installer Builder
# ============================================================
# Creates a self-contained .app with embedded Node.js
# and packages it into a DMG for distribution.
#
# Usage: ./build-installer.sh
# Output: Lumina-FX.dmg (ready for GitHub release)
# ============================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Lumina FX"
APP_BUNDLE="$SCRIPT_DIR/${APP_NAME}.app"
DMG_NAME="Lumina-FX.dmg"
DMG_VOLUME="Lumina FX"
NODE_VERSION="22.14.0"

echo ""
echo "============================================"
echo "  Lumina FX — Installer Builder"
echo "============================================"
echo ""

# ---- Detect architecture ----
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  NODE_ARCH="darwin-arm64"
  echo "[1/6] Architecture: Apple Silicon (arm64)"
else
  NODE_ARCH="darwin-x64"
  echo "[1/6] Architecture: Intel (x64)"
fi

# ---- Download Node.js if not cached ----
NODE_TAR="node-v${NODE_VERSION}-${NODE_ARCH}.tar.gz"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TAR}"
CACHE_DIR="$SCRIPT_DIR/.build-cache"
mkdir -p "$CACHE_DIR"

if [ ! -f "$CACHE_DIR/$NODE_TAR" ]; then
  echo "[2/6] Downloading Node.js v${NODE_VERSION} for ${NODE_ARCH}..."
  curl -L -o "$CACHE_DIR/$NODE_TAR" "$NODE_URL"
else
  echo "[2/6] Using cached Node.js v${NODE_VERSION}"
fi

# Extract node binary
echo "       Extracting node binary..."
tar -xzf "$CACHE_DIR/$NODE_TAR" -C "$CACHE_DIR" --strip-components=2 "node-v${NODE_VERSION}-${NODE_ARCH}/bin/node"
BUNDLED_NODE="$CACHE_DIR/node"
chmod +x "$BUNDLED_NODE"

# ---- Clean previous build ----
echo "[3/6] Building ${APP_BUNDLE}..."
rm -rf "$APP_BUNDLE"

# ---- Create .app structure ----
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources/app"

# Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>lumina-start</string>
  <key>CFBundleName</key>
  <string>Lumina FX</string>
  <key>CFBundleDisplayName</key>
  <string>Lumina FX</string>
  <key>CFBundleIdentifier</key>
  <string>com.lumina.fx</string>
  <key>CFBundleVersion</key>
  <string>3.0.0</string>
  <key>CFBundleShortVersionString</key>
  <string>3.0.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>Lumina</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>LSUIElement</key>
  <false/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>Lumina FX uses audio input (microphone or line-in) for real-time BPM detection and beat-reactive lighting.</string>
  <key>NSCameraUsageDescription</key>
  <string>Lumina FX does not use the camera; this entry is required by WebKit for media capture permission prompts.</string>
</dict>
</plist>
PLIST

# Copy icon (Lumina.icns should be in repo root)
if [ -f "$SCRIPT_DIR/Lumina.icns" ]; then
  cp "$SCRIPT_DIR/Lumina.icns" "$APP_BUNDLE/Contents/Resources/Lumina.icns"
  echo "       Icon: Lumina.icns"
else
  echo "       WARNING: Lumina.icns not found — app will use generic icon"
fi

# Copy Node.js binary into the app
cp "$BUNDLED_NODE" "$APP_BUNDLE/Contents/MacOS/node"
chmod +x "$APP_BUNDLE/Contents/MacOS/node"

# Compile native WKWebView window
echo "       Compiling native window (lumina-webview)..."
if [ -f "$SCRIPT_DIR/lumina-webview.swift" ]; then
  swiftc -O -o "$APP_BUNDLE/Contents/MacOS/lumina-webview" "$SCRIPT_DIR/lumina-webview.swift" \
    -framework Cocoa -framework WebKit -target "${ARCH}-apple-macosx12.0" 2>/dev/null || {
    echo "       WARNING: Swift compilation failed — will fall back to browser"
  }
else
  echo "       WARNING: lumina-webview.swift not found — will use browser"
fi

# Generate version.json from git tag
GIT_TAG=$(cd "$SCRIPT_DIR" && git describe --tags --abbrev=0 2>/dev/null || echo "v3.0.0")
echo "{\"tag\":\"$GIT_TAG\",\"date\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "$SCRIPT_DIR/version.json"
echo "       Version: $GIT_TAG"

# Copy app files
APP_DIR="$APP_BUNDLE/Contents/Resources/app"
cp "$SCRIPT_DIR/version.json" "$APP_DIR/"
cp "$SCRIPT_DIR/lighting-server.js" "$APP_DIR/"
cp "$SCRIPT_DIR/lighting-app.html" "$APP_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/lighting-app-V2A.html" "$APP_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/fixture-library.json" "$APP_DIR/"
cp "$SCRIPT_DIR/viz.html" "$APP_DIR/"
cp "$SCRIPT_DIR/package.json" "$APP_DIR/"
cp "$SCRIPT_DIR/package-lock.json" "$APP_DIR/" 2>/dev/null || true
cp -r "$SCRIPT_DIR/custom-fixtures" "$APP_DIR/" 2>/dev/null || true
cp -r "$SCRIPT_DIR/lib" "$APP_DIR/" 2>/dev/null || true

# Compile Swift helper that switches the macOS default input device by name
echo "       Compiling CoreAudio input switcher..."
if [ -f "$SCRIPT_DIR/set-default-input.swift" ]; then
  swiftc -O "$SCRIPT_DIR/set-default-input.swift" -o "$APP_DIR/set-default-input" 2>&1 | tail -3 || {
    echo "       WARNING: swiftc failed — helper will be missing, manual fallback still works"
  }
  chmod +x "$APP_DIR/set-default-input" 2>/dev/null || true
fi

# Install production dependencies into the app bundle
echo "       Installing production dependencies..."
cd "$APP_DIR"
npm install --omit=dev --silent 2>/dev/null || {
  echo "       npm install failed, copying existing node_modules..."
  cp -r "$SCRIPT_DIR/node_modules" "$APP_DIR/" 2>/dev/null || true
}
cd "$SCRIPT_DIR"

# Create launcher script (uses bundled Node.js — no system Node needed)
cat > "$APP_BUNDLE/Contents/MacOS/lumina-start" << 'LAUNCHER'
#!/bin/bash
# ============================================================
# Lumina FX — Launcher (Node.js bundled inside)
# ============================================================

PORT=3457

# Resolve paths
APP_CONTENTS="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$APP_CONTENTS/Resources/app"
NODE_BIN="$APP_CONTENTS/MacOS/node"

# macOS helpers
notify() {
  osascript -e "display notification \"$1\" with title \"Lumina FX\"" 2>/dev/null
}

alert_error() {
  osascript -e "display alert \"Lumina FX\" message \"$1\" as critical" 2>/dev/null
}

# Verify bundled Node.js
if [ ! -x "$NODE_BIN" ]; then
  alert_error "Bundled Node.js not found.\n\nThe app may be corrupted. Please re-download Lumina FX."
  exit 1
fi

# Verify server file
if [ ! -f "$PROJECT_DIR/lighting-server.js" ]; then
  alert_error "Server file not found.\n\nThe app may be corrupted. Please re-download Lumina FX."
  exit 1
fi

# Create user directories
mkdir -p "$HOME/Documents/Lumina Shows" 2>/dev/null

# Kill anything already on our port
lsof -ti:$PORT 2>/dev/null | xargs kill -9 2>/dev/null
sleep 0.3

# Start the server
cd "$PROJECT_DIR"
"$NODE_BIN" lighting-server.js &
SERVER_PID=$!

# Wait for server to be ready
READY=false
for i in {1..30}; do
  if curl -s "http://localhost:$PORT" > /dev/null 2>&1; then
    READY=true
    break
  fi
  sleep 0.3
done

if [ "$READY" = false ]; then
  alert_error "Server failed to start.\n\nCheck if port $PORT is already in use."
  kill $SERVER_PID 2>/dev/null
  exit 1
fi

# Open native window (or fall back to browser)
WEBVIEW_BIN="$APP_CONTENTS/MacOS/lumina-webview"
if [ -x "$WEBVIEW_BIN" ]; then
  notify "Lumina FX is running"
  "$WEBVIEW_BIN" &
  WEBVIEW_PID=$!
  # Keep alive until either server or webview exits
  wait $WEBVIEW_PID 2>/dev/null
  kill $SERVER_PID 2>/dev/null
else
  open "http://localhost:$PORT"
  notify "Lumina FX is running"
  wait $SERVER_PID
fi
LAUNCHER

chmod +x "$APP_BUNDLE/Contents/MacOS/lumina-start"

# ---- Verify app size ----
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo "       App bundle: $APP_SIZE"

# ---- Build DMG ----
echo "[4/6] Creating DMG..."
rm -f "$SCRIPT_DIR/$DMG_NAME"

# Create temporary DMG directory
DMG_TMP="$SCRIPT_DIR/.dmg-tmp"
rm -rf "$DMG_TMP"
mkdir -p "$DMG_TMP"
cp -r "$APP_BUNDLE" "$DMG_TMP/"
ln -s /Applications "$DMG_TMP/Applications"

# Create DMG
hdiutil create -volname "$DMG_VOLUME" \
  -srcfolder "$DMG_TMP" \
  -ov -format UDZO \
  "$SCRIPT_DIR/$DMG_NAME" > /dev/null

rm -rf "$DMG_TMP"

DMG_SIZE=$(du -sh "$DMG_NAME" | cut -f1)
echo "       DMG created: $DMG_NAME ($DMG_SIZE)"

echo "[5/6] Cleaning up..."
rm -f "$CACHE_DIR/node"

echo "[6/6] Done!"
echo ""
echo "============================================"
echo "  ${DMG_NAME} is ready for distribution"
echo ""
echo "  Users: Download → Open DMG → Drag to"
echo "  Applications → Double-click to run"
echo "============================================"
echo ""
