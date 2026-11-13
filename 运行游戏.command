#!/bin/bash
# 双击运行：先清掉 macOS 给文件打的"来自网络/未验证"隔离标记，再打开游戏。
cd "$(dirname "$0")"
xattr -cr build/CatFishing.app 2>/dev/null
open build/CatFishing.app
