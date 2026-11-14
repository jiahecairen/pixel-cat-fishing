"""矿山岛的矿石和 5 个矿井的数据（一次性生成 data/balance.json 里的 mine.mines / mine.ore_defs / 矿石物品）。
规则见 docs/MINES_PLAN.md。改数据改这里，再运行：python3 tools/mine_data.py"""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# id: (名字, 描述, 形状, 高光, 主色, 暗色, 卖价(铜), 硬度倍数)
ORES = {
 "stone":   ("石头", "最常见的石头，修东西要用", "chunk", "w", "a", "A", 3, 1.0),
 "coal":    ("煤块", "黑黑的，烧起来很旺", "chunk", "a", "A", "K", 4, 1.0),
 "metal":   ("金属", "含铁的矿块，能炼成铁", "chunk", "W", "a", "A", 9, 1.2),
 "gold_ore":("金矿石", "沉甸甸的金矿石，可以拿去卖", "nugget", "W", "y", "H", 16, 1.4),
 "tin_ore": ("锡矿石", "银白色的软金属矿", "chunk", "W", "w", "a", 14, 1.3),
 "quartz":  ("石英", "透明的白色晶体", "crystal", "W", "w", "c", 22, 1.5),
 "amber":   ("琥珀", "半透明的树脂化石", "nugget", "l", "h", "H", 34, 1.6),
 "garnet":  ("石榴石", "深红色的小宝石", "gem", "p", "r", "R", 52, 1.8),
 "moonstone":("月光石", "泛着蓝白光的稀有宝石", "gem", "W", "c", "b", 160, 2.0),
 "opal":    ("欧泊", "里面像有彩虹在流动", "gem", "W", "p", "c", 190, 2.0),
 "copper_ore":("铜矿石", "带着绿锈的红铜矿", "chunk", "n", "f", "F", 20, 1.3),
 "silver_ore":("银矿石", "亮闪闪的银色矿块", "chunk", "W", "a", "S", 36, 1.5),
 "jade":    ("翡翠", "温润的绿色玉石", "gem", "W", "g", "G", 55, 1.7),
 "lapis":   ("青金石", "深蓝色里点缀着金星", "chunk", "c", "B", "K", 78, 1.9),
 "topaz":   ("黄玉", "透亮的金黄色宝石", "gem", "W", "y", "H", 110, 2.1),
 "sunstone":("日光石", "像一小块凝固的阳光", "gem", "W", "y", "f", 260, 2.4),
 "peridot": ("橄榄石", "黄绿色的火山宝石", "gem", "W", "g", "y", 240, 2.3),
 "cobalt_ore":("钴矿石", "蓝色的金属矿，很硬", "chunk", "c", "b", "B", 48, 1.7),
 "sapphire":("蓝宝石", "深海一样的蓝", "gem", "W", "b", "B", 85, 2.0),
 "aquamarine":("海蓝宝", "像一滴凝固的海水", "gem", "W", "c", "b", 120, 2.1),
 "tanzanite":("坦桑石", "蓝紫色，换个角度换个颜色", "gem", "c", "p", "B", 170, 2.3),
 "azurite": ("蓝铜矿", "蓝得发黑的铜矿", "chunk", "c", "B", "K", 230, 2.4),
 "ice_crystal":("冰晶", "摸上去永远是凉的", "crystal", "W", "c", "b", 420, 2.7),
 "star_sapphire":("星光蓝宝石", "里面有一颗六芒星", "gem", "W", "c", "B", 460, 2.8),
 "sulfur":  ("硫磺", "黄色，味道很冲", "chunk", "y", "h", "H", 70, 1.9),
 "obsidian":("黑曜石", "火山冷却成的黑玻璃", "chunk", "a", "K", "K", 105, 2.1),
 "ruby":    ("红宝石", "烧得通红的宝石", "gem", "W", "r", "R", 150, 2.3),
 "fire_opal":("火蛋白石", "里面有一团火苗", "gem", "y", "r", "R", 210, 2.5),
 "magma_core":("熔岩核", "还是烫的，别直接抱着", "nugget", "y", "r", "R", 300, 2.7),
 "dragon_blood":("龙血石", "传说是龙留下的血", "gem", "p", "R", "K", 620, 3.0),
 "sun_gold":("日冕金", "比金子还要亮的金子", "nugget", "W", "y", "f", 680, 3.1),
 "meteorite":("陨铁", "从天上掉下来的铁", "chunk", "a", "A", "K", 130, 2.4),
 "mithril": ("秘银", "又轻又硬的银蓝色金属", "chunk", "W", "c", "a", 190, 2.6),
 "starstone":("星辰石", "夜里会微微发光", "gem", "W", "y", "A", 260, 2.7),
 "void_crystal":("虚空晶", "看久了会觉得在往里吸", "crystal", "p", "A", "K", 360, 2.9),
 "iridium": ("铱", "世上最重的金属之一", "nugget", "W", "a", "S", 480, 3.0),
 "aether":  ("以太晶", "轻得像是不存在", "crystal", "W", "c", "p", 880, 3.4),
 "world_core":("世界之核", "据说是这座山的心脏", "gem", "y", "W", "p", 960, 3.5),
}

# 每口井：start 前 20 层一开始的 4 种（按常见程度从多到少）；new 第 21/41/61/81 层各出现一种；rare 最后 3 层小概率。
# 第 21/41/61 层起依次不再出现 start 里最常见的前 3 种（最后一种一直都有）。
# 重复规则：start 里最多从上一口井"前 50 层出现过的矿"里借，第 21 层起全是自己的新矿。
MINES = [
 {"id": 1, "name": "灰岩矿井", "desc": "矿山岛最浅的一口井，石头和煤到处都是",
  "start": ["stone", "coal", "metal", "gold_ore"], "new": ["tin_ore", "quartz", "amber", "garnet"], "rare": ["moonstone", "opal"]},
 {"id": 2, "name": "赤铜矿井", "desc": "铁轨塌了的旧矿井，红铜和白银",
  "start": ["metal", "tin_ore", "quartz", "copper_ore"], "new": ["silver_ore", "jade", "lapis", "topaz"], "rare": ["sunstone", "peridot"]},
 {"id": 3, "name": "蓝晶矿井", "desc": "潮湿阴冷，岩缝里全是蓝色的光",
  "start": ["copper_ore", "silver_ore", "jade", "cobalt_ore"], "new": ["sapphire", "aquamarine", "tanzanite", "azurite"], "rare": ["ice_crystal", "star_sapphire"]},
 {"id": 4, "name": "地火矿井", "desc": "越往下越热，岩浆就在隔壁",
  "start": ["cobalt_ore", "sapphire", "aquamarine", "sulfur"], "new": ["obsidian", "ruby", "fire_opal", "magma_core"], "rare": ["dragon_blood", "sun_gold"]},
 {"id": 5, "name": "星陨矿井", "desc": "山最深处，陨石砸出来的洞",
  "start": ["sulfur", "obsidian", "ruby", "meteorite"], "new": ["mithril", "starstone", "void_crystal", "iridium"], "rare": ["aether", "world_core"]},
]
START_CHANCE = [0.16, 0.11, 0.08, 0.05]
NEW_CHANCE = [0.045, 0.04, 0.04, 0.035]
RARE_CHANCE = 0.012

def check():
    seen_early = set()
    prev50 = set()
    for k, m in enumerate(MINES):
        assert len(m["start"]) >= 3 and len(m["new"]) == 4 and len(m["rare"]) == 2
        for o in m["start"]:
            assert o in ORES
            if k > 0 and o not in m.get("own", []):
                pass
        if k > 0:
            allowed = prev50
            shared = [o for o in m["start"] if o in allowed]
            assert len(shared) >= 3, (k, shared)
            later = set(m["new"]) | set(m["rare"])
            assert not (later & set(sum([x["start"] + x["new"] + x["rare"] for x in MINES[:k]], []))), (k, "第21层起的矿不能和前面的井重复")
        # 本井前 50 层出现的矿（start + new[0], new[1]）
        prev50 = set(m["start"]) | set(m["new"][:2])

def apply():
    check()
    p = os.path.join(ROOT, "data", "balance.json")
    b = json.load(open(p, encoding="utf-8"))
    mine = b["mine"]
    mine["floors"] = 100
    mine["ore_defs"] = [{"id": k, "hard": v[7]} for k, v in ORES.items()]
    mine["ores"] = [{"id": k, "item": k, "hard_mul": v[7]} for k, v in ORES.items()]
    mines = []
    for m in MINES:
        mines.append({"id": m["id"], "name": m["name"], "desc": m["desc"],
                      "start": [{"id": o, "chance": c} for o, c in zip(m["start"], START_CHANCE)],
                      "new": [{"id": o, "chance": c, "from": 21 + 20 * i} for i, (o, c) in enumerate(zip(m["new"], NEW_CHANCE))],
                      "rare": [{"id": o, "chance": RARE_CHANCE} for o in m["rare"]],
                      "rare_floors": 3})
    mine["mines"] = mines
    items = [i for i in b["items"] if i["id"] not in ORES]
    old = {i["id"]: i for i in b["items"]}
    for k, v in ORES.items():
        it = old.get(k, {})
        it.update({"id": k, "sell": v[6], "name": v[0], "desc": v[1], "sprite": "item_" + k, "weight": 0, "use": "", "drop": ""})
        if k in ("stone", "metal"):
            it["important"] = True
        items.append(it)
    b["items"] = items
    json.dump(b, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    open(p, "a").write("\n")

if __name__ == "__main__":
    apply()
    print("ok", len(ORES), "种矿石")
