#!/bin/bash
# 双击打包《桌面小猫钓鱼》macOS 版。
# 产物：build/CatFishing_v<版本>_Qwen.app（Release · 通用二进制 · 临时 ad-hoc 签名）
# 顺带把 build/CatFishing.app 做成指向它的替身，兼容老的脚本和习惯。
# 打包完会自己无界面起两帧做一次自检，起不来就报错退出（不谎报成功）。
set -u
cd "$(dirname "$0")" || exit 1

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT_BIN" ]]; then
	GODOT_BIN="$(command -v godot 2>/dev/null || command -v godot4 2>/dev/null || true)"
fi
if [[ -z "${GODOT_BIN:-}" || ! -x "$GODOT_BIN" ]]; then
	echo "✗ 找不到 Godot 4（找的是 /Applications/Godot.app）。请装 Godot 4.7，或者 export GODOT_BIN=你的 Godot 路径 再双击。" >&2
	exit 1
fi

version="$(sed -n 's/^config\/version="\([^"]*\)"/\1/p' project.godot | head -n 1)"
if [[ -z "$version" ]]; then
	echo "✗ 读不到 project.godot 里的 config/version，不知道该叫什么版本号。" >&2
	exit 1
fi

app="build/CatFishing_v${version}_Qwen.app"
echo "版本 v$version → $app"
mkdir -p build

# 把导出预设里的版本号跟 project.godot 对齐（Finder「显示简介」和"关于"里显示的就是它）
/usr/bin/python3 - "$version" <<'PY' || true
import re, sys
v = sys.argv[1]
p = 'export_presets.cfg'
s = open(p, encoding='utf-8').read()
# 导出预设里的版本号有两种写法：老文件里是行首的 short_version="…"，新版 Godot 写的是 application/short_version="…"。
# 老脚本只认后一种，所以这两行一直是 0.92 没被同步过（打包出来的 Info.plist 靠 project.godot 才是对的）。
s2 = re.sub(r'(?m)^(application/)?(short_version|version)="[^"]*"', lambda m: '%s%s="%s"' % (m.group(1) or '', m.group(2), v), s)
if s2 != s:
    open(p, 'w', encoding='utf-8').write(s2)
    print("  export_presets.cfg 的版本号已同步为", v)
PY

echo "→ 导入素材…"
if ! "$GODOT_BIN" --headless --editor --path . --import --quit >/tmp/catfish_import.log 2>&1; then
	echo "✗ 导入素材失败，见 /tmp/catfish_import.log" >&2
	tail -20 /tmp/catfish_import.log >&2
	exit 1
fi

echo "→ 导出 Release（通用二进制，约一分钟）…"
rm -rf "$app"
if ! "$GODOT_BIN" --headless --path . --export-release "macOS" "$app" >/tmp/catfish_export.log 2>&1; then
	echo "✗ 导出失败，见 /tmp/catfish_export.log（多半是缺 macOS 导出模板：Godot 菜单 → 编辑器 → 管理导出模板 → 下载/安装 4.7.2）" >&2
	tail -20 /tmp/catfish_export.log >&2
	exit 1
fi
bin="$(ls "$app"/Contents/MacOS/* 2>/dev/null | head -n 1)"
if [[ -z "$bin" || ! -x "$bin" ]]; then
	echo "✗ 导出的包里没找到可执行文件：$app/Contents/MacOS/" >&2
	exit 1
fi

ln -sfn "$(basename "$app")" build/CatFishing.app
codesign --force --sign - "$app" >/dev/null 2>&1 || echo "（临时签名没做成，本机双击一般还是能开）"
xattr -cr "$app" 2>/dev/null

echo "→ 自检：打包出来的 app 无界面起两帧（存档写到临时目录，不碰你的存档）…"
# 这一步以前是拿你的真实用户目录跑的：游戏一启动就会写 user://save.json，
# 等于每打一次包就把玩家的真存档重写一遍。v0.97 起把 HOME 挪到临时目录里做自检，
# 自检完整个目录删掉。玩家双击「运行游戏.command」时照旧写自己的存档。
check_home="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/catfish_pack_home.XXXXXX")"
if [[ -z "$check_home" || ! -d "$check_home" ]]; then
	echo "✗ 建不出临时存档目录，自检不做了（不敢拿你的真存档试）。" >&2
	exit 1
fi
if ! HOME="$check_home" timeout 120 "$bin" --headless --quit-after 2 >/tmp/catfish_pack_check.log 2>&1; then
	rm -rf "$check_home"
	echo "✗ 打包出来的 app 起不来，见 /tmp/catfish_pack_check.log" >&2
	tail -20 /tmp/catfish_pack_check.log >&2
	exit 1
fi
rm -rf "$check_home"
if grep -q "SCRIPT ERROR" /tmp/catfish_pack_check.log; then
	echo "✗ app 能起，但日志里有 SCRIPT ERROR，见 /tmp/catfish_pack_check.log" >&2
	grep "SCRIPT ERROR" -A 2 /tmp/catfish_pack_check.log | head -20 >&2
	exit 1
fi
echo "✓ 自检通过：app 能启动（两帧，退出码 0，无 SCRIPT ERROR；临时存档目录已删）"

echo ""
echo "打包完成："
echo "  $app"
echo "  build/CatFishing.app → $(basename "$app")"
echo "双击「运行游戏.command」就能开。"
