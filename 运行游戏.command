#!/bin/bash
# 双击运行《桌面小猫钓鱼》。
#
# 以前只有一行 open build/CatFishing.app：那个文件不存在时终端一闪就关，看起来就是"双击没反应"。
# 现在会：自己找到 build/ 里最新的 CatFishing_v*_Qwen.app；一个都没有就现打包一份；
# 打开前先清掉 macOS 的"未验证开发者"隔离标记；失败时把原因打印出来并停住等你看。
set -u
cd "$(dirname "$0")" || exit 1

pause() {
	echo ""
	echo "（这个窗口不会自己关，按回车键就可以关掉）"
	read -r _ || true
}

newest() { ls -1dt "$@" 2>/dev/null | head -n 1; }   # 参数是通配符，取最新的那个

app="${CATFISH_APP:-}"
if [[ -n "$app" && ! -d "$app" ]]; then
	echo "CATFISH_APP 指的目录不存在：$app（改用 build/ 里最新的）"
	app=""
fi
[[ -z "$app" ]] && app="$(newest build/CatFishing_v*_Qwen.app)"
[[ -z "$app" ]] && [[ -d build/CatFishing.app ]] && app="build/CatFishing.app"
[[ -z "$app" ]] && app="$(newest build/CatFishing_v*.app)"

if [[ -z "$app" || ! -d "$app" ]]; then
	echo "build/ 里还没有打包好的游戏，现在现打包一份（大约一分钟，先导入素材再导出）。"
	echo ""
	if [[ ! -f 打包游戏.command ]]; then
		echo "✗ 这个文件夹里找不到「打包游戏.command」，没法自动打包。"
		echo "  你可以手动跑：./打包游戏.command"
		pause
		exit 1
	fi
	if [[ ! -x 打包游戏.command ]]; then
		echo "→ 顺手给「打包游戏.command」加上可执行权限…"
		chmod +x 打包游戏.command
	fi
	if ! ./打包游戏.command; then
		echo ""
		echo "✗ 自动打包失败了，上面是原因。"
		pause
		exit 1
	fi
	app="$(newest build/CatFishing_v*_Qwen.app)"
fi

if [[ -z "$app" || ! -d "$app" ]]; then
	echo "✗ 打包脚本说成功了，可还是找不到 .app，见 build/ 目录。"
	pause
	exit 1
fi

bin="$(ls "$app"/Contents/MacOS/* 2>/dev/null | head -n 1)"
if [[ -z "$bin" || ! -x "$bin" ]]; then
	echo "✗ $app 里没找到可执行文件（这个包可能是半途断掉生成的）。删掉它再双击一次就行。"
	pause
	exit 1
fi

echo "打开：$app"
xattr -cr "$app" 2>/dev/null        # 清掉"来自网络/未验证开发者"的隔离标记
if ! open "$app"; then
	echo ""
	echo "✗ macOS 不让打开它。一般是 Gatekeeper 拦的，两种办法："
	echo "  1) 在 Finder 里按住 Control 点这个 .app → 打开（只这一次）；"
	echo "  2) 系统设置 → 隐私与安全性 → 最下面「仍要打开」。"
	pause
	exit 1
fi
echo "✓ 已经启动了。桌面没看到小猫的话，等一下；窗口是透明的，可能贴在屏幕角落。"
exit 0
