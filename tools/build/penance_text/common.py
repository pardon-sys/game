"""反省篇文本的公共部分：说话人、小剧场的写法（同 knight_text/prison.py）。"""
from after_text.common import A, BLUE, CAP, L, N, P, line  # noqa: F401

RAT = "挠脚鼠"
KNIGHT = "骑士"
GUARD = "保卫队员"

PRINCESS = {"kind": "princess", "at": [0, 8], "visual": "normal", "anim": "idle", "dir": "down"}


def say(sp, text, actions=None, emotion=None, act=None, portrait=None):
    s = {"speaker": sp, "text": text}
    if actions:
        s["actions"] = actions
    if emotion:
        s["emotion"] = emotion
    if act:
        s["act"] = act
    if portrait:
        s["portrait"] = portrait
    return s


def tk(by, zone="sole", fx="feather", n=8, iv=0.2):
    return A("tickle", who="princess", by=by, zone=zone, fx=fx, repeat=n, interval=iv)


def pose(visual):
    return A("pose", who="princess", visual=visual)


def release():
    """魔力疲倦满：自动释放（金光、星光 + 释放声、抖一下、笑出声；CGPlayer 换上战损憋笑魔力释放的精灵）"""
    return [A("flash", time=0.5), A("sfx", sound="star_burst"), A("sfx", sound="water_release", volume=-2.0),
            A("shake", who="princess", time=0.4), A("voice", state="laugh")]


def burst(text):
    return dict(say(P, text, release()), act="burst", wait=1.0)


def cg(step):
    """CG 大图换在这一步（gen_floor06_after._with_fail_cg 认 cg 标记，_with_h2 给台上公主换失控二）"""
    return dict(step, cg=True)


def theater(name, cast, body):
    steps = [{"act": 1, "actions": [A("fade_in", time=0.5), A("voice", state="giggle")], "wait": 0.5}] + body + \
            [{"actions": [A("voice", state=""), A("fade_out", time=0.6)], "wait": 0.7}]
    return {"name": name, "cast": cast, "steps": steps}


def dfile(npc_id, name, nodes, entries=None):
    d = {"name": name, "entries": entries or [{"node": "default"}], "nodes": nodes}
    if npc_id:
        d["npc"] = npc_id
    return d
