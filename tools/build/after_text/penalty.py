"""七日赎罪的补罚任务（镇民执行惩罚，用来抵罚的工时）：data/after/penalty.json（ModelShow / PenaltyDanceShow / AfterPenance 读）+ 委托人对话里的节点。
赎罪簿上有还没抵的受罚（示众笑出声、任务失败……）时，市场监督 / 篝火派对的主人头上冒「！」，找他们就能接（白天、晚上宵禁前都行）；做完一次抵掉一条受罚、减工时。
  model  市场监督「活体模特」：站在摊位上给「防痒袜子」当模特，路过的顾客「试试效果」——要保持姿势（平衡 A / D）和表情（J 绷住），
         动了 / 笑了被市场监督加时；撑过时间抵掉。customers：每个顾客 name、intro 登场、desc 挠法描写、zone 部位、push 晃多少、face 掉多少表情
  dance  篝火派对的主人「罚跳舞」：篝火边罚跳（音游 RhythmLane），跳错一拍，围观的人上来挠一下（crowd：挠法 / 部位轮换），错太多加跳一段
"""
from .common import N, P, L

SUP, HOST = "市场监督", "篝火派对的主人"

PENALTY = {
    "hours": 3,
    "model": {
        "intro": [
            {"speaker": SUP, "text": "赎罪簿上还记着你的受罚。……今天来抵一笔。"},
            {"speaker": SUP, "text": "摊位上新到了一批「防痒袜子」，卖不出去。你穿上，站在摊位上给大家看。"},
            {"speaker": P, "text": "就、就站着？那很简单啊。", "emotion": "happy"},
            {"speaker": SUP, "text": "顾客会「试试效果」。"},
            {"speaker": P, "text": "……「试试效果」是什么意思。", "emotion": "surprise"},
            {"speaker": SUP, "text": "就是挠你一下，看看防不防痒。……当模特的，不准动，不准笑。动一下，加时。"},
            {"speaker": N, "text": "（A / D 保持姿势别晃，J 绷住表情。动了或者笑了，市场监督就加时。撑过时间就抵掉一笔受罚）"},
        ],
        "customers": [
            {"name": "商人", "intro": "（商人凑过来，捏起一根羽毛）防痒袜子？我来试试——",
             "desc": "（羽毛隔着袜子在脚底上来回扫——袜子薄得跟没穿一样）", "zone": "sole", "push": 0.35, "face": 18},
            {"name": "小汤姆", "intro": "（小汤姆蹦蹦跳跳地跑过来）姐姐当模特！我要试！",
             "desc": "（小汤姆扳开她的脚趾，手指隔着袜子在趾缝里一下一下地抠）", "zone": "sole", "push": 0.45, "face": 22},
            {"name": "面包店奶奶", "intro": "（奶奶推了推眼镜）哎呀，这袜子质量怎么样？奶奶摸摸看。",
             "desc": "（奶奶的手指捏住脚弓，慢慢地揉——「嗯，料子挺软的」，又揉了揉）", "zone": "sole", "push": 0.3, "face": 16},
            {"name": "保卫队员", "intro": "（巡逻的队员停下来）……队长说，买之前要测试。",
             "desc": "（队员掏出一把小刷子，在脚心上「唰唰」刷了好几下，认真地记着笔记）", "zone": "sole", "push": 0.5, "face": 24},
            {"name": "小莉莉", "intro": "（小莉莉躲在摊位后面，探出半个脑袋）……我、我也想试……",
             "desc": "（狗尾巴草的穗子从脚踝慢慢扫到脚心，又扫回来）", "zone": "sole", "push": 0.35, "face": 20},
            {"name": "篝火派对的主人", "intro": "（派对主人凑过来）哎呀，这么有趣的事怎么不叫我～",
             "desc": "（她的手指钻进袜口，挠了挠脚踝，又顺手挠了一下膝盖窝）", "zone": "thigh", "push": 0.55, "face": 26},
        ],
        "wobble": ["（身子一晃——差点从摊位上掉下去）", "（脚一缩，整个人歪了）"],
        "move": [{"speaker": SUP, "text": "动了。加时。"}, {"speaker": P, "text": "呜……", "emotion": "sad"}],
        "laugh": [{"speaker": SUP, "text": "笑了。加时。"}, {"speaker": P, "text": "那、那是被挠的啊……！", "emotion": "angry"}],
        "react": {"light": ["……（保持微笑）……", "……这、这袜子很防痒哦……", "……一点都不痒……", "……（脚趾在袜子里蜷住了）"],
                  "mid": ["……噗……不、不痒……", "……唔……袜、袜子很好……", "……哈……请、请多关照……", "……别、别挠那里……"],
                  "heavy": ["……哈、哈哈……这袜子……一点都不防痒啊……！", "……不、不卖了……哈哈……", "……投、投降……", "……哈……别再试了……"]},
        "done": [
            {"speaker": SUP, "text": "……时间到。"},
            {"speaker": SUP, "text": "防痒袜子，卖出去了七双。……大家都说「看模特的反应就知道不防痒」。"},
            {"speaker": P, "text": "那、那不就是说这袜子不好吗！", "emotion": "angry"},
            {"speaker": SUP, "text": "……卖出去了就行。受罚抵掉一笔。"},
        ],
        "fail": [{"speaker": SUP, "text": "……加时加到天黑了。今天就到这里，下次再来。"}],
        "time": 45.0,
    },
    "dance": {
        "intro": [
            {"speaker": HOST, "text": "哎呀～赎罪簿上还有受罚没抵？那就——罚跳舞！"},
            {"speaker": P, "text": "罚、罚跳舞……跳舞也算罚吗？", "emotion": "surprise"},
            {"speaker": HOST, "text": "算！我们镇的老规矩：在篝火边跳，跳错一拍，围观的人就上来挠一下～"},
            {"speaker": P, "text": "……这个老规矩到底是谁定的啊。", "emotion": "sad"},
            {"speaker": HOST, "text": "我呀～大家，围过来！"},
            {"speaker": N, "text": "（音符滑进圆圈时按 ↑↓←→。跳错一拍，围观的人挠一下；错太多加跳一段）"},
        ],
        "crowd": [
            {"who": "商人", "desc": "（商人扶住她的腰——「转圈要扶稳嘛」——五根手指顺势一抓）", "zone": "waist"},
            {"who": "小汤姆", "desc": "（小汤姆扑上来抱住她的脚，在脚心上咯吱咯吱地挠了三下才跑开）", "zone": "sole"},
            {"who": "保卫队员", "desc": "（队员一本正经地戳了戳她的腋下：「节拍不对。」）", "zone": "armpit"},
            {"who": "小莉莉", "desc": "（小莉莉蹲下来，狗尾巴草在膝盖窝里扫了一下）", "zone": "thigh"},
            {"who": "篝火派对的主人", "desc": "（主人的羽毛围巾一甩，流苏扫过了后颈和腰侧）", "zone": "neck"},
            {"who": "面包店奶奶", "desc": "（奶奶用鸡毛掸子在她的脚背上轻轻掸了掸）", "zone": "sole"},
        ],
        "extra": [{"speaker": HOST, "text": "错了好多拍哦～加跳一段！"}, {"speaker": P, "text": "还、还要跳……！？", "emotion": "helpless_1"}],
        "react": {"light": ["唔……跳、跳错了……", "……下一拍不会错了！", "……别、别过来……"],
                  "mid": ["哈哈……腰、腰……！", "噗……脚、脚心……！", "哈……节、节拍乱了……！"],
                  "heavy": ["哈哈哈……跳、跳不动了……", "哈……全、全乱了……", "哈哈……饶了我……"]},
        "done": [
            {"speaker": HOST, "text": "好～跳完啦！大家给她鼓掌！"},
            {"speaker": P, "text": "呼……呼……跳、跳得腿都软了……", "emotion": "helpless_1"},
            {"speaker": HOST, "text": "受罚抵掉一笔～下次有受罚，还来找我哦！"},
            {"speaker": P, "text": "我、我才不要……", "emotion": "sad"},
        ],
        "notes": 24, "bpm": 108, "extra_after": 8,
    },
}

# 委托人对话里的节点（gen 插进 after_supervisor / after_bonfire_host）
NODES = {
    "after_supervisor": {"kind": "model", "offer": [L("……赎罪簿上还记着受罚没抵。要来抵一笔吗？"), L("摊位上缺个模特。")],
                         "prompt": "去摊位上当模特抵受罚？", "yes": "……当、当就当！", "no": "等一下再说"},
    "after_bonfire_host": {"kind": "dance", "offer": [L("哎呀～赎罪簿上还有受罚没抵？"), L("来篝火边跳支舞，就当抵罚啦～")],
                           "prompt": "在篝火边罚跳舞抵受罚？", "yes": "跳就跳！", "no": "等一下再说"},
}


def inject(dialogues):
    """补罚的节点：排在这个人所有委托的「能接 / 正在做 / 做完」后面。"""
    for f, spec in NODES.items():
        d = dialogues[f]
        d["nodes"]["penalty_offer"] = {"lines": spec["offer"], "prompt": spec["prompt"],
                                       "choices": [{"text": spec["yes"], "next": "penalty_go"}, {"text": spec["no"], "next": ""}]}
        d["nodes"]["penalty_go"] = {"lines": [L("好。")], "set": {"vars": {"penalty_req": spec["kind"]}, "call": "after_penalty"}}
        i = 0
        while i < len(d["entries"]) and str(d["entries"][i].get("node", "")).startswith("errand_"):
            i += 1
        d["entries"].insert(i, {"if": {"flag": "penalty_open"}, "node": "penalty_offer"})
