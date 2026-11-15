#!/bin/bash
# 逐画面泄漏扫描：把调试包在**每个主要画面**各启动一次、跑几百帧、退出，
# 然后只盯引擎退出时那三行关键字：
#   Leaked instance / still in use / Orphan StringName
# 只要有一个画面退出时还报，就说明那儿有引用环或者没释放的东西。
# v0.97 就是这么抓出 World⇄Shopfronts 的环的；这个脚本把它变成随时能复跑的检查。
#
# 用法：  ./tools/perf/leak_sweep.sh [每个画面跑多少帧，默认 240] [调试包路径] [截图目录]
# 存档一律写到 mktemp 的临时目录（CATFISH_SAVE + HOME 双保险），**绝不碰你的真存档**。
# 每个画面还会留一张截图当"画面真的打开了"的证据（默认丢到 /tmp/catfish_sweep_shots）。
# 截图还用来抓"画面压根没打开"：如果某个画面截出来的图和**基线画面**（列表里第一个，
# 就是"家里"）逐字节一模一样，说明那个面板根本没弹开 → 判失败。
# 截图体积只当参考：迷你视图的窗口本来就只有几十 KB，深色矿洞一屏也才 20 KB，
# 拿几百 KB 当门槛会把好画面误判成坏的。
# 只想跑其中几个画面：LEAK_ONLY=小镇,矿井里 ./tools/perf/leak_sweep.sh
# 注意：整轮共用一份临时存档，画面是一个接一个把进度攒起来的（跟真人一样越玩越多），
# 所以有些缺字只有在"已经钓过鱼、买过东西"之后才会冒出来 —— 这是故意的。
# 判失败四件事：报泄漏 / 没截出图 / 跟基线一帧不差 / 画了图集里没有的文字。
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

shots="${3:-${TMPDIR:-/tmp}/catfish_sweep_shots}"
rm -rf "$shots" 2>/dev/null
mkdir -p "$shots" || exit 1
home="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/catfish_sweep_home.XXXXXX")"
save="$home/save"
trap 'rm -rf "$home"' EXIT

# 名字|环境变量（一个画面一行；加画面就往这里加一行，测试会盯着条数）
screens=(
	"家里|CATFISH_VIEW=1"
	"迷你视图|CATFISH_VIEW=0"
	"小镇|CATFISH_GO=1 CATFISH_VIEW=1"
	"钓鱼中|CATFISH_GO=1 CATFISH_FILL=10 CATFISH_HOLD=1 CATFISH_VIEW=1"
	"专注中|CATFISH_AUTOFOCUS=1 CATFISH_VIEW=1"
	"休息中|CATFISH_BREAK=1 CATFISH_VIEW=1"
	"镇上屋里|CATFISH_GO=1 CATFISH_ROOM=tackle CATFISH_VIEW=1"
	"矿山岛|CATFISH_REGION=isle CATFISH_VIEW=1"
	"矿车大厅|CATFISH_REGION=cave CATFISH_MINEMENU=cart CATFISH_VIEW=1"
	"开工面板|CATFISH_REGION=cave CATFISH_MINEMENU=open CATFISH_VIEW=1"
	"矿井里|CATFISH_REGION=mine CATFISH_RUN=1 CATFISH_SHAFT=3 CATFISH_SEED=7 CATFISH_VIEW=1"
	"矿井开挖|CATFISH_REGION=mine CATFISH_RUN=1 CATFISH_DIG=0,-1 CATFISH_DIGLOOP=1 CATFISH_SEED=7 CATFISH_VIEW=1"
	"矿山岛屋子|CATFISH_REGION=isle CATFISH_ROOM=shop CATFISH_VIEW=1"
	"物品栏|CATFISH_ITEMS=3 CATFISH_BAGSEL=2 CATFISH_VIEW=1"
	"菜单|CATFISH_MENU=1 CATFISH_VIEW=1"
	"邮局寄件|CATFISH_MAIL=isle CATFISH_MAILTAB=0 CATFISH_VIEW=1"
	"邮局取件|CATFISH_MAIL=isle CATFISH_MAILTAB=1 CATFISH_VIEW=1"
	"邮局会员|CATFISH_MAIL=isle CATFISH_MAILTAB=3 CATFISH_VIEW=1"
	"会员柜翻页|CATFISH_MAIL=isle CATFISH_MAILPAGES=2 CATFISH_VIEW=1"
	"图鉴册|CATFISH_BOOK=0 CATFISH_ORES=38 CATFISH_VIEW=1"
	"固定形象|CATFISH_LOOK=2,2,3 CATFISH_MENU=2 CATFISH_VIEW=1"   # 菜单第 3 页（图鉴）；衣柜在 D152 里已经废了，没有这个面板
	"睡觉|CATFISH_ROOM=home CATFISH_NAP=2 CATFISH_VIEW=1"
	"夜晚|CATFISH_HOUR=21 CATFISH_VIEW=1"
	"下雨|CATFISH_WEATHER=rain CATFISH_VIEW=1"
	"读信|CATFISH_GO=1 CATFISH_ROOM=tackle CATFISH_QUEST=letter CATFISH_VIEW=1"
	"任务对话|CATFISH_GO=1 CATFISH_ROOM=tackle CATFISH_QUEST=talk CATFISH_VIEW=1"
	"服装店|CATFISH_GO=1 CATFISH_ROOM=tailor CATFISH_OUTFITSHOP=hat CATFISH_VIEW=1"
	"造船厂|CATFISH_GO=1 CATFISH_ROOM=home CATFISH_SHIPYARD=500 CATFISH_VIEW=1"
	"鱼篓视图|CATFISH_FISHVIEW=1 CATFISH_VIEW=1"
	"商店分页|CATFISH_MENU=0 CATFISH_SHOP=1 CATFISH_VIEW=1"
	"设置页|CATFISH_MENU=3 CATFISH_VIEW=1"
	"状态页|CATFISH_MENU=4 CATFISH_VIEW=1"
	"任务页|CATFISH_MENU=5 CATFISH_VIEW=1"
	"鸟来访|CATFISH_BIRD=1 CATFISH_VIEW=1"
	"摆摊卖货|CATFISH_ITEMS=3 CATFISH_SELLMODE=1 CATFISH_VIEW=1"
)
printf '%-10s %-6s %-8s %-6s %-7s %s\n' "画面" "退出" "泄漏行" "报错" "截图KB" "备注"
printf '%s\n' "--------------------------------------------------------------------------"
bad=0
noshot=0
same=0
miss=0
i=0
base_md5=""
seen=""
for row in "${screens[@]}"; do
	name="${row%%|*}"; envs="${row#*|}"
	if [[ -n "${LEAK_ONLY:-}" && "$name" != *"$LEAK_ONLY"* ]]; then
		skip=1
		for pat in ${LEAK_ONLY//,/ }; do
			[[ "$name" == *"$pat"* ]] && skip=0
		done
		[[ $skip -eq 1 ]] && continue
	fi
	log="$home/leak.log"
	: >"$log"
	i=$((i + 1))
	note=""
	# 截图是给"这个画面真的打开了"当证据的：拿不到图就判这次扫描没跑成
	shot_at=$((frames - 40))
	((shot_at < 20)) && shot_at=20
	shot="$home/shot_$i"
	# shellcheck disable=SC2086
	env HOME="$home" CATFISH_SAVE="$save" CATFISH_SHOT="$shot:$shot_at" $envs \
		timeout 300 "$bin" --quit-after "$frames" --verbose >"$log" 2>&1
	rc=$?
	png="${shot}_${shot_at}.png"
	skb=0
	if [[ -f "$png" ]]; then
		skb=$(( $(/bin/ls -l "$png" | awk '{print $5}') / 1024 ))
		mv -f "$png" "$shots/$(printf '%02d' "$i")_${name}.png" 2>/dev/null
		if [[ $skb -lt 2 ]]; then note="$note 图小得可疑"; fi
	else
		note="$note 没截到图"
	fi
	if [[ $skb -lt 1 ]]; then noshot=$((noshot + 1)); fi
	sig=""
	if [[ -f "$shots/$(printf '%02d' "$i")_${name}.png" ]]; then
		sig="$(md5 -q "$shots/$(printf '%02d' "$i")_${name}.png" 2>/dev/null)"
		if [[ -z "$base_md5" ]]; then
			base_md5="$sig"                      # 列表里第一个画面当基线（默认是"家里"）
		elif [[ -n "$sig" && "$sig" == "$base_md5" ]]; then
			note="$note 跟基线一帧不差"
			same=$((same + 1))
		fi
		case "$seen" in *"|$sig|"*) note="$note 与别的画面完全相同";; *) seen="$seen|$sig|";; esac
	fi
	leak=$(grep -icE 'Leaked instance|still in use|Orphan StringName' "$log")
	err=$(grep -c 'SCRIPT ERROR' "$log")
	if grep -q 'ERROR: Failed loading resource' "$log"; then note="$note 资源加载失败"; fi
	if grep -q '标签图集缺少' "$log"; then
		note="$note 缺字"
		miss=$((miss + 1))
		grep '标签图集缺少' "$log" | sed 's/^/    /' | head -3
		cp -f "$log" "$shots/${name}.log" 2>/dev/null
	fi
	if [[ $err -gt 0 ]]; then note="$note SCRIPT_ERROR"; fi
	if [[ $leak -gt 0 ]]; then
		note="$note ← 有泄漏"
		bad=$((bad + 1))
		grep -E 'Leaked instance|still in use' "$log" | sed 's/^/    /' | head -6
		cp -f "$log" "$shots/${name}.log" 2>/dev/null
	fi
	if [[ $err -gt 0 ]]; then
		cp -f "$log" "$shots/${name}.log" 2>/dev/null
	fi
	if [[ $rc -ne 0 ]]; then note="$note 退出码$rc"; fi
	printf '%-10s %-6s %-8s %-6s %-7s %s\n' "$name" "$rc" "$leak" "$err" "$skb" "${note# }"
done
ran=$i

echo "--------------------------------------------------------------------------"
echo "截图都放在：$shots"
if [[ $bad -gt 0 ]]; then
	echo "✗ 有 $bad 个画面退出时报了泄漏"
fi
if [[ $noshot -gt 0 ]]; then
	echo "✗ 有 $noshot 个画面压根没截出图（画面可能没打开，或者帧号太靠后）"
fi
if [[ $miss -gt 0 ]]; then
	echo "✗ 有 $miss 个画面画了图集里没有的文字（那句中文会被整条跳过 → 玩家看不见），原文已打在上面并留了日志"
fi
if [[ $same -gt 0 ]]; then
	echo "✗ 有 $same 个画面和基线（列表第一个画面）一帧不差 → 那些面板压根没弹开"
fi
if [[ $bad -eq 0 && $noshot -eq 0 && $same -eq 0 && $miss -eq 0 ]]; then
	echo "✓ 泄漏扫描通过：$ran 个画面退出时都没有泄漏、没有缺字，每个都留下了自己的截图（每个 $frames 帧）"
fi
[[ $bad -eq 0 && $noshot -eq 0 && $same -eq 0 && $miss -eq 0 ]]
