#!/bin/bash
set -e
cd "$(dirname "$0")"

TAG="v3.1.3-alpha"
echo ""
echo "=== Publishing $TAG ==="
echo ""

# 1. Set version
echo '{"tag":"'$TAG'","date":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > version.json
echo "  ✓ version.json → $TAG"

# 2. Build HTML
echo "  Building..."
bash build.sh > /dev/null 2>&1
echo "  ✓ Build complete"

# 3. Build DMG installer
echo "  Building installer (this takes a minute)..."
bash build-installer.sh 2>&1 | tail -3
# Restore version.json (build-installer.sh overwrites it with git tag)
echo '{"tag":"'$TAG'","date":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > version.json
echo "  ✓ DMG ready"

# 4. Git commit + push
echo "  Pushing to GitHub..."
git add lighting-app.html lighting-app-V2A.html lighting-server.js version.json lumina-webview.swift build-installer.sh set-default-input.swift publish-now.sh
git commit -m "$TAG: ESP32 LED bridge + per-fixture/group MIDI learn. Drive a 19-pixel WS2812 strip over USB from Lumina: LED N = fixture N (wraps every 19), color = fixture patch color, unassigned fixtures stay dark. New ESP32 LED STRIP section in MIDI panel with SCAN/CONNECT/DISCONNECT/TEST + brightness slider; auto-reconnects last-used port. Arduino sketch in /led-bridge. Also includes (from 3.1.2): MIDI-learn buttons in Fixture Manager and GROUPS strip — click LEARN, press a key, done. Groups map the whole group to one note and fire all members simultaneously." --quiet 2>/dev/null || true
git add led-bridge/ 2>/dev/null || true
git push origin master --quiet
# Create + push git tag so the release page can reference it
git tag -f "$TAG" 2>/dev/null || true
git push origin "$TAG" --force 2>/dev/null || true
echo "  ✓ Pushed + tagged $TAG"

# 5. Open browser to create release
echo ""
echo "  ✓ Opening GitHub release page..."
echo "    → Drag Lumina-FX.dmg from this folder into the browser"
echo ""
open "https://github.com/shtarkair/Lumina-FX-V3A-Mac/releases/new?tag=$TAG&title=$TAG"
open .
echo "  Done. Drag the DMG, click Publish."
echo ""
