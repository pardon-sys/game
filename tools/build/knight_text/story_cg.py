"""骑士篇的背景大图过场（剧情回顾）：整屏一张高清插画（assets/generated/story_scenes/<img>.png，StoryBackdrop），下面照旧是对话框。
每段只有 bg 和台词（不动地图上的人，所以在背包的 CG 图鉴「剧情回顾」里任何时候都能回放）；id 以 story_ 开头，order 是图鉴里的顺序。
  story_kq_<支线>：每个支线的收尾过场（done_cut）演完以后接着演（KnightQuests.complete）；
  story_knight_boss：Boss 开场（knight_boss_open）演完、开打之前（KnightStory 步骤 boss 的 story）。
"""
from after_text.common import BLUE, N, P, line
from knight_text.story_base import DONE, _if, story
from knight_text import kq_samples, kq_shoes


# ---------------------------------------------------------------- Boss 开打之前：背靠背
def knight_boss():
    s = [
        line(N, "（紫色的光爬满了洞顶。四盏灯笼全暗了，广场上只剩盔甲身上那一道道裂缝在发光）"),
        line(N, "（木箱后面，镇民们挤成一团，大气都不敢出）"),
        line(P, "……喂。", "helpless_1"),
        line(BLUE, "……嗯。"),
        line(P, "你说，那里面……他还听得见吗？", "sad"),
        line(BLUE, "……听得见。"),
        line(BLUE, "手帕还在他手里攥着。……攥得那么紧的人，不会什么都听不见。"),
        line(N, "（两个人慢慢退到一起，后背贴上了后背）"),
        _if(line(P, "而且这次……不只是我们两个。", "happy"), {"any": [DONE("shoes"), DONE("samples"), DONE("spear"), DONE("fence"), DONE("host"), DONE("blue")]}),
        _if(line(N, "（广场边上，一个又一个熟悉的身影跑了过来）"), {"any": [DONE("shoes"), DONE("samples"), DONE("spear"), DONE("fence"), DONE("host"), DONE("blue")]}),
        line(P, "那就——用笑声把他叫醒！", "angry"),
        line(BLUE, "……我冻住它。你别笑太早。"),
        line(P, "那可不一定！", "happy"),
    ]
    return story("背靠背", "knight_boss", 90, s, pan="in")


CUTSCENES = {"story_knight_boss": knight_boss, "story_kq_shoes": kq_shoes.story_cut, "story_kq_samples": kq_samples.story_cut}
