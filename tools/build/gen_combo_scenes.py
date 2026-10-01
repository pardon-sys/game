"""生成三来源组合第一次触发时的小演出 data/combo_scenes.json（格式同 data/cgs.json 的 cgs：cast / steps / actions）。

每个三来源组合（data/combos.json 里 keys 有 3 个槽位）一段，三段递进 + 高潮：
  淡入，舞台顶部的来源栏列出三个来源（暗着）→ 旁白报出组合名和说明
  → 第一个来源登场开始挠（点亮第 1 格），公主第 1 句
  → 第二个来源加入一起挠（点亮第 2 格），公主第 2 句
  → 第三个来源加入（点亮第 3 格），失控 2 姿势、大笑、镜头拉近，公主第 3 句
  → 高潮：三个来源一起挠（三格一起闪），公主 2–3 句 → 淡出。
怪物用 cgs.json 的 actors 演员，陷阱用 trap_actors 演员（摆在公主身边，挠的时候发动）。
台词等玩家按键推进，随时可以按 Esc 跳过。台词在下面的 SCENES 里按组合手写：(来源出场顺序, [台词…])。
用法：python tools/build/gen_combo_scenes.py
"""
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])

combos = json.load(open("data/combos.json"))
reactions = json.loads(open("data/princess_reactions.json").read(), strict=False)
cg = json.load(open("data/cgs.json"))
actors = cg["actors"]
trap_actors = cg["trap_actors"]
NAMES = {k: v.get("name", k) for k, v in reactions["sources"].items()}
NAMES.update({"conveyor": "传送带", "brush": "旋转刷", "hand": "机关手", "vine": "藤蔓", "fan": "羽毛风扇",
              "feather": "羽毛陷阱", "stocks": "足枷台", "carpet": "黏黏毛毯", "arm": "伸缩羽毛臂", "rune": "诅咒符文"})
# 陷阱在舞台上的位置（公主站在 (0, 8)）、占用哪一侧（怪物就不站那里）、挠痒特效
TRAP_AT = {"stocks": ([0, 11], None), "carpet": ([-16, 3], None), "rune": ([0, 9], None), "arm": ([46, -2], "right"),
           "conveyor": ([-16, 10], None), "brush": ([-30, 4], "left"), "hand": ([0, -18], "top"), "vine": ([0, 9], None),
           "fan": ([-42, 2], "left"), "feather": ([14, 6], None)}
TRAP_FX = {"stocks": "feather", "arm": "feather", "carpet": "lines", "rune": "heart", "conveyor": "lines",
           "brush": "feather", "hand": "hand", "vine": "lines", "fan": "feather", "feather": "feather"}
SPOTS = {"left": ([-30, 2], [-80, 0], "right"), "right": ([30, 2], [80, 0], "left"), "top": ([0, -26], [0, -70], "down")}

# 组合 id -> (来源出场顺序, [第 1 句, 第 2 句, 第 3 句, 高潮 1, 高潮 2, (高潮 3)])
SCENES = {
    "queen_feast": (["mana_jelly", "bubble_fish", "jelly_queen"], [
        "呀？！软乎乎的触须缠上脚踝了——嘻、嘻嘻……",
        "泡、泡泡也来了！鳍在泡泡外面扫脚心——哈哈哈不要两个一起！",
        "女王大人？！那么多触须一起落下来——哇哈哈哈哈哈！",
        "被、被举起来了！脚心是泡泡、腰上是触须、脖子也……哈哈哈哈全都在痒！",
        "分、分不清哪里在痒了——三种痒叠在一起哈哈哈哈停不下来！",
        "女王的盛宴什么的……我才不是点心——哈哈哈哈哈！"]),
    "full_scrub": (["bubble_fish", "glove", "hedgehog"], [
        "噗——泡泡流冲在脚心上，好痒！",
        "手、手套也来了！十根手指在腰上搓——哈哈哈哈泡泡还没停！",
        "刺猬？！从脚底一路刷上来——噫——哈哈哈哈哈！",
        "冲、搓、刷……三种一起，全身都在被大扫除——哈哈哈哈哈！",
        "不、不需要洗那么干净啦——哈哈哈哈喘不过气了！"]),
    "sole_party": (["rat", "crab", "spider"], [
        "老鼠的胡子……在脚心扫……噗嗤！",
        "螃蟹夹住脚趾了！一边夹一边挠——哈哈哈哈不要！",
        "蜘蛛也爬上来了？！八只脚一起——噫——哈哈哈哈！",
        "胡子、钳子、八只脚……脚底开派对了——哈哈哈哈哈！",
        "脚、脚心要笑坏了——哈哈哈哈谁来救救我！"]),
    "sole_mobilize": (["stocks", "rat", "crab"], [
        "咔哒——脚被足枷锁住了，脚心朝外……",
        "老鼠排着队来挠脚心——哈哈哈哈动不了啊！",
        "螃蟹也来了！脚趾一根一根被夹住——哇哈哈哈哈！",
        "锁着、挠着、夹着……每一下都是暴击——哈哈哈哈哈！",
        "脚心总动员什么的……不要动员啊——哈哈哈哈哈！"]),
    "bubble_spa": (["carpet", "bubble_fish", "mana_jelly"], [
        "毛毯黏住脚了……绒毛在蹭脚踝……",
        "泡泡黏在毛毯上了！里面还有鳍在扫——哈哈哈出不去！",
        "水母钻进泡泡里了——魔力被搅得好乱——哇哈哈哈哈！",
        "绒毛、鳍、触须……泡泡里全是痒——头好晕哈哈哈哈！",
        "泡、泡泡浴一点都不舒服——哈哈哈哈哈转晕了！"]),
    "mob_curse": (["rune", "slime", "bat"], [
        "符文亮了……皮肤变得好敏感……",
        "史莱姆贴上来了！凉凉的——平时没这么痒的哈哈哈哈！",
        "蝙蝠也扑过来了？！翅膀一扫就——哇哈哈哈哈！",
        "诅咒把怪物全招过来了——四面八方都在挠哈哈哈哈！",
        "每、每碰一下都好痒——诅咒快停下哈哈哈哈哈！"]),
    "ultimate_stocks": (["stocks", "rune", "glove"], [
        "足枷台锁住了……挣不开……",
        "诅咒的光……脚心变得好敏感——碰一下都痒——嘻嘻嘻！",
        "手套一左一右来了——噫——！哈哈哈哈每一下都是暴击！",
        "锁着、诅咒着、两只手套一起——哈哈哈哈哈要笑疯了！",
        "终、终极刑台……名字一点都没夸张——哈哈哈哈哈！",
        "饶、饶了我吧——哈哈哈哈哈哈！"]),
    "brush_line": (["carpet", "arm", "hedgehog"], [
        "被毛毯黏住了……走不动……",
        "羽毛臂扫过来了！黏着躲不开——哈哈哈哈！",
        "刺猬也滚过来——刷毛从脚刷到腰——哇哈哈哈哈！",
        "黏住、扫、刷……一道一道流水线——哈哈哈哈头都转晕了！",
        "停、停下流水线——哈哈哈哈哈不要再来一遍！"]),
    "curse_chain": (["rune", "arm", "slime"], [
        "踩到符文了……身体好奇怪……",
        "羽毛臂扫过来了——平时没这么痒的哈哈哈哈！",
        "史莱姆也扑上来——凉凉的……噫——哈哈哈哈哈！",
        "一环扣一环……咒语也念不出来了——哈哈哈哈哈！",
        "每、每一下都是暴击——哈哈哈哈别连起来啊！"]),
    "auto_stocks": (["stocks", "carpet", "arm"], [
        "脚被足枷锁住了……",
        "下面的毛毯也黏上来了——绒毛蹭着脚踝哈哈……",
        "羽毛臂正好扫过锁着的脚心——哇哈哈哈哈！",
        "锁脚、黏脚、扫脚……全自动的——哈哈哈哈哈！",
        "机关们配合得太好了——头都转晕了哈哈哈哈！"]),
    "curse_hall": (["rune", "carpet", "arm"], [
        "符文……皮肤变得好敏感……",
        "毛毯的绒毛在蹭——明明很轻却好痒——哈哈哈！",
        "羽毛臂也扫过来了——噫——哈哈哈哈哈！",
        "整条走廊都在挠我——哈哈哈哈每一下都是暴击！",
        "诅咒、绒毛、羽毛……分不清哪里在痒了哈哈哈哈哈！"]),
    "line_end": (["conveyor", "brush", "hand"], [
        "传送带……停不下来……要被送走了……",
        "旋转刷！羽毛一圈一圈刷过去——哈哈哈哈！",
        "终点还有机关手等着——抓、抓住了——哇哈哈哈哈！",
        "送过来、刷一遍、再抓住挠——哈哈哈哈哈流水线啊！",
        "我、我不是货物——哈哈哈哈哈放我下来！"]),
    "thousand_feather": (["stocks", "fairy", "glove"], [
        "咔哒——脚被锁住了……",
        "小精灵们抱着羽毛围上来了——脚心好痒哈哈哈！",
        "手套把我托起来了？！十根手指一起——哇哈哈哈哈！",
        "羽毛和手指……数、数不清有多少——哈哈哈哈哈！",
        "千手羽毛刑……真的有一千只吗——哈哈哈哈哈！"]),
    "jelly_sole": (["stocks", "slime", "rat"], [
        "脚被锁住了……",
        "史莱姆糊在脚心上——好凉——嘻嘻嘻！",
        "老鼠在果冻上面打滚——哇哈哈哈哈又凉又痒！",
        "果冻、胡子、锁着的脚——哈哈哈哈哈动不了！",
        "脚、脚心要化掉了——哈哈哈哈哈！"]),
    "queen_stocks3": (["stocks", "mana_jelly", "jelly_queen"], [
        "被锁在女王面前了……",
        "小水母的触须先来了——魔力好乱——哈哈！",
        "女王亲自来审判——好多触须——哇哈哈哈哈！",
        "触须从脚心卷到腰上——每、每一下都是暴击哈哈哈哈！",
        "我认罪——我认罪啦——哈哈哈哈哈！"]),
    "troll_stocks3": (["stocks", "bat", "troll"], [
        "脚被锁住了……",
        "蝙蝠在脚边扑腾——羽毛扫脚心——哈哈哈！",
        "巨魔来了——大拇指按在脚心上——哇哈哈哈哈！",
        "扑腾的翅膀加上巨人的手指——哈哈哈哈哈要坏掉了！",
        "巨魔的刑场……一点都不好玩——哈哈哈哈哈！"]),
    "tentacle_feather": (["stocks", "fairy", "tentacle"], [
        "脚被锁住了……",
        "小精灵在下面挠脚心——哈哈哈！",
        "触手把我举起来了？！脚心朝下——哇哈哈哈哈！",
        "触手在腰上、羽毛在脚心——哈哈哈哈哈停不下来！",
        "放、放我下来——哈哈哈哈哈！"]),
    "sticky_ghost": (["slime", "bat", "ghost"], [
        "史莱姆黏上来了……凉凉的……",
        "蝙蝠也扑过来——翅膀扫脖子——哈哈哈！",
        "看不见的手？！在挠腰——哇哈哈哈哈！",
        "黏的、扑的、看不见的……全来了——哈哈哈哈哈！",
        "分不清谁是谁了——哈哈哈哈哈！"]),
    "night_trio": (["spider", "ghost", "bat"], [
        "黑暗里……蜘蛛的脚碰到我了……",
        "看不见的手也来了——两边一起——哈哈哈！",
        "蝙蝠在头上转——头好晕——哇哈哈哈哈！",
        "八只脚、看不见的手、翅膀……夜行三重奏——哈哈哈哈哈！",
        "转、转晕了——哈哈哈哈哈分不清方向了！"]),
    "jelly_sole_party": (["split_slime", "rat", "crab"], [
        "果冻糊在脚底了……凉凉的……",
        "老鼠在果冻上打滚——哈哈哈！",
        "螃蟹也爬上来夹脚趾——哇哈哈哈哈！",
        "脚底开了果冻派对——哈哈哈哈哈越来越多了！",
        "派、派对散场吧——哈哈哈哈哈！"]),
    "vault_trap": (["mimic", "fairy", "tentacle"], [
        "宝箱……宝箱在动？！",
        "小精灵从箱子里飞出来了——羽毛扫脚心哈哈哈！",
        "触手也伸进来了——宝库是陷阱——哇哈哈哈哈！",
        "舌头、羽毛、触手……全都冲过来了——哈哈哈哈哈！",
        "再、再也不乱开宝箱了——哈哈哈哈哈！"]),
    "vine_stocks": (["vine", "stocks", "rat"], [
        "藤蔓缠住腿了……",
        "足枷台也合上了——咔哒——脚完全动不了……",
        "老鼠来了——慢慢挠脚心——哇哈哈哈哈！",
        "缠着、锁着、挠着……哈哈哈哈哈一点都动不了！",
        "藤蔓刑台……脚心交给老鼠了——哈哈哈哈哈！"]),
    "sticky_belt": (["conveyor", "carpet", "crab"], [
        "传送带……把我往前送……",
        "送到毛毯上黏住了——绒毛在蹭——哈哈！",
        "终点站是螃蟹——夹、夹住了——哇哈哈哈哈！",
        "被送过来、黏住、夹着挠——哈哈哈哈哈！",
        "下一站不要是螃蟹啊——哈哈哈哈哈！"]),
    "three_hands": (["ghost", "hand", "arm"], [
        "看不见的手……在挠腰……",
        "机关手从上面抓下来了——举、举起来了——哈哈哈！",
        "羽毛臂也扫过来——三只手——哇哈哈哈哈！",
        "到底有几只手——到处都在痒——哈哈哈哈哈！",
        "被举着挠……放、放我下来——哈哈哈哈哈！"]),
    "wind_bubble": (["fan", "bubble_fish", "bat"], [
        "风……好大的风……",
        "泡泡被风吹着转——我在泡泡里转圈——哈哈！",
        "蝙蝠顺风扑过来了——哇哈哈哈哈！",
        "转、转得好晕——羽毛和鳍一起扫——哈哈哈哈哈！",
        "风停一下——哈哈哈哈哈转不停了！"]),
}


def _is_trap(key):
    return key not in actors and key in trap_actors


def scene(c):
    cid = c["id"]
    text = reactions["combos"].get(cid, {})
    name = text.get("name", cid)
    desc = text.get("description", "")
    order, lines = SCENES[cid]
    cast = {"princess": {"kind": "princess", "at": [0, 8], "visual": "helpless_1", "anim": "helpless", "dir": "down"}}
    taken = {TRAP_AT[k][1] for k in order if _is_trap(k) and TRAP_AT[k][1]}
    free_spots = [s for s in ("left", "right", "top") if s not in taken]
    who_of, enter_of, fx_of, sources = {}, {}, {}, []
    for i, key in enumerate(order):
        who = "src%d" % (i + 1)
        who_of[key] = who
        if _is_trap(key):
            cast[who] = {"kind": "trap:" + key, "at": TRAP_AT[key][0], "hidden": True}
            enter_of[key] = {"do": "enter", "who": who, "from": [0, -6], "time": 0.3}
            fx_of[key] = TRAP_FX.get(key, "feather")
            sources.append({"kind": "trap", "key": key, "name": NAMES.get(key, key)})
        else:
            spot = free_spots.pop(0) if free_spots else "top"
            at, frm, face = SPOTS[spot]
            cast[who] = {"kind": "monster:" + key, "at": at, "dir": "left" if at[0] > 0 else "right", "hidden": True}
            enter_of[key] = {"do": "enter", "who": who, "from": frm, "time": 0.5}
            fx_of[key] = "lines"
            sources.append({"kind": "monster", "key": key, "name": NAMES.get(key, key)})

    def tickle(keys, repeat, interval):
        return [{"do": "tickle", "who": "princess", "by": who_of[k], "repeat": repeat, "interval": interval, "fx": fx_of[k]}
                for k in keys]

    P = "公主"
    steps = [
        {"actions": [{"do": "fade_in", "time": 0.4}, {"do": "voice", "state": "giggle"},
                     {"do": "sources", "list": sources}], "wait": 0.4},
        {"speaker": "", "text": "【%s】%s——%s" % (c.get("category", "三重组合"), name, desc),
         "actions": [{"do": "bubble", "who": "princess", "kind": "surprise"}]},
        {"speaker": P, "text": lines[0],
         "actions": [enter_of[order[0]], {"do": "light", "index": 0}] + tickle(order[:1], 6, 0.32)},
        {"speaker": P, "text": lines[1],
         "actions": [enter_of[order[1]], {"do": "light", "index": 1}, {"do": "bubble", "who": "princess", "kind": "laugh"}]
                    + tickle(order[:2], 7, 0.28)},
        {"speaker": P, "text": lines[2],
         "actions": [enter_of[order[2]], {"do": "light", "index": 2}, {"do": "pose", "who": "princess", "visual": "helpless_2"},
                     {"do": "voice", "state": "laugh"}, {"do": "camera", "zoom": 1.5, "focus": "princess", "time": 0.4},
                     {"do": "shake", "who": "princess", "time": 0.5}] + tickle(order, 8, 0.24)},
    ]
    for j, line in enumerate(lines[3:]):
        steps.append({"speaker": P, "text": line,
                      "actions": [{"do": "light", "all": True}, {"do": "flash", "time": 0.25},
                                  {"do": "shake", "who": "princess", "time": 0.6},
                                  {"do": "bubble", "who": "princess", "kind": "dots" if j == len(lines) - 4 else "laugh"}]
                                 + tickle(order, 10 + j * 2, max(0.14, 0.2 - j * 0.03))})
    steps.append({"actions": [{"do": "fade_out", "time": 0.5}, {"do": "voice", "state": ""}], "wait": 0.6})
    return {"name": name, "cast": cast, "steps": steps}


def main():
    out = {}
    missing = []
    for c in combos["combos"]:
        if len(c.get("keys", [])) >= 3:
            if c["id"] not in SCENES:
                missing.append(c["id"])
                continue
            out[c["id"]] = scene(c)
    assert not missing, "缺少演出台词：%s" % missing
    data = {
        "_说明": [
            "三来源组合第一次触发时的小演出（CG.play_scene(组合 id)；台词按键推进，随时可以按 Esc 跳过）。",
            "scenes：组合 id -> {name, cast, steps}，格式和 data/cgs.json 的 cgs 一样；怪物演员用 cgs.json 的 actors，陷阱演员用 trap_actors（kind = trap:<来源键>）。",
            "sources 指令设定舞台顶部的来源栏（三个来源的图标 + 名字），light 点亮第 index 格（all = true 三格一起闪）。",
            "由 tools/build/gen_combo_scenes.py 生成（台词写在脚本的 SCENES 里），直接改这里会被重新生成覆盖。",
        ],
        "scenes": out,
    }
    open("data/combo_scenes.json", "w").write(json.dumps(data, ensure_ascii=False, indent="\t") + "\n")
    print(len(out), "段组合演出，公主台词", sum(len(v[1]) for k, v in SCENES.items() if k in out), "句")


if __name__ == "__main__":
    main()
