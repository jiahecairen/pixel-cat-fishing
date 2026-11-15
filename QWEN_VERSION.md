# Qwen 版本说明（本分支）

- **GitHub 分支**：`Qwen-v0.94`（远端 `origin/Qwen-v0.94`；本地工作树分支只能小写 `qwen-v0.94`，macOS 文件系统不分大小写）
- **当前版本**：**v0.94**，标签 `v0.94-qwen`，验收包 **`build/CatFishing_v0.94_Qwen.app`**
- **开发模型**：DeepSeek Harness + Qwen3.8（Qwen 侧的独立开发线）
- **基线**：从标签 `v0.89` 分出。
- **这是一条和 Codex 并行的线**：GitHub 上已有 `codex-v0.87` … `codex-v0.91`（标签 `v0.91-codex` = "controllable sea route to mine island"）。两边的同号版本号是**两个不同的东西**，靠 `-qwen` / `-codex` 后缀区分；两条线尚未合并（合并时 `assets/sprites/labels.png` 预计冲突，要在合并后的树上重跑一次 `tools/art/generate.py`）。

## 怎么验收（双击就行）

1. 双击 **`运行游戏.command`** → 自动开 `build/CatFishing_v0.93_Qwen.app`；这个包已经在本机打好了。
2. 想重新打一份：双击 **`打包游戏.command`**（约 10 秒，产物名字里带版本号和 `_Qwen`，打包完自己起两帧自检）。
3. 双击后什么都没发生 / 终端一闪而过：v0.92 之前就是这个毛病，现在的脚本会自动打包 + 打印原因 + 停住等你看。详见 README「运行」。
4. **v0.94 想看点新东西**：进矿山岛 → 分别下 1／2／3／4／5 号井，五口井的石头、地板、崖边描边颜色各不相同（灰岩／赤铜／蓝晶／地火／星陨），票务工位每行和下井提示里都会写井名。**1 号井的画面和 v0.93 逐像素一致**（染色强度 0），想对比就前后各下一次 1 号井和 5 号井。
5. **命令行调试请带上 `CATFISH_SAVE=/tmp/某个临时目录`**：存档和事件日志会写到那里，不会碰你真正的 `user://save.json`（只在调试构建生效）。

## 版本表

| 版本 | 标签 | 做了什么 | 验证 |
|---|---|---|---|
| **v0.94** | `v0.94-qwen` | 五口井各有各的长相：`data/balance.json` 新增 `mine.shaft_themes`（名字 + 五个部位的**调色板键** + 染色强度 `mix`）与全局兜底 `mine.shaft_theme_mix`；`core/mine.gd` 加 `shaft_theme/shaft_name/shaft_color/shaft_mix`（不认识的井退回 1 号井）；`mine_view` 给石头·岩壁·崖壁·地板·崖边描边按井染色，票务工位与下井提示带上井名；染色是**亮度守恒的色相偏移**，1 号井 `mix=0` 保证老玩家零变化；调试新增 `CATFISH_SAVE`（存档挪走）/`CATFISH_SHAFT`（直接开进某口井）/`CATFISH_SEED` 钉死矿图种子；新增 18 项测试（**943 → 961**） | 本机 macOS：`ALL TESTS PASS`（**961 项 0 失败**）+ `SIM PASS`、`--import` 0 报错、`./打包游戏.command` 自检通过、`CatFishing_v0.94_Qwen.app` 200 帧启动 0 报错、五口井各截一张图 0 报错并做了像素比对（色相分开、亮区亮度差 ≤1.3%）、真存档 md5 前后一致。**未验**：配色好不好看的人工目检、井名文字的排版是否溢出、真人手感、透明/穿透/拖动、Intel 机器 |\n| v0.93 | `v0.93-qwen` | 3–5 号井从"永远锁着"变成能开工：`data/balance.json` 新增 `mine.open_shafts`（先开上一口井 + 上一口井挖到 20/40/65 层 + 材料 + 雇工 2/3/4 人）；`core/mine.gd` 加 `open_need/open_prev/deepest_floor/open_missing/open_ready/open_shaft`，`shaft_status` 新增 `wait`/`build` 两态；票务工位加「开工」面板；`ensure()` 给 1–5 号井补齐字段；新增 31 项测试（**912 → 943**） | 本机 macOS：`ALL TESTS PASS`（943 项 0 失败）+ `SIM PASS`、`./打包游戏.command` 自检通过、`CatFishing_v0.93_Qwen.app` 200 帧启动 0 报错、调试包自截图 1 张 0 警告、存档 md5 前后一致。**未验**：开工面板的人工目检、真人手感、透明/穿透/拖动、Intel 机器 |
| v0.92 | `v0.92-qwen` | 修好双击 `运行游戏.command` 打不开（老脚本 `open` 一个不存在的 `build/CatFishing.app`）；新增 `打包游戏.command`；`project.godot` 版本号从 0.89 补到 0.92 并回写导出预设 | 本机 macOS：打包自检通过、`运行游戏.command` 真开真退（存档 md5 未变）、调试包自截图 2 张 0 警告 0 报错、`ALL TESTS PASS`（912 项）+ `SIM PASS`。**未验**：真人双击体验、透明/穿透/拖动肉眼确认、Intel 机器 |
| v0.91 | `v0.91-qwen` | 补 v0.88／v0.89 欠的测试（811 → **912 项**）；修 10 条界面提示不在标签图集里（玩家原本看不到字）；调试传送时 `adapter` 未创建导致 `SCRIPT ERROR`；新增 `CATFISH_MAILPAGES`；README 补齐 40 个调试变量 | 本机 macOS：`ALL TESTS PASS` / `SIM PASS`，真机启动 6 次 0 警告 0 报错。**未验**：截图内容人工目检、`.app` 启动（v0.92 已补做） |

## 本机（macOS，Godot 4.7.2）实际跑过的命令

| 命令 | 结果 |
|---|---|
| `Godot --headless --path . --import` | 退出码 0，0 条 `SCRIPT ERROR` |
| `Godot --headless --path . --script res://tests/run_tests.gd` | `ALL TESTS PASS`，**961 项、0 失败**，无 `SCRIPT ERROR`、无 `WARNING` |
| `Godot --headless --path . --script res://tests/sim_long_run.gd` | `SIM PASS`，0 条 `SCRIPT ERROR` |
| `./打包游戏.command` | `✓ 自检通过`，退出码 0，产物 `build/CatFishing_v0.93_Qwen.app`（163 MB） |
| `codesign -v build/CatFishing_v0.94_Qwen.app` | 退出码 0（`valid on disk` / `satisfies its Designated Requirement`） |
| 调试包 + `CATFISH_SAVE=/tmp/cf_user94 CATFISH_REGION=mine CATFISH_RUN=1 CATFISH_SEED=777 CATFISH_SHAFT=1..5` | 五口井各一张 1920×1080，0 条 `SCRIPT ERROR`；像素比对见 C182。真存档 md5 全程 `738cc5ad…` 不变 |
| `Godot --headless --path . --export-debug "macOS" build/CatFishing_v0.94_Qwen_debug.app` + `codesign --force --deep -s -` | 退出码 0、0 条错误；调试包 178 MB，`build/CatFishing_v0.94_Qwen_debug.command` 已生成 |
| **打包好的调试包** + `CATFISH_SHAFT=1`／`3`（同一颗种子） | 日志 `MINEDBG shaft=1`／`shaft=3`，两张 1920×1080 截图 0 条 `SCRIPT ERROR`、0 条"标签图集缺少文字"；**18.3% 像素不同**、亮区亮度只差 0.4% |
| `build/CatFishing_v0.93_Qwen.app/Contents/MacOS/CatFishing --headless --quit-after 200` | 退出码 0，**0 条 `ERROR`／`SCRIPT ERROR`**（打包好的包不能带 `--path`） |
| 调试包 + `CATFISH_REGION=cave CATFISH_MINEMENU=open CATFISH_SHOT=…:150` | 1920×1080 自截图 `/tmp/cf93app_open_150.png`，0 警告 0 报错 |
| `./运行游戏.command`（v0.92 起可用） | 打开 `build/` 里最新的 `CatFishing_v*_Qwen.app`，进程存活后 `kill` 正常退出，存档 md5 未变 |

## 没验证的部分（不许当成通过）

- **真人双击**的实际体验（代理只能用命令行跑同一个 `.command` 等价验证）。
- 窗口**透明、点击穿透、拖动、通知、音效听感**——`.app` 内的视口截图是 100% 不透明的（截图不带窗口 alpha），不能拿截图当透明度证据。
- **v0.94 五口井配色的"好不好看"没有人工目检**：本代理没有视觉能力，像素比对只能证明"五口井色相确实分开、亮区亮度差 ≤1.3%、1 号井逐像素不变"，不能证明好看；井名文字的排版是否溢出同样没看过。
- **v0.93「开工」面板的排版人工目检**：截图文件在本机 `/tmp/cf93_open_150.png`（编辑器）和 `/tmp/cf93app_open_150.png`（调试包）里，但本次没有肉眼看过；自动化的像素级排版校验在这台机器上不可靠（动态壁纸 + 场景动画会把整屏差异淹掉），所以只报了"有没有报错"，没报"排版对不对"。
- Intel Mac 上的运行；从 GitHub 下载后 Gatekeeper 的第一次拦截。
- 与 `codex-v0.90`／`codex-v0.91` 的合并。
