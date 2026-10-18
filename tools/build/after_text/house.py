"""蓝色小屋（战后）：楼下粉色公主的房间（after_house_objects）、楼上蓝色公主的房间（after_house_up_objects）、楼上的蓝色公主（after_blue_room）。
床：夜里、夜里的事件不在进行中（after_night_busy 没开）→ 睡觉（call after_sleep）；
    白天 → 可以休息到下一个时段（call after_rest：这个时段还有事没做时不让休息，AfterStory.rest）。
梦游的三处手印：clue_bed / clue_tea 随便先看，clue_stairs 要前两处都看过 → after_d1_clues + after_house_up_open（楼梯解锁）。
"""
from .common import BLUE, N, P, L

BUSY = "after_night_busy"

HOUSE = {"name": "", "entries": [{"node": "bed"}], "nodes": {
    "bed": {"goto": [{"if": {"flag": "night", "not": BUSY}, "node": "bed_sleep"}, {"if": {"flag": BUSY}, "node": "bed_busy"},
                     {"node": "bed_day"}]},
    "bed_day": {"lines": [L("……要不要躺一会儿？", P)], "prompt": "休息一下？", "choices": [
        {"text": "休息到下一个时段", "next": "bed_rest"}, {"text": "不了", "next": ""}]},
    "bed_rest": {"lines": [L("……就躺一会儿。一会儿就好……", P, "shy")], "set": {"call": "after_rest"}},
    "bed_busy": {"lines": [L("……那些手印还没弄清楚。睡不着。", P, "angry")]},
    "bed_sleep": {"lines": [L("……呼啊。今天就到这里吧……", P, "shy")], "set": {"call": "after_sleep"}},
    "window": {"goto": [{"if": {"flag": "night"}, "node": "window_night"}],
               "lines": [L("（窗外，队员们扛着木料走来走去）", N)]},
    "window_night": {"lines": [L("（窗外黑漆漆的。巡逻队员的灯笼，一晃一晃地走远了）", N)]},
    "painting": {"lines": [L("（一幅画：地面上的蓝天和草地）", N), L("……真的有这么蓝吗。", P)]},
    "wardrobe": {"lines": [L("（衣柜。蓝色公主借给她的几件衣服，叠得整整齐齐）", N)]},
    "bookshelf": {"lines": [L("（书架。《地面上的童话》被人抽出来过，放回去的时候插反了）", N)]},
    "dresser": {"lines": [L("（梳妆台。镜子里的自己，一脸灰）", N), L("……搬砖搬的。", P, "sad")]},
    "tea": {"lines": [L("（茶几上放着一盘饼干。是面包店的奶奶送来的）", N)]},
    "plant": {"lines": [L("（一盆小花。叶子上沾着一点墙灰）", N)]},
    # —— 梦游的三处手印
    "clue_bed": {"lines": [L("（床尾的被子被掀开了一角。手印就是从这里开始的，歪歪扭扭）", N),
                           L("……刚才就是从这儿钻进来的。脚心到现在还麻麻的……", P, "shy")],
                 "set": {"flags": ["after_d1_clue_bed"]}},
    "clue_tea": {"lines": [L("（茶几上的饼干少了两块。手印绕着茶几转了三圈，像小孩子在找好玩的东西）", N),
                           L("……偷吃饼干？这条裤子……是小孩子吗？", P, "surprise")],
                 "set": {"flags": ["after_d1_clue_tea"]}},
    "clue_stairs": {"goto": [{"if": {"flag": ["after_d1_clue_bed", "after_d1_clue_tea"]}, "node": "clue_stairs_ok"}],
                    "lines": [L("（楼梯上也有手印……房间里好像还有别的痕迹，先看看再上去）", N)]},
    "clue_stairs_ok": {"lines": [L("（手印顺着楼梯一节一节往上爬，最后消失在蓝色公主的房门口）", N),
                                 L("……楼上。果然。", P)],
                       "set": {"flags": ["after_d1_clues", "after_house_up_open"]}},
}}

HOUSE_UP = {"name": "", "entries": [{"node": "bed"}], "nodes": {
    "bed": {"lines": [L("（蓝色的被子。叠得方方正正）", N)]},
    "window": {"lines": [L("（窗外是矿道口。守门的队员打了个哈欠）", N)]},
    "bookshelf": {"lines": [L("（书架。一排旧图鉴，最底下压着一本画满涂鸦的练习本）", N),
                            L("……涂鸦。队长早上说的「满身的涂鸦」……", P), L("……算了，不能乱翻别人的东西。", P, "shy")]},
    "desk": {"lines": [L("（桌上压着几张写过又揉皱的纸）", N), L("……偷看别人的信，不太好。", P, "shy")]},
}}

BLUE_ROOM = {"name": BLUE, "npc": "blue_princess",
             "entries": [{"if": {"flag": "night"}, "node": "night"}, {"node": "day"}],
             "nodes": {
                 "day": {"lines": [L("……这里是我的房间。"), L("……别乱翻。")]},
                 "night": {"lines": [L("（她睡着了。裤脚偶尔动一下，像猫在梦里甩尾巴）", N)]},
             }}
