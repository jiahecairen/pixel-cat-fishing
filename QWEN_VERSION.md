# Qwen 版本说明（本分支）

- **GitHub 分支**：`Qwen-v0.96`（远端 `origin/Qwen-v0.96`；本地工作树分支只能小写 `qwen-v0.96`，macOS 文件系统不分大小写）
- **当前版本**：**v0.96**，标签 `v0.96-qwen`，验收包 **`build/CatFishing_v0.96_Qwen.app`**
- **开发模型**：DeepSeek Harness + Qwen3.8（Qwen 侧的独立开发线）
- **基线**：从标签 `v0.89` 分出。
- **这是一条和 Codex 并行的线**：GitHub 上已有 `codex-v0.87` … `codex-v0.91`（标签 `v0.91-codex` = "controllable sea route to mine island"）。两边的同号版本号是**两个不同的东西**，靠 `-qwen` / `-codex` 后缀区分；两条线尚未合并（合并时 `assets/sprites/labels.png` 预计冲突，要在合并后的树上重跑一次 `tools/art/generate.py`）。

## 怎么验收（双击就行）

1. 双击 **`运行游戏.command`** → 自动开 `build/CatFishing_v0.96_Qwen.app`；这个包已经在本机打好了。
2. 想重新打一份：双击 **`打包游戏.command`**（约 10 秒，产物名字里带版本号和 `_Qwen`，打包完自己起两帧自检）。
3. 双击后什么都没发生 / 终端一闪而过：v0.92 之前就是这个毛病，现在的脚本会自动打包 + 打印原因 + 停住等你看。详见 README「运行」。
4. **v0.94 想看点新东西**：进矿山岛 → 分别下 1／2／3／4／5 号井，五口井的石头、地板、崖边描边颜色各不相同（灰岩／赤铜／蓝晶／地火／星陨），票务工位每行和下井提示里都会写井名。**1 号井的画面和 v0.93 逐像素一致**（染色强度 0），想对比就前后各下一次 1 号井和 5 号井。
5. v0.95 的新东西在井底：**背景、四周压下来的黑暗、矿石反光点的色温**都按井走（灰岩偏紫、赤铜偏铜、蓝晶偏冰蓝、地火偏橙、星陨偏青），但**明暗保持不变**。想快速来回看：`CATFISH_SHAFT=3` 与 `CATFISH_SHAFT=4` 各跑一次（记得带 `CATFISH_SAVE`）。
6. **命令行调试请带上 `CATFISH_SAVE=/tmp/某个临时目录`**：存档和事件日志会写到那里，不会碰你真正的 `user://save.json`（只在调试构建生效）。**打包好的 Release 包不认这个变量**，要拿它做启动自检就再带一个 `HOME=/tmp/某个临时目录`，把整个用户目录挪走（实测有效）。
7. **v0.96 的新东西在图鉴册**：打开图鉴册 → 第 1 页"图鉴"，往下翻页，**10 条鱼后面接着排 38 种矿石**；挖到过的会亮（真图标 + 名字 + `x数量`），没挖到过的是空框 + "？？？"；底栏多了一行 **"矿石 x/38 种"**。想立刻看满的：`CATFISH_BOOK=0 CATFISH_ORES=38 CATFISH_VIEW=1 CATFISH_SAVE=/tmp/临时目录` 跑一次（调试构建才生效）。

## 版本表

| 版本 | 标签 | 做了什么 | 验证 |
|---|---|---|---|
| **v0.96** | `v0.96-qwen` | 矿石终于进图鉴了：`stats["ore_counts"]`（矿石 → 挖到几块；**不升存档版本、老存档自动补空键**）；`core/mine.gd` 在"石头碎了、矿石进背包"那一处后面 `_record_ore()` 记一笔（靠"一格只碎一次"天然幂等，装不下的矿石不算见过），新增 `ore_dex()/ore_dug_count()/dex_found()`；图鉴第 1 页改成**鱼后面接 38 种矿石**共用翻页，没见过的画空框 + "？？？"，底栏加"矿石 x/38 种"，新文字全走 `dyn_text` **不重生成素材**；翻页算术抽成 `Book.dex_pages_for(total, per)` 好测；调试 `CATFISH_BOOK` 顺手播 6 种矿石、新增 `CATFISH_ORES=N`；新增 19 项测试（**978 → 997**） | 本机 macOS：`ALL TESTS PASS`（**997 项 0 失败**）+ `SIM PASS`、`--import` 0 报错、`./打包游戏.command` 自检通过、`CatFishing_v0.96_Qwen.app`（163 MB 通用二进制、`codesign -v` 退出码 0、版本号 0.96）、调试包点亮 6 种 / 38 种各截一张（0 报错 0 缺字；底栏新增 2376 个文字像素、卡片区 5580 像素变化、整屏 0.48% 不同）；真存档只多出空键 `ore_counts`（**逐字段对比过，没有丢任何进度**）。**未验**：图鉴页排版与好不好看的人工目检、38 种逐页翻的手感、真挖一遍的收集节奏、透明/穿透/拖动、Intel 机器 |
| v0.95 | `v0.95-qwen` | 井底的天也分井了：`mine.shaft_themes` 再加 `bg`（背景）/`fog`（黑暗）/`lamp`（灯光）三个调色板键；`mine_view` 加三个静态纯函数 `shaft_backdrop/shaft_darkness/shaft_lamp`，黑暗只做"黑得偏色"（主题色压到 16% 亮度再混，透明度不动）；1 号井三个位就是原色 + `mix=0`，用**精确等式**断言零变化；测试硬卡背景亮度 ≤0.25、黑暗亮度 ≤0.06；新增 17 项测试（**961 → 978**） | 本机 macOS：`ALL TESTS PASS`（**978 项 0 失败**）+ `SIM PASS`、`--import` 0 报错、`./打包游戏.command` 自检通过、`CatFishing_v0.95_Qwen.app` 200 帧 0 报错、调试包 `CATFISH_SHAFT=5` 真机 0 报错、五口井暗区取色证明色相分开而亮度差 ≤3.3%、真存档 md5 全程不变。**未验**：配色好不好看的人工目检、深色井里反光点对比度、真人观感节奏、透明/穿透/拖动、Intel 机器 |
| v0.94 | `v0.94-qwen` | 五口井各有各的长相：`data/balance.json` 新增 `mine.shaft_themes`（名字 + 五个部位的**调色板键** + 染色强度 `mix`）与全局兜底 `mine.shaft_theme_mix`；`core/mine.gd` 加 `shaft_theme/shaft_name/shaft_color/shaft_mix`（不认识的井退回 1 号井）；`mine_view` 给石头·岩壁·崖壁·地板·崖边描边按井染色，票务工位与下井提示带上井名；染色是**亮度守恒的色相偏移**，1 号井 `mix=0` 保证老玩家零变化；调试新增 `CATFISH_SAVE`（存档挪走）/`CATFISH_SHAFT`（直接开进某口井）/`CATFISH_SEED` 钉死矿图种子；新增 18 项测试（**943 → 961**） | 本机 macOS：`ALL TESTS PASS`（**961 项 0 失败**）+ `SIM PASS`、`--import` 0 报错、`./打包游戏.command` 自检通过、`CatFishing_v0.94_Qwen.app` 200 帧启动 0 报错、五口井各截一张图 0 报错并做了像素比对（色相分开、亮区亮度差 ≤1.3%）、真存档 md5 前后一致。**未验**：配色好不好看的人工目检、井名文字的排版是否溢出、真人手感、透明/穿透/拖动、Intel 机器 |\n| v0.93 | `v0.93-qwen` | 3–5 号井从"永远锁着"变成能开工：`data/balance.json` 新增 `mine.open_shafts`（先开上一口井 + 上一口井挖到 20/40/65 层 + 材料 + 雇工 2/3/4 人）；`core/mine.gd` 加 `open_need/open_prev/deepest_floor/open_missing/open_ready/open_shaft`，`shaft_status` 新增 `wait`/`build` 两态；票务工位加「开工」面板；`ensure()` 给 1–5 号井补齐字段；新增 31 项测试（**912 → 943**） | 本机 macOS：`ALL TESTS PASS`（943 项 0 失败）+ `SIM PASS`、`./打包游戏.command` 自检通过、`CatFishing_v0.93_Qwen.app` 200 帧启动 0 报错、调试包自截图 1 张 0 警告、存档 md5 前后一致。**未验**：开工面板的人工目检、真人手感、透明/穿透/拖动、Intel 机器 |
| v0.92 | `v0.92-qwen` | 修好双击 `运行游戏.command` 打不开（老脚本 `open` 一个不存在的 `build/CatFishing.app`）；新增 `打包游戏.command`；`project.godot` 版本号从 0.89 补到 0.92 并回写导出预设 | 本机 macOS：打包自检通过、`运行游戏.command` 真开真退（存档 md5 未变）、调试包自截图 2 张 0 警告 0 报错、`ALL TESTS PASS`（912 项）+ `SIM PASS`。**未验**：真人双击体验、透明/穿透/拖动肉眼确认、Intel 机器 |
| v0.91 | `v0.91-qwen` | 补 v0.88／v0.89 欠的测试（811 → **912 项**）；修 10 条界面提示不在标签图集里（玩家原本看不到字）；调试传送时 `adapter` 未创建导致 `SCRIPT ERROR`；新增 `CATFISH_MAILPAGES`；README 补齐 40 个调试变量 | 本机 macOS：`ALL TESTS PASS` / `SIM PASS`，真机启动 6 次 0 警告 0 报错。**未验**：截图内容人工目检、`.app` 启动（v0.92 已补做） |

## 本机（macOS，Godot 4.7.2）实际跑过的命令

| 命令 | 结果 |
|---|---|
| `Godot --headless --path . --import` | 退出码 0，0 条 `SCRIPT ERROR` |
| `Godot --headless --path . --script res://tests/run_tests.gd` | `ALL TESTS PASS`，**997 项、0 失败**，无 `SCRIPT ERROR`、无 `WARNING`（v0.95 时是 978 项） |
| `Godot --headless --path . --script res://tests/sim_long_run.gd` | `SIM PASS`，0 条 `SCRIPT ERROR` |
| `./打包游戏.command` | `✓ 自检通过`，退出码 0，产物 `build/CatFishing_v0.93_Qwen.app`（163 MB） |
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
- **v0.96 的图鉴页没有人工目检**：机器只证明了"矿石卡片确实按 `ore_counts` 在画、而且只画在图鉴册那块面板里"（调试包两张图：底栏新增 2376 个文字像素、卡片区 5580 像素变化、整屏 0.48% 不同）。**名字有没有溢出卡片、38 种翻起来烦不烦、空框 + "？？？"好不好看，都没有人看过**。
- **v0.95 的背景／黑暗／灯光配色同样没有人工目检**：暗区取色只能说明"五口井色相分开了、整体亮度差 ≤3.3%、背景亮度 ≤0.25"，看不出好不好看，也不能说明深色井里反光点的对比度够不够。
- **整屏逐像素 A/B 在矿洞里不可用**：小猫每帧随机走动会让整屏 36.7% 的像素变化（实测），这种差异里混着走动和染色，不能当"画面没变"的证据。v0.95 的 1 号井零变化改由颜色函数的精确等式保证。
- **v0.94 五口井配色的"好不好看"没有人工目检**：本代理没有视觉能力，像素比对只能证明"五口井色相确实分开、亮区亮度差 ≤1.3%、1 号井逐像素不变"，不能证明好看；井名文字的排版是否溢出同样没看过。
- **v0.93「开工」面板的排版人工目检**：截图文件在本机 `/tmp/cf93_open_150.png`（编辑器）和 `/tmp/cf93app_open_150.png`（调试包）里，但本次没有肉眼看过；自动化的像素级排版校验在这台机器上不可靠（动态壁纸 + 场景动画会把整屏差异淹掉），所以只报了"有没有报错"，没报"排版对不对"。
- Intel Mac 上的运行；从 GitHub 下载后 Gatekeeper 的第一次拦截。
- 与 `codex-v0.90`／`codex-v0.91` 的合并。
