#!/bin/bash
# 构建 arm64 Release 并组装 Crate.app（design.md D2）
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64

APP="build/Crate.app"
BIN=".build/arm64-apple-macosx/release/Crate"
ICONSET="/tmp/crate-appicon.iconset"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Crate"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"
cp src/Assets.xcassets/AppIcon.appiconset/icon_16x16.png "$ICONSET/icon_16x16.png"
cp src/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png "$ICONSET/icon_16x16@2x.png"
cp src/Assets.xcassets/AppIcon.appiconset/icon_32x32.png "$ICONSET/icon_32x32.png"
cp src/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png "$ICONSET/icon_32x32@2x.png"
cp src/Assets.xcassets/AppIcon.appiconset/icon_128x128.png "$ICONSET/icon_128x128.png"
cp src/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png "$ICONSET/icon_128x128@2x.png"
cp src/Assets.xcassets/AppIcon.appiconset/icon_256x256.png "$ICONSET/icon_256x256.png"
cp src/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png "$ICONSET/icon_256x256@2x.png"
cp src/Assets.xcassets/AppIcon.appiconset/icon_512x512.png "$ICONSET/icon_512x512.png"
cp src/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Crate</string>
    <key>CFBundleIdentifier</key>
    <string>com.crate.player</string>
    <key>CFBundleName</key>
    <string>本地音乐播放器</string>
    <key>CFBundleDisplayName</key>
    <string>本地音乐播放器</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string></string>
</dict>
</plist>
EOF

echo "已生成 ${APP}（arm64）"
