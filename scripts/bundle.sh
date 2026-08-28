#!/bin/bash
# Builds Ouvi.app from the SPM package — works with Command Line Tools only
# (no Xcode required). Output: dist/Ouvi.app
# Usage: scripts/bundle.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="dist/Ouvi.app"
VERSION="$(grep -m1 'version =' Sources/OuviKit/Version.swift | cut -d'"' -f2)"

swift build -c "$CONFIG"

BIN=".build/$CONFIG"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"

cp "$BIN/Ouvi" "$APP/Contents/MacOS/Ouvi"
cp "$BIN/ouvi-mcp" "$APP/Contents/Helpers/ouvi-mcp"
cp "$BIN/ouvi-cli" "$APP/Contents/Helpers/ouvi-cli"

# SPM resource bundles (FluidAudio ships one)
find "$BIN" -maxdepth 1 -name "*.bundle" -exec cp -R {} "$APP/Contents/Resources/" \;

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Ouvi</string>
    <key>CFBundleIdentifier</key><string>com.rafacarloss.ouvi</string>
    <key>CFBundleName</key><string>Ouvi</string>
    <key>CFBundleDisplayName</key><string>Ouvi</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.4</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>O Ouvi grava sua voz para transcrever reuniões e ditado — tudo processado no seu Mac.</string>
    <key>NSAudioCaptureUsageDescription</key>
    <string>O Ouvi captura o áudio do sistema para transcrever os outros participantes da reunião — nada sai do seu Mac.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>O Ouvi lê seu calendário para sugerir a gravação no início de cada reunião.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Usado como alternativa para inserir texto ditado em alguns apps.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature is enough for local use; releases use Developer ID + notarization.
codesign --force --deep --sign - "$APP"

echo "Built $APP (v$VERSION, $CONFIG)"
