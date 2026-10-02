"""生成怪物巢穴的过场 data/nest_cgs.json（被巢穴怪物拖进巢穴时播放；格式同 data/cgs.json，CG 播放器载入时合并进来）。

每种巢穴一段，三幕：被拖进巢穴口（失控 1）→ 巢穴里一群一起挠（失控 2）→ CG 图（第三幕：大批同类怪物从四周涌上来，
之后每句都有好几只一起挠）→ 醒来。第三幕立绘 nest_<种类>_3：把横版 CG 图放进 assets/cg/portraits/nest_<种类>_3.png
（或用 tools/art/import_cg.py 从 assets/generated/CG/nest_<种类>.png 生成）后重新运行本脚本，就会换成横版大框。
演员、立绘规则和 standard() 来自 gen_cgs.py。
用法：python tools/build/gen_nest_cgs.py
"""
import json

import gen_cgs as G
from gen_cgs import monster

# 只收集巢穴过场自己的立绘 id
G.portraits.clear()
cgs = {}
nests = {}
## 第三幕涌上来的同类怪物：围着公主的一圈位置（舞台坐标，公主在 (0, 8)）
CROWD = [(-30, 6), (30, 8), (-22, -10), (22, -12), (-12, 24), (14, 26), (-40, 18), (40, 16), (-6, -20), (8, -22),
         (-34, 30), (34, 30)]


def add_crowd(cg, key, foe, fx, n):
    """第三幕：n 只同类怪物从两边涌上来，之后第三幕每句台词都有 3 只一起挠。"""
    names = []
    for i, (x, y) in enumerate(CROWD[:n]):
        name = "crowd%d" % (i + 1)
        cg["cast"][name] = monster(foe, (x, y), "right" if x < 0 else "left", scale=0.85)
        names.append(name)
    steps = cg["steps"]
    i3 = next(i for i, st in enumerate(steps) if st.get("portrait") == key + "_3")
    steps[i3]["actions"] = steps[i3]["actions"] + [
        {"do": "enter", "who": nm, "from": [(-1 if CROWD[i][0] < 0 else 1) * 90, 0], "time": 0.5 + 0.07 * i}
        for i, nm in enumerate(names)]
    k = 0
    for st in steps[i3:]:
        if "text" not in st:
            break  # 第三幕结束（淡出）
        for _ in range(3):
            st["actions"].append({"do": "tickle", "who": "princess", "by": names[k % n], "repeat": 4, "interval": 0.22, "fx": fx})
            k += 1
        st["actions"].append({"do": "hop", "who": names[(k + 1) % n], "count": 1})


def add_nest(kind, foe, name, title, lines, taunts, act3, crowd=10, **kw):
    key = "nest_" + kind
    cg = G.standard(key, name, lines, taunts, act3, foe=foe, burst=G.BL.NEST[kind], **kw)
    cg["name"] = title
    add_crowd(cg, key, foe, kw.get("fx", "lines"), crowd)
    cgs[key] = cg
    nests[kind] = {"cg": key, "source": foe}


add_nest("rat_hole", "rat", "挠脚鼠", "鼠洞里的脚心宴",
         ["被、被拖进洞里了……好黑……好多吱吱声……",
          "鞋子被扒掉了——一整窝老鼠在挠脚心——哈哈哈哈！", "",
          "……醒来了。脚心还麻麻的……看到鼠洞先把它敲碎！"],
         ["吱吱！拖进来啦！", "全家都来挠吱！"],
         [("N", "（洞里铺满了干草，几十只挠脚鼠排着队，把公主的两只脚架在了草堆上）"),
          ("P", "放、放开脚！你们要干什么——"),
          ("M", "吱！脚心宴会，开始！"),
          ("N", "（小爪子挠过脚心，又钻进脚趾缝里抓，一只接一只地轮流上阵）"),
          ("P", "哈哈哈哈！一、一只挠完又换一只——停不下来啊！"),
          ("M", "吱吱～脚趾缝最好吃～"),
          ("P", "……鼠、鼠窝……再也不靠近了……哈哈……")],
         fx="hand", extras={"rat2": monster("rat", (-22, 12), "right"), "rat3": monster("rat", (4, 26), "left")})
add_nest("fairy_flower", "fairy", "羽毛小精灵群", "花心里的羽毛摇篮",
         ["花、花瓣合起来了……被关进花里了……",
          "花蕊里全是小精灵——每个都拿着羽毛——哈哈哈哈！", "",
          "……醒来了。身上一股花香……那朵花一定要打碎！"],
         ["咯咯～欢迎来花里玩～", "羽毛准备好啦～"],
         [("N", "（巨大的花朵把公主整个包了进去，花蕊里飞出一群又一群小精灵）"),
          ("P", "好、好香……不对，好多羽毛……"),
          ("M", "咯咯咯～花粉加羽毛，双倍痒痒～"),
          ("N", "（花粉落在皮肤上，痒意一下子放大了好几倍，羽毛再从上面轻轻扫过）"),
          ("P", "花、花粉——哈哈哈哈比平时痒好多！"),
          ("M", "挠挠大作战，第二回合～"),
          ("P", "腋、腋下也……哈哈哈哈哈！"),
          ("P", "……花里……出不去……哈哈……")],
         fx="feather", enter_from=(0, -70), stand=(16, -10), extras={"fairy2": monster("fairy", (-18, -8), "right")})
add_nest("slime_pool", "slime", "史莱姆", "果冻池的深处",
         ["脚、脚被拖进池子里了……凉凉的……",
          "整个人陷进果冻里了——到处都在蠕动——哈哈哈哈！", "",
          "……醒来了。头发上还挂着果冻……下次先打碎那个池子！"],
         ["噗叽～欢迎回家～", "大家一起，噗叽噗叽～"],
         [("N", "（公主一点一点陷进了史莱姆池，只剩脖子以上露在外面）"),
          ("P", "陷、陷进去了……出不来……"),
          ("M", "噗叽～池子里好暖和吧～"),
          ("N", "（果冻在池底轻轻翻涌，一下一下地揉着脚心、挤着腰）"),
          ("P", "里面在动——哈哈哈哈不要揉腰！"),
          ("M", "噗叽噗叽～再多泡一会儿～"),
          ("P", "……要、要被果冻泡化了……哈哈……")],
         extras={"slime2": monster("slime", (-20, 10), "right")})
add_nest("jelly_egg", "mana_jelly", "魔力水母", "水母卵的孵化场",
         ["卵、卵在发光……一只只小水母钻出来了……",
          "刚孵出来的小水母全缠上来了——哈哈哈哈魔力好乱！", "",
          "……醒来了。魔力还在身体里晃……那堆卵一定要打碎！"],
         ["噗噜～妈妈说要抓住公主～", "孵出来啦～一起挠～"],
         [("N", "（一颗颗水母卵接连裂开，半透明的小水母像气泡一样飘了出来）"),
          ("P", "好、好多……全都朝这边飘过来了！"),
          ("M", "噗噜噗噜～第一口魔力，好甜～"),
          ("N", "（细细的触须缠满了手腕和脚踝，魔力被搅得一阵一阵发麻）"),
          ("P", "麻、麻麻的又好痒——哈哈哈哈停不下来！"),
          ("M", "大家排好队，一只挠一下～"),
          ("P", "……孵、孵化场……不要再孵了……哈哈……")],
         enter_from=(0, -60), stand=(18, -4), extras={"jelly2": monster("mana_jelly", (-20, -2), "right")})
add_nest("chest_pile", "mimic", "宝箱怪", "宝箱山的肚子里",
         ["宝、宝箱堆在动……被拖进去了！",
          "好几个宝箱一起咬住——舌头在挠脚心——哈哈哈哈！", "",
          "……醒来了。身上一股木头味……那堆宝箱一定有问题！"],
         ["咔哒！新宝物入库～", "大家一起收藏～"],
         [("N", "（宝箱堆一个接一个张开了嘴，公主被一路传进了最里面的大箱子）"),
          ("P", "好黑！放我出去！"),
          ("M", "咔哒～宝物要一层一层收好～"),
          ("N", "（每个箱盖里都伸出长长的舌头，从脚心一路舔到腰）"),
          ("P", "舌、舌头好多——哈哈哈哈好痒！"),
          ("M", "露在外面的脚，咔哒咔哒～"),
          ("P", "……再、再也不碰宝箱了……哈哈……")],
         enter_from=(0, 0), stand=(0, -6), extras={"mimic2": monster("mimic", (22, 6), "left")})


def main():
    data = {
        "_说明": [
            "怪物巢穴的过场：被巢穴怪物拖进巢穴时播放（MonsterNest._swallow → Princess.dragged_into_nest → CG.play_nest(种类)）。",
            "格式同 data/cgs.json（portraits / cgs），载入时合并进 cgs.json 的数据；演员用 cgs.json 的 actors。",
            "nest：巢穴种类（MonsterNest.kind）-> {cg: CG id, source: 演员来源键}。",
            "由 tools/build/gen_nest_cgs.py 生成（台词写在脚本里），直接改这里会被重新生成覆盖。",
        ],
        "portraits": G.portraits,
        "nest": nests,
        "cgs": cgs,
    }
    open("data/nest_cgs.json", "w").write(json.dumps(data, ensure_ascii=False, indent="\t") + "\n")
    print(len(cgs), "段巢穴过场,", len(G.portraits), "立绘 id")


if __name__ == "__main__":
    main()
