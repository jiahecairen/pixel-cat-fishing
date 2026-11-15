# Qwen 版本说明（本分支）

- **GitHub 分支**：`Qwen-v0.99`（远端 `origin/Qwen-v0.99`；本地工作树分支只能小写 `qwen-v0.99`，macOS 文件系统不分大小写）
- **当前版本**：**v0.99**，标签 `v0.99-qwen`，验收包 **`build/CatFishing_v0.99_Qwen.app`**
- **开发模型**：DeepSeek Harness + Qwen3.8（Qwen 侧的独立开发线）
- **基线**：从标签 `v0.89` 分出。
- **这是一条和 Codex 并行的线**：GitHub 上已有 `codex-v0.87` … `codex-v0.91`（标签 `v0.91-codex` = "controllable sea route to mine island"）。两边的同号版本号是**两个不同的东西**，靠 `-qwen` / `-codex` 后缀区分；两条线尚未合并（合并时 `assets/sprites/labels.png` 预计冲突，要在合并后的树上重跑一次 `tools/art/generate.py`）。

## 怎么验收（双击就行）

1. 双击 **`运行游戏.command`** → 自动开 `build/CatFishing_v0.99_Qwen.app`；这个包已经在本机打好了。
2. 想重新打一份：双击 **`打包游戏.command`**（约 10 秒，产物名字里带版本号和 `_Qwen`，打包完自己起两帧自检）。
3. 双击后什么都没发生 / 终端一闪而过：v0.92 之前就是这个毛病，现在的脚本会自动打包 + 打印原因 + 停住等你看。详见 README「运行」。
4. **v0.94 想看点新东西**：进矿山岛 → 分别下 1／2／3／4／5 号井，五口井的石头、地板、崖边描边颜色各不相同（灰岩／赤铜／蓝晶／地火／星陨），票务工位每行和下井提示里都会写井名。**1 号井的画面和 v0.93 逐像素一致**（染色强度 0），想对比就前后各下一次 1 号井和 5 号井。
5. v0.95 的新东西在井底：**背景、四周压下来的黑暗、矿石反光点的色温**都按井走（灰岩偏紫、赤铜偏铜、蓝晶偏冰蓝、地火偏橙、星陨偏青），但**明暗保持不变**。想快速来回看：`CATFISH_SHAFT=3` 与 `CATFISH_SHAFT=4` 各跑一次（记得带 `CATFISH_SAVE`）。
6. **命令行调试请带上 `CATFISH_SAVE=/tmp/某个临时目录`**：存档和事件日志会写到那里，不会碰你真正的 `user://save.json`（只在调试构建生效）。**打包好的 Release 包不认这个变量**，要拿它做启动自检就再带一个 `HOME=/tmp/某个临时目录`，把整个用户目录挪走（实测有效）。
7. **v0.99 把画面体检做全了**：`tools/perf/leak_sweep.sh` 从 12 个画面扩到 **35 个**，而且每个画面都要交一张截图（默认在 `/tmp/catfish_sweep_shots/`，`序号_画面名.png`）——**截不出图**或**跟基线画面一帧不差**都判失败。想只跑几个画面：`LEAK_ONLY=小镇,矿井里 ./tools/perf/leak_sweep.sh`。截图我（模型）没法亲眼看，对不对得你点开看。
8. **v0.98 也是收尾版**：新增两个体检脚本 `tools/perf/idle_rss.sh`（挂着别动，看内存会不会一直涨）和 `tools/perf/leak_sweep.sh`（十二个画面各起一次，退出时看引擎漏不漏对象）。本机实测**挂机 4 分钟内存 +0.6%、CPU 5.2%**、**十二个画面退出时零泄漏**。你自己想量：终端里 `./tools/perf/idle_rss.sh 4`（存档写到临时目录，不碰你的真存档）。
9. **v0.97 没有新玩法**，是一版"收尾"：① 关掉游戏时不再漏对象（引擎原来在退出时报 `2 resources still in use at exit` + `5 ObjectDB instances were leaked` + 227 条孤儿字符串，现在 0 条）；② **`打包游戏.command` 的自检不再碰你的存档**（以前每打一次包就把 `user://save.json` 重写一遍，现在自检在 `mktemp` 临时目录里跑）。想自己确认：`codesign` 完双击 `运行游戏.command` 玩一会儿退出，终端里看不到那两条泄漏警告即可。
10. **v0.96 的新东西在图鉴册**：打开图鉴册 → 第 1 页"图鉴"，往下翻页，**10 条鱼后面接着排 38 种矿石**；挖到过的会亮（真图标 + 名字 + `x数量`），没挖到过的是空框 + "？？？"；底栏多了一行 **"矿石 x/38 种"**。想立刻看满的：`CATFISH_BOOK=0 CATFISH_ORES=38 CATFISH_VIEW=1 CATFISH_SAVE=/tmp/临时目录` 跑一次（调试构建才生效）。

## 版本表

| 版本 | 标签 | 做了什么 | 验证 |
|---|---|---|---|
| **v0.99** | `v0.99-qwen` | 画面体检扩到 **35 个画面**（新增：钓鱼中、专注中、休息中、读信、任务对话、服装店、造船厂、鱼篓视图、商店分页、设置页、状态页、任务页、鸟来访、摆摊卖货、迷你视图、固定形象），每个画面必须交一张截图当证据；**截不出图**或**与基线一帧不差**都判失败。加 `LEAK_ONLY` 过滤；**缺字（画了图集里没有的中文）改为硬失败**；`idle_rss.sh` 采完自己关游戏。**扫出来的真 bug**：商店鱼饵页那句"买来的鱼饵每竿用 1 个"从来没进过图集 → 玩家一直看不见，已补进 `LABELS` 重生成；另加静态测试：所有 `label*()` 的中文字面量必须在图集里。测试 **1025 → 1035** | 本机 macOS：`ALL TESTS PASS`（**1035 项 0 失败**）+ `SIM PASS`、`--import` 0 报错、`./打包游戏.command` `✓ 自检通过` 且**打包前后真存档 md5 一字不变**（`9eca58e9…`）、`CatFishing_v0.99_Qwen.app`（163 MB 通用二进制、`codesign -v` 0、版本号 0.99）+ 调试包 178 MB（签名 0）；`退出码 0；`✓ 泄漏扫描通过：35 个画面…没有泄漏、没有缺字，每个都留下了自己的截图`；35 行退出码／泄漏行／`SCRIPT ERROR`／缺字**全 0**，截图 35 张（5–24 KB）在 `/tmp/v099_shots/``。**未验**：截图没有人工目检（模型不收图）、挂机仍只量过一次 4 分钟、Intel 没跑过 |
| v0.98 | `v0.98-qwen` | 收尾版：把「挂机开销」和「逐画面泄漏」变成**能复跑的脚本** —— `tools/perf/idle_rss.sh`（每 5 秒采 RSS + CPU，热身 30 秒后末段比首段高 >20% 且 >20 MB 才判"在涨"）、`tools/perf/leak_sweep.sh`（十二个画面各跑 240 帧，退出时盯 `Leaked instance`／`still in use`／`Orphan StringName`）。两个脚本都强制 `mktemp` 临时存档目录。新增 13 项测试（**1012 → 1025**）钉住这些卫生规则 | 本机 macOS：`ALL TESTS PASS`（**1025 项 0 失败**）+ `SIM PASS`、`--import` 0 报错、`./打包游戏.command` 自检通过且**打包前后真存档 md5 一字不变**（`9eca58e9…`）、`CatFishing_v0.98_Qwen.app`（163 MB 通用二进制、`codesign -v` 0、版本号 0.98）+ 调试包（178 MB、签名 0）；**挂机 4 分钟 166.0 → 167.0 MB（+0.6%）、CPU 平均 5.2%**；**十二个画面退出时泄漏行全 0**。**未验**：只挂了一次 4 分钟（没挂整夜/整天）、十二画面之外的画面、Intel 机器、脚本输出没有画面目检 |
| v0.97 | `v0.97-qwen` | 收尾版：**修掉退出时的引用环**——`Shopfronts` 原来把 `World` 存回成员，两个 RefCounted 互相指永远不回收（退出报 5 个实例 + 2 个脚本资源 + 227 条孤儿 StringName）；改成构造时把 `GROUND_Y` 这个**常量抄成数值** `_gy0`（Node 引用不计数，`m` 照旧存）。**打包自检改用 `mktemp` 临时目录**，不再每次打包重写玩家存档。新增 15 项测试（**997 → 1012**）：扫 `presentation/*.gd` 建"谁持有谁"的单向图，只拦**来回指的环**（单向持有合法） | 本机 macOS：`ALL TESTS PASS`（**1012 项 0 失败**）+ `SIM PASS`、`--import` 0 报错、`bash -n 打包游戏.command` 0、`./打包游戏.command` 自检通过且**打包前后真存档 md5 一字不变**（`9eca58e9…`）、`CatFishing_v0.97_Qwen.app`（163 MB 通用二进制、`codesign -v` 0、版本号 0.97）与调试包（178 MB、签名 0）退出时**泄漏相关输出 0 行**（v0.96 同一套命令：矿洞／图鉴各 64 行、小镇 236 行）。**未验**：截图人工目检、长时间挂机的内存曲线、其它画面的泄漏、透明/穿透/拖动、Intel 机器 |
| v0.96 | `v0.96-qwen` | 矿石终于进图鉴了：`stats["ore_counts"]`（矿石 → 挖到几块；**不升存档版本、老存档自动补空键**）；`core/mine.gd` 在"石头碎了、矿石进背包"那一处后面 `_record_ore()` 记一笔（靠"一格只碎一次"天然幂等，装不下的矿石不算见过），新增 `ore_dex()/ore_dug_count()/dex_found()`；图鉴第 1 页改成**鱼后面接 38 种矿石**共用翻页，没见过的画空框 + "？？？"，底栏加"矿石 x/38 种"，新文字全走 `dyn_text` **不重生成素材**；翻页算术抽成 `Book.dex_pages_for(total, per)` 好测；调试 `CATFISH_BOOK` 顺手播 6 种矿石、新增 `CATFISH_ORES=N`；新增 19 项测试（**978 → 997**） | 本机 macOS：`ALL TESTS PASS`（**997 项 0 失败**）+ `SIM PASS`、`--import` 0 报错、`./打包游戏.command` 自检通过、`CatFishing_v0.96_Qwen.app`（163 MB 通用二进制、`codesign -v` 退出码 0、版本号 0.96）、调试包点亮 6 种 / 38 种各截一张（0 报错 0 缺字；底栏新增 2376 个文字像素、卡片区 5580 像素变化、整屏 0.48% 不同）；真存档只多出空键 `ore_counts`（**逐字段对比过，没有丢任何进度**）。**未验**：图鉴页排版与好不好看的人工目检、38 种逐页翻的手感、真挖一遍的收集节奏、透明/穿透/拖动、Intel 机器 |
| v0.95 | `v0.95-qwen` | 井底的天也分井了：`mine.shaft_themes` 再加 `bg`（背景）/`fog`（黑暗）/`lamp`（灯光）三个调色板键；`mine_view` 加三个静态纯函数 `shaft_backdrop/shaft_darkness/shaft_lamp`，黑暗只做"黑得偏色"（主题色压到 16% 亮度再混，透明度不动）；1 号井三个位就是原色 + `mix=0`，用**精确等式**断言零变化；测试硬卡背景亮度 ≤0.25、黑暗亮度 ≤0.06；新增 17 项测试（**961 → 978**） | 本机 macOS：`ALL TESTS PASS`（**978 项 0 失败**）+ `SIM PASS`、`--import` 0 报错、`./打包游戏.command` 自检通过、`CatFishing_v0.95_Qwen.app` 200 帧 0 报错、调试包 `CATFISH_SHAFT=5` 真机 0 报错、五口井暗区取色证明色相分开而亮度差 ≤3.3%、真存档 md5 全程不变。**未验**：配色好不好看的人工目检、深色井里反光点对比度、真人观感节奏、透明/穿透/拖动、Intel 机器 |
| v0.94 | `v0.94-qwen` | 五口井各有各的长相：`data/balance.json` 新增 `mine.shaft_themes`（名字 + 五个部位的**调色板键** + 染色强度 `mix`）与全局兜底 `mine.shaft_theme_mix`；`core/mine.gd` 加 `shaft_theme/shaft_name/shaft_color/shaft_mix`（不认识的井退回 1 号井）；`mine_view` 给石头·岩壁·崖壁·地板·崖边描边按井染色，票务工位与下井提示带上井名；染色是**亮度守恒的色相偏移**，1 号井 `mix=0` 保证老玩家零变化；调试新增 `CATFISH_SAVE`（存档挪走）/`CATFISH_SHAFT`（直接开进某口井）/`CATFISH_SEED` 钉死矿图种子；新增 18 项测试（**943 → 961**） | 本机 macOS：`ALL TESTS PASS`（**961 项 0 失败**）+ `SIM PASS`、`--import` 0 报错、`./打包游戏.command` 自检通过、`CatFishing_v0.94_Qwen.app` 200 帧启动 0 报错、五口井各截一张图 0 报错并做了像素比对（色相分开、亮区亮度差 ≤1.3%）、真存档 md5 前后一致。**未验**：配色好不好看的人工目检、井名文字的排版是否溢出、真人手感、透明/穿透/拖动、Intel 机器 |\n| v0.93 | `v0.93-qwen` | 3–5 号井从"永远锁着"变成能开工：`data/balance.json` 新增 `mine.open_shafts`（先开上一口井 + 上一口井挖到 20/40/65 层 + 材料 + 雇工 2/3/4 人）；`core/mine.gd` 加 `open_need/open_prev/deepest_floor/open_missing/open_ready/open_shaft`，`shaft_status` 新增 `wait`/`build` 两态；票务工位加「开工」面板；`ensure()` 给 1–5 号井补齐字段；新增 31 项测试（**912 → 943**） | 本机 macOS：`ALL TESTS PASS`（943 项 0 失败）+ `SIM PASS`、`./打包游戏.command` 自检通过、`CatFishing_v0.93_Qwen.app` 200 帧启动 0 报错、调试包自截图 1 张 0 警告、存档 md5 前后一致。**未验**：开工面板的人工目检、真人手感、透明/穿透/拖动、Intel 机器 |
| v0.92 | `v0.92-qwen` | 修好双击 `运行游戏.command` 打不开（老脚本 `open` 一个不存在的 `build/CatFishing.app`）；新增 `打包游戏.command`；`project.godot` 版本号从 0.89 补到 0.92 并回写导出预设 | 本机 macOS：打包自检通过、`运行游戏.command` 真开真退（存档 md5 未变）、调试包自截图 2 张 0 警告 0 报错、`ALL TESTS PASS`（912 项）+ `SIM PASS`。**未验**：真人双击体验、透明/穿透/拖动肉眼确认、Intel 机器 |
| v0.91 | `v0.91-qwen` | 补 v0.88／v0.89 欠的测试（811 → **912 项**）；修 10 条界面提示不在标签图集里（玩家原本看不到字）；调试传送时 `adapter` 未创建导致 `SCRIPT ERROR`；新增 `CATFISH_MAILPAGES`；README 补齐 40 个调试变量 | 本机 macOS：`ALL TESTS PASS` / `SIM PASS`，真机启动 6 次 0 警告 0 报错。**未验**：截图内容人工目检、`.app` 启动（v0.92 已补做） |

## 本机（macOS，Godot 4.7.2）实际跑过的命令

| 命令 | 结果 |
|---|---|
| `Godot --headless --path . --import` | 退出码 0，0 条 `SCRIPT ERROR` |
| `Godot --headless --path . --script res://tests/run_tests.gd` | `ALL TESTS PASS`，**1025 项、0 失败**，无 `SCRIPT ERROR`、无 `WARNING`（v0.97 时是 1012 项） |
| `./tools/perf/idle_rss.sh 4`（调试包，临时存档目录） | 退出码 0；`✓ 判定：挂着没一直在涨`；热身 30 秒后**首段平均 166.0 MB → 末段平均 167.0 MB（+1.0 MB / +0.6%）**；CPU 平均 **5.2%**、最大 5.6%（单核=100%，此时限帧 30 帧）。v0.97 的调试包同命令：209.6 → 191.0 MB（−8.9%） |
| `./tools/perf/leak_sweep.sh 240`（调试包） | `退出码 0；`✓ 泄漏扫描通过：35 个画面…没有泄漏、没有缺字，每个都留下了自己的截图`；35 行退出码／泄漏行／`SCRIPT ERROR`／缺字**全 0**，截图 35 张（5–24 KB）在 `/tmp/v099_shots/`` |
| `LEAK_ONLY=迷你视图,矿井里 ./tools/perf/leak_sweep.sh 120`（v0.99 调试包） | 退出码 0；只跑这 2 个画面；迷你视图 6 KB、矿井里 22 KB 都算正常出图（**别再拿 KB 当门槛**） |
| `Godot --headless --path . --script res://tests/sim_long_run.gd` | `SIM PASS`，0 条 `SCRIPT ERROR` |
| `./打包游戏.command`（v0.93–v0.96） | `✓ 自检通过`，退出码 0。**注意：v0.96 及以前的两帧自检是用你的真实用户目录跑的，会把 `user://save.json` 重写一次**；v0.97 起改成 `mktemp` 临时目录 |
| `./打包游戏.command`（v0.97 起） | `✓ 自检通过：app 能启动（两帧，退出码 0，无 SCRIPT ERROR；临时存档目录已删）`，产物 `build/CatFishing_v0.97_Qwen.app`（163 MB，x86_64 + arm64，`codesign -v` 0，`plutil` 版本号 `0.97`）；**打包前后真存档 md5 完全一致**（`9eca58e9…` → 同一值） |
| `… --quit-after 240 --verbose`（泄漏量测：v0.96 的包/代码 vs v0.97 的代码，各跑小镇／矿洞／图鉴三种画面，全部带 `HOME=/tmp/…` 隔离） | v0.96：**矿洞 64 行、图鉴 64 行、小镇 300 帧那次 236 行**（引擎报 `5 ObjectDB instances were leaked` + `2 resources still in use at exit`，孤儿 StringName 分别是 55／55／227 条）；v0.97 代码 + Release 包 + 调试包：**全部 0 行**，退出码 0、0 条 `SCRIPT ERROR` |
| `codesign -v build/CatFishing_v0.96_Qwen.app` 与 `…_debug.app` | 都退出码 0（`valid on disk` / `satisfies its Designated Requirement`） |
| 调试包 + `CATFISH_SAVE=/tmp/cf_user94 CATFISH_REGION=mine CATFISH_RUN=1 CATFISH_SEED=777 CATFISH_SHAFT=1..5` | 五口井各一张 1920×1080，0 条 `SCRIPT ERROR`；像素比对见 C182。真存档 md5 全程 `738cc5ad…` 不变 |
| `Godot --headless --path . --export-debug "macOS" build/CatFishing_v0.94_Qwen_debug.app` + `codesign --force --deep -s -` | 退出码 0、0 条错误；调试包 178 MB，`build/CatFishing_v0.94_Qwen_debug.command` 已生成 |
| **打包好的调试包** + `CATFISH_SHAFT=1`／`3`（同一颗种子） | 日志 `MINEDBG shaft=1`／`shaft=3`，两张 1920×1080 截图 0 条 `SCRIPT ERROR`、0 条"标签图集缺少文字"；**18.3% 像素不同**、亮区亮度只差 0.4% |
| `build/CatFishing_v0.96_Qwen.app/Contents/MacOS/CatFishing --headless --quit-after 200` | 退出码 0，**0 条 `ERROR`／`SCRIPT ERROR`**（打包好的包不能带 `--path`）。⚠ 这一类启动自检**会把存档重写一次**：v0.96 实测真存档因此多出空键 `stats.ore_counts: {}`，逐字段对比确认没有任何进度变化（md5 由 `738cc5ad…` 变 `9eca58e9…`）。以后做启动自检请再带 `HOME=/tmp/临时目录`（见下一行） |
| `HOME=/tmp/cf_home96 …CatFishing --headless --quit-after 300` | 退出码 0、0 条 `SCRIPT ERROR`；只写 `/tmp/cf_home96/Library/Application Support/Godot/app_userdata/CatFishing/save.json`（1562 字节新档）+ `.bak`，真存档 md5 不变。收尾有引擎自己的 `ERROR: 2 resources still in use at exit` + `WARNING: 5 ObjectDB instances were leaked`（**不是** `SCRIPT ERROR`，是退出时的资源回收提示） |
| 调试包 + `CATFISH_REGION=cave CATFISH_MINEMENU=open CATFISH_SHOT=…:150` | 1920×1080 自截图 `/tmp/cf93app_open_150.png`，0 警告 0 报错 |
| `./运行游戏.command`（v0.92 起可用） | 打开 `build/` 里最新的 `CatFishing_v*_Qwen.app`，进程存活后 `kill` 正常退出，存档 md5 未变 |

## 没验证的部分（不许当成通过）

- **真人双击**的实际体验（代理只能用命令行跑同一个 `.command` 等价验证）。
- 窗口**透明、点击穿透、拖动、通知、音效听感**——`.app` 内的视口截图是 100% 不透明的（截图不带窗口 alpha），不能拿截图当透明度证据。
- **v0.99 的截图我没有肉眼看过**：这轮的模型不收图，所以"画面内容对不对"仍要你点开 `/tmp/catfish_sweep_shots/` 自己看；脚本只保证"有图"和"跟基线不同"。
- **v0.98 的挂机只量了一次 4 分钟**：+0.6% 是**这一段**的斜率，**不是"永远不涨"的证明**；再往后（几小时、一整夜）没有数据。想拉长就 `./tools/perf/idle_rss.sh 60`。RSS 用 `ps -o rss=` 采，不含被系统压缩/换出的部分。
- **v0.97 只量了"退出时漏没漏"，没量挂机内存曲线**：泄漏数是用引擎退出时的自检输出量的（64 行 → 0 行）；**挂机几小时的 RSS 增长没有观测过**。三张对比截图也只做了像素统计（店面带平均 RGB 每通道差 ≤0.12），**没有人工目检**。
- **v0.96 的图鉴页没有人工目检**：机器只证明了"矿石卡片确实按 `ore_counts` 在画、而且只画在图鉴册那块面板里"（调试包两张图：底栏新增 2376 个文字像素、卡片区 5580 像素变化、整屏 0.48% 不同）。**名字有没有溢出卡片、38 种翻起来烦不烦、空框 + "？？？"好不好看，都没有人看过**。
- **v0.95 的背景／黑暗／灯光配色同样没有人工目检**：暗区取色只能说明"五口井色相分开了、整体亮度差 ≤3.3%、背景亮度 ≤0.25"，看不出好不好看，也不能说明深色井里反光点的对比度够不够。
- **整屏逐像素 A/B 在矿洞里不可用**：小猫每帧随机走动会让整屏 36.7% 的像素变化（实测），这种差异里混着走动和染色，不能当"画面没变"的证据。v0.95 的 1 号井零变化改由颜色函数的精确等式保证。
- **v0.94 五口井配色的"好不好看"没有人工目检**：本代理没有视觉能力，像素比对只能证明"五口井色相确实分开、亮区亮度差 ≤1.3%、1 号井逐像素不变"，不能证明好看；井名文字的排版是否溢出同样没看过。
- **v0.93「开工」面板的排版人工目检**：截图文件在本机 `/tmp/cf93_open_150.png`（编辑器）和 `/tmp/cf93app_open_150.png`（调试包）里，但本次没有肉眼看过；自动化的像素级排版校验在这台机器上不可靠（动态壁纸 + 场景动画会把整屏差异淹掉），所以只报了"有没有报错"，没报"排版对不对"。
- Intel Mac 上的运行；从 GitHub 下载后 Gatekeeper 的第一次拦截。
- 与 `codex-v0.90`／`codex-v0.91` 的合并。
