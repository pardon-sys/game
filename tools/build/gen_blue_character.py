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
WORDS = {"helpless_1": ["……噗", "唔", "……哈", "嗯…", "……"], "helpless_2": ["哈哈哈", "不、不行", "哈哈哈哈", "……别看", "哈…哈…"]}
ZONE_WORDS = {"helpless_1": ["……{z}", "{z}……唔", "……别碰{z}"], "helpless_2": ["{z}不行哈哈", "{z}哈哈哈", "……{z}……！"]}


def pick(pool, seed, **kw):
    h = int(hashlib.md5(seed.encode("utf-8")).hexdigest(), 16)
    return pool[h % len(pool)].format(**kw)


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
    "helpless_1": picks(GIGGLE, "g_h1", 3, n="……", z="大腿") + picks(BREAK, "g_h1b", 2, n="……", z="大腿"),
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
    for stage, pool, k in (("calm", CALM, 2), ("giggle", GIGGLE, 2), ("helpless_1", GIGGLE, 2), ("helpless_2", BREAK, 2)):
        if stage in s:
            s[stage] = picks(pool, key + stage, k, n=n, z=z)
    if "grabbed" in s:
        s["grabbed"] = picks(GRABBED, key + "grab", 2)
    if "special" in s:
        s["special"] = picks(SPECIAL, key + "sp", 2, z=z)
    if "portrait_words" in s:
        s["portrait_words"] = {"helpless_1": ["……%s" % n[:2], "……噗", "唔"], "helpless_2": ["%s……哈哈" % n[:2], "哈哈哈", "不、不行"]}
    if "lines_by_content" in s:
        for _c, v in s["lines_by_content"].items():
            for stage, pool in (("calm", CALM), ("giggle", GIGGLE), ("helpless_1", GIGGLE), ("helpless_2", BREAK)):
                if stage in v:
                    v[stage] = picks(pool, key + _c + stage, 2, n=n, z=z)
for cid, c in rx.get("combos", {}).items():
    if not isinstance(c, dict):
        continue
    nm = c.get("name", "")
    c["lines"] = ["……%s。……麻烦。" % nm, pick(["……一起来……太、太狡猾了……哈、哈哈……", "……三、三个一起……不算数……哈哈哈……！",
                                            "……忍、忍得住……嗯、嗯唔……哈……！"], cid)]


def no_ben(t):
    return t.replace("本公主", "我")


for ev, ls in rx.get("magic", {}).items():
    rx["magic"][ev] = [no_ben(x) if isinstance(x, str) else x for x in ls]
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
def convert_steps(cid, steps, noun, zone):
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
                pool = CALM if ha == 0 else (BREAK if ha >= 6 or (late and ha >= 2) else GIGGLE)
                st["text"] = pick_new(pool, seed, used, n=noun, z=zone)
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
    cv = pink.get("combos", {}).get(cid, {})
    nm = cv.get("name", "它们") if isinstance(cv, dict) else "它们"
    keys = []
    for k in [x for x in c.get("cast", {}).values()]:
        kind = str(k.get("kind", ""))
        if kind.startswith("monster:") or kind.startswith("trap:"):
            keys.append(kind.split(":", 1)[1])
    c["steps"] = convert_steps(cid, c.get("steps", []), nm, zone_of(keys[0]) if keys else "腰")
(OUT / "combo_scenes.json").write_text(json.dumps(sc, ensure_ascii=False, indent="\t") + "\n")
print("蓝色公主数据：%d 个来源、%d 组组合、%d 段 CG、%d 段巢穴 CG、%d 段组合演出" % (
    len(rx.get("sources", {})), len(rx.get("combos", {})), len(cgs.get("cgs", {})), len(nest.get("cgs", {})), len(sc.get("scenes", {}))))
