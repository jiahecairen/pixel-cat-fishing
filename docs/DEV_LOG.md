# 开发日志

每完成一个阶段追加一条。测试结果指 Linux 沙盒里用 Godot 4.7.2 无界面/虚拟显示运行的结果；Mac 实机情况单独写。

### 2026-11-12 第一阶段 — 骨架与最小可玩版本（`90c4042`）
- 内容：分层工程、24 色素材、钓鱼状态机、番茄钟、经济、原子存档、桌面悬浮窗。
- 测试：`run_tests.gd` 51 项通过。
- Mac 实机：用户确认透明、置顶、窗口大小、穿透、拖动、位置记忆、系统通知均正常。

### 2026-11-12 第二阶段 — 菜单与升级（`bb711e8`）
- 内容：商店/图鉴/统计/设置四个标签页；鱼竿、鱼饵、鱼篓升级；时长可调；中文像素标签；专注时显示木箱图标。
- 测试：67 项通过；四个标签页截图目检。
- Mac 实机：未反馈。

### 2026-11-12 第三阶段 — 音效、动画、导出（`0a6ad6c`）
- 内容：11 个合成音效、音量设置、水花/闪光/小猫反应、应用图标、macOS 导出预设。
- 测试：67 项通过；首次导出 `.app`（通用二进制，临时签名）。
- Mac 实机：未反馈。音效没法在沙盒里听。

### 2026-11-12 第四阶段 — 自定义形象（`581cec2`）
- 内容：猫拆成毛色/花纹/固定/帽子图层，运行时上色；6×4×4 种组合；首次启动捏猫。
- 测试：86 项通过；全部组合出图目检。
- Mac 实机：未反馈。

### 2026-11-12 第五阶段 — 横版小镇与两种视图（`ccc0ca2`）
- 内容：连续横版世界、航行、摆摊、顾客、满篓气泡、船上睡觉/掌机/偷吃；全画面与迷你两种视图；全画面方向键走动与镜头静止区。
- 经过：第一次运行中途中断，留下了按"专注时全自动循环、取消木箱"做的未提交半成品。用户最终选择保留木箱，于是在半成品基础上改回木箱结算并补上自由走动。期间素材脚本被两次叠加改动，已清理。
- 测试：121 项通过；两种视图各阶段截图目检。
- Mac 实机：未反馈。窗口逻辑重写过，第一阶段的实测结论需要重测。

### 2026-11-12 第六阶段 — 可互动的小镇与原档案缺项
- 内容：走到门口按空格进渔具店（商店）、裁缝铺（捏猫）、小猫的家（图鉴）；街上有三位散步的居民可对话；门楣招牌。补齐原档案缺项：事件日志、钓鱼断点、最小化降功耗、存档失败退避重试、8 小时逻辑模拟。建立文档集与 `CLAUDE.md`。
- 测试：`run_tests.gd` 131 项通过；`sim_long_run.gd` 通过（8 小时、144000 步、存读档 15 次、金币逐步对账）；进门、对话、招牌截图目检。
- Mac 实机：未反馈。
- 未解决：见 `ACCEPTANCE_TESTS.md` 里所有"未运行"项；`REQUIREMENTS.md` 里状态不是"已实现"的项。

### 2026-11-13 第六阶段实机反馈与修复
- Mac 实机（用户）：`.app` 可双击启动；两种视图可切换；方向键、空格可用；音效可接受。8 小时验收先忽略。
- 用户报告的问题与处理：
  - 朝左时小猫瞬移、鱼篓不在身上、返航时小猫跑到船的另一头：同一个原因。水平翻转时把贴图位置多加了一个贴图宽度，而 Godot 的负宽度只翻转不移位，导致翻转后整只猫右移 32 像素。已改，并调整了朝左时鱼篓的位置。
  - 居民被摊位挡住：居民和顾客改为画在摊位前面。
  - 小猫离开摊位时脚从柜台和地面之间露出来：只有摆摊时小猫画在柜台后面，走动时画在摊位前面。
  - 不操作几秒后自动走回摊位：取消，接管后小猫不再自己走开。
- 测试：131 项通过，模拟通过；朝左走、返航、摊位前走过的截图目检。这个翻转问题在 Linux 截图里同样存在，之前没发现是因为只截了朝右的画面。
- Mac 实机复测：未反馈。

### 2026-11-13 顾客相关的三个问题
- 用户报告：顾客走到一半时按方向键，顾客凭空消失；柜台上的鱼盖在路过的居民身上；每次来买鱼的都是兔子。
- 处理：顾客走到一半小猫离开摊位（被接管或进入休息）时，顾客空手掉头走开；绘制顺序改为 柜台 → 柜台上的鱼 → 居民与顾客；顾客每单换一位且不连续重复（原先按"本次开张的第几单"取样子，每次重新开张都从同一位开始），离开时拎的是实际买到的那种鱼。
- 测试：131 项通过，模拟通过；连续四单与中途接管的截图目检。
- Mac 实机复测：未反馈。

### 2026-11-13 第七阶段 — 室内场景
- 内容：渔具店、裁缝铺、小猫的家各有一间室内（门、窗、货架、柜台、镜子、书架、日历、床），熊和兔子当店主，进门时打招呼。屋内用方向键走动，走到互动点按空格打开对应面板，门口按空格出门。屋内状态只在表现层，不进存档。
- 测试：131 项通过，模拟通过；三间屋子、两个互动点打开面板、出门的截图目检。
- Mac 实机：未反馈。

### 2026-11-13 划桨、居民朝向、直立行走
- 用户反馈：划船看不出方向；除兔子外的居民像倒着走；主角应该直立行走。
- 处理：
  - 划桨改成完整循环：桨叶入水（溅水花）→ 在水里从船头推向船尾（留下水纹）→ 抬出水面 → 在空中收回船头。
  - 散步居民的翻转条件写反了（贴图面朝左，却在朝左走时翻转），已改正。
  - 行走姿势重画为两条腿直立行走，手脚交替摆动；头的位置不变，帽子图层不用改。鱼篓背在背上的位置随之调整。
- 测试：131 项通过，模拟通过；划桨 8 帧连拍、两个方向行走的截图目检。居民朝向只核对了代码逻辑，截图里太小看不清。
- Mac 实机：未反馈。

### 2026-11-13 面板去掉与店铺重复的按钮
- 用户要求：镇上有店的功能，默认界面取消对应按钮。（同时提出的宝箱、物品栏两项，约定等这一项测试通过并经用户同意后再做。）
- 内容：去掉小猫头像按钮；菜单按钮改为齿轮，只打开设置；菜单面板一次只显示一页，不能再横向切换标签。
- 影响：迷你悬浮窗里没有键盘操作，进不了屋，所以升级、看图鉴和统计、换形象都要先切到全画面。
- 测试：131 项通过，模拟通过；面板、设置页、渔具店柜台打开商店页的截图目检。
- Mac 实机：未反馈。

### 2026-11-13 修复：切换视图按钮点不了
- 用户反馈：上一次改完后，面板上的切换视图按钮无法点击。
- 原因：去掉小猫头像按钮时，我把夹在"菜单"和"小猫头像"两段之间的"切换视图"点击处理一起删掉了。按钮还在画，但点了没反应。上一次只截图看了面板的样子，没有实际点过每个按钮。
- 处理：恢复点击处理；新增调试开关 `CATFISH_CLICK=帧号:x,y` 模拟点击，并用它把面板上五个按钮逐个点了一遍。
- 测试：131 项通过。模拟点击结果：切换视图（迷你→全画面、全画面→迷你，窗口尺寸都变了）、开始番茄、去小镇、齿轮、退出，全部生效。
- Mac 实机：未反馈。

### 2026-11-13 划桨平滑、退出确认、面板关闭按钮
- 用户反馈：船桨不自然、抬太高、跳帧；商店页面不要显示退出游戏按钮；退出要二次确认。
- 处理：
  - 划桨：桨叶改为沿扁椭圆连续转动（周期 1.7 秒），水下最深 3 像素、空中最高 4 像素，不再有"水里→空中"的位置突变。
  - 任何面板（商店、图鉴、统计、设置、换形象）打开时不显示退出按钮；菜单面板右上角加了自己的关闭按钮。
  - 点退出按钮先弹"确定要退出吗"，点"退出"才退出，点"取消"、点别处或按 Esc 都是取消。系统标题栏的关闭按钮和 Cmd+Q 仍然直接退出（会先存档）。
- 测试：131 项通过；模拟点击验证了：退出按钮弹出确认框、面板打开时退出按钮隐藏且原位置点击无效、面板关闭按钮可用；划桨 16 帧连拍目检。确认框里的"退出"按钮没有实际点过（调试开关一次只能模拟一次点击）。
- Mac 实机：未反馈。

### 2026-11-13 修复：休息时走动显示成睡觉
- 用户反馈：向左或向右移动时显示的是睡觉一样的画面。
- 原因：番茄休息期间，镇上的小猫一律画成打盹（眯眼 + zzz），没有排除"玩家正在用方向键带着它走"的情况。用预置的休息中存档复现了。
- 处理：休息时只有不受玩家控制的小猫才打盹；玩家带着走时照常画走路。
- 复现时顺带发现并修复：读档时如果小猫正处于自由走动状态，按下方向键的第一步会瞬移到码头（亚像素位置没有从存档初始化）。
- 测试：131 项通过；休息中向左、向右、不动、进屋的截图目检。
- Mac 实机：未反馈。

### 2026-11-13 钓到宝箱
- 内容：每一竿 4% 概率钓到宝箱而不是鱼。宝箱提上来后当场打开，按小/中/大三档（权重 70/25/5）给金币，直接入账，不占鱼篓、不进木箱、不算进钓鱼数。图鉴页底部显示累计宝箱数。咬钩后重启，钩上的宝箱能从断点恢复。
- 说明：用户没有回复"先只开金币还是先做物品栏"，按只开金币做；开箱内容集中在 `Game._roll_chest()`，以后加物品只改这里。支线任务未做。
- 测试：143 项通过（新增 12 项宝箱用例）；8 小时模拟通过，其中钓到 18 个宝箱且金币对账无误；宝箱提上来、打开、金币入账的 4 帧截图目检。
- Mac 实机：未反馈。

- 2026-11-13 补记：宝箱的三项实机测试用户确认通过。

### 2026-11-13 物品栏
- 用户选择：物品只来自宝箱；有的能使用；两种视图都能开；不限容量、同种叠加。
- 内容：`core/inventory.gd` 与 `Game.use_item`；六种物品（四种可用）；宝箱 60% 概率附带一件物品；幸运鱼饵（10 分钟稀有度 +0.6、宝箱概率翻倍，可叠加时间，休息不计时）、招财铃（5 单翻倍）、漂流瓶（10–60 金币）、藏宝图碎片（4 片换 400–600 金币）。物品栏面板 `presentation/bag.gd`：全画面占大部分画面（11×3 格），迷你窗缩小版（4×2 格）；面板加背包按钮，Tab / I 开关，方向键选、空格使用。
- 测试：166 项通过（新增 23 项）；8 小时模拟加入随机使用物品，金币对账通过；模拟点击验证了背包按钮打开面板、点格子选中、点"使用"用掉漂流瓶并入账；全画面、迷你窗、空物品栏、宝箱开出物品的截图目检。键盘操作（Tab/I、方向键、空格）没有模拟过。
- Mac 实机：未反馈。

## 迷你窗：鼠标不在窗口上时只隐藏菜单
- 鼠标不在迷你窗上时，只隐藏上方的 HUD 菜单面板；小猫和场景一直显示。用全局鼠标坐标判断是否在窗口可交互区域内，移入即显示菜单，移出 0.8 秒后隐藏；拖动、打开面板、退出确认时保持显示。
- 菜单隐藏时可交互多边形只剩场景区，菜单所在的透明区域不拦截点击。完整窗口不受影响。
- 调试：CATFISH_NOHOVER=1 关闭该行为；设置键 settings.mini_hover（缺省 true）。
- Linux 下只验证了测试与启动无报错；移入/移出行为需 Mac 实机验证。

## 小猫的床（小镇内容 第一项）
- 家里的床成为互动点（空格键小睡）：只在番茄休息时可用，每段休息一次；睡 2.6 秒后"幸运"5 分钟（复用幸运鱼饵效果，稀有鱼和宝箱概率提高）。
- `Game.nap_status()/nap()`，状态记在 `effects.napped_end_ms`；balance.json 新增 `nap.lucky_minutes`。
- 测试 171 项通过（新增 5 项）；Linux 截图看过睡觉画面；Mac 实机待验。

## 天气与昼夜（真实时间）
- `core/weather.gd`：本地时间 → 是否下雨、昼夜暗度和暖色，全是纯函数，不存档。每 2 小时一个时段，24% 的时段会下雨，一场 60–90 分钟（总体约 15%）。
- 下雨：咬钩等待缩短到 1/1.05，宝箱概率 ×0.95（`balance.json` 的 `weather`）；雨停恢复。`Game.weather_override` / `hour_override` 供调试。
- 画面：昼夜染色、雨丝、水面涟漪（迷你窗只染场景区）；小猫在室外下雨时穿蓑衣、戴蓑衣帽（`assets/cat/rain_gear.png`），进屋脱掉，捏猫界面不穿。
- 调试：`CATFISH_WEATHER=rain|clear`、`CATFISH_HOUR=0..24`。
- 测试 186 项通过，SIM PASS；Linux 截图看过白天雨、夜晚、黄昏；Mac 实机待验。

## 黄昏改成日落、迷你窗不再染色
- 用户反馈：迷你窗是透明背景，黄昏/夜晚/下雨的整体色块会把透明区域变成半透明；黄昏应该是太阳下山、火烧云的感觉。
- 迷你窗：不再盖任何色块，只保留雨丝和水面涟漪。
- 完整窗口：日出/日落改在天空里画——天空分成 6 条色带（深蓝紫 → 粉 → 红 → 橙 → 黄），太阳傍晚沉到山后、清晨从山后升起，云被烧红；夜里仍是整体变暗；下雨时晚霞减弱。
- Linux 截图看过黄昏、清晨、正午；Mac 实机待验。

## 天文：日月星、定位、真实天气
- `core/astro.gd`：太阳高度、日出日落、月相（会合月周期）、月亮位置（过中天时刻 = 12 点 + 月相 × 24 小时的简化模型）。都柏林 11-13 和北京夏至的日出日落用 astral 库交叉核对，误差在几分钟内；极昼极夜有测试。
- 天色由太阳高度算出（`Weather.light`），不再按钟点硬编码：日落时间随季节和纬度变化，冬天太阳低、夏天高。
- 画面：天空色带（白天/黄昏/夜晚）、太阳沿轨迹走并沉到山后、月亮按月相画亮面（南半球左右相反）、夜里 70 颗闪烁的星星、阴天和下雨看不到日月星。
- 位置：`io/location.gd` 按电脑时区名（macOS 读 `/etc/localtime`）找城市，离线。`CATFISH_LOC=纬度,经度,名字` 可调试。
- 真实天气：`io/weather_fetcher.gd`，设置页新增"真实天气"开关（默认关）；设置页行距收紧到 10 像素，面板加高 2 像素。
- 修了一个问题：`DirAccess.read_link` 要用实例调用，否则桌面适配器编译失败；新增测试加载桌面适配器，避免以后再被无窗口测试漏掉。
- 新增调试变量：`CATFISH_DAYS=n`（日期往后挪 n 天，看月相）、`CATFISH_LOC`。测试 210 项，SIM PASS。
- 新增 `运行游戏.command`：双击先清除 macOS 隔离标记再打开游戏。

## 镜头改成橡皮筋
- 用户反馈：30%–70% 静止区里镜头完全不动，应该最终还是让小猫居中。
- 现在镜头每帧用缓动（`CAM_PULL = 1.4`/秒，约 2 秒回到正中）把小猫往中间拉；小猫走得比缓动快、走出 30%–70% 时镜头立刻跟上。世界两端仍然夹住，那里小猫无法居中。
- 镜头用浮点位置，画面上取整。只改了 `presentation/main.gd` 的 `_update_camera`；Linux 截图因世界左端被夹住看不出居中，只确认无报错，测试 210 项、SIM PASS，居中效果待 Mac 实机。

## v0.25 流程与体验修正（第一批）
- 新增 `Activity.SOLD_OUT`（追加在枚举末尾）。卖光后小猫停在摊位前，显示鱼骨气泡，点气泡/按钮/空格才走回码头；等多久都不会自己走。
- `can_go_to_town` 不再要求鱼篓有鱼；空篓子上岸后直接在码头自由走动（`dock_roam_x`）。休息期间仍不能出发。
- 镇上左上角按钮换成"去钓鱼"（`btn_fish`），摆摊中/卖光后/自由走动都可点，没卖完的鱼带回船上。
- 航行时镜头硬跟随小猫（整数像素），不再缓动；原先缓动镜头与取整的船各自四舍五入，导致相对抖动。
- 夜里（天暗度 > 0.35）操作提示字改成浅色。
- 测试 223 项通过；`sim_long_run` 的 FakeClock 缺 `local_s/bias_s` 已补（之前版本里这个模拟其实跑不通，现在修好并加入点去钓鱼的随机操作），SIM PASS。
- 下一批（待用户确认方案）：水域分区与可操控船、市场场景、鸟、船头龙头、鱼篓堆鱼。

## v0.26 码头最左端修正
- 用户反馈：走到码头最左端时提示消失，按空格后小猫会向右走一小段才上船。
- 自由走动的左边界从 548 改成 552（等于上船点 `WALK_FROM_X`），在最左端上船不再位移；在码头附近（`near_pier`）提示固定显示"空格键去钓鱼"。
- 测试 223 项、SIM PASS；Linux 截图确认提示。Mac 实机待验。

## v0.27 市场
- 世界向右延伸到 x=1388：小镇尽头有"市场"拱门和彩旗，门后四个 NPC 摊位（水果、蔬菜、面包、鲜花），摊主是居民样子的 NPC，鱼摊挂"鱼摊"招牌，位置挪到中间。
- 三位逛市场的顾客：走一圈，在摊位前停 4.2 秒，1.5 秒时付钱（硬币飞向摊主、摊主轻跳）、货飞到手里，拎着货走向下一个摊位。位置是纯时间函数（`shopper_at`），不用存状态。
- 新素材全由 `generate.py` 生成（82 张，24 色）：拱门、四种雨棚、四种货、四种手持小图标；新增标签"市场/鱼摊/水果/蔬菜/面包/鲜花"。
- 自由走动速度 46→70，因为路程变长；自动走路仍是 8 秒（`walk_ms` 未改，测试不受影响）。
- 测试 223 项、SIM PASS；Linux 截图目检了摊位、顾客购买、走到市场右端。Mac 实机待验。
- 没做：摊主/顾客聊天，市场专属背景（地砖），其他 NPC 向你的鱼摊买鱼。

## v0.28 摊位细节与测试倍速
- 柜台从 15 降到 11 像素高，猫和摊主的脸露在柜台上面；柜台、雨棚立柱各向下多 2 像素踩进草地，修掉摊位底和地面之间漏出的像素点。
- 新增移动倍速（`Journey.speed`）：`[` / `]` 在 1/2/4/8/16 之间切，自由走动、自动走路、航行一起变快，进行中的航行进度保持连续；不存档。左上角显示 `xN`。
- 测试 228 项、SIM PASS；Linux 截图确认柜台与倍速指示。Mac 实机待验。

## v0.29 云层跳动修复
- 原因：云的高度按"屏幕里的第几朵"取，云循环回绕时编号整体错位一朵，云就换了高度、上下一跳。
- 改成按世界编号取高度（编号随云一起滑过屏幕），回绕时不再换高度。只改 `presentation/world.gd` 的云绘制。
- 测试 228 项、SIM PASS；Linux 截图无报错，滑动效果待 Mac 实机。

## v0.30 水域与划船
- 船的位置存进存档（`journey.boat_x`，新档默认 260）。钓鱼/满篓时按方向键划船（`Game.steer_to`，范围 30–440），钓鱼不被打断，咬钩时按船此刻所在水域抽鱼（`fishing.zone`）。
- 三片水域写在 `balance.json` 的 `water.zones`；鱼表里的 `zone_weights` 决定每种鱼在哪片水域出现（没写 `zone_weights` 的鱼仍用 `weight`，所有水域通用）。新增 6 种鱼：泥鳅、鳊鱼、草鱼、鲶鱼、鳜鱼、银龙鱼，共 9 种，价格 4–90。
- 画面：深水区加暗、浅滩加亮、分界处浮标；划船时桨叶动画和航行共用 `_draw_rowing`；船上提示"方向键划船"和当前水域名。图鉴改成 3×3 九宫格，鼠标放上去显示名字和价格。倍速指示下移避免和水域名重叠。
- 测试 237 项、SIM PASS（模拟里加了随机划船和船位范围检查）。三个原有概率测试因鱼表变化改成按水域取值。
- 没做：不同水域的钓鱼等待时间差异、水域名的 NPC 解说、鸟/龙头/鱼篓（下一轮）。

## v0.31 修复三个反馈 + 修正 v0.30 提交里回退的文件
- 图鉴：格子里不再画数量（数字会压到旁边的鱼图上变成乱码），鼠标放到某格上，底部显示名字、数量、价格。
- 鱼摊：`near_stall` 原来只认摊位左半边 16 像素，站在右半边（放鱼的那边）按空格会一直"拒绝"。改成小猫中心落在摊位宽度内都算；按空格从当前位置走到摊位后开张（按距离计时）；靠近时提示"空格键摆摊"。以后可以做成"绕到柜台后面"的动画。
- 水域分界浮标改成黄色浮筒、带竖杆和小旗，免得被当成钓鱼的红白浮漂（划船时钓竿本来就收起，水面上那个红白小东西其实是浮标）。
- 事故：v0.30 提交里 `tests/`、`assets/`、`tools/art/generate.py` 被一份旧压缩包覆盖回了 v0.26 的内容（同名 `_back.tgz` 被复用）。导出的 app 是用云端完整工作区做的所以没受影响，但仓库里这几处是旧的。本版把云端完整文件整体同步回来并逐个文件校验 md5，已一致。以后同步文件一律用新文件名。
- 测试 237 项、SIM PASS。

## v0.32 鸟和船
- 船尾加了木头龙头（鸟的落脚点），船上加了鱼篓：按篓里鱼占容量的比例堆 1–12 块鱼色，满了堆成小山；人在镇上时鱼在猫身上，船上的篓子是空的。
- 鸟（`Game._tick_birds`）：钓鱼或满篓闲置时，每 4–9 分钟来一次。开始时定好种类并发出 `bird_visit`，6 秒后才生效（`bird_gift` 把物品加进物品栏 / `bird_steal` 叼走一条）。时间戳存在 `effects.bird_next_ms / bird_act_ms`，休息期间顺延；重启后这次来访作废；出发去小镇会取消。
- 偷鱼只在小猫盯着浮漂等咬钩（或满篓闲置）时发生，只偷最便宜的非稀有鱼（`Economy.cheapest_common`）。
- 画面：飞来→停下张望→送礼（物品落进船里）或叼鱼飞走；天上白天有 3 只海鸟慢慢飞过，夜里和下雨时不出现。`CATFISH_BIRD=1` 让一开局就来鸟。
- 修了鱼摊里小猫脚没踩地（摆摊时下移 2 像素）。
- 测试 250 项、SIM PASS；同步文件改用新文件名，并逐个校验 md5。

## v0.33 船、加速、水域、摊位和状态页
- 船：鱼篓挪进船舱，画在小猫背后、龙头旁边，下半截被船身盖住；船底被水盖住（按 3 像素一列画，颜色和当地海水一致），水线上一圈白沫，船头船尾向外荡开水纹，航行和划船时船尾拖出尾迹。
- 全局加速：`Journey.speed` 去掉，改成 `Game.time_scale` 和 `Game.fast_forward(dt)`，每帧把番茄钟、旅程、钓鱼、鸟、幸运鱼饵的截止时刻前移（休息中旅程不动）。存档里仍是真实时间。自由走动和划船的按键速度仍乘倍数。
- 水域分界：颜色按离分界线的距离淡入淡出（`ZONE_BLEND` 28 像素），浮标保留。
- 摊位：小猫和路人整体下移 2 像素；去摊位时在柜台前走到最近一端（`CORNER_L` / `CORNER_R`），抬高 3 像素后绕到柜台后，到站正好是摆摊位置；回码头反过来。`World.stall_route` 和 `_walk_pose` 是纯函数，测试覆盖。
- 状态页：菜单第 5 页，顶栏猫头按钮（`btn_cat`）或 C 键打开。`Game.equipment_name`、`Game.bait_active`；名字表在 `balance.json` 的 `equipment`。
- 鸟的数值改成 3–8 分钟一次、偷鱼 30%。
- 测试 263 项、SIM PASS（模拟里加了随机加速）；Linux 截图看过船、水线、摊位逐帧、状态页。Mac 实机待验。

## v0.34 钓鱼手感
- `Fishing` 增加三个状态（追加在末尾）：BAITING 上饵、TWITCH 动漂、TANGLED 空军。流程：上饵 → 抛竿 → 等（20–60 秒）→ 动漂 → 咬或再等 → 最多三次；咬钩时按第几次动漂决定稀有鱼倍率（0.3/1/3）和大小区间。参数都在 `balance.json` 的 `fishing`。
- 鱼有大小：`fish.json` 每种加 `size_cm`；钓到时写进 `catch` 事件，统计里记每种最大值（`stats.fish_best`），空军记 `stats.empty_casts`。
- 鱼饵：`balance.json` 加蚯蚓、小虾（`use: bait`，`max_stack` 99）；`GameState.equipped_bait`；`Game._use_bait` 每次上饵扣 1 个；`Inventory.add` 支持堆叠上限；物品栏按钮对鱼饵显示"装上"。
- 画面：上饵动作、浮漂点水、空军头顶乱线（新精灵 `tangle`）、钓到的鱼旁显示厘米、状态页鱼饵格、图鉴悬停显示最大尺寸、新音效 `twitch`。船水线降到 `WATER_Y`。
- 没做：家里的仓库（下一版）。
- 测试 281 项、SIM PASS；Linux 截图看过上饵、浮漂、船水位、物品栏。Mac 实机待验，空军画面没截到。

## v0.35（11-13）验收修改
- 钓鱼中按方向键先收杆再划（`Game.reel_in/line_out/cast_line`，`main._row_ready_at`）；停船后需按互动键重新甩竿；去掉"空格键去小镇"。
- 摊位：立柱画在猫前面；摊位里按方向键猫留在柜台后（`world.roam_behind`），走出才回前面；已在柜台后时直接走到位。
- 迷你窗：顶栏左移 6 居中（`MINI_HUD_DX`），`MINI_SCENE` 改为整宽；鸟停留 `act_after_ms` 10000；尺寸改 "cm"；鸟礼物不再重复飘字。
- 测试 281 项 ALL TESTS PASS、SIM PASS；Linux 截图看过迷你窗。Mac 实机待验，摊位绕行画面没截图。

## v0.36（11-13）验收修改
- 船可划到码头（`boat_max_x` 512）；`Journey.sail_scale` 按路程折算航行时长；`Journey.turn_sail` / `Game.turn_sail` 航行中掉头，按钮图标随方向变化。
- 水纹重做：`World._ripples` 世界坐标水纹，静止圈 + 速度相关 V 形尾迹，透明度 sin 曲线。
- 加速时顾客离开动画按 `time_scale` 缩放（之前按真实时间，多位顾客叠在一起）；鸟的动画时间也按加速走，避免与结算错开（"同时偷和送"的成因：加速下两次来访画面重叠）。
- 鸟：`bird_start` 生成 0–2 次换位路径，最终位置对应行为；新增 `idle_chance` 的 none 来访；偷鱼后 `anger_ms` 红色💢（新精灵 `anger`），`_tick_idle_full` 在生气期间不恢复钓鱼。
- 水线 `WATER_Y+2`。调试变量 `CATFISH_BIRD=steal|gift|none`。
- 测试 ALL TESTS PASS、SIM PASS；Linux 截图看过尾迹和三种鸟停位。Mac 实机待验，💢画面没截到。

## v0.37（11-13）
- `Journey.sail_curve` 速度曲线（加速 5%、匀速、减速 10%）、`sail_pos`、`halt_sail`；`Game.halt_sail` 取代掉头；方向键打断自动航行。
- 回小镇按钮跑马灯 `_draw_marquee`；出发先收杆（`retract_t0`）；最后 10% 不画船桨。
- 鸟：船动即惊飞（`bird["flee"]`，世界坐标）；`steer_to` 取消来访。V 形尾迹从船前端起。
- 测试 ALL TESTS PASS、SIM PASS；Linux 截图看到跑马灯。Mac 实机待验。

## v0.38（11-13）
- 去钓鱼按钮同回小镇：`_town_button` 覆盖 WALK_TO_BOAT / SAIL_BACK，跑马灯扩到这两个阶段。
- 家里仓库：`GameState.warehouse`、`Inventory.stash/fetch/count_w/owned_w`、`Game.stash_item/fetch_item`；`Bag` 加仓库模式（`wh`、`tab`、`move_selected`），家里新增 `storage` 点位和木箱精灵；新标签：仓库、身上、存入、取出、全部、空格键开仓库。
- 调试变量：`CATFISH_BIRDKIND`（原 CATFISH_BIRD 与旧调试撞名，改名）、`CATFISH_WH=N`。
- 测试 ALL TESTS PASS（新增仓库测试）、SIM PASS（改动前）；Linux 截图看过仓库面板和家里木箱。Mac 实机待验。
- 没做：鱼竿/鱼线/鱼钩作为物品存进仓库（它们还不是物品）；物品栏容量上限。

## v0.39（11-13）
- 状态页精简；新增 `presentation/book.gd`（图鉴 / 最高纪录 / 统计，完整窗口专用）；core 记 `stats.focus_hours`（`Game._record_focus_hours`、`focus_hours_of`）。
- 渔具店鱼饵页：`Game.shop_baits/bait_unlocked/can_buy_bait/buy_bait`，balance 里鱼饵加 `price`/`unlock_fish`；`Menu` 商店分"装备/鱼饵"两页，未解锁灰色 + 小锁（新精灵 `lock`）。
- 浮漂水花：`World._bobber_fx/_retract_fx/_draw_drops`，复用世界坐标涟漪。
- 装修：渔具店/帽子店/摊位地面共 30 多张新精灵（灯笼、门帘、浮漂板、鱼标本、木桶竿、饵料罐、帽子挂板、帽架、布卷、货箱、看板、招牌旗、石灯笼）；`_draw_stall_deco`。
- 调试变量：`CATFISH_BOOK=页`、`CATFISH_SHOP=1`。测试新增按小时记录和买鱼饵。
- 测试 ALL TESTS PASS、SIM PASS；Linux 截图看过各页面和装修。Mac 实机待验。

## v0.40（11-13）
- 码头不能钓鱼：`Game.at_dock()`（船离码头 < 12 像素），`cast_line` 拒绝，提示不显示；`Journey.cfg_dock_x`。
- 帽子店 / 服装店：`Game.set_cat_cfg/cat_items/cat_price/cat_owns/buy_cat_item/wear_cat_item`，存档 `cat.own_hats / own_outfits / outfit`（老存档戴着的帽子自动算已拥有）；新面板 `presentation/outfit_shop.gd`；`data/cat.json` 加价格和 `outfits`。
- 新房子 `house_3`（服装店，x=760，门 782），室内人台、衣物挂板；3 件衣服覆盖层 `assets/cat/outfit_*.png`（`draw_outfit` 只改毛色像素，贴合所有 6 帧）。
- 开发者模式：` 键 / unicode 96、183，`Wardrobe.dev`，换形象面板加"衣服"一行。
- 统计页：箭头紧挨日期；`Game.focus_hours_live`；窄窗口柱宽自适应；没数据时写原因。
- 调试变量：`CATFISH_OUTFITSHOP=hat|outfit`；`CATFISH_LOOK` 可带第 4 项衣服。
- 测试 ALL TESTS PASS（325 项）、SIM PASS；Linux 截图看过两个货架、统计页。Mac 实机待验。

## v0.41（11-13）
- 服装店合并：删掉单独的服装店房子（`house_3`、`noren_clothes`、ROOMS.clothes），裁缝铺改名"服装店"，`OutfitShop` 加"帽子/衣服"标签页（左右键或点击切换）；人台、衣物挂板放进这间屋子。
- N19：`Inventory.roll(rng, drop)`，物品加 `drop` 字段，宝箱只在 chest 里抽；`Game._roll_junk` 钓到杂物（`balance.junk`），事件 `junk`，不占鱼篓。
- N15：`balance.quests`；`Game.quest_state/quest_needs/can_turn_in/turn_in`、`Inventory.remove`；漂流瓶 `use: letter`（第一个开启任务，之后给零钱）；`GameState.quests`、`upgrades.hook`；银钩 = 鱼钩第二档，`hook_rarity_bonus`；新面板 `presentation/quest_panel.gd`，渔具店加 `quest` 点位（柜台左边）。
- 教训：`tests/run_tests.gd` 不加载 `presentation/main.gd`，主脚本的语法错误测试发现不了（这次批量替换缩进弄坏过一次，靠启动截图才发现）。以后每次改完都要 `godot --headless --path . --quit-after 60` 看有没有 SCRIPT ERROR。
- 调试变量：`CATFISH_QUEST=letter|talk`。
- 测试 ALL TESTS PASS（339 项）、SIM PASS；Linux 截图看过服装店两个标签页、信和交付面板。Mac 实机待验。

## v0.42（11-13）
- 市场拱门右立柱补画在人物之后（`world.gd` 在 `_draw_chat` 后用 `draw_texture_rect_region` 再画一次）。
- "鳊鱼"→"鲂鱼"：字库（Fusion Pixel zh_hans）缺"鳊"字，之前图鉴里是方框；`labels()` 加了字库 cmap 检查，缺字直接 assert。
- 测试 ALL TESTS PASS（339 项）、SIM PASS；启动检查无 SCRIPT ERROR。Mac 实机待验。

## v0.43（11-13）
- 物品栏容量：`GameState.bag_slots`（存档）、`Inventory.stack_default/stack_cap/slots_used/room_for`，`add` 受容量限制，`fetch` 同；`Game.give` 放不下送仓库并置 `take_overflow`，主界面弹"行李满了"提示；`can_buy_bait` 检查有没有位置。物品栏标题旁显示已用/总格数。
- 装备物品化：`balance.items` 加 10 件 `use: gear`（`slot`、`level`），`GameState.gear` 记身上各栏的档位（-1 = 老存档，`Game._init_gear` 按升级档位补）；`grant_gear / equip_gear`，`buy_upgrade("rod")` 自动装新竿；鱼竿速度、钩子加成、状态页名字都读 `gear`。新图标 `item_rod/line/hook`。
- 支线：`balance.quests` 增至 3 条（`requires`、`reward_item`、`reward_slots`），`Game.next_quest_letter / room_quest`，服装店加 `quest` 点位（x=172），`quest_panel` 按屋子取任务。银钩改为通过 `grant_gear("hook_1")` 发放；`hook_rarity_bonus` 加金钩 0.5。
- 杂物概率 10%，珍珠加进杂物池。
- 测试 ALL TESTS PASS（358 项，新增 `test_bag_gear_quests`）、SIM PASS；启动检查无 SCRIPT ERROR；Linux 截图看过物品栏和服装店任务面板。Mac 实机待验。


## v0.44 码头浅滩、划船曲线、聊天转向、任务页、装备属性
- 码头：`Journey.boat_at_dock/boat_in_shoal`；贴码头时 `depart` 直接进 WALK_TO_STALL，WALK_TO_BOAT 结束在码头则直接 FISHING（返回 "moored"）；`Game.fishing_blocked()` 阻止浅滩抛竿；空篓子上岸直接逛街。世界层画浅滩（沙底、焦散、浮标）。
- 划船速度曲线（`main.gd` 的 `_boat_v`，加速/减速）；聊天时小猫转向居民、店主按距离转向小猫（`world.gd`）。
- 图鉴册第 4 页"任务"；`Game.gear_stat` + 物品栏属性文字。生成脚本的字符检查只对纯汉字标签做（ASCII 是变宽字形），新增 `+N％` 标签。
- 新增调试变量：`CATFISH_BOATX`、`CATFISH_QSTATE`、`CATFISH_BAGSEL`。
- 测试 ALL TESTS PASS、SIM PASS；启动检查无 SCRIPT ERROR；Linux 截图看过浅滩、上岸提示、任务页、物品栏属性。居民聊天转向和店内店主转向没有截图验证；全部待 Mac 实机。

## v0.45 金银铜、聊天与店里、浪区、后台
- 货币：`core/money.gd`；`wallet_gold` 现在是铜币数，显示用 `Main.draw_money / money_right`（金银铜三种图标）；`Game._clamp_wallet` 封顶 999 金、多的进 `state.piggy`，`piggy_use` 存取；家里新增存钱罐点位（x=106）。
- 居民：聊天范围 46 像素、聊天时小猫退到 24 像素外；下雨只剩第 0 位并打伞（`umbrella` 精灵）；店里顾客 `_draw_room_customer`（30 秒一个周期，纯表现）；店主始终朝向小猫。
- 界面：状态页文字按钮"任务/图鉴"；菜单新增第 6 页"任务"（迷你窗用）；钓鱼提示 `_draw_catch_pop`；`Admin` 后台（F9）。
- 水域：沙滩重画（缓坡、泡沫线、湿沙干沙、桩脚接入沙里）；浪区 `_draw_waves` + `Game.wave_push` + `main._apply_waves`；"浅滩"→"浅水区"。
- 生成脚本字符检查对含 ASCII 的标签跳过逐字检查。
- 新增调试变量 `CATFISH_ADMIN`、`CATFISH_CATCH=鱼id`。
- 测试 ALL TESTS PASS、SIM PASS；启动检查无 SCRIPT ERROR。居民聊天后的位置、后台按钮点击、存钱罐、浪区推回手感都没有实机验证，全部待 Mac。

## v0.46 杂物和鱼二选一、仓库木箱、默认对话、上次钓鱼点
- 杂物改在咬钩时（`FishingSystem._after_twitch`，经 `junk_roller`）决定，hooked_fish 是 `junk:物品id`；世界层提竿时画物品图标；存档断点也认这种值。
- `main.gd` 的收杆动画只在浮漂已入水（WAITING/TWITCH/HOOKED/REELING/SETTLEMENT）时演（`_bobber_in_water`）。
- 仓库：`bag._draw_chest_frame`，"使用/装备"按钮 + U 键；`Game.use_item_w`。
- 店主：`quest_panel.just_done`、`Game.shop_chat`；`room_quest` 优先级改成 进行中 > 未开始 > 做完。
- `journey.remember_fish_spot / fish_spot`，WALK_TO_BOAT 结束时手动靠岸的船改开回钓鱼点。
- 测试 ALL TESTS PASS、SIM PASS；新增 `test_v046`。教训：测试输出里出现 SCRIPT ERROR 时，"ALL TESTS PASS" 也不算过——这次先发现并修了测试里调用不存在的 FakeClock.advance。
- 没验证：提竿画面里杂物图标、收杆动画是否不再触发、仓库按钮实际点击、对话画面，全部待 Mac。

## v0.47：完整价格、鱼篓百分比、造船厂
- 价格：`draw_money_full / money_full_right`，商店、衣帽店、状态页、鱼饵价格全部显示金银铜，不再去尾；面板有重叠处做了调整。
- 鱼篓：`fish.json` 每种鱼有 `units`；`Economy.basket_used/basket_percent`；`basket_capacity` 改浮点（基础 10，每级 +2）；HUD 和船上鱼篓显示百分比；字体加了 `% . ( )`。
- 咬钩：`FishingSystem._plan_bite/_bite_scale`，先决定这一口是鱼/杂物/宝箱，小鱼等待时间乘 0.4–1.0。
- 造船厂：`house_3`、门帘/蓝图/铁锚/帆船模型素材，`ROOMS.shipyard`，`presentation/shipyard_panel.gd`；`GameState.boat_level`；`Game.boat_levels/boat_price/buy_boat_upgrade`（只能买当前级+1，重复提交不扣钱），`wave_zone()` 取当前船级；调试变量 `CATFISH_SHIPYARD=铜币数`。
- 测试 ALL TESTS PASS、SIM PASS、启动无 SCRIPT ERROR；新增 `test_v047`。Linux 截图看过造船厂外观/室内/面板；Mac 实机全部待验，升级后浪区的画面没截图。
- 咬钩最短等待从 20 秒降到约 8 秒（见 D95）。

## v0.48：浪与船、概率规则、换位、版本号、木箱
- 浪：高度缩小，波形相位和白色浪纹都改成从左往右；`wave_need`：船等级达到就不再被推回（`Game.boat_passes_waves`），浪区本身不再变化。
- 概率：`_base_rarity` 恒为 0；鱼饵升级/鱼钩改成 `FishingSystem.gear_wait_mult`；专注时 `luck_mult`、宝箱概率 ×`focus_luck_mult`。
- 位置：造船厂换到 x≈652，家到 x≈1388（`WORLD_END` 1470、`ROAM_MAX_X` 1430）。
- 版本号画在右下角；`project.godot` / `export_presets.cfg` 版本改成 0.48。
- 家里的箱子（`storage` 素材）重画成圆顶木箱 + 铁箍 + 金锁；仓库界面的箱子外框没动。
- 测试 ALL TESTS PASS、SIM PASS、启动无 SCRIPT ERROR；新增 `test_v048`，改了宝箱占比和船相关测试。没验证：Mac 实机、浪的画面。

## v0.49：尺寸、背包不传送、特效层级、船外观
- `fish.json` 尺寸范围重写；`Game.give` 改成 扔掉 / 替换 / 极端情况才进仓库（`is_important`），提示"物品栏满了 / 东西扔掉了 / 换掉了旧物品"。
- 闪光粒子移到面板之前绘制；`boat(level)` 画出 4 种船，`CATFISH_BOATLV` 调试变量。
- 版本号 0.49。测试 ALL TESTS PASS、SIM PASS、启动无 SCRIPT ERROR。
- 岛、岛心湖、蟹笼、工坊只记了规划（D104），没做。

## v0.50：小岛、目的地、转身、被偷播报
- 小岛：`water.island`；`Game.island_*`、`_check_island`（第一次靠近发 `island_found`）、`boat_limits` 对 1 级以上的船放到岛边；世界向左延伸（`CAM_MIN` -4700），`world._draw_island` 画镜像码头、草地、岛心湖、树、雾灯塔。
- 准星按钮（78,14）+ `presentation/dest_panel.gd`；`main.start_auto_sail/_auto_step` 自动航行（巡航 150 像素/秒，进港减速，按方向键取消）；到岛弹白色大标题 `_draw_island_title`。
- 转身：`world.face_left/turn_t0`，`_pending_cast_at` 转完再甩竿。
- 被偷/被吃：`economy.basket_sizes/last_removed_size`，`_show_loss`。
- 取消普通水域，fish.json 的 zone_weights 并入 shallow；HUD 鱼篓图标左移 9 像素给准星按钮腾位置；版本号 0.50。
- 测试 ALL TESTS PASS、SIM PASS、启动无 SCRIPT ERROR；新增 `test_v050`。

## v0.51：海流、岛码头、起名、回小镇停码头
- `Game.current_mult/current_strength`；自动航行 `_auto_step` 用 `BOAT_SPEED * current_mult`；`_draw_waves` 从浪区铺到小岛附近。
- `_draw_island` 用 `draw_set_transform_matrix` 镜像小镇的 `_draw_shoal`、地面、码头、桩脚。
- `GameState.cat_name`、`Game.set_cat_name/town_name`、起名框（`_begin_naming/_name_input/_draw_name_dialog`）、`dyn_text` 像素字体现画；生成脚本把字体复制到 `assets/fonts/pixel.woff`；`CATFISH_CATNAME` 调试变量。
- `go_to_town(stop_at_dock)`、`journey.dock_stop`；目的地面板用它。
- 测试 ALL TESTS PASS、SIM PASS、启动无 SCRIPT ERROR；新增 `test_v051`。版本号 0.51。

## v0.52：商店放大、船吃水、岛的浅水区、叠格、登岛
- `main.gd`：`PANEL_ZOOM`、`_is_zoomed/_zoom_t/_pz/_draw_zoomed`，点击/悬停坐标反推；起名框文字上移；`_interact_island`。
- `world.gd`：`_draw_hull`（水线以上）、`_draw_ripples(t, pass)` 两遍、船 `boat_y` 下沉 2；岛上木桥、看守、西岸树；`island_near_*`。
- `core/inventory.gd`：`slots_of / cells / room_for` 叠格；`game.give` 重要物品满格时顶替。
- `core/journey.gd`：`ISLAND` 活动；`game.gd`：`land_on_island / leave_island / begin_talk_quest / reward_give`；`zone_bounds` 加岛侧浅水区。
- `balance.json`：`island.shallow_to/walk_west/keeper_off`、lighthouse 任务、crab_recipe 物品。素材：`ico_bag`、villager_3、item_crab_recipe。
- 测试 450 项 ALL TESTS PASS、SIM PASS；新增 `test_v052`。版本号 0.52。

## v0.53：商店面板改成占满窗口排版、朝向与聊天瞬移
- 去掉 `PANEL_ZOOM`，`main.big_rect()`；outfit_shop / shipyard_panel / quest_panel / menu(商店页) 各自重排。
- `_draw_boat_cat`：SAIL_OUT 不翻转；`_go_to_town` 清 `face_left/roam_flip`；"docked" 事件设 `roam_flip=false`。
- `world._stroll_pause`：聊天时间从路人的走路时间里扣掉；`main._stand_to`：小猫退开改为走过去。
- `dest_panel`：高亮跟随 `menu.hover`。
- 测试 450 项 ALL TESTS PASS、SIM PASS。版本号 0.53。

## v0.54：雾灯岛岛心湖钓鱼
- `core/game.gd`：`at_lake_spot`、`island_walk_min` 改为湖东岸；`fishing_blocked/cast_line/_tick` 支持 ISLAND；zone "lake"；`lake_junk` 杂物表；登岛收竿。
- `world.gd`：`_draw_lake_fishing`（镜像画坐姿钓鱼）、去掉木桥换小木牌；`main.gd`：空格走到钓位/甩竿/收竿、走动自动收竿、提示文字。
- 数据：鱼加 `zone_weights.lake`、`lamp_shell` 物品、`lighthouse2` 任务、`lake_junk`；素材 `item_lamp_shell`；`coin_copper` 变深。
- 测试 458 项 ALL TESTS PASS、SIM PASS；新增 `test_v054`。版本号 0.54。

## v0.55：雾灯岛玩法扩充
- 修：上船途中选岛排队（`main._queued_x`）；朝左钓鱼的涟漪/水珠镜像并落在湖面（`world._fx_x/_fx_y`）。
- 新玩法：草丛拾取（`game.drift_*`，effects.drift_0..2）、信号台小游戏（`core/signal_game.gd`、`presentation/signal_panel.gd`，`game.signal_*`）、任务 lighthouse3（日记残页）/lighthouse4（雾灯鳞）、`reward_gold`、鱼表 `gate` / `drop_item`、雾灯鱼（夜里+灯塔修好）。
- 画面：夜里灯塔光束、湖面微光、信号台、草丛亮点；素材 item_diary_page / item_lamp_scale / fish_lamp。
- 测试 472 项 ALL TESTS PASS、SIM PASS；新增 `test_v055`。版本号 0.55。

## v0.56：蟹笼、修桥、西岸
- 修：`_draw_sky` 地平线雾气 8 级渐变；`_draw_hull` 船尾那一段区间写错（w-6 → w-3）。
- `game.gd`：`lake_spot_x / bridge_built / island_walk_min(桥)`、`craft_pot / collect_pots / pot_*`、`west_chest_*`；任务 `reward_flag`；`drift_count` 随桥解锁 3 处。
- 数据：木板 plank、pots 配置、west_chest、lighthouse5；素材 item_plank；画面：工作台、湖中蟹笼、桥、木箱。
- 测试 486 项 ALL TESTS PASS、SIM PASS；新增 `test_v056`。版本号 0.56。

## v0.57：岛上往返与提示
- `main._town_button`：岛上一键回镇；`effects.lake_resume` + `_update_roam` 里的自动登岛接着钓；迷你窗不再强制离岛（走回钓位）。
- `world._draw_sky`：太阳在天上时不画月亮；拾取/收笼/木箱的 `_toast`。新增 labels。
- 测试 486 项 ALL TESTS PASS、SIM PASS。版本号 0.57。

## v0.58：岛上按钮与摊位图标
- `generate.py` BTN["town"] 改摊位；`main.gd`：岛上不显示 btn_fish；`_stand_depart`（走到码头再上船）；迷你窗不再自动走回钓位；`_stand_to` 行走时自动收竿、朝向。
- 测试 486 项 ALL TESTS PASS、SIM PASS。版本号 0.58。

## v0.59：迷你窗自动挂机、顶掉物品只腾一格
- `game.gd`：`auto_cfg / pick_water_x / auto_fish_x / end_roam(by_policy)`；`journey.set_fish_spot`；`give()` 顶掉物品只拿走够用的格子。
- `main.gd`：`_auto_policy`（每 1.5 秒判断一次，迷你窗、非休息、4 秒没操作）；ROAM 自动流程走 policy。
- 数据 `balance.auto`；测试 522 项 ALL TESTS PASS、SIM PASS；新增 `test_v059`。版本号 0.59。

## v0.60：岛上任意位置的迷你窗挂机
- `main._auto_policy` 的 ISLAND 分支：到 50% 走去码头回镇，否则走去湖边钓。版本号 0.60，测试 522 项通过。

## v0.61：拱桥、正面钓鱼、图鉴翻页、自动规则
- 新增正面小猫三帧（抛竿/钓鱼/收杆，帽子衣服层共用）；`world.bridge_lift` 拱桥；`game.bridge_spot_x/at_bridge_spot/nearest_spot_x/island_spot_reachable`。
- `balance.auto` 加 island_fish_pct 80、reach_s 10、walk_px_s 70；`end_roam` 改为 ≤30% 去钓；提示文字改“空格键钓鱼”；蟹笼随时可收；`book.gd` 图鉴分页。测试 532 项 ALL TESTS PASS、SIM PASS。版本号 0.61。

## v0.62：自动规则收窄、任务专属物品
- `_auto_policy`：海上/岛上 >80% 回镇卖；去掉镇上 SOLD_OUT 自动出发与 ROAM 的策略分流。`game.item_wanted/_pick_pool/QUEST_ONLY` 过滤瓶子和日记残页；空瓶不给钱。测试 619 项 ALL TESTS PASS、SIM PASS。版本号 0.62。

## v0.63：工坊与店铺门面
- `presentation/shopfronts.gd`（新）：造船厂后院两条船+吊机+屋顶大锚、工坊巨齿轮/烟/铁砧火星/蒸汽、服装店大剪刀/彩旗/遮阳篷、渔具店屋顶大鱼/钓竿/灯笼。`house_4` 贴图、`ROOMS.workshop`、`DOORS`/`HOUSES` 增加；`balance.shop_chat.workshop`；树挪到 x=1010。测试 620 项 ALL TESTS PASS、SIM PASS。版本号 0.63。

## v0.64：卖道具、一次性礼物
- `game.sell_price/sell_item/apply_gift`，bag.gd “卖出”按钮，items 加 sell；`balance.gift`。测试 628 项 ALL TESTS PASS、SIM PASS。版本号 0.64。

## v0.65
对话框系统、雾灯岛修理厂/酒馆/老柯剧情、蟹笼移除、沉船木片。矿山岛（v0.66+）未开始。调试变量 CATFISH_TALK=<对话id>。

## v0.66
主角换成用户提供的新形象（8 帧走路，脚本还原像素网格并统一 18 色）；取消捏猫；其他动作暂用站立帧。下一步：矿山岛。

## v0.67
矿山岛第一版：西码头 → 过海 → 矿山岛（饭店收鱼换宝石、鼹鼠工具店卖镐/灯/限量绳子、矿洞）→ 矿井（32 像素格子、裂痕 4 档、黑暗 + 光圈、竖井 + 梯子、花岗岩边界、工具等级、挂机挖掘与离线补算）；工坊合成梯子。待做：矿车与轨道、随机事件与宝箱奖励池、饭店便当加速、矿里放置物。

## v0.68 矿井改版
主动挖掘取代挂机；取消宝石；洞穴大厅 + 矿车 + 1/2 号井（2 号井铁路坏了）；饭店改做菜；管理员送第一把镐；每局新种子 + 天赋三选一 + 塌方。修了天赋卡片超出画面。新增调试变量 CATFISH_MINEMENU / CATFISH_PERK / CATFISH_DIG。

## v0.69
1 号井：有没结束的一局时矿车直接接着挖，失败时给提示；工坊对话"出售"（整堆卖、任务物品不可卖）；雾灯贝/雾灯鳞只在任务需要时获得；加速对矿山岛生效（Mine.shift）；F9 后台传送；天赋卡片已在 v0.68 修。

## v0.70
修 bug：对话选项上的 action 没被 dialog.gd 读取，导致工坊出售、酒馆雇人、老柯交付任务选了没反应。新增调试变量 CATFISH_CHOOSE。

## v0.71
矿井画面取消矿车；ROAM_SPEED 70→140、矿山岛 WALK_SPEED 46→92、矿井步进 0.11→0.055 秒。

## v0.72
矿井重写为楼层制：随机小地图找出口、炸弹与炸药桶/矿脉连锁、背包容量与回地面换钱、每 5 层电梯存档点、背包与炸弹可买；移除梯子/绳子。重写了矿井测试。

## v0.73
根据试玩反馈：右下角拆成两行（层数/炸弹/镐；背包容量与里面的钱、石头、金属），左下天赋折行；浮字改为"+N 入背包"；探路限 6 格；震波削弱。

## v0.74
矿井：空格才能下一层；爆炸后需松键；入口梯子回地面并二次确认；新增体力与"结实"天赋；顶栏图标不可用变灰；矿井内可缩成迷你窗并播挖矿动画；老柯菜单不再残留已完成的委托选项。

## v0.75
矿井地图改为洞穴式（30×20，房间走廊、岩壁、散落石块、灯光外全黑）；矿车菜单 5 口井各一行，可翻页选起始层；2 号井可修（材料 + 酒馆雇 2 名工人）；目的地面板新增雾灯岛/矿山岛一键直达（测试）。

## v0.76
对话框主角改用用户立绘的半身像；矿井地面、石块、岩壁重画（星露谷式崖壁 + 顶面）。

## v0.77
矿井：方向键顺滑走动（带碰撞、转角自动对齐），面朝石头按住空格挖，黄框提示目标；新增调试变量 CATFISH_WALK。

## v0.78
体力连续消耗并跨局；面朝即可挖、去掉自动对齐；挥镐弧线动画；下层入口改黑洞+梯子（确认下楼）；补给木箱+食物（物品栏可吃）；删除炸药桶/宝箱矿/技能；石头更多、洞口被围；旅店与回家睡觉（测试 3 秒）；钓鱼/买东西缓慢恢复体力。

## v0.79
矿石不产钱（金矿石物品）；背包=物品栏；HUD 只剩体力条和背包容量；移除工坊出售和随处可卖；新增典当行（赎回两倍价）与垃圾箱；石头变小，碰撞盒缩到约 0.52 格。

## v0.80
洞口藏在石头下；取消连锁；清理肉鸽；按住方向键也能挖；石头三种形状、矿不再明显。

## v0.81
矿井状态栏改为层数/体力条/炸弹/背包；去掉矿内多余文字和钱；碰撞盒缩小到脚下；矿洞老钻（卖矿石+教程）。

## v0.82
入口梯子实心；石头放大并加大碰撞；地形不再有孤立岩壁；5 口井、每口 100 层的矿石规则（38 种矿石，图标自动生成）；物品栏显示矿石产地；取消挖矿提示。

## v0.83
物品栏随时丢东西；聊天气泡取代文字提示；木箱变少；"全部"只算一格；山上的 4×4 小鼹鼠；工具店/旅店/饭店可走进去；菜的增益按时间算、去掉光照；去掉石头的黄框。新增调试变量 `CATFISH_ROOM`（shop/rest/inn）、`CATFISH_ROOMX`、`CATFISH_CAVEX`。

## v0.84
矿井卡住自救：每帧检查，站在石头/岩壁/梯子里就挪到最近的空地。

## v0.85
去黄框；背包满了右上角淡出；矿山岛迷你窗不再跳走并显示睡觉；走路不背鱼篓；山上换成脚手架和冒烟小屋；物品栏加鱼篓视图。新增调试变量 `CATFISH_FISHVIEW`。
\n
## v0.86
典当行和垃圾箱挪位，不再盖住老柯；按钮改名"卖这组/丢这组"；赎回页空状态文字。

## v0.87
邮局：雾灯岛西岸宝箱换成邮局，矿山岛也有一个；寄件/取件页、邮费按距离和件数、路上有时间。新增调试变量 `CATFISH_MAIL`、`CATFISH_MAILTAB`、`CATFISH_POSTX`。

## v0.88：矿车票务、邮局会员与修理厂显示
- 矿车大厅改为单一车站流程：隐藏矿井入口和破损轨道画面，移除坏铁路位置打开修理页的交互；上车时按矿井和楼层付费，老钻驾驶矿车通过带抬杆动画的栏杆。
- 邮局改为选物品 → 选收件地址 → 确认邮费；增加暂存包裹物品的逐组取回页，以及付费会员寄存柜（1–5 页，每页 8 格，费用递增）。会员页数写入存档。
- 修理厂已完工项目不再绘制材料图标和数量。
- Codex 开发副本使用 `_codex` 后缀；`build_codex.command` 会生成稳定路径 `build/CatFishing.app` 和版本副本 `build/CatFishing_v0.88_codex.app`。
- 自动测试和画面目检状态见 C176。

## v0.89：雾灯岛行业建筑与老柯立绘
- 邮局确认寄件按钮显示完整应付金额（金/银/铜），费用汇总也显示精确拆分金额。
- 为中年灯塔管理员老柯绘制专属工作服角色图，并用于岛上行走和对话立绘。
- 修理厂、典当行、酒馆换成对应行业的像素外观：铁皮工具工坊、天平金币招牌、渔港木酒馆。素材仍由 `tools/art/generate.py` 按项目调色板生成。
- `build_codex.command` 将按版本号生成 `CatFishing_v0.89_codex.app` 和稳定测试入口 `CatFishing.app`。
- 自动测试及实机画面验证状态见 C177。

## v0.91：补上 v0.88 / v0.89 欠的测试，并修掉真机跑出来的两个问题
- 新工作副本 `/Users/rain/DevGame/CC_CatFashing_Qwen`（`git worktree`，从 `v0.89` 分出），里面没有历代版本压缩包。推到 GitHub 的分支叫 **`Qwen-v0.91`**，标签 **`v0.91-qwen`**（本地分支名只能小写：macOS 文件系统不分大小写）。
- 新增 `test_v088_ticket_and_locker`、`test_v089_scripts_and_art`、`test_labels` 三组测试：检查数从 811 项涨到 **912 项**，本机 macOS 无界面 `ALL TESTS PASS` / `SIM PASS`。
- 真机启动发现：**10 条界面提示不在标签图集里**，运行时只会报警告、玩家看不到字（矿山岛三间屋、雾灯岛五个门口、物品栏和图鉴册各一句）。已加进 `LABELS` 重新生成图集；`label("")` 不再误报。
- 真机启动还发现：调试传送在 `adapter` 创建之前调用 `_update_polygon()`，报 `Nonexistent function 'is_overlay' in base 'Nil'`。已加空值守卫。
- 新增调试变量 `CATFISH_MAILPAGES`（配合 `CATFISH_MAIL` 看会员寄存柜的寄件地址页和会员页）。
- 存档安全：启动真机前把 `user://save.json` 备份到 `_backup_save/`（该目录已加进 `.gitignore`，不提交）。
- 这是一条和 Codex 并行的线：GitHub 上已有 `codex-v0.90`／`codex-v0.91`（标签 `v0.91-codex`），两边的 0.91 是不同东西，靠 `-qwen` / `-codex` 后缀区分；两边都从 `v0.89` 分出，尚未合并（合并时 `assets/sprites/labels.png` 预计冲突，要在合并后的树上重跑一次 `tools/art/generate.py`）。
- 验证状态见 C176–C179：**测试和截图都在本机跑过；截图内容没有人工目检，`.app` 启动也没验证**。

## v0.92：修好"双击运行游戏.command 没反应"，并真打包出可验收的 CatFishing_v0.92_Qwen.app
- **用户反馈的问题是真的**：`运行游戏.command` 只有一行 `open build/CatFishing.app`，而 `build/` 不入库；`CC_CatFashing_Qwen` 这个工作树里从来没人打包过，`build/` 目录都不存在 → `open` 直接报 `The file … does not exist.`、终端一闪就关。本机复现过。
- `运行游戏.command` 重写：优先开 `build/` 里最新的 `CatFishing_v*_Qwen.app`，没有就现打包一份，`open` 前清隔离标记，失败时把原因打印出来并停住等用户看（不再一闪而过）。
- 新增 `打包游戏.command`：版本号从 `project.godot` 读并回写 `export_presets.cfg` → `--import` → `--export-release "macOS"` → 生成 `build/CatFishing_v<版本>_Qwen.app` + `build/CatFishing.app` 替身 → 临时签名 + `xattr -cr` → **自己无界面起两帧自检**，有 `SCRIPT ERROR` 就失败退出。
- 产物：**`build/CatFishing_v0.92_Qwen.app`**（163 MB 通用二进制，`CFBundleShortVersionString=0.92`，签名校验通过，PCK 里确认带上了 `data/*.json`）。另外打了一份调试包用 `CATFISH_SHOT` 让它**自己截图**，证明这个包真的在跑游戏画面（两张 1920×1080，0 警告 0 报错）。
- `project.godot` 的 `config/version` 从 `0.89` 升到 `0.92`（之前一直没跟着版本号走，"关于"里显示的是旧版本）。
- 验证状态见 C180：打包、启动、自检、回归测试都在本机跑过；**真人双击、透明/穿透/拖动、Intel 机器**还没验。

## v0.93：3–5 号井从"永远锁着"变成可以自己开工
- 之前矿车大厅里 3/4/5 号井是死的：`shaft_ok()` 只认 1 号和修好的 2 号，剩下三口永远返回 `locked`，玩家无论怎么挖都开不了 → 5 口井的数据（`mine.shafts=5`）和 5 种矿石分层其实是空转的。
- 现在改成数据驱动的**开工工程**：`data/balance.json` 新增 `mine.open_shafts`（3/4/5 号各一条：`prev` 要先开放哪口井、`depth` 上一口井要挖到多深、`items` 要哪些材料、`crew` 要几个雇工）。数值一个都没写进 `.gd`。
- `core/mine.gd` 新增 `open_need()` / `open_prev()` / `deepest_floor()` / `open_missing()` / `open_ready()` / `open_shaft()`；`shaft_ok()` 认 `shafts[id].open`；`shaft_status()` 多两种状态：`wait`（上一口井还没开）和 `build`（材料·工人·深度还差东西），原来的 `locked` 只留给"数据里根本没这口井"。
- **先查再扣**：`open_shaft()` 先把 `open_missing()` 算完，缺什么就返回 `depth` / `mat` / `crew` / `prev` 并**一件材料都不扣、`revision` 不动**；齐了才一次扣完并置 `shafts[id].open = 1`。重复开工返回 `done`，不重复扣。
- `presentation/mine_view.gd`：票务工位上新增「开工」面板（沿用 2 号井修理面板的 `_panel()` + `dyn_text` 路径），逐条列出上一口井的深度进度、每种材料"要几个 / 有几个"、工人"要几个 / 已雇几个"；开工成功后自动跳回票务工位并选中这口井。`_open("open")` 让 `CATFISH_MINEMENU=open` 直接看这块面板。
- `ensure()` 现在给 1–5 号井都补齐 `{fixed, open, cp, best}` 字段，老存档只有 1/2 号井的条目也不会缺字段。
- 测试：新增 `test_v093_open_shafts`（31 项），检查数 **912 → 943**；顺带改掉两条被这次改动改旧了的断言（`shaft_status(3)` 从 `locked` 变 `wait`）。两处自己写反的判断已修正（"材料清单非空"写成"为空"、`prev < id` 的 `or` 条件把合法数据判成非法）。
- 本机实跑：`ALL TESTS PASS`（943 项 0 失败）、`SIM PASS`，两者退出码 0、0 条 `SCRIPT ERROR`；`./打包游戏.command` → `✓ 自检通过`，产物 **`build/CatFishing_v0.93_Qwen.app`**（163 MB，`CFBundleShortVersionString=0.93`，`codesign -v` 通过，200 帧无界面启动 0 报错）；调试包带 `CATFISH_MINEMENU=open` 自截图 `/tmp/cf93app_open_150.png`（1920×1080，0 警告 0 报错）。启动前后 `user://save.json` md5 一致（`738cc5ad…`，已备份在 `_backup_save/`）。
- 这次没动 `tools/art/generate.py`（面板文字走 `dyn_text` 动态字体，不是标签图集），所以没有重新生成素材。
- 验证状态见 C181：**测试、打包、启动、自检都在本机跑过；开工面板的排版没有人工目检**（自动化的像素校验在这台机器上不可靠，见 C179/C180 的教训）。


## v0.94：五口井各有各的长相（配色进 json，1 号井一个像素都没变）
- `docs/MINES_PLAN.md` 早就写了五口井的矿脉阶梯（灰岩／赤铜／蓝晶／地火／星陨），但画面是同一套石头颜色，挖 5 号井和挖 1 号井长得一样。这次把"每口井长什么样"做成数据。
- `data/balance.json` 新增 `mine.shaft_themes`（1–5 号各一条：`name` + `dirt`/`stone`/`rock`/`deep`/`rim` 五个部位的**调色板键** + `mix` 染色强度）和全局兜底 `mine.shaft_theme_mix`。**颜色存的是单字母调色板键，不是十六进制**——沿用 `presentation/palette.gd` 生成出来的 `Pal.BY_KEY`，所以既不会画出 24 色以外的颜色，也不用改任何生成脚本（这次没动 `tools/art/`，素材一张都没重生成）。
- `core/mine.gd` 新增 `shaft_theme()`（没写的井退回 1 号井）、`shaft_name()`（没有这条或没写名字就叫"N 号井"，**不会把别的井的名字套过来**）、`shaft_color(id, slot)`（不认识的部位退回石头色）、`shaft_mix(id)`（每口井自己的 `mix` 优先，没写用全局值）。core 里只出现"键字符串"和浮点数，不出现 `Color`。
- `presentation/mine_view.gd`：`_block_color()` 多一个井号参数（迷你地图、碎块两处跟着改）；新增 `_shaft_color()` / `_shaft_now()` / `_tint()`；`_draw_mine()` 里石头·岩壁·崖壁用 `rock_tint`、地板用轻一档的 `floor_tint`、崖边描边用主题的 `rim`；`_draw_wall()` 的描边色从写死的木褐改成参数。票务工位每一行、下井提示都带上井名。
- **染色只改色相不改明暗**：`_tint()` 把主题色先除以它自己的亮度再按比例混进白色。第一版直接用主题色当 modulate，深色的 4/5 号井越染越黑、几乎看不出是"另一种石头"；改成亮度归一后，实测五口井亮区亮度只差 1.3% 以内、石头区平均色却明显分开（2 号井偏红、3 号井蓝通道最高、4 号井最橙、5 号井偏紫）。1 号井 `mix = 0` → 染色值是纯白 modulate，画面与 v0.93 逐像素一致。
- 调试口子上补了三件事（都只在调试构建生效）：`CATFISH_SAVE=目录` 把存档和事件日志整个挪走（**命令行调试务必带上**，别墅玩家的真存档）、`CATFISH_SHAFT=N` 直接开进某一口井、`CATFISH_SEED` 在矿井里也钉死本局地图种子（两张截图只差颜色，好比对）。`CATFISH_REGION` 现在会顺手把小猫放到矿山岛上（`Journey.Activity.ISLAND`），否则 `mine_view.active()` 每帧被 `journey.on_island()` 踢掉，截出来整屏是黑的。
- 测试：新增 `test_v094_shaft_themes`（**18 项**），检查数 **943 → 961**。覆盖：五口井都有主题、每条都写了名字/五个部位/染色强度、**所有颜色键都能在 `Pal.BY_KEY` 里查到**、没有十六进制、五个名字都含"矿井"且互不相同、五口井石头色两两不同、**1 号井四色仍是 `O`/`a`/`A`/`S` 且 `mix == 0`**、2–5 号井 `mix` 落在 0.3–0.8、没写主题的井号退回 1 号井、问不存在的部位退回石头色、每口井的 `mix` 优先于全局、换个存档颜色照 json 走、**主题不会被抄进存档里存两份**。
- 本机实跑：`ALL TESTS PASS`（**961 项 0 失败**）+ `SIM PASS`，退出码都 0、0 条 `SCRIPT ERROR`、0 条 `WARNING`。五口井各截一张 1920×1080（同一颗种子、frame 200），0 条 `SCRIPT ERROR`、0 条"标签图集缺少文字"，像素比对结果记在 C182。打包：`./打包游戏.command` → `✓ 自检通过`，产物 **`build/CatFishing_v0.94_Qwen.app`**（163 MB，`CFBundleShortVersionString=0.94`，`codesign -v` 通过，200 帧无界面启动 0 报错），另打调试包 `build/CatFishing_v0.94_Qwen_debug.app`（178 MB）+ 启动脚本，`build/CatFishing.app` 已指向 v0.94。**打包好的调试包**也逐口井跑过：`CATFISH_SHAFT=1` 与 `=3` 两张截图 18.3% 像素不同、亮区亮度只差 0.4%（详见 C182）。
- **踩过的坑（记下来免得再犯）**：①`Godot --user-dir` 对本项目无效，真存档照样被写——已改成游戏内的 `CATFISH_SAVE` 覆盖 `SaveService`/`EventLog` 路径，并在每次命令行启动前后核对真存档 md5；②`OS.set_user_data_dir()` 在 Godot 4.7 的 GDScript 里不存在（解析期就报错）；③`CATFISH_RUN` 嵌在 `CATFISH_REGION` 里面，只给 `CATFISH_RUN` 不会开局；④四个 Godot 编辑器并发跑同一个工程会互相抢导入锁，刷出上万条 `SCRIPT ERROR`，串行跑就没这事。
- 顺手修了 `打包游戏.command` 的一个小毛病：同步版本号到 `export_presets.cfg` 的正则只认 `application/short_version="…"` 这种写法，本工程里写的是行首的 `short_version="…"`，所以那次同步**从来没生效过**（预设里一直停在 0.92；打包出来的 `Info.plist` 靠 `project.godot` 才是对的，所以没被发现）。改成两种写法都认，重新打包后预设里也是 `0.94` 了。
- 验证状态见 C182：**测试、打包、启动、自检、像素比对都在本机跑过；五口井配色的"好不好看"没有人工目检**（本代理没有视觉能力，像素比对只能证明"色相分开了、亮度没塌"）。


## v0.95：井底的天、黑暗和灯光也跟着井走（石头之外的另外三个颜色）
- 接 v0.94：五口井的**石头**分开了，但井底那块背景（`Pal.U_K` 深紫黑）、四周压下来的黑暗（写死的 `Color(0.03,0.02,0.05)`）、矿石反光（写死的 `Pal.L_Y`／`Pal.L_C`）还是全场一套，`docs/MINES_PLAN.md` 里"各井的背景主题"这条只算做了一半。
- `data/balance.json` 的 `mine.shaft_themes` 每条加三个键：`bg`（背景底色）、`fog`（黑暗叠加）、`lamp`（灯光/反光）。**存的还是单字母调色板键**，不是十六进制；1 号井给的是 `K`／`K`／`y`（就是原来那三个颜色），2 号井 `O`／`O`／`h`（铜炉子）、3 号井 `B`／`B`／`c`（冰蓝）、4 号井 `R`／`R`／`f`（地火）、5 号井 `S`／`S`／`W`（星陨青）。
- `presentation/mine_view.gd` 新增三个**静态**纯函数，好让无界面测试能直接调用比对：`shaft_backdrop(key, mix)`（背景最多混一半，别把井底染成彩色）、`shaft_darkness(key, mix, a)`（主题色先压到 16% 亮度再混，透明度原样传下去）、`shaft_lamp(key, mix)`（主题色提亮 35% 当色温）。`_draw_mine()` 里的背景矩形、黑暗叠加、矿石反光三处改成走这三个函数；主题计算挪到背景之前（顺便踩了一次坑：`m.game.mine` 没有类型，`var x := m.game.mine.shaft_color(...)` 推不出类型，编译期就炸，必须显式写 `: String`）。
- **1 号井的不变式改成用精确等式断言**（不再靠像素比对）：`shaft_backdrop(1 号井的 bg, 0.0) == Pal.U_K`、`shaft_darkness(..., 0.0, 0.5) == Color(0.03,0.02,0.05,0.5)`、`shaft_lamp(..., 0.0) == Pal.L_Y`。混 0 成 = 一个字节都没改，比截图对比重。
- 测试：新增 `test_v095_shaft_backdrop`（**17 项**），检查数 **961 → 978**。覆盖：五口井都写了 `bg`/`fog`/`lamp` 且全是 `Pal.BY_KEY` 里的键；背景色、灯光色各至少 4 种不同、五口井背景两两不同；混 0 成的三个精确等式；2–5 号井背景确实不等于 `Pal.U_K`；**染完色背景亮度仍 ≤ 0.25、黑暗亮度 ≤ 0.06**（不会把矿洞照亮、不会变彩色卡片）；灯光不低于原暖黄亮度的一半（反光点还看得见）；写错的键退回 `Pal.U_K`；`mix` 写大了夹到 1、写负数等于不染。
- 本机实跑：`--import` 0 报错；`ALL TESTS PASS`（**978 项 0 失败**）+ `SIM PASS`，退出码 0、0 条 `SCRIPT ERROR`、0 条 `WARNING`。同一颗种子（`CATFISH_SEED=777`）五口井各截一张 frame 200，5 张都 0 报错 0 缺字。**暗区平均 RGB 实测**：1 号井 `(26.5,20.0,35.0)`（与 v0.94 的截图一致，0.03 的差是小猫随机走动带来的采样噪声，不是颜色变化）；2 号井红通道升到 27.8、蓝降到 34.0（偏暖）；3 号井蓝 37.3 最高（偏冷）；4 号井红 29.0 最高（最暖）；5 号井绿 22.0 + 蓝 35.8（青蓝）。整体亮度 39.7–41.0、亮区亮度 125.6–126.4 → 染色没把矿洞变亮。
- 打包：`./打包游戏.command` → `✓ 自检通过`，产物 **`build/CatFishing_v0.95_Qwen.app`**（163 MB，`CFBundleShortVersionString=0.95`，`codesign -v` 通过，200 帧无界面启动 0 报错），调试包 `build/CatFishing_v0.95_Qwen_debug.app`（178 MB，签名通过）+ 启动脚本已生成，`build/CatFishing.app` 指向 v0.95。调试包真机跑 `CATFISH_SHAFT=5` 进对井、0 报错、只写 `/tmp/cf_user95app/save.json`。启动前后真存档 md5 仍是 `738cc5ad…`。
- 顺便说明**为什么 1 号井的像素对比这次不算证据**：矿洞的黑暗是绕着小猫一格一格压暗的，小猫每帧随机走一格的步，整屏就有三成以上像素会变（实测 v0.94→v0.95 的 1 号井整屏 36.7% 像素变了、但暗区平均色只差 0.03），所以逐像素 A/B 在这种场景下本来就没意义，改用上面的精确等式来保证 1 号井不变色。
- 验证状态见 C183：**测试、打包、启动、自检、暗区取色都在本机跑过；"好不好看"没有人工目检**（本代理没有视觉能力）。


## v0.96：矿石终于进图鉴了（挖到过什么矿，翻开就能看到）
- 接 v0.95：`docs/MINES_PLAN.md` 的"还没做（等用户定）"里只剩**矿石的用途**这一条。这一版先把"看得见"的部分做掉：**挖到过的矿石进图鉴册**，和鱼一起收集。用户离开前授权自由发挥，所以这一条按最保守的做法做（只加记录、不改任何价格/掉落数值、不给矿石加消耗）。
- 存档只多一个键：`stats["ore_counts"]`（矿石物品 id → 挖到过几块）。在 `core/game_state.gd` 的 `stats` 默认值里加了个空字典。`GameState._merge()` 只覆盖"存档里已有的键"，所以**老存档读进来自动补上这个空键，不需要迁移、不升 `save_version`**。
- `core/mine.gd`：`_break_cell()` 里石头碎掉、矿石进物品栏的**那一行后面**调 `_record_ore(item, cnt)`。这行前面已经先写了 `run()["dug"][key] = 1`，一格石头只会碎一次，所以计数**天然幂等**（同一格重复提交不会重复加），不需要额外去重。新增三个只读接口：`ore_dex()`（全部矿石，顺序就是 `mine.ores` 在 json 里的顺序 = 越深的井越靠后，并去重）、`ore_dug_count(id)`、`dex_found()`（见过几种）。
- `presentation/book.gd`：图鉴册第 1 页"图鉴"原来是 10 条鱼，现在是**先鱼后矿石的一整串卡片**，翻页直接跨过两段（38 种矿石接在鱼后面）。没见过的矿石画一个**空框 + "？？？"**，不露图；见过的画真图标 + 名字 + `x数量`。底栏左边原来只有"共钓到 77"，右边加了 **"矿石 6/38 种"**。新文字全部走 `m.dyn_text()`（运行时点阵字），所以**这一版没有重新生成素材、没动 `LABELS`**。
- 翻页的算术抽成静态纯函数 `Book.dex_pages_for(total, per)`（`per` 给 0 时当 1 张一页，不会除零），`dex_pages()` 调它。这样"要翻几页"能在无界面测试里断言，不用真的开一个窗口。
- 调试钩子扩展：`CATFISH_BOOK=N` 原来只播鱼的数据，现在**顺手播 6 种矿石**进去；想指定点亮几种用新的 **`CATFISH_ORES=N`**（不给就是 6 种）。
- 踩到的两个坑（都记下来免得再踩）：① 和 v0.95 的 `fog_key` 同一类——`m.game`、`game.mine` 这些成员**没有类型**，`var nf := g.fish_list.size()` 推不出类型，编译期就 `Cannot infer the type`，必须写成 `var nf: int = int(...)`。② 测试里想把小猫摆到指定格子：`run["x"]/["y"]` 和 `run["fx"]/["fy"]` **必须同时写**——`fpos()` 只认"整数格对得上"的偏移，光写 `fx/fy` 会被丢掉退回整数格中心；而且**往下挖必须比格中心偏 0.2 格**，否则 `target()` 的探测距离够不着下面那格（第一次跑测就因此 6 项失败）。
- 测试：新增 `test_v096_ore_dex`（**19 项**），检查数 **978 → 997**。覆盖：图鉴里矿石种数 = `mine.ores` 条数（38）且无重复；每种矿石都能在 `inventory.by_id` 里查到（名字和图标对得上）；新存档一种都没见过；**真的挖碎一块埋着矿的石头 → 图鉴记 1 块、见过 1 种**；再挖同一格不会变 2 块（幂等）；存档往返后计数还在；把 `ore_counts` 这个键从存档里删掉也读得回来（当一种都没见过、不报错）；`dex_pages_for` 的翻页算术（12 张一页要翻 ≥3 页、刚好一页/空图鉴都只 1 页、多一张多一页、每页 1 张时 13 页且不会除零）。
- 本机实跑：`--import` 0 报错；`ALL TESTS PASS`（**997 项 0 失败**）+ `SIM PASS`，退出码 0、0 条 `SCRIPT ERROR`、0 条 `WARNING`。图鉴页截图：`CATFISH_BOOK=0 CATFISH_ORES=6` 与 `CATFISH_ORES=38` 各一张 1920×1080（`CATFISH_SAVE=/tmp/cf_user96` 挪开真存档），**两张都 0 报错、0 缺字**；两张只有 **0.46%（9576 个）**像素不同、差异全部落在图鉴册那块面板内（x 252–1817、y 54–1067 的稀疏文字/图标点），说明矿石卡确实在按 `ore_counts` 画、而且没碰到画面其它地方。
- 打包：`./打包游戏.command` → `✓ 自检通过`，产物 **`build/CatFishing_v0.96_Qwen.app`**（163 MB 通用二进制，`CFBundleShortVersionString`/`CFBundleVersion` 都是 0.96，`codesign -v` 退出码 0），`build/CatFishing.app` 已指向 v0.96；调试包 `build/CatFishing_v0.96_Qwen_debug.app` + 启动脚本同版本生成。全程真存档 md5 仍是 `738cc5ad…`。
- **还没做**：矿石的"用途"目前只到"看得见"——**工坊合成、任务需求**还没有，矿石仍然只进不出（除了直接在物品栏卖钱）。这条继续挂在 `docs/MINES_PLAN.md` 等用户定。
- 验证状态见 C184：**测试、打包、自检、图鉴页截图取色都在本机跑过；图鉴页的排版与"好不好看"没有人工目检**（本代理没有视觉能力，像素差异只能证明"矿石卡在画、且只画在面板里"）。


## v0.97：退出时不再漏对象，打包自检不再碰你的存档（这版全是"收尾"）
- 起因是 v0.96 打包自检的日志：`--verbose` 退出时引擎报 **`ERROR: 2 resources still in use at exit`** + **`WARNING: 5 ObjectDB instances were leaked at exit`**，还有 **227 条 Orphan StringName**（`_fronts`、`_draw_drops`、`ROOM_MIN_X` 这些名字全在门面和小镇那边）。当时当成"退出时的噪音"放过了，这版去查：**是真泄漏，不是噪音**。
- 查出来的环：`presentation/world.gd` 是 `extends RefCounted` 的助手类，`_fronts = Shopfronts.new(self)` 把门面（也是 RefCounted）存进成员；而 `shopfronts.gd` 的 `_init(world)` 又 `w = world` 把 World 存了回来。**两个引用计数的对象互相指，谁都归不了零**，于是这两个脚本资源永远释放不掉 → 引擎报的就是那两行。单向持有本身没问题（持有者被释放时被持有者跟着归零），**坏在来回指**。
- 修法（`presentation/shopfronts.gd`）：门面不再存 World，改成构造时把地面高度**抄成数值** `var _gy0: float`，`_gy()` 返回它；`m`（主节点）照旧存——**Node 的引用不参与引用计数，不会成环**。`GROUND_Y` 是 `const`（124），抄一份数值不存在"过期"的问题。改动只有这一处，`Shopfronts.new(self)` 两个调用点一个字没动。
- 防再犯（`tests/run_tests.gd::test_v097_no_helper_cycles`，**15 项**，检查数 **997 → 1012**）：扫 `presentation/*.gd`，先认出头一行是 `extends RefCounted` 的助手，再找出"谁把哪个助手赋给了自己的成员"画一张**单向图**，最后只拦**来回指的环**（A 存 B 且 B 存回 A）。另外钉住这次的具体现场：门面不许再出现 `var w`、不许再出现 `w.GROUND_Y`、`_gy0`/`return _gy0` 要在、`GROUND_Y` 必须还是 `const`（否则抄数值就危险）、门面在单向图里必须是叶子，外加三个画面脚本还能编译。
- 另一件更要紧的：**`打包游戏.command` 的两帧自检以前是拿玩家真实用户目录跑的**。游戏一启动就写 `user://save.json`，等于**每打一次包就把你的真存档重写一遍**——v0.96 那次真存档多出空键 `stats.ore_counts` 就是这么来的（那次没有丢进度，但这条路本身迟早出事）。现在自检把 `HOME` 用 `mktemp -d` 挪到临时目录，跑完整个目录删掉；`bash -n` 语法自检通过。**实测打包前后真存档 md5 一模一样**（`9eca58e9…` → `9eca58e9…`），临时目录里只有它自己写的 1562 字节新档。
- 本机实跑（都在真 macOS / Godot 4.7.2 上）：`--import` 0 报错；`ALL TESTS PASS`（**1012 项 0 失败**）+ `SIM PASS`，两者退出码 0、**0 条 `SCRIPT ERROR`、0 条 `WARNING`**；`./打包游戏.command` → `✓ 自检通过`，产物 **`build/CatFishing_v0.97_Qwen.app`**（163 MB，x86_64 + arm64，`codesign -v` 退出码 0，版本号 0.97）+ 调试包 `CatFishing_v0.97_Qwen_debug.app`（178 MB，临时签名退出码 0）。
- 泄漏修没修好，用**同一套关键字**（`Leaked instance|still in use|Orphan StringName`）前后各量一次（都带 `--verbose`、都带 `HOME=/tmp/…` 隔离）：**改之前** —— 矿洞（v0.96 调试包，`--quit-after 240`）**64 行**（孤儿 StringName 55 条）、图鉴页（同一个包）**64 行**（55 条）、小镇（v0.96 代码，编辑器外 `--path .`，`--quit-after 300`）**236 行**（227 条；引擎那两行是 `5 ObjectDB instances were leaked` + `2 resources still in use at exit`）。**改之后** —— 同样的三种画面各跑一次 + Release 包 200 帧 + 调试包 240 帧：**全部 0 行**，退出码 0、0 条 `SCRIPT ERROR`。
- 画面有没有被改坏：同版本两次运行的整屏像素差是 **10.98%**（街上的人会走、天色在变，这就是噪声地板），改动前后的差只有 **1.54%**，店面那一带（y 560–760）三张图平均 RGB 差 **≤0.12/255**。也就是说**看不出这次改动动过画面**，加上改的是常量抄数值，逻辑上也不可能变。
- 验证状态见 C185：测试、打包、自检、三屏泄漏测量、真存档 md5 对比都在本机跑过。**没做人工目检**（本代理没有视觉能力），也没量过 Intel 机器。


## v0.98：给"挂机"这件事装了体检表（挂多久涨不涨内存、每个画面退出漏不漏对象）
- v0.97 修完泄漏后，我在"没验证"里写了两条一直没人补：**挂机几小时的内存曲线没量过**、**其它画面的泄漏没量过**。这版就把这两件事变成**随时能复跑的脚本**，而不是每次靠我手敲一长串命令。
- 新增 `tools/perf/leak_sweep.sh`：把调试包在**十二个画面**各启动一次、各跑几百帧、退出，只盯引擎退出时的三类关键字（`Leaked instance`／`still in use`／`Orphan StringName`）。覆盖：家里、小镇、镇上屋里、矿山岛、矿车大厅、矿井里、物品栏、菜单、邮局、图鉴册、睡觉、下雨。任何一个画面报泄漏就退出码 1，并把那几行原样打出来。
- 新增 `tools/perf/idle_rss.sh`：把游戏开着**什么都不做**，每 5 秒用 `ps -o rss=` 采一次常驻内存 + CPU，最后按"热身 30 秒后，末段平均比首段平均高出 20% 且绝对值 > 20 MB"判"在涨"。**读的是 RSS（常驻内存）不是虚拟内存**，退出时把临时目录 `rm -rf` 掉。
- 两个脚本都钉死一条卫生规则：**存档一律写到 `mktemp` 的临时目录**（`HOME` + `CATFISH_SAVE` 双保险），绝不让体检顺手重写玩家的真存档。这条由 `test_v098_perf_hygiene`（**13 项**，检查数 **1012 → 1025**）兜底：扫 `tools/perf/*.sh`，少一个脚本没带 `mktemp` + `CATFISH_SAVE` 就红；顺带钉住扫描脚本要开 `--verbose`、要认那三类关键字、画面数 ≥ 10、挂机探针读的是 RSS，以及 `打包游戏.command` 的临时 HOME（v0.97 的规则）和 `FPS_NORMAL := 30` / `FPS_HIDDEN := 5` 两个常量还在。
- 本机实测（真 macOS / Godot 4.7.2，`build/CatFishing_v0.98_Qwen_debug.app`）：
  - **挂机 4 分钟内存不涨**：`./tools/perf/idle_rss.sh 4` → 热身 30 秒后**首段平均 166.0 MB → 末段平均 167.0 MB（+1.0 MB / +0.6%）**，热身后的区间 166–167 MB；**CPU 平均 5.2%、最大 5.6%（单核=100%）**；脚本判 `✓ 判定：挂着没一直在涨`，退出码 0。
  - 拿 v0.97 的调试包再跑一次同样的 4 分钟做对照：首段 209.6 MB → 末段 191.0 MB（**−18.6 MB / −8.9%**，是往下走的），CPU 平均 5.1%。两次都没出现「一直在涨」。（两次开局画面不完全一样，绝对值别横着比，只看各自曲线斜率。）
  - **十二个画面退出时零泄漏**：`./tools/perf/leak_sweep.sh 240` → 家里／小镇／镇上屋里／矿山岛／矿车大厅／矿井里／物品栏／菜单／邮局／图鉴册／睡觉／下雨，**每行退出码 0、泄漏行 0、`SCRIPT ERROR` 0、缺字 0**，最后一行 `✓ 泄漏扫描通过：12 个画面退出时都没有泄漏（每个 240 帧）`，退出码 0。（同脚本对 v0.97 的调试包也跑过一次，同样 12/12 干净。）
- 顺手确认了一件事：桌面宠物**不是满帧在画**。`presentation/main.gd` 平时就限 30 帧（`FPS_NORMAL := 30`），窗口最小化直接降到 5 帧（`FPS_HIDDEN := 5`），逻辑照常靠时间戳推进（不靠帧数）——上面那个 CPU 数字就是在这个限帧下量出来的。
- 本机实跑：`--import` 0 报错；`ALL TESTS PASS`（**1025 项 0 失败**）+ `SIM PASS`，退出码 0、0 条 `SCRIPT ERROR`；`./打包游戏.command` → `✓ 自检通过`，产物 **`build/CatFishing_v0.98_Qwen.app`**（163 MB 通用二进制，`codesign -v` 退出码 0，版本号 0.98）+ 调试包 `CatFishing_v0.98_Qwen_debug.app`（178 MB，临时签名退出码 0）。**打包前后真存档 md5 一字不变**（`9eca58e9…`）。
- 这版**没动任何玩法、数值、存档字段**，只加了两个 `tools/perf/` 脚本 + 一个卫生规则测试。
- 验证状态见 C186：两个脚本都在本机真跑过，数字是采出来的。**没做人工目检**，也没量过 Intel 机器和真正的"挂机一整夜/一整天"（只量了几分钟一段的曲线）。


## v0.99：体检从"十二个画面"扩到"三十五个画面"，而且每个画面都留一张截图当证据
- 上一版的扫描只覆盖十二个画面。这版把 `tools/perf/leak_sweep.sh` 的画面表扩到 **35 个**：家里、迷你视图、小镇、钓鱼中、专注中、休息中、镇上屋里、矿山岛、矿车大厅、开工面板、矿井里、矿井开挖、矿山岛屋子、物品栏、菜单、邮局寄件／取件／会员、会员柜翻页、图鉴册、固定形象（菜单图鉴页）、睡觉、夜晚、下雨、**读信、任务对话、服装店、造船厂、鱼篓视图、商店分页、设置页、状态页、任务页、鸟来访、摆摊卖货**。全部用**已有的** `CATFISH_*` 调试变量拼出来，没为扫描新加任何调试入口。
- 更关键的是**证据**：以前只报"退出时漏没漏"，万一某个画面压根没打开，扫描照样绿。现在每个画面都带 `CATFISH_SHOT` 在倒数第 40 帧截一张图，**截不到图（或图小于 120 KB）直接判这次扫描没跑成**（退出码 1），截图统一收到 `/tmp/catfish_sweep_shots/序号_画面名.png`，不会跟着临时目录一起被删。
- 顺手抓到自己的两个 bug（都是上一版脚本留下的）：
  - `idle_rss.sh` 采完样**没关游戏**，桌面上留了三个开着的游戏窗口（都是探针起的，存档在临时目录）。现在采完 `kill -TERM`，十秒不退再 `-KILL`，并打一行"已关掉探针开的那个游戏窗口"。
  - 画面表里有一行标着"衣柜"，其实 `CATFISH_MENU=2` 打开的是菜单第 3 页（图鉴）。**衣柜这个面板按 D152 已经废了**（形象固定后不再有捏猫面板），所以那行改名成"固定形象"，并注明它开的是图鉴页——不是漏扫了一个画面，是根本没有那个画面。
- 测试：`test_v098_perf_hygiene` 加四项（**1025 → 1029**）——扫描脚本必须带 `CATFISH_SHOT` 且认 `.png`；必须有"没截到图"这条失败判据；必须有"跟基线一帧不差"这条（面板没弹开但游戏照常画一帧的那种）；必须支持 `LEAK_ONLY`。画面数门槛从 ≥10 提到 **≥30**（实际 35）。
- README 的 `CATFISH_MENU` 说明原来写 `0..3`，实际 `presentation/menu.gd` 的 `TABS` 有 **6** 页（商店／图鉴／统计／设置／状态／任务），改成 `0..5`。
- 截图当证据这件事我踩了自己一版坑：一开始把"图小于 120 KB 判失败"当门槛，结果**迷你视图（5 KB）和矿洞（20 KB）被误判成坏画面**——深色、平涂的一屏本来就能压到几十 KB。改成**只把"压根没截出图"当失败**，体积只当参考列在表里。
  但"有图"不等于"画面打开了"：面板没弹开时游戏照样正常画一帧。所以加了一条真判据——**某个画面的图和基线画面（列表第一个，就是"家里"）逐字节相同 → 判失败**，说明那个面板根本没弹开。（顺带：两个画面之间完全相同只提示、不判死，免得把"夜晚"和"下雨"这种本来就接近的画面误杀。）
- 加了 `LEAK_ONLY=小镇,矿井里 ./tools/perf/leak_sweep.sh` 这样的过滤：不然调一个画面要等一整轮半小时。
- **这轮扫描真的抓到一个玩家看得见的 bug**：商店第 2 页（鱼饵页）要画 `"买来的鱼饵每竿用 1 个"`，可这句**不在标签图集里** → 引擎 `push_warning("标签图集缺少文字…")` 之后**整条文字被跳过**，那句提示玩家一个字都看不见。
  修法按规矩走：把这句加进 `tools/art/generate.py` 的 `LABELS` → 重新生成素材（`labels.png` 从 4870 变 4880 像素宽，`presentation/labels.gd` 多出这条键）→ 重新导入 → 重打两个包。
  一开始我把"缺字"只当提示，改成**硬失败**之后才逼着自己去修——不然它就永远是表里一个不起眼的"缺字"。
- **静态补一层，别等运行时**：新增 `test_v099_label_atlas_coverage`——把 `presentation/*.gd` 里所有 `label(...) / label_left(...) / label_center(...) / label_right(...)` 的**中文字面量**扫一遍，要求每一条都能在上 `Labels.RECTS` 里找到（跳过 `%` 格式串和 `"…"` 后面接 `+` 的拼接串）。
  为什么之前的测试没抓到：v0.90 那条只抽查了 `World.SPOT_HINT` 和 `_island_hint()` 两处，**没有扫调用点**。检查数 **1029 → 1035**。
- 生成素材这轮踩了两个环境坑（都记下来，下次别再摸黑）：
  1. Xcode 命令行工具自带的 `python3`（3.9.6）跑 `tools/art/generate.py` 会报 `SyntaxError: Non-UTF-8 code starting with '\xe7' … but no encoding declared`——这台机器 `LANG=C.UTF-8` 但 `LC_CTYPE` 是空的，那份源码里全是中文。**已在 shebang 后加一行 `# -*- coding: utf-8 -*-`**，谁在什么 locale 下跑都一样。
  2. 这个仓库的素材生成需要 `Pillow`（画图）、`fontTools`（量字宽）、`numpy`（主角走路图还原）。三个都得装上才能跑通 `build()`。
- 重生成会把**所有** 226 张 PNG 重写成新的字节（Pillow 版本不同 → 压缩/滤波不同，像素不变）。我用脚本逐张比对：**225 张和 HEAD 像素完全一致**，只有 `assets/sprites/labels.png` 真的变了（就是这次要改的那张）。剩下的全部 `git checkout` 回 HEAD，别把重编码的噪声混进提交。
- 差点闯祸一次：清理 `__pycache__` 时我 `rm -rf tools/art/__pycache__`，把仓库里**已经提交**的三个 `.pyc`（cpython-310/312/313）一起删了，已 `git checkout --` 原样恢复。
  规矩：**清临时产物只删自己刚生成的那一个文件，不整目录 `rm -rf`**——这仓库里有历史提交的 `__pycache__`。
- 本机实测（`build/CatFishing_v0.99_Qwen_debug.app`，每画面 240 帧）：`退出码 0；`✓ 泄漏扫描通过：35 个画面退出时都没有泄漏、没有缺字，每个都留下了自己的截图（每个 240 帧）`；35 行**退出码全 0、泄漏行全 0、`SCRIPT ERROR` 全 0、缺字全 0**，35 张截图都落在 `/tmp/v099_shots/`（最小 5 KB＝迷你视图、最大 24 KB＝菜单）。唯一备注：`矿井开挖` 那一帧与 `矿井里` 逐字节相同（开挖动作在第 200 帧还没画进画面，只提示、不判失败）。`
- 本机实跑：`ALL TESTS PASS`（**1027 项 0 失败**，0 条 `SCRIPT ERROR`）；扫描脚本 `bash -n` 通过。
- 这版**没动任何玩法、数值、存档字段**，只改了 `tools/perf/` 两个脚本、README 一行和测试。
- 挂机内存（`./tools/perf/idle_rss.sh 4 build/CatFishing_v0.99_Qwen_debug.app`，热身后 30 秒不计）：**首段平均 248.1 MB → 末段平均 209.0 MB（−39.1 MB / −15.8%）**，区间 209.0–261.0 MB，末次采样 209.0 MB；**CPU 平均 5.2%、最大 6.1%**（单核=100）。判定 `✓ 判定：挂着没一直在涨`，退出码 0。
  别把单次数字当趋势：同一个 v0.98 包上一轮量到 166→167 MB，这轮 v0.99 首段 248 MB——**首段绝对值跟机器当时的状态强相关，只有同一轮里的"首段 vs 末段"差值有意义**。
- 探针这轮还证明自己会关窗口了：采完 `kill -TERM` 杀的是它自己开的进程，日志里那行 bash 的 `Terminated: 15` 是它亲手杀的（不是游戏自己崩），紧跟一句 `已关掉探针开的那个游戏窗口`。

## v1.00（2026-11-15）：存档不许"悄悄丢"——回退要吭声、写失败要说原因

### 为什么做这版
`io/save_service.gd` 早就有原子写 + `.bak` 回退，但**玩家不知道自己的进度丢了**：正式档坏了会自动去读 `.bak`（少一段进度）却一声不吭；写盘一直失败也只是每 5 秒闷头重试 + 写日志，玩家以为已经存好了，一关窗口全没。

### 改了什么
- `io/save_service.gd`
  - 新增 `last_source`（`main`／`bak`／空 = 一份都没读到）和 `last_error`（失败原因）。回退到 `.bak` 时 `push_warning`。
  - **改名顺序修好了**：老代码先 `remove(.bak)` 再 `rename(正式档 → .bak)`；万一改名失败，唯一的备份已经被自己删了。现在先直接改名，改不动才删旧备份再试一次。
  - 最后一步 `rename(.tmp → 正式档)` 失败时，把刚挪走的旧档**放回原位**，正式位置不空着；临时文件回读不合格就先删掉 `.tmp` 再返回 false。
- `presentation/main.gd`
  - 回退到备份 → 事件日志 `load_from_backup` + 屏幕提示（延后 3.4 秒弹）。
  - 写盘失败 → 这一串失败只记**一条** `save_failed`（带 `why=saver.last_error`，不再每 5 秒刷日志），之后每 20 秒提醒一次「存档没写进去／进度还在内存里，别关窗口」；写成功后记 `save_recovered`（带卡了多少秒）并提示「存档补上了」。
  - 关窗口这一下要是没写进去，**补试两次**（每次隔 200 ms），还不行记 `save_lost_on_quit`。
- 5 条新提示文字加进 `tools/art/generate.py` 的 `LABELS` 并重生成：226 张素材里**只有 `labels.png` 的像素变了**（4880 → 4930 宽，正好 5 条 × 10 px），其余 225 张与 HEAD 逐像素相同、已 `git checkout` 还原。
- 测试 **1035 → 1060**（新增 `test_v100_save_safety`：空目录／首写不冒 .bak／二写留旧档在 .bak／主档写坏自动回退并报 `bak`／两份都坏返回空不崩／写到"假目录"里返回 false 且带原因／提示文字必须在图集里）。

### 这轮我自己踩的四个坑（都改成断言或笔记钉住了）
1. **提示被同一帧的礼物提示顶掉**（真 bug，靠 A/B 才抓出来）：最早我也用 `call_deferred("_toast", …)` 弹回退提示，而它和 `apply_gift()` 的「收到一份礼物」排在同一帧，后弹的把先弹的覆盖 → **回退提示一个像素都没画出来**，日志有警告、画面没字。现在延后到 3.4 秒后由 `_update_save_notice()` 弹（用时间戳，不数帧）。
2. **第二轮 A/B 没信号，因为存档已经自愈了**：坏 `save.json` + 好 `.bak` 跑完一次，游戏退出时已经把坏档改名成 `.bak`、新档上位 → 第二次跑读到的是好档，不再回退。这本身是**好事**（存档会自己修好），但意味着**每次 A/B 之前必须重新制造坏档**，不然对照组会偷偷变成实验组。
3. **`DirAccess` 的实例方法把目录建到别处**：`DirAccess.open("user://").make_dir_recursive_absolute("t100")` 返回 `OK`，实际却把 `t100/` 建到了**进程当前目录**（项目里凭空多一个空目录，差点混进提交），`user://` 那边根本没建。要用**静态**方法 + `user://` 全路径（`io/event_log.gd` 一直就是这么写的）。两个多余目录都已 `rmdir`，真存档 md5 全程一字不变。
4. `///` 注释在 GDScript 里是语法错误（要 `##`）：`main.gd` 编译不过时连带 9 项测试一起红，`SPRITES 列了 0 张贴图` 那串红全是它的连带伤，不是真问题。

### 实测（本机 macOS 真跑过的）
- `--script res://tests/run_tests.gd` → `ALL TESTS PASS`，**1060 项 0 失败**，`SCRIPT ERROR` 0 条。
- `--script res://tests/sim_long_run.gd` → `SIM PASS`，0 报错。
- `--headless --path . --import` → 退出码 0，0 报错。
- `./打包游戏.command` → `✓ 自检通过`；`build/CatFishing_v1.00_Qwen.app`（通用二进制，版本号 1.00，`codesign -v` 0）；调试包 `--export-debug` + `codesign --sign -` + `xattr -cr` 全部退出码 0。**打包前后真存档 md5 一字不变**（`9eca58e9…`）。
- **提示到底画没画出来（这次做了 A/B）**：造两份存档各跑两次（同 `CATFISH_SEED=7`，第 120 帧截图）——`/tmp/v100_bad`（坏 `save.json` + 好 `save.json.bak`）vs `/tmp/v100_good`（正常档）。同存档重复跑的差异 = 噪声地板 **3000 px**；两次独立 A/B **都**不同、且不在噪声里的稳定差异 **21708 px**，包围盒 x 36–569／y 402–521，颜色全是同一个 `(120,48,52)`（标签墨色压在深色面板上）。按基座 960×540、像素风 3 倍、Retina 再 2 倍折算：`label(_toast_l1, (17,63))` 应落在 (36, 396)，实测 36／402 起 —— **位置对得上，就是那条提示**。探针日志 `BAKNOTICE fired at frame 102`（≈3.4 秒）。
- `./tools/perf/leak_sweep.sh 240 build/CatFishing_v1.00_Qwen_debug.app /tmp/v100_shots` → 退出码 **0**：`✓ 泄漏扫描通过：35 个画面退出时都没有泄漏、没有缺字…`；35 行退出码／泄漏行／`SCRIPT ERROR`／缺字**全 0**，截图 35 张 5–25 KB；软提示仍只有 `矿井开挖 与别的画面完全相同`。
- 提交 `60d04f2`、标签 `v1.00-qwen`，已推到 `origin/Qwen-v1.00`（本地分支仍叫 `qwen-v0.99`：本地名只是本机标签，历史一条线，不再每版改名）。

### 这版留下的可复用做法
- **画面提示要"证明画出来了"**：同种子跑两次同一份存档当噪声地板，再用两次独立 A/B 的**交集**减掉噪声，剩下的才敢说是提示本身（这次 21708 px vs 噪声 3000 px）。单张截图 + "日志里有警告"不够——日志有警告而画面一个像素没变，正是这版抓到的那个 bug。
- **A/B 前先确认实验条件可重复**：坏档会被游戏自己修好，第二次跑就不回退了。
- **下一版想收掉的一条软提示**：`矿井开挖` 那行的截图老是和 `矿井里` 一帧不差，因为 `CATFISH_DIG` 只在启动时 `start_dig` 一次，等扫描在第 200 帧截图时那一格早挖完了。打算加个调试开关 `CATFISH_DIGLOOP=1`（只在 `CATFISH_DIG` 存在时，每帧检查 `game.mine.digging()` 为假就重新 `start_dig`，让小猫一直挥镐），这样任意帧截出来的都是"正在挖"的画面，软提示自然消失。**这版没做**（怕和挂机探针抢机器，也不想在收尾时动 `main.gd`）。
- **挂机内存补测到 20 分钟**（`./tools/perf/idle_rss.sh 20 build/CatFishing_v1.00_Qwen_debug.app`，v0.99 只量过 4 分钟，这轮把那条"只量过一次 4 分钟"的欠账补上）：热身 30 秒后 **首段平均 184.2 MB → 末段平均 111.0 MB（−73.2 MB / −39.7%）**，热身后区间 109.0–261.0 MB，最后一次采样 111.0 MB；CPU 平均 **5.4%**、最大 6.8%（单核=100）；脚本自己关掉它开的窗口，判定 `✓ 挂着没一直在涨`。**还是别把绝对值当预算**：首段 261 MB 是启动后还没释放的那点东西，v0.99 那轮首段是 248 MB —— 只有同一轮里"首段 vs 末段"的差值有意义；而且 20 分钟仍然不是"挂几个小时"，更长的没测过。

