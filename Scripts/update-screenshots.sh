#!/bin/bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPOSITORY_ROOT"

SCENES=("light-home" "dark-home" "light-queue" "light-lyrics")
OUTPUT_NAMES=("浅色-首页.png" "深色-首页.png" "浅色-待播清单.png" "浅色-歌词.png")
SCREENSHOT_DIRECTORY="$REPOSITORY_ROOT/docs/截图"
TEMP_DIRECTORY="$(mktemp -d)"
CURRENT_PID=""

cleanup() {
    local exit_status="$?"
    if [[ -n "$CURRENT_PID" ]] && kill -0 "$CURRENT_PID" 2>/dev/null; then
        kill "$CURRENT_PID" 2>/dev/null || true
        wait "$CURRENT_PID" 2>/dev/null || true
    fi
    rm -rf "$TEMP_DIRECTORY"
    return "$exit_status"
}
trap cleanup EXIT INT TERM

stop_current_app() {
    if [[ -n "$CURRENT_PID" ]] && kill -0 "$CURRENT_PID" 2>/dev/null; then
        kill "$CURRENT_PID" 2>/dev/null || true
        wait "$CURRENT_PID" 2>/dev/null || true
    fi
    CURRENT_PID=""
}

wait_for_ready_file() {
    local ready_file="$1"
    local app_log="$2"

    for _ in {1..200}; do
        if [[ -s "$ready_file" ]]; then
            return 0
        fi
        if [[ -n "$CURRENT_PID" ]] && ! kill -0 "$CURRENT_PID" 2>/dev/null; then
            echo "应用在截图就绪前退出："
            sed -n '1,120p' "$app_log"
            return 1
        fi
        sleep 0.1
    done

    echo "等待截图窗口超时："
    sed -n '1,120p' "$app_log"
    return 1
}

echo "正在构建最新版 Crate.app…"
Scripts/bundle.sh

APP_EXECUTABLE="$REPOSITORY_ROOT/build/Crate.app/Contents/MacOS/Crate"
mkdir -p "$SCREENSHOT_DIRECTORY"

for index in "${!SCENES[@]}"; do
    scene="${SCENES[$index]}"
    output_name="${OUTPUT_NAMES[$index]}"
    ready_file="$TEMP_DIRECTORY/$scene.ready"
    store_directory="$TEMP_DIRECTORY/$scene-store"
    app_log="$TEMP_DIRECTORY/$scene.log"
    capture_file="$TEMP_DIRECTORY/$output_name"
    mkdir -p "$store_directory"

    echo "正在生成 ${output_name}…"
    "$APP_EXECUTABLE" \
        --screenshot-scene "$scene" \
        --screenshot-ready-file "$ready_file" \
        --screenshot-store "$store_directory" \
        >"$app_log" 2>&1 &
    CURRENT_PID="$!"

    wait_for_ready_file "$ready_file" "$app_log"
    window_id="$(tr -d '[:space:]' < "$ready_file")"
    if [[ ! "$window_id" =~ ^[0-9]+$ ]]; then
        echo "应用返回了无效的窗口编号：$window_id"
        exit 1
    fi

    if ! /usr/sbin/screencapture -x -l "$window_id" "$capture_file"; then
        echo "截图失败。请在系统设置中允许当前终端或 Codex 录制屏幕后重试。"
        exit 1
    fi
    if [[ ! -s "$capture_file" ]]; then
        echo "截图文件为空：$capture_file"
        exit 1
    fi

    stop_current_app
done

reference_width=""
reference_height=""
for output_name in "${OUTPUT_NAMES[@]}"; do
    capture_file="$TEMP_DIRECTORY/$output_name"
    width="$(sips -g pixelWidth "$capture_file" | awk '/pixelWidth/ { print $2 }')"
    height="$(sips -g pixelHeight "$capture_file" | awk '/pixelHeight/ { print $2 }')"

    if [[ -z "$width" || -z "$height" || "$width" -lt 1200 || "$height" -lt 700 ]]; then
        echo "截图尺寸异常：${output_name} (${width:-未知}×${height:-未知})"
        exit 1
    fi
    if [[ -z "$reference_width" ]]; then
        reference_width="$width"
        reference_height="$height"
    elif [[ "$width" != "$reference_width" || "$height" != "$reference_height" ]]; then
        echo "四张截图尺寸不一致：${output_name} 为 ${width}×${height}，预期 ${reference_width}×${reference_height}"
        exit 1
    fi
done

for output_name in "${OUTPUT_NAMES[@]}"; do
    cp "$TEMP_DIRECTORY/$output_name" "$SCREENSHOT_DIRECTORY/$output_name"
done

start_count="$(grep -c '^<!-- ui-screenshots:start -->$' README.md || true)"
end_count="$(grep -c '^<!-- ui-screenshots:end -->$' README.md || true)"
if [[ "$start_count" != "1" || "$end_count" != "1" ]]; then
    echo "README 截图区块标记缺失或重复，未自动更新。"
    exit 1
fi

README_BLOCK="$TEMP_DIRECTORY/readme-screenshots.md"
cat >"$README_BLOCK" <<'EOF'
<!-- ui-screenshots:start -->
| 浅色主题 | 深色主题 |
| --- | --- |
| ![Crate 浅色主题首页](docs/截图/浅色-首页.png) | ![Crate 深色主题首页](docs/截图/深色-首页.png) |

| 待播清单 | 动态歌词 |
| --- | --- |
| ![Crate 浅色主题待播清单](docs/截图/浅色-待播清单.png) | ![Crate 浅色主题歌词页](docs/截图/浅色-歌词.png) |
<!-- ui-screenshots:end -->
EOF

awk -v block_file="$README_BLOCK" '
    BEGIN { replacing = 0 }
    /^<!-- ui-screenshots:start -->$/ {
        while ((getline line < block_file) > 0) print line
        close(block_file)
        replacing = 1
        next
    }
    /^<!-- ui-screenshots:end -->$/ { replacing = 0; next }
    !replacing { print }
' README.md >"$TEMP_DIRECTORY/README.md"
cp "$TEMP_DIRECTORY/README.md" README.md

echo "已更新 4 张截图和 README（${reference_width}×${reference_height}）。"
