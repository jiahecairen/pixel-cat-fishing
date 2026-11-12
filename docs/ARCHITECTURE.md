# 架构

## 分层

```
presentation/   画面、输入、音效播放        可以用节点、Input、窗口
      │  只调用 Game 的方法，只读 GameState
      ▼
core/           规则与状态（纯逻辑）        不许碰节点/窗口/Input/DisplayServer
      │
io/             配置、存档、日志            只做文件读写
platform/       窗口、穿透、拖动、通知      每个平台一个适配器
data/           鱼种、数值、小猫选项        JSON
```

移植新平台 = 在 `platform/` 加一个适配器并在 `platform.gd` 登记；`core/`、`io/`、`data/`、素材都不用动。没有悬浮窗能力的平台（手机、主机）自动只用全画面视图。

## 模块

| 文件 | 职责 | 原档案里的对应名字 |
|---|---|---|
| `core/game.gd` | 总控：每帧 `tick()` 推进所有系统，返回事件列表 | GameController |
| `core/game_state.gd` | 唯一状态：金币、鱼篓、木箱、番茄钟、旅程、升级、形象、设置、统计 | GameState |
| `core/fishing_system.gd` | 钓鱼状态机，可存取断点 | FishingSystem |
| `core/pomodoro.gd` | 番茄钟阶段 | （新增） |
| `core/journey.gd` | 活动循环：钓鱼 → 满篓闲置 → 航行 → 走路 → 摆摊 → 返航，以及自由走动 | （新增） |
| `core/economy.gd` | 入篓、逐条出售、偷吃、木箱结算，全部幂等 | （ECO-001） |
| `core/upgrades.gd` | 金币升级 | （新增） |
| `core/clock.gd` | 时间源，测试时可替换 | — |
| `io/config_loader.gd` | 读取并校验 `data/*.json` | ConfigLoader |
| `io/save_service.gd` | 原子存档与 .bak 回退 | SaveService |
| `io/event_log.gd` | 事件日志 | EventLog |
| `platform/platform_adapter.gd` | 平台接口与默认实现（全屏应用） | PlatformAdapter |
| `platform/desktop_adapter.gd` | 桌面实现：悬浮窗、穿透、原生拖动、通知 | DesktopWindow |
| `presentation/main.gd` | 入口：视图模式、镜头、输入、HUD、事件反馈 | — |
| `presentation/world.gd` | 画横版世界：海、船、码头、小镇、摊位、顾客、居民 | CatPresenter |
| `presentation/menu.gd` / `wardrobe.gd` | 菜单面板 / 捏猫面板 | — |

## 时间与推进

- 所有系统保存的是"截止时刻"（墙上时间毫秒），不是倒计时。`tick()` 比较当前时刻与截止时刻。
- 每次 `tick()` 每个系统最多前进一步。电脑睡眠几小时醒来，不会一口气补钓、补卖或补吃。
- 番茄休息期间整个活动循环暂停：记下暂停时刻，恢复时把所有截止时刻顺延。

## 坐标

- **世界坐标**：一个连续的横版世界，x 从左（海）到右（小镇）。常量在 `world.gd` 顶部。
- **视图坐标**：窗口里的美术像素。`视图 = 世界 − 镜头`。整个画布按整数倍放大。
- **界面坐标**：HUD 和面板，固定在视图左上角附近。
- 迷你视图固定 128×96，镜头锁定小猫；全画面视图随窗口大小变化，镜头有静止区并被世界边界夹住。

## 存档

`GameState.to_dict()` → JSON → `user://save.json`。写入顺序：写 `.tmp` → 读回校验 → 旧档改名 `.bak` → `.tmp` 改名为正式档。读档时主档坏了用 `.bak`。字段缺失时保留默认值，所以旧存档能直接升级。

## 事件

`Game.tick()` 返回的事件（`catch`、`basket_full`、`ate`、`docked`、`open`、`sale`、`sold_out`、`boarded`、`back`、`focus_done`、`break_done`）同时驱动三件事：画面反馈和音效、系统通知、事件日志。
