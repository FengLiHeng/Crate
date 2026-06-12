#!/bin/bash
# 构建 arm64 Release 并组装 Crate.app（design.md D2）
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64

APP="build/Crate.app"
BIN=".build/arm64-apple-macosx/release/Crate"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Crate"

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

echo "已生成 $APP（arm64）"
