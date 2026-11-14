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
