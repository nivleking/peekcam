#!/bin/bash
# Builds PeekCam.app from the Swift package (no Xcode needed).
# Usage: scripts/make-app.sh            -> build/app.noindex/PeekCam.app
#        scripts/make-app.sh --install  -> also copies it to ~/Applications
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="0.1.0"
APP="build/app.noindex/PeekCam.app"
# Reuse SnapMark's self-signed identity when it exists: a fixed identity keeps the
# Camera permission across rebuilds. Override with PEEKCAM_SIGN.
IDENTITY="${PEEKCAM_SIGN:-SnapMark Dev}"

swift build -c release --product PeekCam
BIN="$(swift build -c release --show-bin-path)/PeekCam"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/PeekCam"

# App icon: every size macOS asks for, from one 1024 px PNG (sips and iconutil ship with macOS).
[[ -f Resources/AppIcon-1024.png ]] || swift scripts/make-icon.swift Resources/AppIcon-1024.png
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET" "$APP/Contents/Resources"
for size in 16 32 128 256 512; do
  sips -z $size $size Resources/AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Resources/AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"


cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.kelvin.PeekCam</string>
  <key>CFBundleName</key><string>PeekCam</string>
  <key>CFBundleExecutable</key><string>PeekCam</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSCameraUsageDescription</key><string>PeekCam shows your camera so you can check how you look before a call.</string>
  <key>NSMicrophoneUsageDescription</key><string>PeekCam shows a level meter so you can check your microphone. No audio is recorded.</string>
  <key>NSHumanReadableCopyright</key><string>PeekCam</string>
</dict>
</plist>
PLIST

if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  echo "warning: \"$IDENTITY\" not found, using an ad-hoc signature (permissions reset on each rebuild)" >&2
  codesign --force --sign - "$APP"
fi
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  mkdir -p "$HOME/Applications"
  pkill -x PeekCam 2>/dev/null || true
  rm -rf "$HOME/Applications/PeekCam.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "Installed to ~/Applications/PeekCam.app"
fi
