# Qwen 版本说明（本分支）

- **GitHub 分支**：`Qwen-v0.91`（远端 `origin/Qwen-v0.91`，本地工作树叫 `qwen-v0.91`，macOS 文件系统不分大小写所以本地只能小写）
- **标签**：`v0.91-qwen`（一个版本一个提交）
- **开发模型**：DeepSeek Harness + Qwen3.8（Qwen 侧的独立开发线）
- **基线**：从标签 `v0.89` 分出。
- **注意：这是一条和 Codex 并行的线。** 仓库里同时有 `codex-v0.87` … `codex-v0.91`（其中 `codex-v0.91` = "controllable sea route to mine island"，标签 `v0.91-codex`）已经推到 GitHub。**两边的 0.91 是两个不同的东西**，靠后缀 `-qwen` / `-codex` 区分；本分支没有包含 Codex 那条线的 v0.90（参考风格岛屿像素图）和 v0.91（可控航线），也还没和它们合并。

## 这一版做了什么

1. **补上 v0.88 / v0.89 欠的自动测试**（那两版当时一个测试都没加）：新增 `test_v088_ticket_and_locker`、`test_v089_scripts_and_art`、`test_labels`，检查数 **811 → 912**。
2. **修好真机跑出来的两个问题**：
   - 10 条界面提示不在标签图集里（运行时只报警告、玩家看不到字）：矿山岛三间屋（`空格键看工具`／`空格键让厨师做菜`／`空格键住宿休息`）、雾灯岛五处（`空格键看修理厂`／`空格键进酒馆`／`空格键进典当行`／`空格键扔东西（垃圾箱）`／`空格键进邮局寄快递`）、物品栏 `鱼篓是空的`、图鉴册 `当天没有小时记录`。已加进 `tools/art/generate.py` 的 `LABELS` 并重新生成图集。
   - 调试变量在 `_ready` 里传送时 `adapter` 还没创建，报 `SCRIPT ERROR: Nonexistent function 'is_overlay' in base 'Nil'`；`_update_polygon()` 加了空值守卫。`label("")` 也不再误报警告。
3. **调试与文档**：新增 `CATFISH_MAILPAGES`；README 补齐 40 个一直没写进文档的调试变量；`docs/ACCEPTANCE_TESTS.md` 新增 C178／C179 并重写 C176／C177；`docs/DEV_LOG.md` 追加 v0.91 记录。

## 在这台 Mac 上实际跑过什么

| 命令 | 结果 |
|---|---|
| `Godot --headless --path . --import` | 通过，无报错 |
| `Godot --headless --path . --script res://tests/run_tests.gd` | `ALL TESTS PASS`，912 项、0 失败，无 `SCRIPT ERROR` |
| `Godot --headless --path . --script res://tests/sim_long_run.gd` | `SIM PASS` |
| `python3 tools/art/generate.py` | `OK: 214 张素材，全部只用调色板 24 色`；除 `assets/sprites/labels.png`（149×4770 → 149×4850）外，其余 225 张与之前**逐像素一致** |
| 真机启动 6 次（`CATFISH_SHOT`） | 6 张截图全部生成，**0 条标签警告、0 条 `SCRIPT ERROR`** |

## 没验证的部分（不许当成通过）

- 截图内容的**人工目检**（本次由无视觉能力的代理生成，只做了像素统计和图集校验，没有肉眼看过画面）。
- 真实窗口透明、点击穿透、窗口拖动、通知、音效听感。
- `.app` 导出包能否双击启动（这一版没有导出）。
- 与 `codex-v0.90` 那条线的合并（`assets/sprites/labels.png` 预计冲突，需要在合并后的树上重跑 `tools/art/generate.py`）。
