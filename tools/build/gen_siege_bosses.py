"""攻防战小 Boss 的数据（SiegeBoss 读）：技能名、冷却、预警时长、喊话，出场 / 狂暴 / 打倒的横幅，打倒奖励。
另外输出狂欢要塞的机关数据 data/siege/fortress.json（FortressRules 读）。技能名只在这里写一份。

  data/siege/bosses.json   {boss 键: {name, color, crystals, rage_cd, intro / rage / defeat: {title, sub, color?}, skills: {技能: {name, cd, warn, shout}}, notices}}
  data/siege/fortress.json 要塞车身 / 增援 / 六个机关（名字取自 bosses.json 的 carnival_fortress.skills）

用法：python tools/build/gen_siege_bosses.py
"""
import json
from pathlib import Path


def S(name, cd, warn=0.0, shout=""):
    out = {"name": name, "cd": cd, "warn": warn}
    if shout:
        out["shout"] = shout
    return out


BOSSES = {
    # 第 3 波：TrollGeneral（冷却按 rate 缩短，狂暴后 rate 变大）
    "troll_general": {
        "name": "攻城巨魔将军", "color": [1.0, 0.55, 0.35], "crystals": 30,
        "intro": {"title": "攻城巨魔将军", "sub": "第 3 波的小 Boss——看清地上的预警！"},
        "rage": {"title": "将军狂暴了！", "sub": "移速变快、技能更频繁，地震重击变成两连！", "color": [1.0, 0.3, 0.25]},
        "defeat": {"title": "攻城巨魔将军被打倒了！", "color": [1.0, 0.9, 0.5]},
        "skills": {
            "grab": S("大手抓挠", 8.0, 0.45, "抓到了！脚心——给我露出来！"),
            "swipe": S("三连扫掌", 6.0),
            "quake": S("地震重击", 11.0, 1.0),
            "throw": S("投掷上墙", 10.0, 0.0, "飞——上——去！"),
            "ram": S("攻城锤冲锋", 16.0, 1.2, "攻城锤——撞开它！"),
            "leap": S("跳劈城墙", 18.0, 0.9),
            "cry": S("战吼", 15.0, 0.0, "吼——————！"),
            "banner": S("痒痒军旗", 24.0, 0.0, "插旗！小的们，给我钻出来！"),
            "build": S("就地搭塔", 30.0, 0.0, "哔——！工兵！就在这儿搭！"),
        },
        "notices": {"banner_broken": "痒痒军旗被拆掉了！"},
    },
    # 第 6 波：GaleBear（冷却是实际秒数 ×2，狂暴后 × rage_cd）
    "gale_bear": {
        "name": "狂风熊统领", "color": [1.0, 0.78, 0.35], "crystals": 40, "rage_cd": 0.45,
        "intro": {"title": "狂风熊统领", "sub": "第 6 波：躲开羽痒龙卷，冻结风眼！冰塔伤害只有 25%。"},
        "rage": {"title": "熊统领：狂风推进！", "sub": "半血后向城墙推进，技能与协作加快！"},
        "defeat": {"title": "狂风熊统领被打倒了！"},
        "skills": {
            "tornado": S("八向羽痒龙卷", 3.6, 0.18),
            "vacuum": S("吸痒羽毛风眼", 4.2, 0.18),
            "chase": S("羽刷追痒", 2.4, 0.15),
            "pulse": S("挠痒风盾震荡", 2.7, 0.12),
            "lanes": S("羽痒三岔压城", 4.8, 0.18),
            "convoy": S("旋风挠痒运兵", 4.8, 0.15),
            "paw": S("熊掌挠挠", 1.8, 0.1, "熊掌挠脚心！"),
        },
    },
    # 第 9 波：PuppetMaster
    "puppet_master": {
        "name": "狂欢挠痒魔偶师", "color": [0.95, 0.65, 0.85], "crystals": 50, "rage_cd": 0.45,
        "intro": {"title": "狂欢挠痒魔偶师", "sub": "第 9 波：缎带换位、刷轮拖行！塔伤害只有 25%。"},
        "rage": {"title": "魔偶师：机关狂欢！", "sub": "双人拖行、六段刷挠，机关接力加快！"},
        "defeat": {"title": "狂欢挠痒魔偶师被打倒了！"},
        "skills": {
            "tether": S("缎带提线", 3.2, 0.18),
            "swap": S("缎带换位", 6.0, 0.18),
            "brush": S("双路机关刷挠", 2.4, 0.12),
            "cross": S("十字刷具阵", 4.2, 0.18),
            "link": S("双子痒感线", 6.0, 0.12),
            "lift": S("吊起刷挠", 3.6, 0.12),
            "relay": S("挠痒接力号令", 4.5, 0.12),
            "winch": S("缎带绞盘拖行", 3.0, 0.1),
        },
    },
    # 第 12 波：CarnivalFortress（机关由 FortressMechanisms 调度；life = 机关持续秒数）
    "carnival_fortress": {
        "name": "狂欢攻城堡垒", "color": [1.0, 0.78, 0.3], "crystals": 0,
        "intro": {"title": "狂欢攻城堡垒", "sub": "持续增援！救回冰塔 · 蓄力时攻击核心"},
        "rage": {"title": "展开平台：双重追猎", "sub": "巨手巡航 · 交叉空降 · 双钩重炮"},
        "overdrive": {"title": "超载：全机关同时运转！", "sub": "每轮三个机关一起来 · 冷却缩短 · 增援全开", "color": [1.0, 0.35, 0.3]},
        "defeat": {"title": "狂欢攻城堡垒被打倒了！"},
        # 第十轮：原六个机关冷却 ×0.7；新增五个（auto = 不进轮换，由要塞自己按条件放：护盾柱按血量、车头舱门按时间）
        "skills": {
            "missiles": S("猎笑巡航弹", 12.6) | {"life": 7.0},
            "hands": S("伸缩追猎巨手", 11.2) | {"life": 12.0},
            "rockets": S("双线火箭运兵", 14.0) | {"life": 5.0},
            "crane": S("双钩劫塔", 18.2) | {"life": 8.7},
            "convoy": S("三批交叉车阵", 18.2) | {"life": 9.0},
            "cannon": S("三连锁定重炮", 21.0) | {"life": 12.0},
            "tornado_launcher": S("龙卷发射器", 18.0) | {"life": 9.0},
            "portal_drop": S("传送门空降", 22.0) | {"life": 10.0},
            "fireworks": S("烟花弹幕", 20.0) | {"life": 8.0},
            "magnet": S("磁吸车头", 18.0) | {"life": 5.0},
            "shields": S("护盾发生柱", 999.0) | {"life": 40.0, "auto": True},
            "hatch": S("车头舱门", 16.0) | {"life": 3.0, "auto": True},
        },
        # 要塞上的怪物协作（FortressCooperation）
        "cooperation": {
            "escort": S("盾蟹护卫车队", 16.0), "repair": S("工兵维护母车", 20.0), "airlift": S("蝠群接应火箭兵", 18.0),
            "hook": S("钩索接应巨手", 16.0), "warm": S("暖炉伴车拆塔", 22.0), "resonance": S("共振塔车队号令", 24.0),
        },
        "notices": {
            "pair": "平台调度：%s ＋ %s",
            "tower_dismantled": "冰塔被拆解！下轮重炮：四连装填",
            "recoil_title": "重炮反冲 −%d", "recoil_sub": "整轮炮击已取消！",
            "triple": "超载调度：%s ＋ %s ＋ %s",
            "shield_up": "护盾发生柱立起来了！柱子不倒，母车几乎打不动——先打柱子！",
            "shield_down": "护盾柱全倒了！母车的护盾消失！",
            "hatch": "车头舱门打开了！一排攻城车冲出来了！",
            "magnet": "车头在吸人！往反方向跑或者冲刺挣开！",
            "portal": "传送门开到城墙上了！冰封它！",
        },
    },
}

FORTRESS = {
    "body": [1176, 400], "hp": 6000, "expand_hp": 2000,
    "crew_cap": 64, "cart_cap": 40, "alive_cap": 800,
    "base_rate": 10.0, "tier_seconds": 45.0, "multipliers": [1.0, 1.5, 2.0, 2.5, 3.0],
    "skills": {k: {"name": v["name"], "cd": v["cd"], "life": v["life"], "auto": v.get("auto", False)}
               for k, v in BOSSES["carnival_fortress"]["skills"].items()},
    "pairs": [["hands", "missiles"], ["convoy", "rockets"], ["crane", "cannon"], ["tornado_launcher", "magnet"], ["portal_drop", "fireworks"]],
    "pair_delays": [0.8, 0.8, 1.0, 0.8, 0.8],
    # 第十轮加强：机关出手更快（预警 ×warn_mult），巨手更快更远；剩 overdrive_ratio 血进超载（每轮三个机关、冷却再 ×overdrive_cd、增援最高档）
    "warn_mult": 0.75, "hand_speed": 1.4, "hand_reach": 1.5,
    "overdrive_ratio": 0.3, "overdrive_cd": 0.6,
    # 护盾发生柱：剩 shield_at 比例的血各立一次 shield_count 根（每根 shield_hp），柱子没倒完母车受伤 ×shield_reduction
    "shield_at": [0.75, 0.45], "shield_count": 3, "shield_hp": 40, "shield_reduction": 0.2,
    # 车头舱门：登场时车头前排 intro_carts 辆，之后每次放 hatch_count 辆
    "intro_carts": 8, "hatch_count": 10,
    # 龙卷发射器 / 传送门空降 / 烟花弹幕 / 磁吸车头
    "tornado_count": 3, "tornado_crew": 4, "portal_crew": 12, "firework_waves": 3, "firework_shells": 7,
    "magnet_radius": 260.0, "magnet_pull": 70.0,
}


def skill_names(boss):
    """文本模块（tools/build/siege_text）用：技能键 → 名字。"""
    return {k: v["name"] for k, v in BOSSES[boss]["skills"].items()}


def main():
    Path("data/siege").mkdir(parents=True, exist_ok=True)
    Path("data/siege/bosses.json").write_text(json.dumps({"_说明": ["攻防战小 Boss 的技能 / 横幅（tools/build/gen_siege_bosses.py 生成；SiegeBoss 读）。"],
                                                          **BOSSES}, ensure_ascii=False, indent="\t") + "\n")
    Path("data/siege/fortress.json").write_text(json.dumps(FORTRESS, ensure_ascii=False, indent="\t") + "\n")
    print("攻防战 Boss 数据：", ", ".join("%s（%d 技能）" % (k, len(v["skills"])) for k, v in BOSSES.items()))


if __name__ == "__main__":
    main()
