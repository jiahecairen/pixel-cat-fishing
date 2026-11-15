#!/bin/bash
# 逐画面泄漏扫描：把调试包在**每个主要画面**各启动一次、跑几百帧、退出，
# 然后只盯引擎退出时那三行关键字：
#   Leaked instance / still in use / Orphan StringName
# 只要有一个画面退出时还报，就说明那儿有引用环或者没释放的东西。
# v0.97 就是这么抓出 World⇄Shopfronts 的环的；这个脚本把它变成随时能复跑的检查。
#
# 用法：  ./tools/perf/leak_sweep.sh [每个画面跑多少帧，默认 240] [调试包路径]
# 存档一律写到 mktemp 的临时目录（CATFISH_SAVE + HOME 双保险），**绝不碰你的真存档**。
# 有任何一个画面报泄漏 → 退出码 1。
set -u
cd "$(dirname "$0")/../.." || exit 1

frames="${1:-240}"
version="$(sed -n 's/^config\/version="\([^"]*\)"/\1/p' project.godot | head -n 1)"
app="${2:-build/CatFishing_v${version}_Qwen_debug.app}"
bin="$(ls "$app"/Contents/MacOS/* 2>/dev/null | head -n 1)"
if [[ -z "${bin:-}" || ! -x "$bin" ]]; then
	echo "✗ 找不到调试包里的可执行文件：$app/Contents/MacOS/" >&2
	echo "  先打一个：Godot --headless --path . --export-debug \"macOS\" $app" >&2
	exit 1
fi

home="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/catfish_sweep_home.XXXXXX")"
save="$home/save"
trap 'rm -rf "$home"' EXIT

# 名字|环境变量
screens=(
	"家里|CATFISH_VIEW=1"
	"小镇|CATFISH_GO=1 CATFISH_VIEW=1"
	"镇上屋里|CATFISH_GO=1 CATFISH_ROOM=tackle CATFISH_VIEW=1"
	"矿山岛|CATFISH_REGION=isle CATFISH_VIEW=1"
	"矿车大厅|CATFISH_REGION=cave CATFISH_MINEMENU=cart CATFISH_VIEW=1"
	"矿井里|CATFISH_REGION=mine CATFISH_RUN=1 CATFISH_SHAFT=3 CATFISH_VIEW=1"
	"物品栏|CATFISH_ITEMS=3 CATFISH_VIEW=1"
	"菜单|CATFISH_MENU=1 CATFISH_VIEW=1"
	"邮局|CATFISH_MAIL=isle CATFISH_VIEW=1"
	"图鉴册|CATFISH_BOOK=0 CATFISH_ORES=38 CATFISH_VIEW=1"
	"睡觉|CATFISH_ROOM=home CATFISH_NAP=2 CATFISH_VIEW=1"
	"下雨|CATFISH_WEATHER=rain CATFISH_VIEW=1"
)

printf '%-10s %-6s %-8s %-6s %s\n' "画面" "退出" "泄漏行" "报错" "备注"
printf '%s\n' "------------------------------------------------------------"
bad=0
for row in "${screens[@]}"; do
	name="${row%%|*}"; envs="${row#*|}"
	log="$home/leak.log"
	: >"$log"
	# shellcheck disable=SC2086
	env HOME="$home" CATFISH_SAVE="$save" $envs timeout 300 "$bin" --quit-after "$frames" --verbose >"$log" 2>&1
	rc=$?
	leak=$(grep -icE 'Leaked instance|still in use|Orphan StringName' "$log")
	err=$(grep -c 'SCRIPT ERROR' "$log")
	note=""
	if grep -q 'ERROR: Failed loading resource' "$log"; then note="$note 资源加载失败"; fi
	if grep -q '标签图集缺少' "$log"; then note="$note 缺字"; fi
	if [[ $err -gt 0 ]]; then note="$note SCRIPT_ERROR"; fi
	if [[ $leak -gt 0 ]]; then
		note="$note ← 有泄漏"
		bad=$((bad + 1))
		grep -E 'Leaked instance|still in use' "$log" | sed 's/^/    /' | head -6
	fi
	if [[ $rc -ne 0 ]]; then note="$note 退出码$rc"; fi
	printf '%-10s %-6s %-8s %-6s %s\n' "$name" "$rc" "$leak" "$err" "${note# }"
done

echo "------------------------------------------------------------"
if [[ $bad -eq 0 ]]; then
	echo "✓ 泄漏扫描通过：${#screens[@]} 个画面退出时都没有泄漏（每个 $frames 帧）"
else
	echo "✗ 有 $bad 个画面退出时报了泄漏"
fi
[[ $bad -eq 0 ]]
