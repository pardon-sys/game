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
    if weak:
        z = weak[0]
        a = pick(["%s嗯、唔……哈……！" % method, "%s不、不行……哈哈……！" % method], cid + "m")
        b = pick(["……%s、%s不行……哈哈哈……那里……真的不行……哈哈哈哈……！" % (z, z),
                  "哈哈哈……！别、别碰%s……忍、忍不住……哈哈哈哈……！" % z,
                  "……一直、一直在%s上……哈哈哈……我、我投降……哈哈哈……！" % z], cid + "w")
        c = pick(["……明明……忍得住的……偏偏是%s……哈哈哈哈……！" % z, "哈哈哈……为、为什么……都知道我%s怕……哈哈哈……！" % z], cid + "x")
    else:
        a = pick(["%s嗯。" % method, "%s唔……" % method], cid + "m")
        b = pick(["……忍、忍得住……嗯、嗯唔……哈……！", "……一、一起来……太狡猾了……哈、哈哈……", "……噗。……没、没笑……哈……"], cid + "w")
        c = pick(["……哈、哈哈……别、别一起……！", "……还、还好……没碰大腿……哈……"], cid + "x")
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
def convert_steps(cid, steps, noun, zone, method_lines=None):
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
            if st.get("portrait") == "wake":
                st["text"] = pick_new(WAKE, seed, used, n=noun)
            elif st.get("act") == "burst":
                if i == last_burst:
                    st["text"] = pick_new(DAZED, seed, used, n=noun, z=zone)
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
                pool = CALM if ha == 0 else (GIGGLE if ha <= 2 and not late else (BREAK if late and ha >= 4 else H1))
                st["text"] = pick_new(pool, seed, used, n=noun, z=zone)
                # 组合演出：每隔几句换成说手法和感受的句子（组合台词）
                if method_lines and i in plain_idx and plain_idx.index(i) % 3 == 1:
                    st["text"] = method_lines[(plain_idx.index(i) // 3) % len(method_lines)]
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
    c["steps"] = convert_steps(cid, c.get("steps", []), "它们", weak[0] if weak else (blue_zone(keys[0]) if keys else "腰"), ml)
(OUT / "combo_scenes.json").write_text(json.dumps(sc, ensure_ascii=False, indent="\t") + "\n")
print("蓝色公主数据：%d 个来源、%d 组组合、%d 段 CG、%d 段巢穴 CG、%d 段组合演出" % (
    len(rx.get("sources", {})), len(rx.get("combos", {})), len(cgs.get("cgs", {})), len(nest.get("cgs", {})), len(sc.get("scenes", {}))))
