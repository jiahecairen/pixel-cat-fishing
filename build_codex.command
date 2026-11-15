#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT_BIN" ]]; then
	GODOT_BIN="$(command -v godot || command -v godot4 || true)"
fi
if [[ -z "$GODOT_BIN" || ! -x "$GODOT_BIN" ]]; then
	echo "找不到 Godot 4。请安装 Godot，或设置 GODOT_BIN。" >&2
	exit 1
fi

version="$(sed -n 's/^config\/version="\([^"]*\)"/\1/p' project.godot | head -n 1)"
if [[ -z "$version" ]]; then
	echo "无法从 project.godot 读取版本号。" >&2
	exit 1
fi

mkdir -p build
versioned_app="build/CatFishing_v${version}_codex.app"
rm -rf build/CatFishing.app "$versioned_app"

"$GODOT_BIN" --headless --editor --path . --import --quit
"$GODOT_BIN" --headless --path . --export-release "macOS" build/CatFishing.app
ditto build/CatFishing.app "$versioned_app"

echo "构建完成："
echo "  build/CatFishing.app"
echo "  $versioned_app"
