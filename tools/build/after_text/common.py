"""七日赎罪文本包的公共部分。"""
P, BLUE, CAP, MAYOR, N = "公主", "蓝色的公主", "保卫队队长", "镇长", ""
PANTS = "blue_tickle_pants"
BLUE_NODE = "AfterBlue"          # 导演把跟着的蓝色公主改名成这个（过场里用）


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
