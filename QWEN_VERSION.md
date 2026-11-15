# Qwen 版本说明（本分支）

- **GitHub 分支**：`Qwen-v0.92`（远端 `origin/Qwen-v0.92`；本地工作树分支只能小写 `qwen-v0.92`，macOS 文件系统不分大小写）
- **当前版本**：**v0.92**，标签 `v0.92-qwen`，验收包 **`build/CatFishing_v0.92_Qwen.app`**
- **开发模型**：DeepSeek Harness + Qwen3.8（Qwen 侧的独立开发线）
- **基线**：从标签 `v0.89` 分出。
- **这是一条和 Codex 并行的线**：GitHub 上已有 `codex-v0.87` … `codex-v0.91`（标签 `v0.91-codex` = "controllable sea route to mine island"）。两边的同号版本号是**两个不同的东西**，靠 `-qwen` / `-codex` 后缀区分；两条线尚未合并（合并时 `assets/sprites/labels.png` 预计冲突，要在合并后的树上重跑一次 `tools/art/generate.py`）。

## 怎么验收（双击就行）

1. 双击 **`运行游戏.command`** → 自动开 `build/CatFishing_v0.92_Qwen.app`；这个包已经在本机打好了。
2. 想要重新打一份：双击 **`打包游戏.command`**（约 10 秒，产物名字里带版本号和 `_Qwen`，打包完自己起两帧自检）。
3. 双击后什么都没发生 / 终端一闪而过：v0.92 之前就是这个毛病，现在的脚本会自动打包 + 打印原因 + 停住等你看。详见 README「运行」。

## 版本表

| 版本 | 标签 | 做了什么 | 验证 |
|---|---|---|---|
| **v0.92** | `v0.92-qwen` | 修好双击 `运行游戏.command` 打不开（老脚本 `open` 一个不存在的 `build/CatFishing.app`）；新增 `打包游戏.command`；`project.godot` 版本号从 0.89 补到 0.92 并回写导出预设 | 本机 macOS：打包自检通过、`运行游戏.command` 真开真退（存档 md5 未变）、调试包自截图 2 张 0 警告 0 报错、`ALL TESTS PASS`（912 项）+ `SIM PASS`。**未验**：真人双击体验、透明/穿透/拖动肉眼确认、Intel 机器 |
| v0.91 | `v0.91-qwen` | 补 v0.88／v0.89 欠的测试（811 → **912 项**）；修 10 条界面提示不在标签图集里（玩家原本看不到字）；调试传送时 `adapter` 未创建导致 `SCRIPT ERROR`；新增 `CATFISH_MAILPAGES`；README 补齐 40 个调试变量 | 本机 macOS：`ALL TESTS PASS` / `SIM PASS`，真机启动 6 次 0 警告 0 报错。**未验**：截图内容人工目检、`.app` 启动（v0.92 已补做） |

## 本机（macOS，Godot 4.7.2）实际跑过的命令

| 命令 | 结果 |
|---|---|
| `./打包游戏.command` | `✓ 自检通过`，退出码 0，8.6 秒，产物 163 MB |
| `./运行游戏.command` | 打开 `CatFishing_v0.92_Qwen.app`，进程存活 ≥12 秒，`kill` 后正常退出，`user://save.json` md5 前后一致 |
| `codesign -v build/CatFishing_v0.92_Qwen.app` | `valid on disk` / `satisfies its Designated Requirement` |
| `Godot --headless --path . --script res://tests/run_tests.gd` | `ALL TESTS PASS`，912 项、0 失败，无 `SCRIPT ERROR` |
| `Godot --headless --path . --script res://tests/sim_long_run.gd` | `SIM PASS` |
| 调试包 + `CATFISH_SHOT=…:150` | 两张 1920×1080 自截图（198 / 276 种颜色，两图 100 万像素不同），0 警告 0 报错 |

## 没验证的部分（不许当成通过）

- **真人双击**的实际体验（代理只能用命令行跑同一个 `.command` 等价验证）。
- 窗口**透明、点击穿透、拖动、通知、音效听感**——`.app` 内的视口截图是 100% 不透明的（截图不带窗口 alpha），不能拿截图当透明度证据。
- Intel Mac 上的运行；从 GitHub 下载后 Gatekeeper 的第一次拦截。
- 与 `codex-v0.90`／`codex-v0.91` 的合并。
