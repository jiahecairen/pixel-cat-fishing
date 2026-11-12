# CatFishing — 桌面小猫钓鱼 × 番茄钟

macOS 桌面上的像素小猫，在透明悬浮窗里坐船钓鱼。开始一个番茄钟，小猫就陪你专注 25 分钟，完成后把渔获加成结算成金币。

## 运行

用 Godot 4.7 打开本文件夹（`project.godot`），按 F5。或在终端：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/rain/DevGame/CC_CatFashing
```

操作：

- 拖动小猫/小船可以移动窗口，位置会被记住
- 面板按钮从左到右：开始番茄（专注中变为"放弃"，休息中变为"跳过休息"）、卖鱼、退出
- 面板和猫船以外的透明区域不拦截鼠标

## 玩法规则

| 模式 | 小猫在做什么 | 鱼去哪里 |
|---|---|---|
| 专注 25 分钟 | 每 20–60 秒钓一条 | 进"番茄渔获"，不限量 |
| 完成番茄 | — | 渔获按 1.5 倍结算，另加 10 金币；每第 4 个番茄再加 50 |
| 休息 5 / 15 分钟 | 打盹 | — |
| 自由挂机 | 钓鱼速度减半 | 进鱼篓（10 格），满了就停，需手动卖 |
| 放弃专注 | — | 已钓的鱼按原价结算，不计入番茄数 |

数值全部在 `data/balance.json` 和 `data/fish.json`，改完重启即可。

## 目录结构

```
core/          纯逻辑，不依赖窗口和节点：状态、钓鱼状态机、番茄钟、经济
io/            配置加载与校验、原子存档
platform/      平台适配：窗口、穿透、拖动、通知。移植新平台只在这里加一个类
presentation/  画面与输入
data/          鱼种与数值配置
assets/sprites 生成出的像素素材
tools/art/     素材生成脚本与调色板
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
| 核心逻辑单元测试（51 项） | 通过（Godot 4.7.2 Linux 无界面） |
| 画面渲染、钓鱼动画、番茄结算流程 | 通过（Linux 虚拟显示下截图目检） |
| macOS 透明窗口、置顶 | **未验证** |
| macOS 局部鼠标穿透 | **未验证** |
| macOS 原生拖动与 30/60 帧切换 | **未验证** |
| Retina 屏下的窗口大小 | **未验证** |
| macOS 系统通知 | **未验证** |
| 多显示器、长时间运行 | **未验证** |

## 移植说明

- **Windows**：`platform/desktop_adapter.gd` 已走通用 Godot API，预计只需实测和通知部分的小改。
- **iOS / Android**：自动落到基类适配器，按全屏应用显示（带背景色）。需要补触屏布局和通知。
- **Switch**：需任天堂开发者资质与第三方 Godot 移植方案。
- **3DS**：Godot 4 无法运行，计划单独做一个精简版。可复用的是 `assets/`、`data/` 和规则设计；画布已控制在 128×96。
