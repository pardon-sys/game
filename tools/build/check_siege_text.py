"""攻防战文本检查（读生成好的数据；有问题时列出来并以非 0 退出）：
  - 笑倒 CG / 三来源组合演出 / 失败小剧场：四幕（act 1~4）+ 爆发（act = burst）、句数达到要求；
  - 粉色公主的段落要写脚的手法（脚心 / 趾缝 / 足弓……），蓝色公主的段落要写大腿 / 屁股的手法（腿根 / 内侧 / 屁股 / 交界……）；
  - 蓝色公主的台词不重复，也不靠固定口头禅（同一个短语出现在太多句里会列出来，「不痒」最多出现 MAX_NOT_ITCHY 次）；
  - 没有繁体字 / 日文假名。
  受挠台词（攻防战全部来源，粉 / 蓝）也一起查字和重复。
用法：python tools/build/check_siege_text.py [--top]（--top 额外列出蓝色公主台词里最常见的短语）
"""
import json
import os
import re
import sys
from collections import Counter
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])
PINK, BLUE = "公主", "蓝色的公主"
FOOT = ("脚心", "趾缝", "足弓", "脚趾", "脚底", "脚跟", "脚背", "脚掌")
LEG = ("腿根", "内侧", "屁股", "交界", "大腿")
# 常见繁体字（简体里没有的写法）
TRAD = set("這個們來說時會對還樣點開關讓過頭腳嗎麼為與東車長風飛實現發經見認識間聽覺學體從後邊兩隻癢擊撓戰鬥塊護隊禮爾們總彈網線織蟲貓魚鳥龍雙觸緊靈寶門萬幾臉語")
KANA = re.compile(r"[぀-ヿ]")
MAX_NOT_ITCHY = 3
CG_MIN, BOSS_MIN, THEATER_MIN, SCENE_MIN = 28, 38, 32, 28
BOSSES = ("troll_general", "gale_bear", "puppet_master", "carnival_fortress")

problems = []
blue_lines = []


def text_of(steps):
    return [s for s in steps if s.get("text")]


def scan_chars(where, text):
    bad = sorted({ch for ch in text if ch in TRAD})
    if bad:
        problems.append("%s：繁体字 %s" % (where, "".join(bad)))
    if KANA.search(text):
        problems.append("%s：日文假名「%s」" % (where, text))


def check_theater(where, th, extra_blue=None):
    """失败小剧场：四幕 + 两个人各爆发一次，两个人的手法都要写到。"""
    steps = th.get("steps", [])
    acts = [str(s.get("act")) for s in steps]
    for a in ("1", "2", "3", "4"):
        if a not in acts:
            problems.append("%s：缺第 %s 幕" % (where, a))
    if acts.count("burst") < 2:
        problems.append("%s：两个人要各爆发一次（现在 %d 次）" % (where, acts.count("burst")))
    lines = text_of(steps)
    if len(lines) < THEATER_MIN:
        problems.append("%s：只有 %d 句（要 %d）" % (where, len(lines), THEATER_MIN))
    body = "".join(s["text"] for s in lines)
    if not any(w in body for w in FOOT):
        problems.append("%s：没写粉色公主脚的手法" % where)
    if not any(w in body for w in LEG):
        problems.append("%s：没写蓝色公主大腿 / 屁股的手法" % where)
    for s in lines:
        scan_chars(where, s["text"])
        if s.get("speaker") == BLUE and (extra_blue is None or s["text"] not in extra_blue):
            blue_lines.append((where, s["text"]))


def check_cg(where, cg, who, min_lines):
    steps = cg.get("steps", [])
    acts = {str(s.get("act")) for s in steps}
    for a in ("1", "2", "3", "4", "burst"):
        if a not in acts:
            problems.append("%s：缺第 %s 幕" % (where, a))
    lines = text_of(steps)
    if len(lines) < min_lines:
        problems.append("%s：只有 %d 句（要 %d）" % (where, len(lines), min_lines))
    body = "".join(s["text"] for s in lines)
    want = FOOT if who == "pink" else LEG
    if not any(w in body for w in want):
        problems.append("%s：没写%s的手法" % (where, "脚" if who == "pink" else "大腿 / 屁股"))
    for s in lines:
        scan_chars(where, s["text"])
        if s.get("speaker") == BLUE:
            blue_lines.append((where, s["text"]))


def main():
    for who, path in (("pink", "data/siege_cgs.json"), ("blue", "data/characters/blue/siege_cgs.json")):
        data = json.loads(Path(path).read_text())
        for cid, cg in data["cgs"].items():
            key = cid.replace("death_siege_", "")
            check_cg("CG %s（%s）" % (key, who), cg, who, BOSS_MIN if key in BOSSES else CG_MIN)
    for who, path in (("pink", "data/siege_scenes.json"), ("blue", "data/characters/blue/siege_scenes.json")):
        for sid, sc in json.loads(Path(path).read_text())["scenes"].items():
            check_cg("组合 %s（%s）" % (sid, who), sc, who, SCENE_MIN)
    for path in sorted(Path("data/theater/siege").glob("siege_fail_*.json")):
        if path.stem.endswith("_pants"):
            continue
        normal = json.loads(path.read_text())
        check_theater("小剧场 %s" % path.stem, normal)
        pants = Path(str(path).replace(".json", "_pants.json"))
        if pants.exists():
            check_theater("小剧场 %s" % pants.stem, json.loads(pants.read_text()), {s.get("text") for s in normal["steps"]})
    # 受挠台词：攻防战的全部来源（gen_siege_reactions.siege_sources）
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from gen_siege_reactions import siege_sources
    for who in ("pink", "blue"):
        for key, src in siege_sources(who).items():
            lines = []
            for stage in ("calm", "giggle", "helpless_1", "helpless_2", "special", "grabbed", "trigger"):
                lines += src.get(stage, [])
            for group in ("lines_by_content", "variants"):
                for v in src.get(group, {}).values():
                    for stage_lines in v.values():
                        lines += stage_lines
            for t in lines:
                scan_chars("台词 %s（%s）" % (key, who), t)
                if who == "blue":
                    blue_lines.append(("台词 " + key, t))
    # 蓝色公主：重复句 / 口头禅
    seen = Counter(t for _w, t in blue_lines)
    for t, n in seen.items():
        if n > 1:
            problems.append("蓝色公主重复的台词（%d 次）：%s" % (n, t))
    n_itchy = sum(1 for _w, t in blue_lines if "不痒" in t)
    if n_itchy > MAX_NOT_ITCHY:
        problems.append("蓝色公主「不痒」出现了 %d 句（最多 %d）" % (n_itchy, MAX_NOT_ITCHY))
    if "--top" in sys.argv:
        grams = Counter()
        for _w, t in blue_lines:
            core = re.sub(r"[哈噗咿……、。！？，\s]", "", t)
            grams.update({core[i:i + 3] for i in range(len(core) - 2)})
        print("蓝色公主最常见的三字短语：", grams.most_common(25))
    for p in problems:
        print("  " + p)
    print("攻防战文本检查：蓝色公主台词 %d 句，问题 %d 个" % (len(blue_lines), len(problems)))
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
