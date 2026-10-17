"""攻防战全部挠痒来源的受挠台词（写进 data/princess_reactions.json 的 sources；可以反复运行，按键覆盖）：
  攻城怪 / 巨魔将军 / 地精工兵、敌塔（enemy_<种类>）、大范围陷阱（hazard_<种类>）、临时痒痒装备（equip_t_<名字>）、
  Boss（gale_bear / puppet_master / carnival_fortress，按技能分组）、怪物配合技（team_<id>，发动时的字幕）。
台词在 tools/build/siege_text/reactions_*.py 和 team_lines.py（粉色 / 蓝色公主各手写一套），这里只负责拼装；
蓝色公主版由 gen_blue_character.py 用 siege_sources("blue") 写进她的 reactions.json（之后再跑它）。
每个来源：name、calm / giggle / helpless_1 / helpless_2、taunts（怪物的嘲讽）、special（暴击）、portrait_words（立绘飘字）、
         first_encounter（第一次挠到时的三句话）、grabbed（被抓住时）。
用法：python tools/build/gen_siege_reactions.py
"""
import json
import os
import sys
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])
sys.path.insert(0, str(Path(__file__).resolve().parent))
from siege_text import reactions_1, reactions_2, reactions_bosses, team_lines  # noqa: E402

SPEAKER = {"pink": "公主", "blue": "蓝色的公主"}


def siege_sources(who):
    """{来源键: 来源段}（who = pink / blue）。"""
    out = {}
    for table in (reactions_1.RX, reactions_2.RX, reactions_bosses.RX):
        for key, entry in table.items():
            src = json.loads(json.dumps(entry[who]))
            src["name"] = entry["name"]
            taunts = entry.get("taunts") or src.get("taunts")
            if taunts:
                src["taunts"] = list(taunts)
            if "first_encounter" in src:
                src["first_encounter"] = [{"speaker": SPEAKER[who], "emotion": e, "text": t} for e, t in src["first_encounter"]]
            out[key] = src
    out.update(team_lines.sources(who))
    return out


def main():
    src = siege_sources("pink")
    rx_path = Path("data/princess_reactions.json")
    rx = json.loads(rx_path.read_text())
    rx["sources"].update(src)
    rx_path.write_text(json.dumps(rx, ensure_ascii=False, indent="\t") + "\n")
    print("攻防战受挠台词：%d 个来源" % len(src))


if __name__ == "__main__":
    main()
