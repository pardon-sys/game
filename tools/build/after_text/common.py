"""七日赎罪文本包的公共部分。"""
P, BLUE, CAP, MAYOR, N = "公主", "蓝色的公主", "保卫队队长", "镇长", ""
PANTS = "blue_tickle_pants"
BLUE_NODE = "AfterBlue"          # 战后导演中的蓝色公主节点名（过场里用）


def L(text, speaker=None, emotion=None, npc_id=None):
    d = {"text": text}
    if speaker is not None:
        d["speaker"] = speaker
    if emotion:
        d["emotion"] = emotion
    if npc_id:
        d["npc"] = npc_id
    return d


def A(do, **kw):
    kw["do"] = do
    return kw


def line(sp, text, emotion=None, actions=None, npc_id=None):
    s = {"speaker": sp, "text": text}
    if emotion:
        s["emotion"] = emotion
    if actions:
        s["actions"] = actions
    if npc_id:
        s["npc"] = npc_id
    return s


def day_is(n):
    return {"var": {"after_day": ["==", n]}}


# ---------------------------------------------------------------- 劳动 / 补罚小游戏（ErrandWorkStage）共用
# 道具 → 舞台上的命中特效（HitFx.KINDS）
TOOL_FX = {"brush": "brush", "feather": "feather", "oil": "brush", "chain": "pinch", "finger": "hand", "gear": "brush",
           "duster": "feather", "salt": "hand", "tongue": "suck", "tassel": "feather", "rush": "feather",
           "toes": "hand", "scrape": "hand", "hand": "hand"}


def event(phase, tool, caption, *replies, zone="sole", fx=None):
    """一组挠痒事件：阶段、道具、挠法描写（下方反应框）、公主的反应（按闷笑分 light / mid / heavy 三档，平均分成三份）。"""
    n = len(replies) // 3
    assert n >= 2 and n * 3 == len(replies), caption
    return {"phase": phase, "tool": tool, "zone": zone, "fx": fx or TOOL_FX.get(tool, "hand"), "caption": caption,
            "react": {"light": list(replies[:n]), "mid": list(replies[n:2 * n]), "heavy": list(replies[2 * n:])}}


def nodes(who, request, offer, accept, active, done):
    """委托人对话里的四个节点（能接 / 接下 / 正在做 / 做完），文本都只有一句时用。"""
    return {"offer": {"lines": [L(offer, who)], "prompt": "接下这个委托？",
                      "choices": [{"text": "我来！", "next": "accept"}, {"text": "等一下再说", "next": ""}]},
            "accept": {"lines": [L(accept, who)], "set": {"vars": {"errand_req": request}, "call": "errand_start"}},
            "active": {"lines": [L(active, who)]}, "done": {"lines": [L(done, who)]}}


# 棚布补漏 / 筛叶风选共用的界面文字（errand_canopy.py / errand_sifting.py）
WORKSHOP_UI = {
    "panel": "%s %d/%d\n总进度 %d/%d",
    "count": "完成 %d / %d",
    "resume": [L("（工具留在原处，已经完成的部分分开放好，可以接着上一次做）", N)],
    "recover": "（她先放稳工具，笑着缓一口气。已经做好的部分不动，只重新整理手上这一段）",
    "error_react": ["哎呀！先收回来，这一下我重新做！", "没弄坏！别忙着记我的错！", "你先别笑，我马上就调好！"],
    "success_react": ["好啦！你看，我就说能做好！", "这一段没乱！快记上！", "好了，下一段！这次不许抢着捣乱！"],
    "steady": "方向和位置合适，继续。", "off": "先停手，把工具调回来。",
    "beat_ok": "合拍！", "beat_miss": "慢半拍！下一个接上。",
    "bag_ok": "这一袋够了！", "bag_retry": "分量偏了，只重装这一袋。",
    "labels": ["目标", "工具", "风向", "下一片", "收集", "袋量", "张力"],
    "release": {
        "desc": ["（魔力从身体里漫开——暖洋洋的，被挠了半天的腰侧一下子松快下来，她舒服地呼了一口气）",
                 "（星光一闪，痒意化成了一阵温温的舒服，她手里的工具差点滑掉）"],
        "react": ["……呼……好舒服……", "……唔……暖暖的……", "……等等，我还在干活！", "才、才没有觉得舒服！"],
        "tickler": ["哟，舒服了？", "看来挠到位了。"]},
    "sensitive": {"light": ["刚释放完……别碰！", "现在碰哪里都……！"],
                  "mid": ["哈哈……现在不行……！", "噗……一碰就……！"],
                  "heavy": ["哈哈哈……太、太敏感了……！", "哈哈……等一下……！"]},
}
