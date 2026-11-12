# CatFishing — 桌面小猫钓鱼 × 番茄钟

macOS 桌面上的像素小猫，在透明悬浮窗里坐船钓鱼。开始一个番茄钟，小猫就陪你专注 25 分钟，完成后把渔获加成结算成金币。

## 运行

**直接玩**：双击 `build/CatFishing.app`（未经 Apple 公证；如果系统拦截，在"系统设置 → 隐私与安全性"里点"仍要打开"，或右键 → 打开）。

**开发调试**：用 Godot 4.7 打开本文件夹（`project.godot`），按 F5。或在终端：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/rain/DevGame/CC_CatFashing
```

操作：

- 拖动小猫/小船可以移动窗口，位置会被记住
- 面板第一排按钮：开始番茄（专注中变为"放弃"，休息中变为"跳过休息"）、卖鱼、菜单；第二排的 × 是退出
- 面板、猫船和打开的菜单以外的透明区域不拦截鼠标

## 玩法规则

| 模式 | 小猫在做什么 | 鱼去哪里 |
|---|---|---|
| 专注 25 分钟 | 每 20–60 秒钓一条 | 进"番茄渔获"（面板上显示木箱图标），不限量 |
| 完成番茄 | — | 渔获按 1.5 倍结算，另加 10 金币；每第 4 个番茄再加 50 |
| 休息 5 / 15 分钟 | 打盹 | — |
| 自由挂机 | 钓鱼速度减半 | 进鱼篓（面板上显示鱼篓图标，10 格起），满了就停，需手动卖 |
| 放弃专注 | — | 已钓的鱼按原价结算，不计入番茄数 |

## 菜单

| 标签 | 内容 |
|---|---|
| 商店 | 用金币升级，每项 5 级。鱼竿：自由挂机更快（满级时与专注同速，不会快于 20–60 秒）；鱼饵：稀有鱼更容易上钩；鱼篓：每级容量 +2 |
| 图鉴 | 每种鱼钓到的数量和单价，没钓到过的显示为剪影 |
| 统计 | 今日番茄数、累计番茄数、近七日柱状图 |
| 设置 | 专注 / 短休 / 长休时长（分钟）；窗口大小（2–5 倍）和音效音量（0 静音–3）点加号循环切换。时长改动从下一个阶段开始生效 |

数值全部在 `data/balance.json` 和 `data/fish.json`，改完重启即可。

## 音效与动画

音效由 `tools/audio/generate.py` 用方波/三角波/噪声合成（8-bit 风格），共 11 个：抛竿、咬钩、收竿、上鱼、稀有鱼、金币、购买、失败、番茄完成、休息结束、按钮。

动画反馈：浮漂落水和咬钩时有水花；钓到鱼小猫会眯眼跳一下；钓到稀有鱼有闪光；完成番茄时满屏落星。

## 导出

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" build/CatFishing.zip
```

需要先在 Godot 编辑器里安装导出模板（编辑器 → 管理导出模板）。导出预设在 `export_presets.cfg`：通用二进制（Intel + Apple Silicon）、临时签名、不公证。

## 目录结构

```
core/          纯逻辑，不依赖窗口和节点：状态、钓鱼状态机、番茄钟、经济
io/            配置加载与校验、原子存档
platform/      平台适配：窗口、穿透、拖动、通知。移植新平台只在这里加一个类
presentation/  画面与输入
data/          鱼种与数值配置
assets/sprites 生成出的像素素材
assets/sfx     生成出的音效
tools/art/     素材生成脚本与调色板
tools/audio/   音效生成脚本
build/         导出的 macOS 应用（不进版本库）
tests/         无界面单元测试
```

## 测试

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_tests.gd
```

看到 `ALL TESTS PASS` 且退出码为 0 才算通过。

调试时可以让时间加速（仅调试版生效）：

```bash
CATFISH_SPEED=60 /Applications/Godot.app/Contents/MacOS/Godot --path .    # 25 分钟变 25 秒
```

## 验证状态

| 项目 | 状态 |
|---|---|
| 核心逻辑单元测试（67 项） | 通过（Godot 4.7.2 Linux 无界面） |
| 画面渲染、钓鱼动画、番茄结算、菜单四个标签页、水花/闪光/小猫反应 | 通过（Linux 虚拟显示下截图目检） |
| 导出 macOS 应用包 | 已生成（Linux 下导出，通用二进制，临时签名） |
| 导出的 `.app` 能否在 macOS 上正常启动 | **未验证** |
| 音效听感与音量 | **未验证**（沙盒没有声音输出，只确认了文件生成和播放代码无报错） |
| macOS 透明窗口、置顶、窗口大小 | 通过（用户 2026-11-12 实测） |
| macOS 局部鼠标穿透 | 通过（用户 2026-11-12 实测） |
| macOS 原生拖动、位置记忆 | 通过（用户 2026-11-12 实测） |
| macOS 系统通知（番茄完成、鱼篓满） | 通过（用户 2026-11-12 实测） |
| macOS 上菜单的点击、打开菜单后的穿透区域、调整窗口大小 | **未验证** |
| 拖动时 30→60→30 帧切换是否真的生效 | **未验证**（手感顺滑，但没有量过帧率） |
| 多显示器、长时间运行 | **未验证** |

## 第三方素材

界面中文标签用 [Fusion Pixel Font](https://github.com/TakWolf/fusion-pixel-font) 10px 预渲染成图集，字体以 SIL OFL 1.1 许可发布，许可文本在 `tools/art/fonts/OFL.txt`。新增文字时把它加到 `tools/art/generate.py` 的 `LABELS` 列表后重新生成。

## 移植说明

- **Windows**：`platform/desktop_adapter.gd` 已走通用 Godot API，预计只需实测和通知部分的小改。
- **iOS / Android**：自动落到基类适配器，按全屏应用显示（带背景色）。需要补触屏布局和通知。
- **Switch**：需任天堂开发者资质与第三方 Godot 移植方案。
- **3DS**：Godot 4 无法运行，计划单独做一个精简版。可复用的是 `assets/`、`data/` 和规则设计；画布已控制在 128×96。
