#!/bin/bash
# 挂机油调：把游戏开着**什么都不做**，每 5 秒采一次 RSS（常驻内存）和 CPU，
# 看桌面宠物一直挂着会不会越占越多。桌面宠物最怕的就是"挂着挂着吃掉几百 MB"。
#
# 用法：  ./tools/perf/idle_rss.sh [挂几分钟，默认 4] [调试包路径]
# 存档写到 mktemp 的临时目录（CATFISH_SAVE + HOME 双保险），**绝不碰你的真存档**。
# 判定：末段平均 RSS 比首段（热身后）平均 RSS 高出 20% 且绝对值 > 20 MB → 判"在涨"，退出码 1。
set -u
cd "$(dirname "$0")/../.." || exit 1

mins="${1:-4}"
version="$(sed -n 's/^config\/version="\([^"]*\)"/\1/p' project.godot | head -n 1)"
app="${2:-build/CatFishing_v${version}_Qwen_debug.app}"
bin="$(ls "$app"/Contents/MacOS/* 2>/dev/null | head -n 1)"
if [[ -z "${bin:-}" || ! -x "$bin" ]]; then
	echo "✗ 找不到调试包里的可执行文件：$app/Contents/MacOS/" >&2
	exit 1
fi

home="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/catfish_idle_home.XXXXXX")"
save="$home/save"
log="$home/idle.csv"
trap 'rm -rf "$home"' EXIT

echo "t_s,rss_mb,cpu" >"$log"
start=$(date +%s)
end=$((start + mins * 60))
# shellcheck disable=SC2086
env HOME="$home" CATFISH_SAVE="$save" "$bin" >"$home/game.log" 2>&1 &
pid=$!
echo "挂了 ${mins} 分钟：${app}（pid ${pid}，存档在 ${save}）"

alive=1
while (( $(date +%s) < end )); do
	if ! kill -0 "$pid" 2>/dev/null; then alive=0; break; fi
	t=$(( $(date +%s) - start ))
	rss_kb="$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')"
	cpu="$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' ')"
	if [[ -z "$rss_kb" ]]; then alive=0; break; fi
	rss_mb=$((rss_kb / 1024))
	echo "${t}s  RSS ${rss_mb} MB  CPU ${cpu}%"
	echo "$t,$rss_mb,$cpu" >>"$log"
	sleep 5
done

if [[ $alive -eq 0 ]]; then
	echo "✗ 游戏中途退出了（本来要挂满 $mins 分钟）——看 $home/game.log"
	[[ -f "$home/game.log" ]] && tail -12 "$home/game.log"
	exit 1
fi

# 热身 30 秒后再取"首段"，避开启动期贴图加载的正常上涨
/usr/bin/python3 - "$log" <<'PY'
import csv, sys
rows = [r for r in csv.DictReader(open(sys.argv[1], encoding='utf-8'))]
if len(rows) < 6:
    print("采样太少，判不了"); sys.exit(1)
warm = 30
after = [r for r in rows if int(r['t_s']) >= warm]
head = after[:max(1, len(after) // 3)]
tail = after[-max(1, len(after) // 3):]
h = sum(float(r['rss_mb']) for r in head) / len(head)
t = sum(float(r['rss_mb']) for r in tail) / len(tail)
cpu = [float(r['cpu']) for r in after if r['cpu']]
print("热身 %ds 后：首段平均 %.1f MB → 末段平均 %.1f MB（差 %+.1f MB / %+.1f%%）" % (
    warm, h, t, t - h, 0.0 if h == 0 else (t - h) / h * 100.0))
print("热身后的 RSS 区间：%.1f – %.1f MB（启动那一两秒不算）" % (
    min(float(r['rss_mb']) for r in after), max(float(r['rss_mb']) for r in after)))
print("末次采样：%.1f MB" % float(rows[-1]['rss_mb']))
if cpu:
    print("CPU（%%，单核=100）：平均 %.1f，最大 %.1f" % (sum(cpu) / len(cpu), max(cpu)))
if (t - h) > 20.0 and (h > 0 and (t - h) / h > 0.20):
    print("✗ 判定：内存一直在涨")
    sys.exit(1)
print("✓ 判定：挂着没一直在涨")
PY
