"""背景大图过场（剧情回顾）的写法：story(名字, 图, 图鉴顺序, 台词步骤)——前面摆上大图（bg），最后收起（bg_clear）。"""
from after_text.common import A

DONE = lambda q: {"flag": "kq_%s_done" % q}


def story(name, img, order, steps, pan="in"):
    return {"name": name, "order": order, "letterbox": False, "skippable": True,
            "steps": [{"actions": [A("bg", img=img, pan=pan)], "wait": 0.8}] + steps + [{"actions": [A("bg_clear")], "wait": 0.5}]}


def _if(step, cond):
    return dict(step, **{"if": cond})
