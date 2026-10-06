#!/bin/bash
# Builds a universal (arm64 + x86_64) TextDiff.app into ./build and zips it for release.
# Usage: scripts/build-app.sh [version]
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${1:-0.1.0}"
APP="build/TextDiff.app"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/TextDiff"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TextDiff"
strip -x "$APP/Contents/MacOS/TextDiff"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>TextDiff</string>
    <key>CFBundleDisplayName</key><string>TextDiff</string>
    <key>CFBundleIdentifier</key><string>io.github.minjongkim01.textdiff</string>
    <key>CFBundleExecutable</key><string>TextDiff</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleDevelopmentRegion</key><string>ko</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

# Ad-hoc signature: required to run on Apple Silicon. Not notarized.
codesign --force --deep --sign - "$APP"

ditto -c -k --keepParent "$APP" "build/TextDiff-${VERSION}.zip"
echo "Built $APP ($(du -sh "$APP" | cut -f1)) and build/TextDiff-${VERSION}.zip"
