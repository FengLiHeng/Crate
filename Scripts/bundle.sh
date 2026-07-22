#!/bin/bash
# 构建 arm64 Release 并组装 Crate.app（design.md D2）
set -euo pipefail
cd "$(dirname "$0")/.."

SWIFT_BUILD_FLAGS_ARRAY=()
APP_VERSION="${APP_VERSION:-2.5.0}"
APP_BUILD="${APP_BUILD:-15}"
if [[ -n "${SWIFT_BUILD_FLAGS:-}" ]]; then
    # 允许受限环境传入 --disable-sandbox 等 SwiftPM 构建参数；默认不改变本地打包行为。
    SWIFT_BUILD_FLAGS_ARRAY=(${SWIFT_BUILD_FLAGS})
fi
if [[ ${#SWIFT_BUILD_FLAGS_ARRAY[@]} -gt 0 ]]; then
    swift build "${SWIFT_BUILD_FLAGS_ARRAY[@]}" -c release --arch arm64
else
    swift build -c release --arch arm64
fi

APP="build/Crate.app"
BIN=".build/arm64-apple-macosx/release/Crate"
RESOURCE_BUNDLE=".build/arm64-apple-macosx/release/Crate_Crate.bundle"
ICONSET="/tmp/crate-appicon.iconset"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Crate"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
fi
cp src/Assets.xcassets/AlbumPlaceholder.imageset/album-placeholder.png "$APP/Contents/Resources/album-placeholder.png"
# SwiftPM 会原样复制资源目录，发布 bundle 中不应包含 Finder 元数据。
find "$APP" -name '.DS_Store' -delete
find "$APP" -name '._*' -delete

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
if ! iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"; then
    /usr/bin/python3 - "$ICONSET" "$APP/Contents/Resources/AppIcon.icns" <<'PY'
import pathlib
import struct
import sys

iconset = pathlib.Path(sys.argv[1])
output = pathlib.Path(sys.argv[2])
chunks = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_16x16@2x.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_128x128@2x.png"),
    ("ic09", "icon_256x256@2x.png"),
    ("ic10", "icon_512x512@2x.png"),
]

body = bytearray()
for kind, name in chunks:
    data = (iconset / name).read_bytes()
    body.extend(kind.encode("ascii"))
    body.extend(struct.pack(">I", len(data) + 8))
    body.extend(data)

output.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)
PY
fi
rm -rf "$ICONSET"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Crate</string>
    <key>CFBundleIdentifier</key>
    <string>com.crate.player</string>
    <key>CFBundleName</key>
    <string>Crate</string>
    <key>CFBundleDisplayName</key>
    <string>Crate</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
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

echo "已生成 ${APP}（arm64，版本 ${APP_VERSION} (${APP_BUILD})）"
