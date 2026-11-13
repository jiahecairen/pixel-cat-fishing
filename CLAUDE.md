# CatFishing 项目规则

桌面小猫钓鱼 × 番茄钟（Godot 4.7，GDScript，先做 macOS）。接手时按顺序读：本文件 → `docs/REQUIREMENTS.md`（需求与完成情况）→ `docs/DECISION_REGISTER.md`（已定的决定）→ `docs/ARCHITECTURE.md` → `docs/ACCEPTANCE_TESTS.md`（哪些验证过、哪些没有）。`docs/DEV_LOG.md` 是历史，`README.md` 是给玩家和日常开发看的说明。

## 必须遵守

- **先核对再动手**：以仓库里的实际文件和 `git status` 为准，不要把文档或记忆当成实时状态。工作区有未提交改动时先弄清来源，不要覆盖。
- **用户定过的事不擅自改**：`docs/DECISION_REGISTER.md` 里的决定（咬钩 20–60 秒、木箱结算、小猫不自己出发、形象免费、24 色调色板等）要改必须先问用户。
- **分层不能破**：`core/` 不得引用节点、窗口、`DisplayServer`、`Input`；平台相关的东西只能进 `platform/`；数值进 `data/*.json`，不要写死在代码里。
- **计时用时间戳**：一律经 `core/clock.gd`，禁止用帧数或 `_process` 的累计 delta 做业务计时。
- **经济必须幂等**：鱼获、出售、结算都带 id，重复提交不能重复生效；`GameState` 是唯一的状态来源。
- **素材只能由脚本生成**：改图改 `tools/art/generate.py`，改音效改 `tools/audio/generate.py`；只用 `tools/art/palette.py` 的颜色；新增界面文字要加进 `LABELS` 并重新生成。
- **不做的事**：不 `git reset --hard`、不 `git clean -fd`、不 `git add` 之外的批量删除；不删用户存档。

## 每次改动后

1. 重新生成素材（如果动了生成脚本）并导入：`python3 tools/art/generate.py`，`godot --headless --path . --import`
2. 跑测试，两个都要看到通过标记且退出码为 0：
   - `godot --headless --path . --script res://tests/run_tests.gd` → `ALL TESTS PASS`
   - `godot --headless --path . --script res://tests/sim_long_run.gd` → `SIM PASS`
3. 画面有改动就截图目检（`CATFISH_SHOT`，见 README 的调试变量）。
4. 更新 `docs/ACCEPTANCE_TESTS.md`：没在真实 macOS 上验证过的一律写"未运行"，不能写"通过"。
5. 在 `docs/DEV_LOG.md` 末尾追加一条记录；需求或决定有变化时同步 `REQUIREMENTS.md` / `DECISION_REGISTER.md`。
6. 提交并打版本标签（`v0.N`，每个版本一个提交）；按用户要求推送到 GitHub `jiahecairen/pixel-cat-fishing`（本机没有 GitHub 登录信息，由云端会话推送；标签推送在会话里会被拦截，推不上去）。向用户汇报时说明：实际跑了哪些命令、结果如何、哪些没验证。

## 如实汇报

- 沙盒是 Linux，跑不了 macOS 版 Godot。透明窗口、穿透、拖动、通知、键盘手感、音效听感、`.app` 能否启动，都只有用户在 Mac 上能验证。
- 退出码为 0 不等于通过：要同时看到通过标记，且输出里没有 `SCRIPT ERROR`。
