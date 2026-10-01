"""生成笑倒 CG 总文件 data/cgs.json（格式说明见生成结果开头的 _说明 和 docs/ARCHITECTURE.md）。

每种怪物一段：失控 1 立绘 → 失控 2 立绘 → CG 图（第三幕）[→ 第二张 CG 图（第四幕）] → 醒来。
怪物巢穴的过场在单独的文件里：tools/build/gen_nest_cgs.py → data/nest_cgs.json（它会 import 这里的 standard 等工具）。
CG 图由 tools/art/import_cg.py 生成到 assets/cg/portraits/<来源键>_3.png（第二张为 _4.png）；
文件存在时自动标成横版大框（wide），不存在时用失控 2 立绘占位。
用法：python tools/build/gen_cgs.py
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])
M = "res://scenes/actors/monsters/%s.tscn"
actors = {
    "slime": {"scene": M % "slime"},
    "bat": {"scene": M % "feather_bat"},
    "ghost": {"scene": M % "tickle_ghost"},
    "spider": {"scene": M % "tickle_spider"},
    "troll": {"scene": M % "tickle_troll"},
    "rat": {"scene": M % "foot_rat"},
    "crab": {"scene": M % "pincer_crab"},
    "split_slime": {"scene": M % "split_slime", "sprite": {"scale": 1.5}},
    "mimic": {"scene": M % "mimic", "sprite": {"region": [128, 112, 16, 16]}},
    "fairy": {"scene": M % "fairy_swarm", "sprite": {"hframes": 2}},
    "tentacle": {"scene": M % "tentacle_boss", "sprite": {"hframes": 2}},
    "mana_jelly": {"scene": M % "mana_jelly", "sprite": {"hframes": 2}},
    "bubble_fish": {"scene": M % "bubble_fish", "sprite": {"hframes": 2}},
    "glove": {"scene": M % "ghost_glove", "sprite": {"hframes": 2}},
    "hedgehog": {"scene": M % "brush_hedgehog", "sprite": {"hframes": 4}},
    "jelly_queen": {"scene": M % "jelly_queen", "sprite": {"hframes": 2}},
}
# 陷阱演员（组合演出用）：贴图、待机 / 发动帧、铺几格、旋转、羽毛臂。舞台上的摆放位置在 gen_combo_scenes.py。
T = "res://assets/generated/%s.png"
trap_actors = {
    "stocks": {"hit_fx": "feather", "texture": T % "stocks", "hframes": 2, "idle": [0], "active": [1], "z": 1, "pitch": 1.3},
    "carpet": {"hit_fx": "goo", "texture": T % "carpet", "hframes": 2, "idle": [0, 1], "active": [0, 1], "fps": 3, "tiles": [3, 2], "z": -1, "pitch": 1.5},
    "rune": {"hit_fx": "curse", "texture": T % "hex_rune", "hframes": 3, "idle": [0], "active": [1, 1, 0], "z": -1, "pitch": 0.8},
    "arm": {"hit_fx": "feather", "texture": T % "feather_arm", "hframes": 4, "arm": True, "length": 2, "dir": "left", "z": 2, "pitch": 1.2},
    "conveyor": {"hit_fx": "brush", "texture": T % "conveyor", "hframes": 4, "idle": [0], "active": [0, 1, 2, 3], "fps": 10, "tiles": [3, 1], "z": -1},
    "brush": {"hit_fx": "brush", "texture": T % "feather_brush", "hframes": 1, "idle": [0], "active": [0], "spin": 0.6, "offset": [-8, -8]},
    "hand": {"hit_fx": "hand", "texture": T % "grab_hand", "hframes": 3, "idle": [0], "active": [2, 1], "fps": 6, "z": 2},
    "vine": {"hit_fx": "brush", "texture": T % "vine", "hframes": 3, "idle": [0], "active": [1], "z": 1, "pitch": 0.9},
    "fan": {"hit_fx": "feather", "texture": T % "fan", "hframes": 2, "idle": [0], "active": [0, 1], "fps": 14},
    "feather": {"hit_fx": "feather", "texture": T % "feather_arm", "hframes": 4, "idle": [3], "active": [3], "spin": 0.3},
}
P = "公主"
portraits = {
    "defeat_1": {"file": "res://assets/cg/portraits/defeat_1.png", "placeholder": "helpless_1"},
    "defeat_2": {"file": "res://assets/cg/portraits/defeat_2.png", "placeholder": "helpless_2"},
    "wake": {"file": "res://assets/cg/portraits/wake.png", "placeholder": "sad"},
}


def pt(key):
    portraits[key + "_1"] = {"file": "res://assets/cg/portraits/%s_1.png" % key, "placeholder": "helpless_1"}
    portraits[key + "_2"] = {"file": "res://assets/cg/portraits/%s_2.png" % key, "placeholder": "helpless_2"}
    for act in (3, 4):
        f = "res://assets/cg/portraits/%s_%d.png" % (key, act)
        if act == 4 and not os.path.exists(f.replace("res://", "")):
            continue  # 只有一张 CG 图的怪物没有第四幕
        portraits["%s_%d" % (key, act)] = {"file": f, "placeholder": "helpless_2"}
        if os.path.exists(f.replace("res://", "")):  # 横版 CG 图放进来（tools/art/import_cg.py）后才用大框
            portraits["%s_%d" % (key, act)]["wide"] = True
    return key + "_1", key + "_2", key + "_3"


def princess(visual="helpless_1", at=(0, 8)):
    return {"kind": "princess", "at": list(at), "visual": visual, "anim": "helpless", "dir": "down"}


def monster(key, at, dir_="left", hidden=True, scale=None):
    m = {"kind": "monster:" + key, "at": list(at), "dir": dir_, "hidden": hidden}
    if scale:
        m["scale"] = scale
    return m


def opening(extra=None):
    return {"actions": [{"do": "fade_in", "time": 0.7}, {"do": "voice", "state": "giggle"}] + (extra or []), "wait": 0.8}


def ending(wake_text):
    return [
        {"actions": [{"do": "fade_out", "time": 0.9}, {"do": "voice", "state": ""}], "wait": 1.0},
        {"portrait": "wake", "speaker": P, "text": wake_text},
    ]


def standard(key, name, lines, taunts, act3, fx="lines", enter_from=(90, 0), stand=(22, 8), extras=None, cam=True, act4=None, foe=None):
    """三幕：
    第一幕（失控 1 立绘）：怪物登场、挠痒——公主 1 句 + 怪物 1 句
    第二幕（失控 2 立绘）：失控 2 姿势、镜头拉近——公主 1 句 + 怪物 1 句
    第三幕（横版 CG 图）：画面切到 CG 图，舞台移到右侧继续演——act3 的 5~7 句（最多）
    最后淡出、醒来。"""
    p1, p2, p3 = pt(key)
    cast = {"princess": princess(), "foe": monster(foe or key, stand, "left" if stand[0] > 0 else "right")}
    cast.update(extras or {})
    extra_names = list((extras or {}).keys())
    enter_extras = [{"do": "enter", "who": n, "from": [(-1 if cast[n]["at"][0] < 0 else 1) * 80, 0], "time": 0.7} for n in extra_names]
    tickle_extras = [{"do": "tickle", "who": "princess", "by": n, "repeat": 5, "interval": 0.32, "fx": fx} for n in extra_names]
    everyone = ["foe"] + extra_names
    steps = [
        opening(),
        # 第一幕
        {"portrait": p1, "speaker": P, "text": lines[0],
         "actions": [{"do": "enter", "who": "foe", "from": list(enter_from), "time": 0.6},
                     {"do": "bubble", "who": "princess", "kind": "surprise"}] + enter_extras},
        {"speaker": name, "text": taunts[0],
         "actions": [{"do": "tickle", "who": "princess", "by": "foe", "repeat": 4, "fx": fx},
                     {"do": "bubble", "who": "princess", "kind": "laugh"}]},
        # 第二幕
        {"portrait": p2, "speaker": P, "text": lines[1],
         "actions": [{"do": "pose", "who": "princess", "visual": "helpless_2"},
                     {"do": "voice", "state": "laugh"},
                     {"do": "tickle", "who": "princess", "by": "foe", "repeat": 6, "interval": 0.28, "fx": fx}] + tickle_extras
                    + ([{"do": "camera", "zoom": 1.5, "focus": "princess", "time": 0.5}] if cam else [])},
        {"speaker": name, "text": taunts[1],
         "actions": [{"do": "hop", "who": "foe", "count": 2}, {"do": "taunt", "who": "foe"}]},
    ]
    # 第三幕：CG 图（横版大框占左边），舞台镜头把公主移到右侧可见处；有第二张 CG 图时接着演第四幕
    steps += _act(act3, p3, name, everyone, fx, True)
    if act4:
        steps += _act(act4, key + "_4", name, everyone, fx, False)
    return {"name": "", "cast": cast, "steps": steps + ending(lines[3])}


def _act(lines_, portrait, name, everyone, fx, first):
    steps = []
    for i, (who, text) in enumerate(lines_):
        speaker = {"P": P, "M": name, "N": ""}[who]
        acts = []
        if i == 0:
            acts += [{"do": "flash", "time": 0.5}]
            if first:
                acts += [{"do": "camera", "zoom": 1, "focus": "princess", "anchor": [262, 112], "time": 0.4}]
            else:
                acts += [{"do": "voice", "state": "laugh"}, {"do": "shake", "who": "princess", "time": 0.6}]
        by = everyone[i % len(everyone)]
        acts += [{"do": "tickle", "who": "princess", "by": by, "repeat": 5 + i, "interval": max(0.18, 0.3 - i * 0.02), "fx": fx}]
        if who == "M":
            acts += [{"do": "hop", "who": by, "count": 1}]
        if who == "P":
            acts += [{"do": "bubble", "who": "princess", "kind": "dots" if i == len(lines_) - 1 else "laugh"}, {"do": "shake", "who": "princess", "time": 0.4}]
        step = {"speaker": speaker, "text": text, "actions": acts}
        if i == 0:
            step["portrait"] = portrait
        steps.append(step)
    return steps


cgs = {}

# 通用：陷阱或不明来源——看不见的手和羽毛
p1, p2 = "defeat_1", "defeat_2"
cgs["death_generic"] = {
    "name": "笑到脱力",
    "cast": {"princess": princess()},
    "steps": [
        opening(),
        {"portrait": p1, "speaker": P, "text": "哈、哈哈……不行了……机关还在挠……",
         "actions": [{"do": "tickle", "who": "princess", "repeat": 5, "fx": "feather"},
                     {"do": "bubble", "who": "princess", "kind": "laugh"}]},
        {"portrait": p2, "speaker": P, "text": "停、停下来哈哈哈哈！脚心、腰上……到处都……！",
         "actions": [{"do": "pose", "who": "princess", "visual": "helpless_2"}, {"do": "voice", "state": "laugh"},
                     {"do": "tickle", "who": "princess", "repeat": 7, "interval": 0.25, "fx": "hand"},
                     {"do": "camera", "zoom": 1.5, "focus": "princess", "time": 0.5}]},
        {"speaker": P, "text": "……笑、笑得……一点力气都没有了……",
         "actions": [{"do": "camera", "zoom": 1, "time": 0.4}, {"do": "bubble", "who": "princess", "kind": "dots"}]},
    ] + ending("……呜。在检查点醒过来了。下次一定要躲开那些机关……"),
}

def add(key, name, title, lines, taunts, act3, **kw):
    cg = standard(key, name, lines, taunts, act3, **kw)
    cg["name"] = title
    cgs["death_" + key] = cg


# lines = [第一幕公主, 第二幕公主, (未用), 醒来]；taunts = [第一幕怪物, 第二幕怪物]；act3 = [(P 公主 / M 怪物 / N 旁白, 台词)]
add("slime", "史莱姆", "黏糊糊的胜利",
    ["史、史莱姆……别过来……本公主已经笑不动了……",
     "凉凉的……黏在脚心上……哈哈哈哈别蹭了！", "",
     "……醒来了。身上还是黏黏的……那只史莱姆，给本公主记住！"],
    ["噗叽～还要挠～", "噗叽噗叽～公主投降了吧～"],
    [("N", "（史莱姆整个扑了上来，把公主裹进了凉凉的果冻里）"),
     ("P", "好冰……哈哈哈哈！脚、脚被吸进去了！"),
     ("M", "噗叽～脚心的形状，史莱姆记住了～"),
     ("P", "不要在里面蠕动啊——哈哈哈哈哈！"),
     ("M", "噗叽噗叽，再抱紧一点～"),
     ("P", "对不起……本公主……认输……哈哈……")])
add("bat", "羽毛蝙蝠", "羽毛风暴",
    ["头上……全是扑扑的翅膀声……",
     "翅膀上的羽毛……扫在脖子上哈哈哈！不要一直绕着转！", "",
     "……头发里还夹着羽毛。这次一定要打中它们！"],
    ["扑扑～痒不痒？", "再来一圈～"],
    [("N", "（蝙蝠们一只接一只扑下来，把公主团团围住）"),
     ("P", "别、别都落在身上！翅膀扫得好痒！"),
     ("M", "扑扑～轮到我了～"),
     ("P", "腋下……腋下不行哈哈哈哈！"),
     ("M", "大家一起扇～扇到公主投降为止～"),
     ("P", "……羽毛……满天都是羽毛……哈哈……")],
    enter_from=(0, -70), stand=(18, -6), fx="feather")
add("ghost", "痒痒幽灵", "看不见的手",
    ["谁、谁在那里？！明明什么都看不见……",
     "看不见的手在挠腰……哈哈哈哈这不公平！", "",
     "……醒来了。下次先把火把全部点亮再说！"],
    ["嘻嘻……在这里哦～", "看不见才更痒吧～"],
    [("N", "（火光一闪，看不见的手全都现了形——整整一大群幽灵）"),
     ("P", "原、原来有这么多只？！"),
     ("M", "嘻嘻，我们一直都在旁边哦～"),
     ("P", "凉飕飕的手……在挠脚心……哈哈哈哈！"),
     ("M", "再多笑一点～我们最喜欢笑声了～"),
     ("P", "……不、不笑了……哈哈……真的不笑了……")],
    enter_from=(0, 0), stand=(24, 4))
add("spider", "挠痒蜘蛛", "蛛丝陷阱",
    ["脚、脚被蛛丝粘住了……动不了……",
     "八只脚一起挠……哈哈哈哈数都数不过来！", "",
     "……身上的蛛丝好不容易才扯掉。可恶的蜘蛛！"],
    ["粘住啦～慢慢挠～", "八只脚可是很忙的～"],
    [("N", "（一只比房间还大的蜘蛛从天花板上垂了下来）"),
     ("P", "好、好大……不要过来……"),
     ("M", "八只脚，正好一只挠一处～"),
     ("P", "毛茸茸的……痒死了哈哈哈哈！"),
     ("M", "用蛛丝把脚绑好，慢慢来～"),
     ("P", "……动、动不了……哈哈……")],
    enter_from=(0, -60), stand=(20, 0))
add("troll", "挠痒巨魔", "巨人的手指",
    ["放、放开……好大的手……",
     "脚心！它专挑脚心！哈哈哈哈投降、投降啦！", "",
     "……醒来了。那只巨魔还在大厅里等着吧……这次绝对不会再被抓住！"],
    ["咕嘿嘿，挠你脚心！", "跑不掉的，小公主～"],
    [("N", "（巨魔一把捏住公主的脚踝，把她整个按在了地上）"),
     ("P", "放开！脚、脚心朝上了！"),
     ("M", "咕嘿嘿，巨魔的手指最会挠脚心！"),
     ("P", "一根手指就……哈哈哈哈哈哈！"),
     ("M", "再挠一百下！一下都不能少！"),
     ("P", "……一百下……会笑坏的……哈哈……")],
    stand=(26, 6))
add("rat", "挠脚鼠", "脚心大合唱",
    ["一、二、三……好多只老鼠……",
     "全都在挠脚心——哈哈哈哈不行不行不行！", "",
     "……鞋子都被扒掉了。挠脚鼠……本公主讨厌你们！"],
    ["吱吱！脚心！", "大家一起上吱！"],
    [("N", "（老鼠们从四面八方涌过来，一只接一只爬上公主的脚）"),
     ("P", "好、好多……数不清了！"),
     ("M", "吱吱！脚趾缝也要挠！"),
     ("P", "那里最痒了——哈哈哈哈！"),
     ("M", "吱～大家排好队，轮流挠！"),
     ("P", "……排、排队也不行啦……哈哈……")],
    fx="hand", extras={"rat2": monster("rat", (-22, 12), "right"), "rat3": monster("rat", (4, 26), "left")})
add("crab", "钳钳蟹", "夹住不放",
    ["脚趾……被夹住了……动不了……",
     "一边夹一边用钳子尖挠——哈哈哈哈放开！", "",
     "……脚趾还红红的。离那些钳子远一点……"],
    ["咔嚓咔嚓！", "夹住啦～"],
    [("N", "（螃蟹一只接一只横着爬过来，钳子咔嚓咔嚓地响）"),
     ("P", "脚趾……每个脚趾都被夹住了！"),
     ("M", "咔嚓咔嚓～钳子尖挠挠～"),
     ("P", "边夹边挠——哈哈哈哈太过分了！"),
     ("M", "兄弟们，横着走，一起上！"),
     ("P", "……脚、脚……没知觉了……哈哈……")],
    enter_from=(90, 0), stand=(20, 14))
add("split_slime", "分裂史莱姆", "越打越多",
    ["又、又分裂了……到底有几只……",
     "四面八方都是凉凉的……哈哈哈哈别挤过来！", "",
     "……醒来了。下次一定用满蓄力的星光一口气解决！"],
    ["噗叽～分裂！", "我们人多～"],
    [("N", "（小史莱姆们又合成了一只大史莱姆，把公主整个抱住）"),
     ("P", "合、合体了？！"),
     ("M", "噗叽～分开挠，合起来也挠～"),
     ("P", "软软的……到处都在动……哈哈哈哈！"),
     ("M", "再分裂一次好不好～"),
     ("P", "……不要……再多就……哈哈……")],
    extras={"mini1": monster("split_slime", (-20, 14), "right", scale=0.9), "mini2": monster("split_slime", (6, 28), "left", scale=0.9)})
add("mimic", "宝箱怪", "被宝箱吞掉",
    ["宝、宝箱在动……放开本公主！",
     "舌头！它用舌头挠——哈哈哈哈好痒！", "",
     "……醒来了。身上一股木头味……看到宝箱先敲一敲！"],
    ["咔哒！上钩了～", "宝物就是你～"],
    [("N", "（宝箱怪一口把公主吞进去一半，只剩两只脚在外面乱蹬）"),
     ("P", "好黑！放我出去！"),
     ("M", "咔哒～宝物要好好收藏～"),
     ("P", "里面有舌头在挠——哈哈哈哈！"),
     ("M", "露在外面的脚也不能放过～"),
     ("P", "……再、再也不乱开宝箱了……哈哈……")],
    enter_from=(0, 0), stand=(0, -6))
add("fairy", "羽毛小精灵群", "羽毛围攻",
    ["好多发光的小精灵……每个都拿着羽毛……",
     "羽毛从四面八方扫过来——哈哈哈哈停不下来！", "",
     "……醒来了。她们还在笑我吧……用魔法把她们全部吹走！"],
    ["咯咯咯～", "挠挠挠～"],
    [("N", "（小精灵们一拥而上，每个人都抱着一根羽毛）"),
     ("P", "你、你们要干什么……"),
     ("M", "挠挠大作战，开始～"),
     ("P", "脚心、腋下、脖子……哪里都有羽毛！"),
     ("M", "咯咯咯～公主笑得好开心～"),
     ("P", "……才、才不开心……哈哈哈……")],
    fx="feather", enter_from=(0, -70), stand=(16, -10))
add("tentacle", "痒痒触手怪", "触手的怀抱",
    ["被、被卷住了……好多根触手……",
     "每一根都在挠……腰、脚心、脖子——哈哈哈哈投降投降！", "",
     "……醒来了。那家伙还在大厅里等着……这次先用满蓄力的星光让它松手！"],
    ["咕噜噜～抓到了～", "触手可是有很多根的哦～"],
    [("N", "（触手一根接一根缠上来，把公主牢牢卷住）"),
     ("P", "放开！脚、脚被卷住了！"),
     ("M", "咕噜噜～每一根都要挠一挠～"),
     ("P", "吸盘……吸盘好痒——哈哈哈哈！"),
     ("M", "还有好多根没轮到哦～"),
     ("P", "……投降……真的投降了……哈哈……")],
    enter_from=(60, 0), stand=(34, 6))

add("mana_jelly", "魔力水母", "水母的海底摇篮",
    ["软、软乎乎的触须……缠上来了……",
     "魔力被搅得乱七八糟……哈哈哈哈身体好敏感！", "",
     "……醒来了。腿上好像还缠着触须的感觉……下次离那些水母远一点！"],
    ["噗噜噗噜～", "魔力，好好吃～"],
    [("N", "（四周忽然变成了一片海底，粉色和蓝色的水母从光里一只只飘下来）"),
     ("P", "这、这里是哪里……好多水母……"),
     ("M", "噗噜～公主的魔力，甜甜的～"),
     ("N", "（半透明的触须一圈一圈缠上小腿，又软又凉，顺着脚心滑来滑去）"),
     ("P", "腿、腿被缠住了——脚心那里不行哈哈哈哈！"),
     ("M", "大家一起～触须挠挠～"),
     ("P", "魔力在身体里晃……越晃越痒……哈哈哈哈停不下来！"),
     ("P", "……要、要被水母泡化了……哈哈……")],
    enter_from=(0, -60), stand=(18, -4), extras={"jelly2": monster("mana_jelly", (-20, -2), "right")})
add("bubble_fish", "泡泡鱼", "泡泡里的笑声",
    ["又、又被关进泡泡里了……戳不破……",
     "鳍在外面一下一下地扫……哈哈哈哈出不去！", "",
     "……泡泡终于破了。醒来浑身湿漉漉的……再也不想看见泡泡了！"],
    ["咕噜咕噜～", "泡泡牢笼～"],
    [("N", "（巨大的泡泡把公主整个包了起来，一圈泡泡鱼围在外面）"),
     ("P", "放、放我出去！这个泡泡怎么戳都戳不破！"),
     ("M", "咕噜～大家一起吹泡泡～"),
     ("N", "（鱼群张开嘴，一串串细小的泡泡流从四面八方喷向泡泡里的脚心）"),
     ("P", "泡、泡泡流冲在脚底上——哈哈哈哈好痒！"),
     ("P", "手、手够不到……只能乱踢……哈哈哈哈！")],
    stand=(22, 0), extras={"fish2": monster("bubble_fish", (-22, 4), "right")},
    act4=[("N", "（泡泡的壁一软，小鱼们竟然一条接一条钻了进来）"),
          ("P", "进、进来了？！不要挤到脚边——"),
          ("M", "咕噜咕噜～脚心最好玩～"),
          ("N", "（几十条小鱼挤满了两只脚，嘴巴一张一合地轻轻啄着脚心和脚趾缝）"),
          ("P", "噗——哈哈哈哈！捂、捂住嘴也忍不住哈哈哈哈！"),
          ("M", "脚趾缝里也要啄一啄～"),
          ("P", "……脚、脚心……全是小鱼……哈哈……投降……")])
add("glove", "幽灵手套", "千只手套",
    ["左边……右边……两只手套一起……",
     "十根手指同时在挠——哈哈哈哈数不过来！", "",
     "……醒来了。好像全身还被手指戳着……下次绝对不让它们凑到一起！"],
    ["左手～", "右手～"],
    [("N", "（两只手套拍了拍手——四面八方飘来了几十只系着蝴蝶结的白手套）"),
     ("P", "怎、怎么会有这么多！不是只有一对吗？！"),
     ("M", "大家都是左手和右手哦～"),
     ("N", "（手套们一拥而上，有的挠腰，有的戳腋下，有的捏住脸颊，还有的托住脚心）"),
     ("P", "哈哈哈哈！腰、腰上……脖子也……哈哈哈哈！"),
     ("M", "咯吱咯吱～一、二、三，一起挠～"),
     ("P", "连、连头发都被摸了——哈哈哈哈这是犯规！"),
     ("P", "……数不过来……全身都……哈哈……")],
    enter_from=(80, -10), stand=(20, -2), fx="hand", extras={"glove2": monster("glove", (-20, -2), "right")})
add("hedgehog", "刷刷刺猬", "刺猬大游行",
    ["刺猬……又滚过来了……躲不开……",
     "刷毛从脚底一路刷上来——哈哈哈哈别滚了！", "",
     "……醒来了。浑身都是刷毛的痒意……下次一定躲进凹槽里！"],
    ["咕噜咕噜～", "刷刷刷！"],
    [("N", "（咕噜咕噜的声音越来越多——一大群刺猬从四面八方滚了过来）"),
     ("P", "等、等一下，怎么来了这么多只！"),
     ("M", "刺猬大游行，开始～"),
     ("N", "（刺猬们爬上公主的身体，刷毛在肚子、腋下和脚心上来回打滚）"),
     ("P", "肚、肚子上在滚——哈哈哈哈好扎好痒！"),
     ("M", "脚抬起来也没用哦～脚心也有刺猬～"),
     ("P", "腿、腿翘得再高也……哈哈哈哈哈！"),
     ("P", "……全身都被刷过一遍了……哈哈……")],
    enter_from=(90, 0), stand=(20, 10), fx="lines")
add("jelly_queen", "魔力水母女王", "女王的花之海",
    ["女、女王……好多触须一起落下来……",
     "魔力雨……身体越来越敏感——哈哈哈哈停不下来！", "",
     "……醒来了。好像还能闻到樱花的味道……这次先打碎图腾，速战速决！"],
    ["呵呵～小公主～", "在我的魔力里好好笑吧～"],
    [("N", "（女王张开伞盖，把公主装进了一个巨大的泡泡，小水母们一只只飘了进来）"),
     ("P", "这是……泡泡？外面全是水母……"),
     ("M", "孩子们，好好招待客人～"),
     ("N", "（小水母用细细的触须缠住手腕和脚踝，一边笑一边轻轻地挠）"),
     ("P", "手、手腕被缠住了——哈哈哈哈放开！"),
     ("P", "脚踝也……哈哈哈哈大家都在笑……")],
    enter_from=(60, -20), stand=(34, 2),
    extras={"jelly1": monster("mana_jelly", (-24, -4), "right"), "jelly2": monster("mana_jelly", (8, -20), "left")},
    act4=[("N", "（泡泡碎成了漫天花瓣——开满樱花的女王本体缓缓落下，缎带一样的触须铺满了整片天空）"),
          ("M", "呵呵～接下来，由我亲自来～"),
          ("P", "好、好大……触须像缎带一样……"),
          ("N", "（粉色的触须卷住双腿、拂过腰间，花瓣落在哪里，哪里就痒起来）"),
          ("P", "哈哈哈哈哈！花瓣……花瓣也在挠——哈哈哈哈！"),
          ("M", "在花海里笑吧，小公主～笑到魔力全部变成我的～"),
          ("P", "……女王大人……饶、饶命……哈哈哈……")])

def main():
    data = {
        "_说明": [
            "笑倒 CG 总文件：公主被挠到闷笑值溢出、生命值归零时播放（CG Autoload，scripts/cg/cg_player.gd）。",
            "portraits：CG 立绘接口。id -> {file, placeholder, wide}。wide = 横版 CG 图（第三幕），立绘框变成高 180、按图片比例的大框；file 放正式素材（推荐 228x304，与现有立绘同为 2 倍密度，其它尺寸按比例缩放），不存在时用 placeholder 指定的公主状态立绘占位。",
            "trap_actors：陷阱演员（组合演出用）。来源键 -> {texture, hframes, idle / active 帧列表, fps, tiles [宽,高], spin 每秒圈数, arm 羽毛臂, length, dir, z, offset, pitch}；hit_fx 立绘贴片种类；cast 里写 kind = trap:<来源键>，被 tickle 的 by 指到时发动。",
            "actors：怪物演员。来源键 -> {scene 怪物场景, sprite 可覆盖 hframes / region [x,y,w,h] / scale / offset [x,y] / frame}。演员只复制场景里的 Sprite，不带 AI。",
            "death：{by_source: {最后一次挠痒的来源键: CG id}, default: 找不到时（陷阱等）用的 CG id}。",
            "怪物巢穴的过场（被拖进巢穴时播）在 data/nest_cgs.json，CG 播放器载入时合并进来。",
            "cgs：CG id -> {name, cast, steps}。",
            "cast：演员名 -> {kind, at [x,y], dir, hidden, scale, visual, anim}。kind = princess（公主）/ monster:<来源键> / source（致死的那只怪）。坐标以舞台地面中心为原点，单位像素。",
            "steps：按顺序执行。每一步可写 portrait（立绘 id，一直保持到下次更换，none = 隐藏）、actions（演绎指令，同时开始）、",
            "  speaker / text / emotion（台词，等玩家推进；auto 秒后自动前进）、wait（没有台词时停留的秒数，默认等指令演完）、await_actions（先演完指令再出台词）。",
            "actions 的 do：enter（at, from 相对起点, time）/ exit / move（to, time）/ hop（count, height）/ shake（time）/ face（dir）/",
            "  pose（公主：visual, anim, dir；怪物：style = idle / wiggle / bounce）/ tickle（who 被挠的, by 挠的, repeat, interval, fx = lines / feather / hand / heart）/",
            "  bubble（kind = laugh / surprise / dots / sad / shy / angry / happy / question）/ say（text 头顶对白）/ taunt（随机一句该怪物的回嘴）/",
            "  sfx（sound, volume, pitch）/ voice（state = laugh / giggle / 空）/ camera（zoom：1 = 基础 2 倍，1.5 = 3 倍，2 = 4 倍；focus 演员名或 [x,y]；anchor 舞台框里的对准位置，默认中心；time）/ flash / fade_in / fade_out（time）/ wait（time）。",
        ],
        "portraits": portraits,
        "actors": actors,
        "trap_actors": trap_actors,
        "death": {"by_source": {k: "death_" + k for k in actors}, "default": "death_generic"},
        "cgs": cgs,
    }
    open("data/cgs.json", "w").write(json.dumps(data, ensure_ascii=False, indent="\t") + "\n")
    print(len(cgs), "CG,", len(portraits), "立绘 id")


if __name__ == "__main__":
    main()
