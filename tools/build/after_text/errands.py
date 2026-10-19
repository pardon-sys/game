"""七日赎罪的镇民委托（AfterErrands）：data/after/errands.json 的数据 + 委托人对话里接委托的几个节点（generate 时插进各人的对话文件）。
  from [天, 时段]：从什么时候起能接（有赎罪簿以后、白天、做完之前）。hours：做完减几工时。kind：玩法（errand_<kind>.gd）。target：送到哪一格（目标标记）。
"""
from . import errand_dance, errand_goats, errand_ladder, errand_massage
from .common import N, P, L

SHOW = "res://levels/floor_06/scripts/%s_show.gd"

ERRANDS = {
    "cookies": {"name": "送饼干", "npc": "after_granny", "from": [2, 1], "hours": 3, "kind": "cookies",
                "objective": "把饼干送给守城门的队员", "target": [29, 37]},
    "apples": {"name": "捡苹果", "npc": "after_merchant", "from": [2, 1], "hours": 2, "kind": "apples",
               "objective": "捡回十个苹果（别踩痒痒草）"},
    # 第 3 天起白天都能接（「小游戏画面」型的 kind=show：走到 target 开演 show 脚本）
    "ladder": {"name": "扶梯子", "npc": "after_engineer", "from": [3, 0], "hours": 3, "kind": "show", "show": SHOW % "ladder",
               "objective": "到脚手架房子底下，光脚爬梯子补屋檐", "target": [24, 10]},
    "goats": {"name": "赶蘑菇羊回圈", "npc": "after_maid", "from": [3, 0], "hours": 3, "kind": "goats",
              "objective": "把五只蘑菇羊引回羊圈（别跑也别停）", "target": [57, 33]},
    "dance": {"name": "篝火舞会排练", "npc": "after_bonfire_host", "from": [3, 0], "hours": 3, "kind": "show", "show": SHOW % "dance",
              "objective": "到篝火边排练篝火舞", "target": [44, 26]},
    "massage": {"name": "足底按摩试新手法", "npc": "after_bonfire_host", "from": [3, 0], "hours": 2, "kind": "show", "show": SHOW % "massage",
                "objective": "到篝火边的长椅上坐好（鞋要脱）", "target": [41, 27]},
}

# 委托人对话里的节点：offer 接委托 / active 正在做 / done 做完以后
NODES = {
    "cookies": {
        "offer": {"lines": [L("孩子，来得正好。刚烤好一篮饼干，想送给守城门的队员们——他们守了一整夜呢。"),
                            L("奶奶腿脚不方便，你帮我跑一趟？"),
                            L("就是……路上那几个小馋猫，鼻子灵得很。闻到香味，准会缠上来。")],
                  "prompt": "帮奶奶送饼干？",
                  "choices": [{"text": "交给我吧！", "next": "accept"}, {"text": "等一下再说", "next": ""}]},
        "accept": {"lines": [L("好孩子。篮子拿稳了——被小鬼们缠上了，分他们一块就肯走；不想给，就跑快点。"),
                             L("（拿到了一篮饼干，一共六块）", N)],
                   "set": {"vars": {"errand_req": "cookies"}, "call": "errand_start"}},
        "active": {"lines": [L("快去吧，饼干要凉了。守城门的队员在南边城门那里。")]},
        "done": {"lines": [L("队员们说饼干很好吃。辛苦你啦。"), L("……腰没被那几个小鬼挠坏吧？呵呵。")]},
    },
    "apples": {
        "offer": {"lines": [L("哎哟哟——刚进的一筐苹果，被搬木料的车一撞，滚了一地！"),
                            L("你手脚快，帮我捡回来？四十秒，捡齐十个！"),
                            L("对了，有几个滚到了那种开粉花的怪草旁边……那草会缠人，小心点。")],
                  "prompt": "帮忙捡苹果？",
                  "choices": [{"text": "好，计时开始！", "next": "accept"}, {"text": "等一下再说", "next": ""}]},
        "accept": {"lines": [L("预备——开始！")], "set": {"vars": {"errand_req": "apples"}, "call": "errand_start"}},
        "active": {"lines": [L("快快快！还有好几个没捡！")]},
        "done": {"lines": [L("一个都没少，好！这个账我给你记一笔。"), L("……摊子被踩烂的那笔，另算。")]},
    },
    "ladder": errand_ladder.NODES,
    "goats": errand_goats.NODES,
    "dance": errand_dance.NODES,
    "massage": errand_massage.NODES,
}


def inject(dialogues):
    """把接委托的节点插进委托人的对话（entries 最前面，按 errand_<id>_open / _active / _done 选）。"""
    per_npc = {}
    for eid, spec in ERRANDS.items():
        d = dialogues[spec["npc"]]
        per_npc[spec["npc"]] = per_npc.get(spec["npc"], 0) + 1
        nodes = NODES[eid]
        d["nodes"]["errand_%s" % eid] = nodes["offer"]
        d["nodes"]["errand_%s_accept" % eid] = nodes["accept"]
        d["nodes"]["errand_%s" % eid]["choices"][0]["next"] = "errand_%s_accept" % eid
        d["nodes"]["errand_%s_active" % eid] = nodes["active"]
        d["entries"][0:0] = [{"if": {"flag": "errand_%s_open" % eid}, "node": "errand_%s" % eid},
                             {"if": {"flag": "errand_%s_active" % eid}, "node": "errand_%s_active" % eid}]
        # 做完以后的话：只说一次（seen 过就回到平常的对话）；排在这个人所有委托的「能接 / 正在做」后面，免得挡住下一个委托
        d["nodes"]["errand_%s_done" % eid] = nodes["done"]
        d["entries"].insert(2 * per_npc[spec["npc"]], {"if": {"flag": "errand_%s_done" % eid, "not": "dlg_floor_06/%s_errand_%s_done" % (spec["npc"], eid)},
                                "node": "errand_%s_done" % eid})
