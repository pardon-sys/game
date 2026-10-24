"""第 7 天晚上的庆功宴（工时还清以后）：data/after/festival_night.json（AfterFestival / FestivalDanceShow 读）+ 过场 + 摊主对话的节点。
流程：走到篝火边 → 开场过场（after_d7_festival）→ 广场自由活动：
  必做：找篝火派对的主人领舞（FestivalDanceShow）——独舞领舞（光脚，踩错一拍围观的人挠脚心）→ 邀舞（蓝色公主不肯跳，挠到她服软；
        千手痒痒裤的小手帮倒忙）→ 双人舞（小手时不时挠两个人）→ 全镇一起跳。
  可选：五个摊位（stall_<id>.py，各自一个小游戏），做完有一句纪念。
  领舞以后找镇长放烟花 → 烟花（粉色公主随口哼歌：伏笔）→ 队长合上赎罪簿 →「七日赎罪 完」→ 回小屋睡觉。
  dance.sections：每段 kind（lane 音游 / invite 邀舞）、name、bpm、notes、start / end、miss（被挠的旁白，带 who 谁被挠）、react（三档）。
  dance.invite：resolve 蓝色公主的嘴硬值；spots 每个部位 power（减多少嘴硬）、lines；help 小手帮倒忙挠粉色的旁白和反应；agree 她服软。
"""
from .common import A, BLUE, CAP, MAYOR, N, P, L, line

HOST = "篝火派对的主人"
MER, ENG, MAID, GRANNY = "商人", "工匠", "女仆", "面包店奶奶"
TOM, LILY, KIDS, TOWN = "小汤姆", "小莉莉", "小孩们", "镇民们"


def miss(who, caption):
    return {"who": who, "caption": caption}


DANCE = {
    "name": "篝火领舞",
    "hint": "音符滑进圆圈时按 ↑↓←→ / WASD",
    "intro": [
        L("各位——！庆功宴的篝火舞，现在开始——！", HOST),
        L("（广场上一下子安静下来。篝火噼啪作响，满广场的笑声灯笼一盏接一盏地亮着）", N),
        L("领舞的，就是我们这七天最忙的那位～", HOST),
        L("（所有人的目光都落到了她身上）", N),
        L("……好、好多人在看……", P, "shy"),
        L("对了，领舞的规矩——领舞的人要光脚踩在篝火边的暖沙上，这样舞步才会被篝火记住～", HOST),
        L("这规矩是你刚编的吧！", P, "angry"),
        L("是老规矩！对吧，镇长？", HOST),
        L("……嗯。确实是老规矩。", MAYOR),
        L("（……居然是真的……）", P, "sad"),
        L("（她脱下鞋放在长椅边，光脚踩上了暖暖的沙地。围观的小孩们已经蹲在了圈边上，眼睛亮晶晶地盯着她的脚）", N),
        L("还有哦——跳错了拍子，围观的大家可以「帮你找回节奏」～", HOST),
        L("我就知道还有这一条！", P, "angry"),
    ],
    "sections": [
        {"id": "solo", "kind": "lane", "name": "第一段：领舞", "zone": "sole", "bpm": 104, "notes": 18,
         "start": [
             L("第一段，领舞！音乐——！", HOST),
             L("（鼓点响起来。她深吸一口气，踩着暖沙跳出了第一步）", N),
         ],
         "end": [
             L("（第一段的鼓点停了，围观的人群爆发出一阵掌声）", N),
             L("跳得好——！", TOWN),
             L("呼……脚底全是沙……还、还被挠了好几下……", P, "helpless_1"),
             L("那么——第二段是双人舞！领舞的人要去邀请自己的舞伴～", HOST),
             L("（所有人的目光，一齐转向了站在篝火另一边、抱着手臂的蓝色公主）", N),
             L("……", BLUE),
             L("……不。", BLUE),
         ],
         "miss": [miss("pink", "（踩错一拍——圈边的小汤姆扑上来抱住她的脚踝，十根手指在脚心上乱挠）"),
                  miss("pink", "（拍子乱了。小莉莉蹲在沙地上，捏着狗尾巴草在她脚趾缝里扫了一圈）"),
                  miss("pink", "（一个趔趄，面包店奶奶「扶」住她的脚，顺手在脚弓上揉了两下）"),
                  miss("pink", "（踩空了！两个小孩一人抓一只脚，挠前脚掌的挠前脚掌，扫脚跟的扫脚跟）")],
         "react": {"light": ["……被、被抓到了……", "唔……脚、脚心……", "……只是踩错一拍而已……", "……下一拍……不会错……"],
                   "mid": ["哈哈……放、放开我的脚……！", "噗哈……趾缝……！", "哈哈……沙、沙子也在痒……！", "大、大家都在看……哈哈……！"],
                   "heavy": ["哈哈哈……领、领舞的尊严……", "哈哈……脚、脚心不行……！", "哈哈哈哈……我、我投降……", "呜哈……节、节奏全没了……"]}},
        {"id": "invite", "kind": "invite", "name": "邀舞"},
        {"id": "pair", "kind": "lane", "name": "第二段：双人舞", "zone": "sole", "bpm": 112, "notes": 20,
         "start": [
             L("（蓝色公主红着脸站进了篝火圈。两个人面对面，手牵着手）", N),
             L("……只跳一首。", BLUE),
             L("嗯！一首就好！", P, "happy"),
             L("（千手痒痒裤的小手们兴奋地晃来晃去，看起来比谁都想跳）", N),
             L("……它们，也要跳。", BLUE),
             L("……你的裤子会不会趁机挠我的脚。", P, "surprise"),
             L("……会。", BLUE),
             L("音乐——！", HOST),
         ],
         "end": [
             L("（双人舞的最后一拍，两个人转了一个圈，停在了一起）", N),
             L("……", BLUE),
             L("……跳完了。", P, "shy"),
             L("……嗯。", BLUE),
             L("（她们的手还牵着，谁都没先松开）", N),
             L("好——！最后一段！全镇一起跳——！", HOST),
         ],
         "miss": [miss("pink", "（拍子乱了——两只小手从蓝色公主的裤子上伸过来，掰开她的脚趾在趾缝里挠）"),
                  miss("blue", "（转圈慢了半拍——小手们立刻转过去，在蓝色公主自己的大腿内侧打圈）"),
                  miss("pink", "（踩错了！一只小手顺着牵着的手臂爬过来，在她脚心上画了个圈）"),
                  miss("blue", "（两个人撞在一起。小手们「啪啪」两下，轮流捏了捏蓝色公主的屁股）")],
         "react": {"light": ["……你、你的裤子……", "唔……趾、趾缝……", "……小手别过来……", "……下、下一拍跟上……"],
                   "mid": ["哈哈……管、管管你的裤子……！", "噗……脚、脚趾……！", "哈哈……它们在挠我……！", "转、转不动了……哈哈……！"],
                   "heavy": ["哈哈哈……小、小手……投降……", "哈哈……你的裤子……犯规……！", "哈哈哈哈……脚……不行了……", "呜哈……跳、跳不下去了……"]},
         "react_blue": {"light": ["……嗯。", "……没事。", "……专心跳。"],
                        "mid": ["……唔……！", "……别……停……", "……腿……"],
                        "heavy": ["……哈……！", "……噗……哈……", "……不、跳了……哈……"]}},
        {"id": "town", "kind": "lane", "name": "第三段：全镇一起跳", "zone": "sole", "bpm": 124, "notes": 22,
         "start": [
             L("（镇民们一个接一个地走进篝火圈，手拉着手，围成了一个大大的圆）", N),
             L("全镇一起跳！跳错的人——被旁边的人挠！", HOST),
             L("为什么最后还有这条！", P, "angry"),
             L("……每年都有。", MAYOR),
             L("（她左手牵着蓝色公主，右手牵着小莉莉。小莉莉抬头冲她笑了笑，另一只手里还捏着那根狗尾巴草）", N),
         ],
         "end": [
             L("（最后一个鼓点落下，篝火「轰」地蹿起老高。整个广场都在欢呼）", N),
             L("好——！今年的篝火舞，圆满结束——！", HOST),
             L("哈……哈……跳、跳完了……", P, "helpless_1"),
             L("……脚。全是沙。", BLUE),
             L("你也是！你也光脚了！", P, "surprise"),
             L("……被裤子脱的。", BLUE),
         ],
         "miss": [miss("pink", "（踩错了——旁边的小莉莉立刻蹲下去，狗尾巴草在她脚心上扫了三下）"),
                  miss("pink", "（拍子乱了，小汤姆从后面钻过来，挠了挠她的脚跟就跑）"),
                  miss("blue", "（蓝色公主慢了半拍——小手们兴高采烈地捏了她一下，她攥紧了粉色公主的手）"),
                  miss("pink", "（一绊——好几个小孩一起扑过来，按住她的脚挠前脚掌）")],
         "react": {"light": ["……又、又是脚……", "唔……莉莉……", "……一起跳的时候也要挠吗……", "……忍、忍住……"],
                   "mid": ["哈哈……莉、莉莉别扫了……！", "噗哈……脚跟……！", "哈哈……全、全镇都在挠……！", "哈哈……节、节奏……！"],
                   "heavy": ["哈哈哈哈……全镇……犯规……", "哈哈……我、我是领舞……放过我……", "哈哈哈……脚心……化了……", "呜哈……停、停不下来……"]},
         "react_blue": {"light": ["……嗯。", "……我没事。", "……跳你的。"],
                        "mid": ["……唔……！", "……别捏……", "……抓紧……"],
                        "heavy": ["……哈……！", "……噗……", "……哈……哈……"]}},
    ],
    "invite": {
        "resolve": 100,
        "intro": [
            L("（她光着脚走到蓝色公主面前，伸出手）", N),
            L("……来跳嘛。", P, "happy"),
            L("……不跳。", BLUE),
            L("刚才在排练的时候，你明明跳了两步！左、右！", P, "angry"),
            L("……那是走路。", BLUE),
            L("（千手痒痒裤的小手们却「唰」地一下全竖了起来，朝篝火的方向拼命地挥）", N),
            L("……你的裤子想跳。", P, "surprise"),
            L("……裤子不算。", BLUE),
            L("哼——那我就挠到你答应为止！", P, "angry"),
            L("（挑一个地方挠她，让她的嘴硬值降到零。挠对了地方，接一串连击。千手痒痒裤会帮倒忙）", N),
        ],
        "prompt": "挠蓝色公主哪里？（嘴硬值 %d）",
        "spots": [
            {"id": "waist", "name": "腰", "zone": "waist", "power": 15,
             "lines": [L("（指尖戳了戳她的腰侧）", N), L("……就这样？", BLUE), L("……不跳。", BLUE)]},
            {"id": "knee", "name": "膝盖窝", "zone": "thigh", "power": 20,
             "lines": [L("（她蹲下去，手指钻进了蓝色公主的膝盖窝）", N), L("……唔。……那是……膝盖。", BLUE), L("……还是不跳。", BLUE)]},
            {"id": "thigh", "name": "大腿", "zone": "thigh", "power": 35, "combo": True,
             "lines": [L("（手指贴着大腿内侧，慢慢往上打圈，到腿根就停住，再从膝盖画起）", N),
                       L("……！……停……那里……", BLUE, "shy"), L("嘿嘿，声音在抖哦～跳不跳？", P, "happy")]},
            {"id": "butt", "name": "屁股", "zone": "butt", "power": 35, "combo": True,
             "lines": [L("（左右轮流捏一下，再在屁股和大腿交界的地方轻轻刮了一道）", N),
                       L("……！……你……", BLUE, "shy"), L("跳不跳——跳不跳——", P, "happy")]},
            {"id": "sole", "name": "脚心", "zone": "sole", "power": 5,
             "lines": [L("（她蹲下来挠了挠蓝色公主光着的脚心）", N), L("……不怕。", BLUE),
                       L("诶？你、你的脚心不怕痒？", P, "surprise"), L("……你的，怕。", BLUE)]},
        ],
        "combo_ok": [L("……哈……！……噗……", BLUE, "shy"), L("（她的肩膀抖了一下，咬住了嘴唇）", N)],
        "combo_fail": [L("……哼。……忍住了。", BLUE)],
        "help": {"caption": ["（千手痒痒裤的小手急得不行，「帮忙」伸过来——结果挠到了粉色公主的脚心）",
                             "（小手们想帮她挠主人，却顺着她的手臂爬上来，在她自己的腋下戳了戳）",
                             "（两只小手在半空中犹豫了一下，一只挠蓝色公主，一只挠粉色公主的脚趾缝）"],
                 "react": ["哈哈……不、不是挠我啦！", "噗……你、你的裤子帮倒忙……！", "哈哈……挠错人了……！"]},
        "agree": [
            L("……哈……哈……够、够了……", BLUE, "shy"),
            L("跳不跳？", P, "happy"),
            L("……", BLUE),
            L("……跳。……就一首。", BLUE),
            L("好耶——！", P, "happy"),
            L("（围观的镇民们一齐鼓起了掌。蓝色公主的耳朵尖，红得像篝火）", N),
        ],
    },
    "praise": {"perfect": ["漂亮！", "好！", "就是这样！", "完美～"], "good": ["不错～", "还行！", "稍微慢了点～"]},
    "stumble": [
        L("（脚下一软，她整个人踉跄了一下，一屁股坐在了暖沙上）", N),
        L("哈……哈……等、等一下……笑、笑得腿都软了……", P, "helpless_2"),
        L("没关系没关系～这一段重新来！", HOST),
    ],
    "retry": [L("嗯……这一段分数差了一点点～再来一遍！", HOST), L("呜……", P, "sad")],
    "done": [
        L("（掌声和欢呼声把整个广场都填满了。灯笼一盏一盏地晃，像也在跟着笑）", N),
        L("……谢谢你，陪我跳。", P, "shy"),
        L("……裤子要跳的。", BLUE),
        L("嘿嘿。", P, "happy"),
    ],
}

FESTIVAL = {
    "dance": DANCE,
    "objective": {
        "dance": "庆功宴：去篝火边找派对主人领舞",
        "free": "庆功宴：逛逛摊位，或者去找镇长放烟花",
    },
    "stall_names": {"guess": "脚底猜猜乐", "ring": "忍笑套圈", "ice": "冰雕摊", "fish": "捞痒痒鱼", "lick": "舔盐耐力赛"},
    "stall_done": "（%s：通关了！）",
    "dance_first": "先去篝火边领舞吧——派对主人在等你。",
}


# ---------------------------------------------------------------- 过场
def festival_open():
    s = [
        {"actions": [A("camera", to=[41, 24], zoom=1.0, time=0.6)], "wait": 0.6},
        line(N, "（天黑透了。广场上挂满了笑声灯笼，一盏接一盏，从图腾柱一直挂到城门口）"),
        line(N, "（篝火烧得正旺。烤饼干的香味、蘑菇羊咩咩的叫声、小孩们的笑声，全都混在一起）"),
        line(MAYOR, "……七天前，这里还是一片焦土。"),
        line(MAYOR, "城墙补好了，图腾柱扶正了，镇子……也笑回来了。"),
        line(CAP, "（站到篝火前，翻开那本赎罪簿）……一百个工时，一个不少，都还清了。"),
        line(CAP, "从今天起——你不欠小镇什么了。"),
        line(P, "……", "shy"),
        line(TOWN, "哦——！！"),
        line(HOST, "那么！庆功宴——开始～！篝火舞马上就跳，摊位也都开张啦，随便逛～"),
        line(TOM, "姐姐！我的摊位有好玩的！"),
        line(LILY, "还有奶奶的猜猜乐！还有冰雕！还有小羊！"),
        line(P, "好、好多……先从哪里开始……", "happy"),
        line(BLUE, "……跳舞。主人在等。"),
        line(P, "你是不是想看我跳舞？", "happy"),
        line(BLUE, "……没有。"),
        {"actions": [A("camera", reset=True, time=0.4)], "wait": 0.4},
    ]
    return {"name": "庆功宴", "letterbox": True, "skippable": True, "steps": s}


def festival_finale():
    s = [
        {"actions": [A("camera", to=[41, 22], zoom=1.0, time=0.6)], "wait": 0.6},
        line(MAYOR, "……好了。最后，放烟花吧。"),
        line(MAYOR, "这些烟花，是攻防战那天大家没舍得用掉的。……说好了，留到今天。"),
        line(N, "（镇民们点燃了引线。一道光拖着尾巴窜上了地下小镇的穹顶——）"),
        {"actions": [A("flash", time=0.4), A("sfx", sound="star_burst")], "wait": 0.4},
        line(N, "（「砰」——一朵粉色的烟花在洞顶上炸开，照亮了整片岩壁。接着是金色的、蓝色的，一朵接一朵）"),
        line(TOWN, "哇——！"),
        line(N, "（两个人并排坐在篝火边的长椅上，光着的脚还沾着沙子）"),
        line(P, "……好漂亮。", "happy"),
        line(BLUE, "……嗯。"),
        line(N, "（她看着烟花，不知不觉地哼起了一支小调。调子很短，软软的，像是哄小孩睡觉的那种）"),
        line(BLUE, "……"),
        line(BLUE, "……这首歌。"),
        line(P, "嗯？", "surprise"),
        line(BLUE, "……你从哪听来的。"),
        line(P, "诶……？不知道。就是……会唱。", "surprise"),
        line(P, "……好奇怪哦，我连自己是从哪来的都想不起来，却记得一首歌。", "sad"),
        line(BLUE, "……"),
        line(N, "（蓝色公主没有再说话。她低着头，过了好一会儿，才轻轻地开口）"),
        line(BLUE, "……再唱一遍。"),
        line(P, "……好。", "shy"),
        {"actions": [A("flash", time=0.4), A("sfx", sound="star_burst", volume=-4.0)], "wait": 0.6},
        line(N, "（烟花一朵接一朵地开。歌声很小，混在欢呼声里，只有坐在旁边的人听得见）"),
        line(CAP, "（远远地看着长椅上的两个人，把赎罪簿合上，夹在了腋下）"),
        line(CAP, "……七天。辛苦了。"),
        {"actions": [A("fade_out", time=1.2)], "wait": 1.2},
        {"actions": [A("chapter_end", title="七日赎罪　完", subtitle="——那首歌，是谁教她的？", next="floor_06_after_house")], "wait": 1.4},
    ]
    return {"name": "烟花", "letterbox": True, "skippable": False, "steps": s}


CUTSCENES = {"after_d7_festival": festival_open, "after_d7_finale": festival_finale}

# ---------------------------------------------------------------- 对话节点（gen 插进各自的对话文件，排在最前面）
NODES = {
    "after_bonfire_host": {
        "festival_dance": {"lines": [L("领舞大人～大家都等着呢！准备好了吗？")], "prompt": "开始领舞？",
                           "choices": [{"text": "跳！", "next": "festival_dance_go"}, {"text": "等一下", "next": ""}]},
        "festival_dance_go": {"lines": [L("音乐——准备～！")], "set": {"call": "festival_dance"}},
        "festival_after": {"lines": [L("哎呀～今年是我见过最热闹的篝火舞！"), L("……那两只裤子上的小手，跳得比谁都起劲呢～")]},
    },
    "after_mayor": {
        "festival_finale": {"lines": [L("……烟花都准备好了。"), L("要放了吗？")], "prompt": "放烟花？（庆功宴就到这里）",
                            "choices": [{"text": "放吧！", "next": "festival_finale_go"}, {"text": "再逛一会儿", "next": ""}]},
        "festival_finale_go": {"lines": [L("好。……大家，点火——")], "set": {"call": "festival_finale"}},
        "festival_wait": {"lines": [L("先去跳舞吧。领舞的人不在，篝火都不够旺。")]},
    },
}


def inject(dialogues, stalls):
    """庆功宴的入口：派对主人（领舞）、镇长（放烟花）、五个摊主（stalls：对话文件 → 摊位 id），都排在 entries 最前面。"""
    host = dialogues["after_bonfire_host"]
    host["nodes"].update(NODES["after_bonfire_host"])
    host["entries"][0:0] = [{"if": {"flag": "after_festival_on", "not": "festival_dance_done"}, "node": "festival_dance"},
                            {"if": {"flag": ["after_festival_on", "festival_dance_done"]}, "node": "festival_after"}]
    mayor = dialogues["after_mayor"]
    mayor["nodes"].update(NODES["after_mayor"])
    mayor["entries"][0:0] = [{"if": {"flag": ["after_festival_on", "festival_dance_done"]}, "node": "festival_finale"},
                             {"if": {"flag": "after_festival_on"}, "node": "festival_wait"}]
    for f, (sid, spec) in stalls.items():
        d = dialogues[f]
        d["nodes"]["stall_offer"] = {"lines": spec["offer"], "prompt": spec["prompt"],
                                     "choices": [{"text": spec["yes"], "next": "stall_go"}, {"text": "等一下再说", "next": ""}]}
        d["nodes"]["stall_go"] = {"lines": spec["go"], "set": {"vars": {"stall_req": sid}, "call": "festival_stall"}}
        d["nodes"]["stall_done"] = {"lines": spec["after"]}
        d["entries"][0:0] = [{"if": {"flag": "after_festival_on", "not": "stall_%s_done" % sid}, "node": "stall_offer"},
                             {"if": {"flag": ["after_festival_on", "stall_%s_done" % sid]}, "node": "stall_done"}]
