"""蓝色公主的角色数据：从粉色公主的数据转换生成 data/characters/blue/（Characters 按当前操控的角色读）。

蓝色公主是成熟的三无属性：被挠时努力憋笑，平时只有极短的拟声词 / 短句（「……嗯。」「……唔。」「……不痒。」），
憋不住（失控）之后台词才变多变乱；不说「本公主」，自称「我」。
输出：
  reactions.json    受挠台词（通用 + 每个来源 + 组合台词 + 立绘飘字），结构同 data/princess_reactions.json
  fatigue.json      魔力疲倦爆发台词
  ticklish.json     部位表：大腿、屁股最怕（×1.4），脚心反而不太怕（×0.95）
  cgs.json / nest_cgs.json / combo_scenes.json  笑倒 CG、巢穴 CG、组合演出：公主的台词按她的性格改写、说话人换成「蓝色的公主」，
                    CG 专用立绘（粉色公主的图）去掉 → 用她自己对应阶段的立绘；魔力爆发一幕的立绘 = 她立绘图的最后一格（战损憋笑释放）
台词用模板 + 每个来源 / 部位的名字生成，按 id 做固定种子，每次生成结果一样。
用法：python tools/build/gen_blue_character.py（改了粉色公主的数据之后重新跑一次）
"""
import hashlib
import re
import json
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])
OUT = Path("data/characters/blue")
OUT.mkdir(parents=True, exist_ok=True)
PINK_SPEAKER = "公主"
BLUE = "蓝色的公主"

SENSITIVITY = {"thigh": 1.4, "butt": 1.4, "waist": 1.1, "belly": 1.05, "armpit": 1.0, "neck": 1.0, "chest": 1.0, "sole": 0.95}

CALM = ["……嗯。", "……唔。", "……不痒。", "……别碰。", "……啧。", "……{n}。……无聊。", "……这种程度。", "……没感觉。……真的。",
        "……哼。", "……还好。", "……{z}？……不怕。", "……走开。"]
GIGGLE = ["……噗。……刚才是咳嗽。", "……唔、嗯……", "……{n}……别、别……", "……哈。……没笑。", "……嗯唔……不、不痒……",
          "……噗嗤。……忘掉它。", "……{z}……不行……嗯……", "……呜。……别挠{z}。", "……忍得住。……嗯、嗯……"]
# 失控一：已经憋不住、笑出声了，但还在努力（比失控二短）
H1 = ["……噗、哈哈……不、不是……", "哈、哈哈……憋、憋不住……", "……哈哈……{z}……别、别碰那里……",
      "噗哈……！刚、刚才那个不算……哈哈……", "……呜、哈哈……{n}……停、停一下……", "哈哈……明明忍得住的……哈哈哈……",
      "……哈、哈哈……{z}……为、为什么……"]
BREAK = ["……哈、哈哈……不、不行……{z}……那里……哈哈哈哈……忍、忍不住了……！",
         "哈哈哈……停、停下……{n}……停下来……哈哈哈哈……我、我投降……！",
         "……不、不要了……哈哈哈哈……{z}也、也不行……为什么偏偏是那里……哈哈哈……！",
         "哈哈哈哈……忍、忍不住……明明一直忍着的……{n}……哈哈哈哈哈……！",
         "……呜、哈哈哈……{z}……会坏掉的……哈哈哈哈……别看……别看我这样……！",
         "哈哈哈哈哈……！不、不算……这次不算……{z}……哈哈哈哈……！"]
BURST_START = ["……魔力……要满出来了。", "……身体里……在发烫。……要出来了。", "……不行……魔力……压不住了。"]
BURST_COMFY = ["……哈。……全部放出去了。……舒服。", "……呼……魔力走了……身体很轻。……舒服。", "……嗯……放出来了……有点……舒服。"]
BURST_SENS = ["……刚放完……身体好敏感……哈、哈哈……不、不要现在挠……！", "……敏感……全身都变得好敏感……{z}……哈哈哈哈……！",
              "……放完之后……好敏感……{n}……哈、哈哈哈……停下……！"]
DAZED = ["……嗯……天花板……在转……", "……{n}……软软的……是云吗……", "……没、没笑……一次都……没笑……嘿……",
         "……数到一百……就不痒了……一、二……", "……她……在哪里……", "……再、再一下……就忍住了……", "……好困……谁在……挠我的{z}……"]
WAKE = ["……醒了。……刚才的事，忘掉。", "……下次。不会再输。", "……{n}。记住了。", "……没笑。……一次都没有。"]
GRABBED = ["……放开。", "……抓得真紧。……别挠。", "……啧。……挣开就好。", "……被抓住了。……麻烦。"]
SPECIAL = ["……！？哈、哈哈哈——不、不算……刚才不算……！", "……呜！？{z}……哈哈哈哈……！", "……！……那、那里……哈哈哈……！"]
WORDS = {"helpless_1": ["噗、哈哈", "憋…不住", "……哈哈", "哈、哈哈", "噗哈"],
         "helpless_2": ["哈哈哈哈", "不、不行哈哈", "别看哈哈哈", "哈哈…哈哈哈", "停、停下哈哈"]}
ZONE_WORDS = {"helpless_1": ["{z}…哈哈", "噗、{z}……", "别碰{z}哈哈"], "helpless_2": ["{z}不行哈哈哈", "{z}哈哈哈哈", "……{z}……哈哈！"]}
MAGIC = {
    "channel": ["……冰晶。回应我。", "……别动。结界要成形了。", "……集中。……不许挠。"],
    "interrupted": ["……啧。断了。", "……念到一半……被挠……", "……再来一次。"],
    "fizzle": ["……太快了。", "……冰没结起来。"],
    "burst": ["……冻住。", "……结界，展开。"],
    "burst_full": ["……全部，冻住。", "……这一圈，谁也别想动。"],
}


def pick(pool, seed, **kw):
    h = int(hashlib.md5(seed.encode("utf-8")).hexdigest(), 16)
    return re.sub("…{3,}", "……", pool[h % len(pool)].format(**kw))


def pick_new(pool, seed, used, **kw):
    """同一段演出里尽量不重复。"""
    for i in range(len(pool) * 2):
        line = pick(pool, "%s~%d" % (seed, i), **kw)
        if line not in used:
            used.add(line)
            return line
    return pick(pool, seed, **kw)


def picks(pool, seed, count, **kw):
    out, i = [], 0
    while len(out) < min(count, len(pool)) and i < 50:
        line = pick(pool, "%s#%d" % (seed, i), **kw)
        if line not in out:
            out.append(line)
        i += 1
    return out


pink = json.loads(Path("data/princess_reactions.json").read_text(), strict=False)
zones_pink = json.loads(Path("data/actors/princess_ticklish.json").read_text())
tz = json.loads(Path("data/tickle_zones.json").read_text())
ZNAME = {k: v["name"] for k, v in zones_pink["zones"].items()}


def zone_of(key):
    w = tz.get("sources", {}).get(key, {})
    if not w:
        return "腰"
    return ZNAME.get(max(w, key=lambda z: w[z]), "腰")


def src_name(key):
    v = pink.get("sources", {}).get(key, {})
    return str(v.get("name", "它")) if isinstance(v, dict) else "它"


# ------------------------------------------------------------------ 部位表
tk = json.loads(json.dumps(zones_pink))
tk["_说明"] = ["蓝色公主的部位表（tools/build/gen_blue_character.py 生成）：大腿、屁股最怕，脚心反而不太怕。其它字段同 data/actors/princess_ticklish.json。"]
for z, v in tk["zones"].items():
    v["sensitivity"] = SENSITIVITY.get(z, 1.0)
    v["words"] = {st: [w.format(z=v["name"]) for w in ws] for st, ws in ZONE_WORDS.items()}
(OUT / "ticklish.json").write_text(json.dumps(tk, ensure_ascii=False, indent="\t") + "\n")

# ------------------------------------------------------------------ 受挠台词
rx = json.loads(json.dumps(pink))
rx["_说明"] = "蓝色公主的受挠台词（tools/build/gen_blue_character.py 从粉色公主的数据转换）：平时只有短拟声词，失控后才变多。结构同 data/princess_reactions.json。"
rx["lines"] = {
    "calm": picks(CALM, "g_calm", 5, n="……", z="腰"), "giggle": picks(GIGGLE, "g_gig", 5, n="……", z="腰"),
    "helpless_1": picks(H1, "g_h1", 5, n="……", z="大腿"),
    "helpless_2": picks(BREAK, "g_h2", 5, n="……", z="屁股"), "grabbed": GRABBED[:3], "special": picks(SPECIAL, "g_sp", 3, z="大腿"),
}
rx["portrait_words"] = WORDS
for key, s in rx.get("sources", {}).items():
    if not isinstance(s, dict):
        continue
    n, z = s.get("name", "它"), zone_of(key)
    s["first_encounter"] = [{"speaker": BLUE, "emotion": "surprise", "text": "……%s。" % n},
                            {"speaker": BLUE, "emotion": "shy", "text": pick(["……被它碰到的地方，有点痒。……不，没什么。", "……%s……会挠人。……麻烦。" % n,
                                                                              "……%s附近……别、别碰。" % z], key)},
                            {"speaker": BLUE, "emotion": "angry", "text": pick(["……别靠近我。", "……打掉就好。", "……挣开就好。……很简单。"], key + "x")}]
    for stage, pool, k in (("calm", CALM, 2), ("giggle", GIGGLE, 2), ("helpless_1", H1, 2), ("helpless_2", BREAK, 2)):
        if stage in s:
            s[stage] = picks(pool, key + stage, k, n=n, z=z)
    if "grabbed" in s:
        s["grabbed"] = picks(GRABBED, key + "grab", 2)
    if "special" in s:
        s["special"] = picks(SPECIAL, key + "sp", 2, z=z)
    if "portrait_words" in s:
        s["portrait_words"] = {"helpless_1": ["%s…哈哈" % n, "噗、哈哈", "憋…不住"], "helpless_2": ["%s……哈哈哈" % n, "哈哈哈哈", "不、不行哈哈"]}
    if "lines_by_content" in s:
        for _c, v in s["lines_by_content"].items():
            for stage, pool in (("calm", CALM), ("giggle", GIGGLE), ("helpless_1", H1), ("helpless_2", BREAK)):
                if stage in v:
                    v[stage] = picks(pool, key + _c + stage, 2, n=n, z=z)
# 千手痒痒魔：她认识它（不点明）。被它挠时的台词带着惋惜和自责，和别的来源不一样。
BOSS_LINES = {
    "first_encounter": [{"speaker": BLUE, "emotion": "sad", "text": "……原来，你在这里。"},
                        {"speaker": BLUE, "emotion": "sad", "text": "……你的手，变多了。"},
                        {"speaker": BLUE, "emotion": "angry", "text": "……对不起。……但我不会让你再挠她了。"}],
    "calm": ["……别这样。", "……你以前不会这样的。", "……是你。"],
    "giggle": ["……这招……以前是用来逗我的……", "……还、还记得……我哪里怕……"],
    "helpless_1": ["……哈、哈哈……你还是……从右边来……哈哈……", "噗、哈哈……别……别像以前那样……哈哈……"],
    "helpless_2": ["哈哈哈……对、对不起……哈哈哈……都是我……哈哈哈哈……！", "哈哈哈哈……停、停下……我不想……这样见到你……哈哈哈……！"],
    "grabbed": ["……你的手，还是这么凉。", "……放开。……求你了。"],
    "portrait_words": {"helpless_1": ["……对不起", "噗、哈哈", "别…这样"], "helpless_2": ["对不起哈哈", "哈哈哈哈", "停下…哈哈"]},
}
if isinstance(rx.get("sources", {}).get("thousand_hand"), dict):
    rx["sources"]["thousand_hand"].update(json.loads(json.dumps(BOSS_LINES)))
# ------------------------------------------------------------------ 组合演出的台词：按这个组合的来源（手法 / 部位 / 怪物还是陷阱）生成
# 每个来源的短手法（填进句子里）；陷阱类说「动不了」，怪物类说「别过来」。
SHORT = {
    "arm": "羽毛臂扫", "barnacle": "小吸盘嘬", "bat": "翅膀尖扑", "binding": "缎带里的羽毛蹭", "boots": "靴子里的软毛蹭",
    "brush": "转个不停的刷子", "bubble_fish": "泡泡炸开", "cage": "笼缝里伸进来的东西", "carpet": "黏黏的绒毛", "caterpillar": "一排小脚爬",
    "clamp": "夹着腿挠", "conveyor": "一排排毛刷", "crab": "钳子一夹一挠", "cuffs": "举着手被挠", "cushion": "坐垫里的软毛",
    "fairy": "一群小翅膀", "fan": "风里的羽毛", "feather": "羽毛慢慢划", "feather_swing": "荡一下扫一下", "foot_bath": "咕嘟咕嘟的泡泡",
    "foot_thigh_rack": "从脚心刷到腿", "frog": "长舌头舔", "ghost": "凉凉的手指", "glove": "空手套抓挠", "hand": "机关手的指尖",
    "hedgehog": "硬刷毛来回刷", "imp": "小刷子比划", "jelly_queen": "软触须缠", "legloop": "吊着的腿被挠", "mana_jelly": "黏糊糊的触须",
    "mimic": "箱子里的舌头", "mud": "泥里的气泡", "octopus": "八只小吸盘", "prone": "趴着被刷", "rat": "小爪子抠",
    "rune": "符文的光", "saddle_bench": "跨着的刷子", "scissor_stand": "交叉的刷子", "shower": "羽毛雨", "sitz_bath": "往上冒的泡泡",
    "slime": "黏液慢慢爬", "snare": "倒吊着被挠", "spider": "八条细腿踩", "spinwheel": "转一圈扫一下", "split_slime": "小史莱姆挤",
    "spring_seat": "一颠一颠的刷毛", "squirrel": "蓬松的尾巴扫", "stocks": "锁着脚被挠", "supine": "仰躺着被画圈", "teaser": "点一下又退开",
    "tentacle": "软触手打转", "thigh_brush_ring": "刷环一圈圈转", "thigh_pincer": "羽毛钳轻轻拧", "thousand_hand": "好多手指一起",
    "troll": "大手指用力挠", "vest": "背心里的羽毛", "vine": "藤蔓嫩芽缠", "wardrobe": "柜子里的手", "wheel": "转轮上的羽毛",
    "maze_hand": "看不见的手指", "glow_moth": "发光的鳞粉", "dream_fluff": "粘着的绒球", "lamp_imp": "黑暗里的小手",
    "laugh_jar": "吸笑声的瓶子", "mirror_puddle": "倒影里的手", "shadow_vine": "影子里的藤尖", "feather_curtain": "羽毛门帘",
    "cradle_bench": "椅下的手", "hand_gate": "门后的手", "hand_shadow": "那团影子", "hand_rhythm": "一起狠挠的手",
    "night_stalker": "抱住的手臂", "blind_bat": "扫过的翅膀", "wall_brush": "墙缝的刷子", "hanging_hands": "垂下来的手",
    "thousand_pants": "裤子里的手指",
}
MONSTERS = {"night_stalker", "blind_bat", "maze_hand", "glow_moth", "dream_fluff", "lamp_imp", "laugh_jar", "barnacle", "bat", "bubble_fish", "caterpillar", "crab", "fairy", "frog", "ghost", "glove", "hedgehog", "imp", "jelly_queen",
            "mana_jelly", "mimic", "octopus", "rat", "slime", "spider", "split_slime", "squirrel", "tentacle", "thousand_hand", "troll"}
KIND_SAY = {"monster": ["别、别过来……", "小、小东西……走开……", "一、一只就够了……"],
            "trap": ["动、动不了……", "机、机关……停下……", "挣、挣不开……"]}
# {s}/{z}：这一句挑中的来源的手法 / 部位；{s2}/{z2}：下一个来源的；{k}：怪物 / 陷阱的说法
CALM_T = ["……{s}。……不痒。", "……{z}……没、没感觉。", "……唔。……{s}……而已。", "……{z}那里……别碰。", "……啧。……{s}……",
          "……这、这种程度……{z}……忍得住。", "……{s}……慢、慢一点……不，没什么。", "……嗯。……{z}……还好。", "……{k}"]
GIGGLE_T = ["……噗。……{s}……犯规……", "……唔、嗯……{z}……别、别一直……", "……哈。……刚才……{s}……不算……", "……嗯唔……{z}和{z2}……一起……",
            "……{s}……又、又来……噗……", "……哈、哈……{z}……为、为什么……", "……别、别笑……我没笑……{s}……", "……噗、噗哈……{s2}也……",
            "……噗……{k}"]
H1_T = ["……哈、哈哈……{z}……{s}……为、为什么……", "哈哈……{s}……停、停一下……哈哈……", "噗哈哈……{s}……{z}……不、不行……哈哈……",
        "哈哈哈……{s}，还有{s2}……太、太多了……", "……哈哈……明、明明忍得住的……{s}……哈哈哈……", "哈哈……{s2}……{z2}也……别、别一起……哈哈哈……",
        "哈、哈哈……{s}……那、那个节奏……哈哈……", "……呜、哈哈……{s}……{k}哈哈……"]
BREAK_T = ["哈哈哈哈……忍、忍不住……明明一直忍着的……{s}……哈哈哈哈哈……！", "哈哈哈……{s}……{z}……{z}不行……停、停下……哈哈哈哈……！",
           "哈哈哈哈哈……！{s}和{s2}……一起……我、我投降……！", "哈哈哈……{s2}……{k}哈哈哈哈哈……！", "哈哈哈哈……！{s}……{z}……真、真的……不行……哈哈哈……！",
           "哈哈哈……停、停下来……{s}……停下来……哈哈哈哈……！", "……哈哈哈哈……{s}……对、对不起……{z}……认输……哈哈哈哈……！",
           "哈哈哈哈……！{s2}……还、还在……哈哈哈……！"]
# 部位是大腿 / 屁股（她最怕）时额外的、更崩的句子
WEAK_H1 = ["……哈、哈哈……{z}……为、为什么……偏偏是{z}……", "噗哈哈哈……！{z}、{z}不可以……哈哈……",
           "……{z}……不、不许……噗……哈哈哈……！", "……唔、唔……{z}……知道了……我怕……哈哈哈……"]
WEAK_BREAK = ["哈哈哈哈哈……！{z}……那里……真的……不行……哈哈哈哈哈……！", "哈哈哈……{s}……一直在{z}上……我、我投降……哈哈哈哈……！"]
BURST_START_T = ["……魔力……要满出来了。……{s}……别再……", "……不行……{z}被挠得……魔力……压不住了。", "……身体里……在发烫。……都是{s}……害的。",
                 "……{z}……被{s}……好烫……魔力……要出来了。"]
BURST_COMFY_T = ["……嗯……放出来了……{z}……有点……舒服。", "……呼……{z}……轻、轻松了……", "……魔力走了……{s}……也停了……吗。",
                 "……哈……身体很轻……刚才{s}的……不算。", "……{z}……不、不烫了……嗯……舒服。",
                 "……呼。……{z}……安静下来了。……还行。", "……嗯。……{z}……凉凉的……刚刚好。"]
DAZED_T = ["……嗯……天花板……在转……{s}……", "……{s}……软软的……是云吗……", "……没、没笑……{z}……一次都……没笑……嘿……",
           "……数到一百……{z}就不痒了……一、二……", "……再、再一下……{s}……就忍住了……", "……好困……谁在……挠我的{z}……",
           "……{z}……是、是别人的……不是我的……嘿……", "……冰、冰块……融化了……{z}……也化了……"]
BURST_SENS_T = ["……刚放完……{z}……好敏感……{s}……不、不要现在……哈哈……！", "哈哈哈……！{s}……刚放完就……犯规……哈哈哈哈！",
                "……碰、碰哪里都痒……{z}……尤其……哈哈哈哈……！", "哈哈……{s2}……回、回来了……哈哈哈哈……！",
                "……等、等一下……{z}还……还没好……哈哈哈哈……！", "……不、不公平……刚放完……{z}……哈哈哈……！"]


def combo_voice(keys):
    """组合的来源 → [(短手法, 部位, 怪物 / 陷阱)]；部位用她最怕的（blue_zone）。"""
    out = []
    for k in keys:
        if k in SHORT:
            out.append((SHORT[k], blue_zone(k), "monster" if k in MONSTERS else "trap"))
    return out


_VOICE_USES = {}


def voice_line(pool, voice, seed, used, slot):
    """从模板池挑一句（同一段不重复），填入第 slot 个来源（轮流）和下一个来源的手法 / 部位。
    所有组合演出合起来也尽量均匀：候选句里挑全局用得最少的（同样少时按种子顺序）。"""
    s, z, kind = voice[slot % len(voice)]
    s2, z2, _ = voice[(slot + 1) % len(voice)]
    k = pick(KIND_SAY[kind], seed + "k")
    kw = dict(s=s, z=z, s2=s2, z2=z2 if z2 != z else "别的地方", k=k)
    cands = []
    for i in range(len(pool) * 3):
        line = pick(pool, "%s~%d" % (seed, i), **kw)
        if line not in used and line not in cands:
            cands.append(line)
    if not cands:
        return pick(pool, seed, **kw)
    line = min(cands, key=lambda t: _VOICE_USES.get(t, 0))
    _VOICE_USES[line] = _VOICE_USES.get(line, 0) + 1
    used.add(line)
    return line


# ------------------------------------------------------------------ 组合台词：不念组合名，说手法和感受
# 每个来源怎么挠（{z} = 挠的部位）；她最怕大腿和屁股，碰到这两处的组合台词明显更崩。
TECH = {
    "arm": "细长的羽毛臂在{z}上扫来扫去", "barnacle": "小吸盘一嘬一嘬地吸着{z}", "bat": "翅膀尖在{z}上扑棱棱地扫",
    "binding": "绑在{z}上的羽毛一圈圈地转", "boots": "靴子里的软毛在{z}上蹭", "brush": "转个不停的羽毛刷贴着{z}",
    "bubble_fish": "泡泡一个接一个在{z}上炸开", "cage": "笼子缝里伸进来的东西在{z}上戳", "carpet": "黏黏的绒毛裹着{z}蹭",
    "caterpillar": "一排小脚顺着{z}一路爬", "clamp": "夹住的{z}被一下一下地挠", "conveyor": "传送带上的毛刷一排排扫过{z}",
    "crab": "钳子在{z}上一夹一挠", "cuffs": "手举着放不下，{z}整个露着", "cushion": "坐垫里的软毛顶着{z}一下下地蹭",
    "fairy": "一群小翅膀在{z}边上起哄地扑", "fan": "风卷着羽毛往{z}上吹", "feather": "羽毛在{z}上慢慢地划",
    "feather_swing": "秋千一荡，羽毛就扫过{z}", "foot_bath": "泡泡咕嘟咕嘟地往{z}上冒", "foot_thigh_rack": "从脚心到{z}一路被刷",
    "frog": "长舌头在{z}上舔了一下又一下", "ghost": "凉凉的手指钻进{z}", "glove": "空空的手套在{z}上抓挠",
    "hand": "机关手的指尖在{z}上点", "hedgehog": "硬硬的刷毛在{z}上来回刷", "imp": "小工匠拿着小刷子在{z}上比划",
    "jelly_queen": "软软的触须顺着{z}往上缠", "legloop": "吊着的腿没法收，{z}被一下下地挠", "mana_jelly": "黏糊糊的触须在{z}上滑",
    "mimic": "箱子里伸出来的舌头卷着{z}", "mud": "泥里的小气泡在{z}上冒", "octopus": "八只小吸盘一起贴着{z}",
    "prone": "趴着动不了，毛刷在{z}上转圈", "rat": "小爪子在{z}上一下一下地抠", "rune": "符文的光让{z}变得一碰就痒",
    "saddle_bench": "跨着的凳子上刷子顶着{z}来回", "scissor_stand": "两边的刷子像剪刀一样交叉刷着{z}",
    "shower": "细细的羽毛雨落在{z}上", "sitz_bath": "泡泡从下面一直往{z}上冒", "slime": "黏液慢慢地在{z}上爬",
    "snare": "倒吊着，{z}被一下一下地挠", "spider": "八条细腿在{z}上快快地踩", "spinwheel": "转盘一转，羽毛就扫过{z}",
    "split_slime": "小史莱姆们挤着往{z}里钻", "spring_seat": "弹簧座一颠一颠，刷毛就蹭着{z}", "squirrel": "蓬松的尾巴在{z}上扫来扫去",
    "stocks": "脚被锁住，{z}只能任人挠", "supine": "仰躺着，{z}上被一圈圈地画", "teaser": "逗弄羽毛在{z}上点一下又退开",
    "tentacle": "软软的触手钻到{z}里打转", "thigh_brush_ring": "刷环套着{z}一圈圈地转", "thigh_pincer": "羽毛钳夹着{z}轻轻地拧",
    "thousand_hand": "好多只手指同时在{z}上挠", "troll": "大手指在{z}上用力地挠", "vest": "背心里面的羽毛贴着{z}蹭",
    "vine": "藤蔓的嫩芽顺着{z}往上缠", "wardrobe": "柜子里伸出来的手在{z}上乱挠", "wheel": "转轮上的羽毛一下下扫过{z}",
    # 第八层夜迷宫
    "maze_hand": "看不见的手指在{z}上慢慢画圈", "glow_moth": "发光的鳞粉落在{z}上", "dream_fluff": "软绵绵的绒球粘在{z}上蹭",
    "lamp_imp": "灯一灭，小手就扑到{z}上", "laugh_jar": "瓶子吸着笑声，{z}跟着发痒", "mirror_puddle": "倒影里伸出的手挠着{z}",
    "shadow_vine": "影子里的藤尖缠着{z}画圈", "feather_curtain": "羽毛门帘从{z}上一路刷过", "cradle_bench": "椅子下面的手在{z}上一下下点",
    "hand_gate": "门后的手一下子贴到{z}上", "hand_shadow": "被那团影子看着，{z}凉凉地发痒", "hand_rhythm": "身上的手一起在{z}上狠挠",
    "night_stalker": "一团手臂抱住她，在{z}上乱挠", "blind_bat": "看不见的时候，翅膀尖扫过{z}", "wall_brush": "墙缝里的刷子夹着{z}转",
    "hanging_hands": "吊起来的时候，手指在{z}上挠", "thousand_pants": "裤子里的手指在{z}上一起动",
}
WEAK = ("大腿", "屁股")


def blue_zone(key):
    """她挨这个来源挠的部位：来源最常挠的两处里有大腿 / 屁股就算那里（她最怕）。"""
    w = tz.get("sources", {}).get(key, {})
    top = sorted(w, key=lambda z: -w[z])[:2]
    for z in top:
        if ZNAME.get(z) in WEAK:
            return ZNAME[z]
    return zone_of(key)


def combo_lines(cid, keys, desc):
    """keys = 组合的来源键（不含 *）。返回 3 句：手法 + 感受；碰到大腿 / 屁股的明显更崩。"""
    parts, zones = [], []
    for k in keys:
        z = blue_zone(k)
        zones.append(z)
        if k in TECH:
            parts.append(TECH[k].format(z=z).replace("腋下上", "腋下").replace("脖子上", "脖子").replace("腋下里", "腋下"))
    if not parts:   # 按条件触发的组合：用说明里的手法
        parts = [desc.rstrip("。！")]
    weak = [z for z in zones if z in WEAK]
    method = "……" + "，".join(parts[:3]) + "……"
    shorts = [SHORT[k] for k in keys if k in SHORT] or ["它们"]
    s = pick(shorts, cid + "s")
    if weak:
        z = weak[0]
        a = pick(["%s嗯、唔……哈……！" % method, "%s不、不行……哈哈……！" % method], cid + "m")
        b = pick(["……%s、%s不行……哈哈哈……%s……真的不行……哈哈哈哈……！" % (z, z, s),
                  "哈哈哈……！别、别在%s上%s……忍、忍不住……哈哈哈哈……！" % (z, s),
                  "……一直、一直在%s上……%s……哈哈哈……我、我投降……哈哈哈……！" % (z, s),
                  "噗哈哈哈……%s……专、专挑%s……哈哈哈哈……！" % (s, z)], cid + "w")
        c = pick(["……明明……忍得住的……偏偏是%s……%s……哈哈哈哈……！" % (z, s),
                  "哈哈哈……为、为什么……都知道我%s怕……%s……哈哈哈……！" % (z, s),
                  "……%s……%s……不、不行了……哈哈哈哈哈……！" % (s, z)], cid + "x")
    else:
        a = pick(["%s嗯。" % method, "%s唔……" % method], cid + "m")
        b = pick(["……忍、忍得住……%s……嗯、嗯唔……哈……！" % s, "……%s……一、一起来……太狡猾了……哈、哈哈……" % s,
                  "……噗。……%s……没、没笑……哈……" % s], cid + "w")
        c = pick(["……哈、哈哈……%s……别、别一起……！" % s, "……还、还好……没碰大腿……%s……哈……" % s,
                  "……%s……%s……够、够了……哈哈……" % (s, zones[0] if zones else "那里")], cid + "x")
    return [a, b, c]


COMBO_KEYS = {c["id"]: [k for g in c.get("keys", []) for k in g if k != "*"] for c in json.loads(Path("data/combos.json").read_text())["combos"]}
for cid, c in rx.get("combos", {}).items():
    if not isinstance(c, dict):
        continue
    c["lines"] = combo_lines(cid, COMBO_KEYS.get(cid, []), str(c.get("description", "")))


def no_ben(t):
    return t.replace("本公主", "我")


# 她的魔法是冰晶结界（scripts/combat/ice_barrier.gd）
rx["magic"] = dict(MAGIC, _说明="蓝色公主的冰晶结界：channel 开始吟唱、interrupted 被打断、fizzle 蓄力不足、burst 1~2 档、burst_full 满蓄力")
(OUT / "reactions.json").write_text(json.dumps(rx, ensure_ascii=False, indent="\t") + "\n")

# ------------------------------------------------------------------ 疲倦爆发
fat = {
    "_说明": ["蓝色公主的魔力疲倦爆发台词（gen_blue_character.py 生成）。结构同 data/princess_fatigue.json。"],
    "burst": ["……魔力……出来了。……哈。", "……全部……放出去了。……舒服。", "……嗯……身体好轻……"],
    "after": ["……放完了。……身体……变得好敏感。", "……别碰。……现在……碰哪里都痒。"],
    "first": [{"speaker": BLUE, "emotion": "surprise", "text": "……魔力……满了。……压不住。"},
              {"speaker": BLUE, "emotion": "shy", "text": "……哈。……全部冲出去了。……有点舒服。"},
              {"speaker": BLUE, "emotion": "sad", "text": "……但是皮肤……变得好敏感。……麻烦。"}],
    "warning": ["……魔力……快满了。", "……要小心。……再被挠……就压不住了。"],
}
(OUT / "fatigue.json").write_text(json.dumps(fat, ensure_ascii=False, indent="\t") + "\n")


# ------------------------------------------------------------------ CG / 巢穴 CG / 组合演出
def convert_steps(cid, steps, noun, zone, method_lines=None, voice=None):
    """voice（组合演出用）：这个组合的来源 [(短手法, 部位, 怪物 / 陷阱)]，句子按它生成（每个组合不一样）；没有就用通用的池子。"""
    said_idx = [i for i, st in enumerate(steps) if st.get("speaker") == PINK_SPEAKER and "text" in st]
    burst_idx = [i for i in said_idx if steps[i].get("act") == "burst"]
    plain_idx = [i for i in said_idx if steps[i].get("act") != "burst" and steps[i].get("portrait") != "wake"]
    last_burst = burst_idx[-1] if burst_idx else -1
    out = []
    used = set()
    for i, st in enumerate(steps):
        st = dict(st)
        if st.get("speaker") == PINK_SPEAKER and "text" in st:
            t = st["text"]
            seed = "%s:%d" % (cid, i)
            slot = said_idx.index(i)
            if st.get("portrait") == "wake":
                st["text"] = pick_new(WAKE, seed, used, n=noun)
            elif st.get("act") == "burst":
                if i == last_burst:
                    st["text"] = voice_line(DAZED_T, voice, seed, used, slot) if voice else pick_new(DAZED, seed, used, n=noun, z=zone)
                elif voice:
                    pool = BURST_COMFY_T if "舒服" in t else (BURST_SENS_T if "敏感" in t else (BURST_START_T if i == burst_idx[0] else BREAK_T))
                    st["text"] = voice_line(pool, voice, seed, used, slot)
                elif "舒服" in t:
                    st["text"] = pick_new(BURST_COMFY, seed, used)
                elif "敏感" in t:
                    st["text"] = pick_new(BURST_SENS, seed, used, n=noun, z=zone)
                elif i == burst_idx[0]:
                    st["text"] = pick_new(BURST_START, seed, used)
                else:
                    st["text"] = pick_new(BREAK, seed, used, n=noun, z=zone)
            else:
                ha = t.count("哈")
                # 越往后越憋不住：后 40% 的句子只要原句在笑就失控
                late = plain_idx.index(i) >= len(plain_idx) * 0.6 if i in plain_idx else False
                # 憋着（短）→ 失控一就破功（笑出声）→ 后段完全崩溃
                tier = 0 if ha == 0 else (1 if ha <= 2 and not late else (3 if late and ha >= 4 else 2))
                if voice:
                    pool = [CALM_T, GIGGLE_T, H1_T, BREAK_T][tier]
                    vz = voice[slot % len(voice)][1]
                    if tier >= 2 and vz in WEAK:
                        pool = pool + (WEAK_H1 if tier == 2 else WEAK_BREAK)
                    st["text"] = voice_line(pool, voice, seed, used, slot)
                else:
                    st["text"] = pick_new([CALM, GIGGLE, H1, BREAK][tier], seed, used, n=noun, z=zone)
                # 组合演出：第 2、5、8 句换成说手法和感受的整句（组合台词，各用一次）
                k = plain_idx.index(i) if i in plain_idx else -1
                if method_lines and k in (1, 4, 7) and k // 3 < len(method_lines):
                    st["text"] = method_lines[k // 3]
            st["speaker"] = BLUE
        elif st.get("speaker", "") == "" and "text" in st:
            st["text"] = no_ben(st["text"]).replace("公主", BLUE)
        elif "text" in st:
            st["text"] = st["text"].replace("公主殿下", "蓝色的公主").replace("公主", "蓝发的姑娘")
        out.append(st)
    return out


def convert_portraits(portraits):
    out = {}
    for pid, info in portraits.items():
        # 第八层的战败大图两个公主同框（谁操控都一样）：保留原图
        if pid.startswith("boss8_"):
            out[pid] = dict(info)
            continue
        ph = info.get("placeholder", "helpless_1")
        if pid == "fatigue_burst":
            ph = "damaged_giggle_burst"
        out[pid] = {"file": "", "placeholder": ph}
    return out


cgs = json.loads(Path("data/cgs.json").read_text())
cgs["_说明"] = ["蓝色公主版的笑倒 CG（gen_blue_character.py 从 data/cgs.json 转换）：台词改写、立绘用她自己的。"]
cgs["portraits"] = convert_portraits(cgs.get("portraits", {}))
for cid, c in cgs.get("cgs", {}).items():
    key = cid.replace("death_", "")
    c["steps"] = convert_steps(cid, c.get("steps", []), src_name(key), zone_of(key))
(OUT / "cgs.json").write_text(json.dumps(cgs, ensure_ascii=False, indent="\t") + "\n")

nest = json.loads(Path("data/nest_cgs.json").read_text())
nest["portraits"] = convert_portraits(nest.get("portraits", {}))
for cid, c in nest.get("cgs", {}).items():
    c["steps"] = convert_steps(cid, c.get("steps", []), "小家伙们", "腰")
(OUT / "nest_cgs.json").write_text(json.dumps(nest, ensure_ascii=False, indent="\t") + "\n")

sc = json.loads(Path("data/combo_scenes.json").read_text())
for cid, c in sc.get("scenes", {}).items():
    cv = rx.get("combos", {}).get(cid, {})
    ml = cv.get("lines", []) if isinstance(cv, dict) else []
    keys = []
    for k in [x for x in c.get("cast", {}).values()]:
        kind = str(k.get("kind", ""))
        if kind.startswith("monster:") or kind.startswith("trap:"):
            keys.append(kind.split(":", 1)[1])
    weak = [blue_zone(k) for k in keys if blue_zone(k) in WEAK]
    # 按条件触发的组合（没有具体来源）：用 combos.json 里的来源键（不含 *）
    vkeys = keys or COMBO_KEYS.get(cid, [])
    voice = combo_voice(vkeys) or [("它们", weak[0] if weak else "腰", "monster")]
    c["steps"] = convert_steps(cid, c.get("steps", []), "它们", weak[0] if weak else (blue_zone(keys[0]) if keys else "腰"), ml, voice)
(OUT / "combo_scenes.json").write_text(json.dumps(sc, ensure_ascii=False, indent="\t") + "\n")
# ------------------------------------------------------------------ 常见物品 / 通用对话（data/dialogues/common.json 的她的版本）
# Dialogue.start(id) 先查当前角色的 dialogues.json，有同 id 的就用她的。
def bl(emotion, text):
    return {"speaker": BLUE, "emotion": emotion, "text": text}


COMMON = {
    "got_bronze_key": [bl("happy", "……铜钥匙。……收好了。")],
    "got_gold_key": [bl("happy", "……金钥匙。……出口，应该就在前面。")],
    "locked_bronze": [bl("sad", "……锁着。……要铜钥匙。")],
    "locked_gold": [bl("sad", "……金锁。……先找金钥匙。")],
    "gate_closed": [bl("angry", "……铁栅栏。……推不动。"), bl("normal", "……附近应该有拉杆。……找找看。")],
    "laugh_recover": [bl("sad", "……哈……哈……停、停下来了……"), bl("angry", "……刚才的，不算。……没笑。……一次都没有。")],
    "respawn": [bl("sad", "……唔。"), bl("angry", "……再来。这次不会输。")],
}
common = json.loads(Path("data/dialogues/common.json").read_text())
missing = [k for k in common if not k.startswith("_") and k not in COMMON]
assert not missing, "common.json 里这些对话还没有蓝色公主的版本：%s" % missing
(OUT / "dialogues.json").write_text(json.dumps(dict({"_说明": "蓝色公主版的通用对话（gen_blue_character.py 生成）：铁栅栏、钥匙、锁、笑完恢复、复活等。"}, **COMMON),
                                               ensure_ascii=False, indent="\t") + "\n")

# ------------------------------------------------------------------ 夜迷宫：被看不见的手盖住时的反应（levels/floor_08/scripts/maze_lines.gd 读）
# 她看不见手：只觉得「有什么」贴上来了。平时嘴硬，越多越破功；大腿 / 屁股（最怕）按只数分档，明显更崩。
def weak_tiers(z):
    return {
        "1": ["……！%s……什么……看不见的……" % z, "……唔嗯……%s……被、被碰到了……" % z, "……%s……别……那里……" % z],
        "2": ["……两、两只……？%s上……哈……" % z, "……哈、哈哈……%s……数不清……" % z, "……噗哈……又、又多了一只……%s……" % z],
        "4": ["哈哈哈……%s……全、全是……看不见……哈哈……！" % z, "……哈哈……忍、忍不住……%s……要坏掉了……" % z,
              "哈哈哈……为什么……都往%s……哈哈哈……！" % z],
        "6": ["哈哈哈哈哈……！%s……好多……好多……哈哈哈哈……！" % z, "……哈哈哈……我、我投降……%s……投降……哈哈哈哈……！" % z,
              "哈哈哈……补、补偿……也不是这样的……%s……哈哈哈哈……！" % z],
    }


MAZE_LINES = {
    "_说明": "夜迷宫里蓝色公主被看不见的手盖住时的反应（gen_blue_character.py 生成）：zones 普通部位一只；weak 大腿 / 屁股按只数分档。",
    "zones": {
        "sole": ["……脚心。……有什么，贴上来了。", "……看不见……但是，脚心……痒……", "……唔。……谁、谁在挠脚心……"],
        "armpit": ["……！腋下……什么也没有……却……", "……手、手臂……放不下来……噗……", "……腋下……别、别钻……"],
        "waist": ["……腰……一下一下的……看不见……", "……噗。……腰上……有东西……", "……别捏……腰……"],
        "neck": ["……脖子……凉凉的……", "……在脖子上……吹气……？……没人……", "……唔、嗯……脖子……"],
        "belly": ["……肚子……在画圈……噗……", "……什么在……肚子上……", "……唔……肚、肚子……不行……"],
        "chest": ["……胸口……有什么……贴着……", "……！……别、别乱戳……", "……唔……胸口……痒……"],
    },
    "weak": {"thigh": weak_tiers("大腿"), "butt": weak_tiers("屁股")},
    "lamp_clear": ["……呼。……光，好暖。", "……都、都散了。……没笑。", "……月光……谢谢。"],
    "rhythm_charge": ["……？……它们……在等什么……", "……身上的……一起……停住了……", "……不、不对……要来了……"],
    "rhythm_hit": ["哈哈哈哈……！一、一起……犯规……哈哈哈……！", "……哈哈……全、全部一起……", "噗哈哈哈……！我、我就知道……"],
    "rhythm_miss": ["……躲开了。……哼。", "……没挠到。……呼。", "……光里……它们不敢。"],
    "shake_off": ["……冻住，然后……甩掉。", "……别贴着我……走开。", "……冰。……你们，怕冷。"],
    # 第五轮：看不清（黑暗敏感）、追逐怪、遮眼蝠、墙缝刷轮、垂落吊手、千手痒痒裤让魔法失败
    "dark": ["……看不见了……下一下……会在哪……", "……好黑……身体……自己在等……", "……看、看不清……反而……更……",
             "……不知道从哪边来……别……别这样……"],
    "stalker_seen": ["……有什么……在后面……", "……脚步声……不，是手……很多手……", "……别回头。……跑。"],
    "stalker_lost": ["……走、走了……？……呼……", "……憋住了。……它没听见。", "……安静……别出声……"],
    "bat": ["……！眼、眼睛……看不见……！", "……翅膀……别捂着……哈……脖子……", "……什么都看不见……全身……都在等……"],
    "brush": ["……刷、刷子……夹住了……！", "……大腿……刷……哈哈……放开……", "……墙里……为什么会有……刷子……"],
    "hanging": ["……！吊、吊起来了……", "……脚、脚够不着地……哈……腰……", "……放、放我下来……哈哈……！"],
    "pants_fail": ["……噗哈……！裤、裤子……揉、揉腿根……念、念不下去……哈哈哈……！", "……哈哈……别、别在念咒的时候……捏屁股……魔、魔力散了……哈哈哈……",
                   "……唔……手、手指沿着大腿内侧爬上来了……咒、咒语……忘了……哈哈哈哈……！", "……哈……那、那条线……刮、刮一下就……失、失败了……哈哈……",
                   "……哈哈哈……左边捏、右边捏……这、这样怎么施法……哈哈哈哈……！"],
    # 千手痒痒裤发作（每隔几秒一下）：按手法分（揉腿根 / 沿内侧往上爬 / 轮流捏屁股 / 大腿和屁股交界处轻刮）
    "pants_knead": ["……唔……腿、腿根……裤子在揉……别……", "……又、又在揉……一圈一圈的……噗……", "……腿根……按、按进去了……唔嗯……！",
                    "……别、别揉了……腿、腿软……"],
    "pants_climb": ["……手指……沿着大腿内侧……往、往上爬……", "……一、一节一节……停、停在那里……！", "……别、别往上……噗……",
                    "……又、又爬上来了……从膝盖……到……唔……！"],
    "pants_pinch": ["……左、左边捏完……右边……噗……", "……屁、屁股……轮流捏……不、不许……", "……捏、捏一下……又捏一下……唔……！",
                    "……别、别打拍子似的捏……哈……"],
    "pants_scrape": ["……那、那条线……别刮……哈……", "……指、指甲……在腿和屁股中间……刮……噗……！", "……来、来回刮……犯规……唔嗯……",
                     "……交、交界那里……不行……哈哈……"],
}
(OUT / "maze_lines.json").write_text(json.dumps(MAZE_LINES, ensure_ascii=False, indent="\t") + "\n")

print("蓝色公主数据：%d 个来源、%d 组组合、%d 段 CG、%d 段巢穴 CG、%d 段组合演出" % (
    len(rx.get("sources", {})), len(rx.get("combos", {})), len(cgs.get("cgs", {})), len(nest.get("cgs", {})), len(sc.get("scenes", {}))))
