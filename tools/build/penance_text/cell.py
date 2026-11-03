"""反省篇第一章·反省牢房（floor_06_penance_cell）：六件道具的长小剧场（PenanceCell 的调查点 → 对话 floor_06/penance_<id>）、
墙缝里的挠脚鼠（floor_06/penance_rat）、换上鼠鼠装钻进墙缝（过场 penance_crawl → 章末画面）。
每段：铺垫 → 嘴硬 → 失控一、二 → 魔力释放后再被挠（act = burst）；结尾都嘴硬一句「我才不会认错」。
功能拘束挠痒床是本章的章末大段：四幕 + 一张 CG（penance_bed）。只写痒、笑、释放后的舒服；她是成年人。
"""
from .common import A, BLUE, CAP, L, N, P, PRINCESS, RAT, burst, cg, dfile, line, pose, say, theater, tk

STOOL, DOLL, BED, TUB, CAT, CHEST = "反省凳", "布偶", "反省床", "浴桶", "橘猫", "旧箱子"

# ---------------------------------------------------------------- 1 反省足枷凳：每说一句嘴硬的话，刷子就快一档
STOCKS = theater("反省足枷凳", {
    "princess": dict(PRINCESS, at=[0, 6]),
    "stool": {"kind": "trap:stocks", "at": [0, 12]},
}, [
    say(N, "（一张矮矮的木凳，前面竖着一块带两个半圆缺口的木板。木板上刻着一行字：「坐下，说出你的错」）", act=1),
    say(P, "……说出你的错？我没有错。", emotion="angry"),
    say(P, "坐一下又不会怎么样。我就坐着，什么都不说，它能拿我怎么样。", emotion="angry"),
    say(N, "（她刚坐下，木板「咔哒」一声落下来，正好扣住了两只脚踝。鞋子被轻轻一顶，掉在了地上）", [A("sfx", sound="stocks", volume=-4.0), A("shake", who="princess", time=0.3)]),
    say(P, "诶！？扣、扣住了！？", emotion="surprise"),
    say(N, "（木板底下伸出一把小小的软刷，在她的脚心上「沙」地刷了一下，又停住了。像是在等她说话）", [tk("stool", fx="lines", n=3, iv=0.3)]),
    say(P, "……哼。我才不说。", emotion="angry"),
    say(N, "（刷子又「沙沙」刷了两下——比刚才快了一点）", [tk("stool", fx="lines", n=5, iv=0.22), pose("giggle")]),
    say(P, "……呜。不说话也刷？那、那我说：「我没错！」", emotion="angry"),
    say(N, "（刷子一下子快了一档，从脚跟一路刷到脚尖，再从脚尖刷回脚跟）", [tk("stool", fx="lines", n=10, iv=0.16)], act=2),
    say(P, "噫……！说、说了也刷！？这凳子不讲道理！", emotion="giggle"),
    say(N, "（又快了一档。第二把刷子从木板另一边伸出来，专门去拨她的脚趾缝）", [tk("stool", fx="brush", n=12, iv=0.14)]),
    say(P, "（……原、原来是……嘴硬一句……就快一档……！）", emotion="giggle"),
    say(P, "那、那我不说了！一句都不说了……！", [pose("helpless_1")], emotion="helpless_1"),
    say(N, "（她紧紧闭上嘴。刷子慢了下来，慢得要命——一根一根刷毛，慢慢地划过脚心最软的那一块）", [tk("stool", fx="feather", n=8, iv=0.3)]),
    say(P, "（……慢、慢慢刷……比快的还……！）", emotion="helpless_1"),
    say(N, "（她憋得肩膀直抖。脚趾蜷起来又张开，张开又蜷起来，刷子就趁着张开的时候钻进缝里）", [tk("stool", fx="brush", n=10, iv=0.22)], act=3),
    say(P, "……臭……臭队长……！", emotion="helpless_1"),
    say(N, "（这一句骂出口，两把刷子同时快到了最高档）", [tk("stool", fx="lines", n=16, iv=0.1), pose("helpless_2")]),
    say(P, "噗——哈哈哈！不算！刚才那句不算——哈哈哈哈！", emotion="helpless_2"),
    say(N, "（「不算」也是嘴硬。刷子又快了一点点。她仰着头笑，两只脚在木板的缺口里扭来扭去，可怎么也抽不出来）", [tk("stool", fx="lines", n=16, iv=0.1)]),
    say(P, "我、我错了！我错了行了吧——哈哈哈哈！", emotion="helpless_2"),
    say(N, "（刷子停了半秒……像是在想这句是不是真心的。然后又刷了起来）", [tk("stool", fx="brush", n=12, iv=0.12)]),
    say(P, "它听得出来——！它听得出来我不是真心的——哈哈哈！", emotion="helpless_2"),
    say(N, "（憋不住的笑声和魔力一起往上涌，越积越多，越积越多——）", [tk("stool", fx="lines", n=14, iv=0.1)]),
    burst("（星光一下子炸开，把木板都震得「嗡嗡」响……哈啊……全放出去了……脚底下暖洋洋的……好舒服……）"),
    say(N, "（可木板没有松开。刷子抖了抖身上的星光，贴上了刚释放完、敏感得发烫的脚心）", [tk("stool", fx="feather", n=10, iv=0.16), pose("helpless_2")], act=4),
    say(P, "呀啊……！放、放完以后……轻轻一下就……！", emotion="helpless_2"),
    say(N, "（刷子不急不慢，在脚心正中央画着小圈，画完一个，又在趾根上画一个）", [tk("stool", fx="feather", n=14, iv=0.13)]),
    say(P, "……哈哈……哈……不嘴硬了……一句都不说了……让、让我歇一下……", emotion="helpless_2"),
    say(N, "（她安安静静地笑着，一句硬话都没说。刷子终于慢下来，「咔」地缩回了木板底下，枷板也抬起来了）", [tk("stool", fx="feather", n=4, iv=0.3), pose("helpless_1")]),
    say(N, "（她抱着膝盖坐在凳子上，揉了好半天脚心，才把鞋穿回去）"),
    say(P, "……哈……哈……这凳子……是队长做的吧。一模一样的不讲道理。", emotion="sad"),
    say(P, "……不过。我才不会认错。……小声说的，它听不见。", emotion="angry"),
])

# ---------------------------------------------------------------- 2 痒痒床头人偶：抱着睡，布手偷偷挠腰和膝窝；背后的绣花（线索）
DOLL_T = theater("床头的旧布偶", {
    "princess": dict(PRINCESS, at=[0, 8]),
    "doll": {"kind": "trap:plush_doll", "at": [10, 6]},
}, [
    say(N, "（床头坐着一只旧布偶。毛线织的耳朵，脸上补过好几回，纽扣做的眼睛亮亮的）", act=1),
    say(P, "……好旧。谁的呀，放在反省室里。", emotion="question"),
    say(P, "……嘿嘿，有点可爱。反正也睡不着，借我抱一下。", emotion="happy"),
    say(N, "（她抱着布偶躺到床上，把脸埋进它软软的肚子里。闻起来有一点点灰尘的味道，还有一点点……像是很久以前的被子的味道）"),
    say(P, "……奇怪。好像……以前也抱过这样的……", emotion="sad"),
    say(N, "（眼皮越来越重。她迷迷糊糊地睡着了——）", [A("fade_out", time=0.4)], act=2),
    say(N, "（……腰上，有什么东西轻轻地戳了一下）", [A("fade_in", time=0.4), A("tickle", who="princess", by="doll", zone="waist", fx="hand", repeat=3, interval=0.3)]),
    say(P, "……嗯……别闹……", emotion="giggle"),
    say(N, "（又戳了一下。然后是两下、三下。一只软软的布手，沿着腰侧一节一节地往下捏）", [A("tickle", who="princess", by="doll", zone="waist", fx="hand", repeat=8, interval=0.2), pose("giggle")]),
    say(P, "……嘻……嘻嘻……在做梦……一定是在做梦……", emotion="giggle"),
    say(N, "（布手顺着腰滑下去，钻进膝盖窝，用毛线做的指头在那里挠圈圈）", [A("tickle", who="princess", by="doll", zone="thigh", fx="hand", repeat=10, interval=0.18)]),
    say(P, "噗……！哈……膝、膝盖窝……！", [A("shake", who="princess", time=0.3)], emotion="giggle"),
    say(N, "（她笑醒了。……布偶好好地被她抱在怀里，一动不动，纽扣眼睛无辜地看着天花板）"),
    say(P, "……？", emotion="question"),
    say(P, "……一定是做梦。再睡。", emotion="sad"),
    say(N, "（第二次，布手从大腿外侧慢慢爬上来，爬到腿根那里，用小小的指尖一下一下地点）",
        [A("tickle", who="princess", by="doll", zone="thigh", fx="hand", repeat=12, interval=0.16), pose("helpless_1")], act=3),
    say(P, "……哈……哈哈……腿……腿根不行……！", emotion="helpless_1"),
    say(N, "（她又笑醒了。布偶还是一动不动。只是……它的一只手，好像比刚才更靠近她的腰了一点点）"),
    say(P, "……你。是你吧。", emotion="angry"),
    say(DOLL, "……"),
    say(P, "我不睡了！我盯着你！", emotion="angry"),
    say(N, "（……盯了三分钟。眼皮又打架了。第三次——这一次，两只布手一起动了：一只挠腰，一只钻膝盖窝，像是怕她再醒过来，挠得又轻又快）",
        [A("tickle", who="princess", by="doll", zone="waist", fx="hand", repeat=14, interval=0.12),
         A("tickle", who="princess", by="doll", zone="thigh", fx="hand", repeat=14, interval=0.12), pose("helpless_2")]),
    say(P, "哈哈哈哈！抓、抓到你了——哈哈哈！放、放手——不对，是我放手……我放不开——哈哈哈！", emotion="helpless_2"),
    say(N, "（她想把布偶扔开，可两只布手紧紧勾着她的衣服。越挣越痒，越痒越使不上劲）", [A("tickle", who="princess", by="doll", zone="waist", fx="hand", repeat=14, interval=0.11)]),
    burst("（一圈星光从怀里炸开，把布偶弹到了床尾……哈……哈啊……身体轻飘飘的……好舒服……）"),
    say(N, "（布偶在床尾翻了个身，又慢吞吞地爬了回来，趴在她刚释放完、软得发烫的腿上）", [pose("helpless_2")], act=4),
    say(P, "……不、不要过来……现在碰哪里都……！", emotion="helpless_2"),
    say(N, "（毛线指头在膝盖窝里轻轻一勾——就一下。她整个人弹了起来）", [A("tickle", who="princess", by="doll", zone="thigh", fx="hand", repeat=8, interval=0.14), A("shake", who="princess", time=0.4)]),
    say(P, "哈哈哈哈！一下就……一下就受不了……哈哈哈！", emotion="helpless_2"),
    say(N, "（布偶挠了好一会儿，才心满意足地松开手，躺回床头，纽扣眼睛又亮晶晶地看着天花板）", [A("tickle", who="princess", by="doll", zone="waist", fx="hand", repeat=6, interval=0.2), pose("helpless_1")]),
    say(N, "（她把布偶拎起来，想狠狠地瞪它一眼——然后看见了它背后的绣花）"),
    say(N, "（褪了色的线，歪歪扭扭地绣着两个手拉手的小人。……和排水管那块手帕上的，一模一样）"),
    say(P, "……这个……", emotion="surprise"),
    say(P, "……队长的东西。又是队长的东西。", emotion="sad"),
    say(P, "……我才不会认错。……可是，这只布偶，我先替你保管着。", emotion="sad"),
])

# ---------------------------------------------------------------- 3 功能拘束挠痒床（章末大段 + CG）：四档；想按停止按成了加速
BED_T = theater("功能拘束挠痒床", {
    "princess": dict(PRINCESS, at=[0, 6]),
    "bed": {"kind": "trap:penance_bed", "at": [0, 12]},
}, [
    say(N, "（屋子最里面是一张长长的木床。粉色的床垫，床尾一块带两个缺口的木板，床边一根红色的拉杆，旁边钉着一张说明）", act=1),
    say(N, "（「反省床。分四档：一档，二档，三档，四档。拉杆往下：停止。」）"),
    say(P, "……四档是什么的四档啊。说明写得也太随便了吧。", emotion="angry"),
    say(P, "反正有停止。躺一下看看，不对劲就拉杆。……我很聪明的。", emotion="happy"),
    say(N, "（她躺上去。床垫软软的，枕头也软软的。……然后「咔哒」一声，床尾的木板扣住了两只脚踝，鞋子被顶落到地上）", [A("sfx", sound="stocks", volume=-4.0), A("shake", who="princess", time=0.3)]),
    say(P, "又来！？这里的东西为什么都要先扣脚！", emotion="surprise"),
    say(N, "（「一档」。床尾伸出一排白色的羽毛排刷，在光着的脚心上，从左扫到右，再从右扫到左）", [tk("bed", n=10, iv=0.2), pose("giggle")], act=2),
    say(P, "……嘻……嘻嘻……一档……还好……还好……", emotion="giggle"),
    say(N, "（「二档」。床板轻轻一翻，把她翻成了趴着。羽毛排刷换了个方向，顺着大腿后侧，从膝盖窝一直刷到大腿根）",
        [A("tickle", who="princess", by="bed", zone="thigh", fx="feather", repeat=12, interval=0.16)]),
    say(P, "翻、翻过来了！？大腿后面……那里我自己都没碰过……！", emotion="surprise"),
    say(N, "（羽毛一根一根地从腿后面扫过去，扫到最上面，就在那一圈软软的地方打个转）", [A("tickle", who="princess", by="bed", zone="thigh", fx="feather", repeat=14, interval=0.14), pose("helpless_1")]),
    say(P, "（不行……要拉杆……拉杆在……！）", emotion="helpless_1"),
    say(N, "（她伸长了手去够那根红色的拉杆，指尖勾住了，用力往下一拉——）", [A("sfx", sound="lever", volume=-2.0)]),
    say(N, "（……床板「咔」地翻回来，两侧伸出了两把圆圆的软刷。说明上的字，原来是反着贴的：往下，是「加速」）", [A("shake", who="princess", time=0.4)], act=3),
    say(P, "说明是反的——！？谁贴的——！！", emotion="surprise"),
    cg(say(N, "（「三档」「四档」一起来了。羽毛排刷扫着脚心和每一道趾缝，两把软刷贴着腰的两侧一圈一圈地揉）",
           [tk("bed", n=16, iv=0.1), A("tickle", who="princess", by="bed", zone="waist", fx="brush", repeat=16, interval=0.1), pose("helpless_2")])),
    say(P, "噗——哈哈哈哈！脚心！腰！一、一起来不行——哈哈哈哈！", emotion="helpless_2"),
    say(N, "（她在床上扭来扭去，可脚踝被扣着，腰往左躲左边的刷子在等，往右躲右边的刷子在等）", [A("tickle", who="princess", by="bed", zone="waist", fx="brush", repeat=14, interval=0.1)]),
    say(P, "停、停下来——拉杆！拉杆往上——哈哈哈！够、够不着——！", emotion="helpless_2"),
    say(N, "（羽毛排刷像是认得她的脚，专挑最怕的地方：脚心正中央、脚趾根、两只脚的小脚趾外侧）", [tk("bed", n=16, iv=0.1)]),
    say(P, "我、我错了！我反省！我反省还不行吗——哈哈哈哈！", emotion="helpless_2"),
    say(N, "（反省床没有耳朵。它只是在「四档」上，认认真真地工作着）", [tk("bed", n=14, iv=0.1), A("tickle", who="princess", by="bed", zone="waist", fx="brush", repeat=14, interval=0.1)]),
    say(P, "眼泪……眼泪都出来了……哈哈哈……肚子……笑得肚子疼……！", emotion="helpless_2"),
    say(N, "（魔力在身体里翻涌，笑声一阵比一阵大，满了，满了——）", [tk("bed", n=12, iv=0.1)]),
    burst("（星光从床上整个炸开，羽毛被吹得满屋子飘……哈啊……哈……全、全放出去了……身体好轻……好舒服……）"),
    say(N, "（羽毛慢慢落下来。床尾的木板还扣着。排刷抖掉身上的星光，又贴了上来——轻轻的，一档的力道）", [tk("bed", n=8, iv=0.2)], act=4),
    say(P, "……一档……一档就……为什么一档就这么……！", emotion="helpless_2"),
    say(N, "（刚释放完的脚心敏感得发烫，羽毛轻轻一扫，就像刚才四档那么痒）", [tk("bed", n=14, iv=0.13), A("shake", who="princess", time=0.3)]),
    say(P, "哈哈……哈哈哈……求、求你……就一档也不行……", emotion="helpless_2"),
    say(N, "（腰侧的软刷也凑过来，只碰了一下——她「呀」地一声整个人弹起来，笑得把枕头都踢到了床下）",
        [A("tickle", who="princess", by="bed", zone="waist", fx="brush", repeat=8, interval=0.14), A("shake", who="princess", time=0.5)]),
    say(P, "我……我投降……反省床大人……我投降……哈哈哈……", emotion="helpless_2"),
    say(N, "（不知过了多久，床「叮」地响了一声，所有的刷子都缩了回去，木板也抬了起来。说明的背面，还有一行小字：「反省时间：一刻钟」）", [pose("helpless_1")]),
    say(P, "……一刻钟……刚、刚才那些……只有一刻钟……？", emotion="helpless_1"),
    say(N, "（她瘫在床上，脚心还一跳一跳地发麻，好半天才爬起来，把那张说明撕下来，揉成一团）"),
    say(P, "……这张床，以后谁也别想让我躺。", emotion="angry"),
    say(P, "……我才不会认错。……真的不会。……一刻钟也不会。", emotion="sad"),
])

# ---------------------------------------------------------------- 4 痒痒浴桶：「洗洗脑子」
TUB_T = theater("痒痒浴桶", {
    "princess": dict(PRINCESS, at=[0, 8]),
    "tub": {"kind": "trap:sitz_bath", "at": [0, 12]},
}, [
    say(N, "（角落里摆着一只大木桶，冒着热气。桶边挂着一块木牌：「洗洗脑子。——队长」）", act=1),
    say(P, "……洗洗脑子。他是在骂我吧。", emotion="angry"),
    say(P, "……不过，热水。……泡一下脚，应该没关系吧。今天走了好多路。", emotion="happy"),
    say(N, "（她脱下鞋袜，坐在桶边，把两只脚慢慢放进热水里。暖暖的，舒服得她眯起了眼睛）"),
    say(P, "……哈……这个好。这个可以。……就这个，我不跟队长计较了。", emotion="happy"),
    say(N, "（桶底「咕嘟」冒出一串泡泡。泡泡贴着她的脚底往上浮，一颗一颗在脚心上破掉）", [tk("tub", fx="lines", n=6, iv=0.25), pose("giggle")], act=2),
    say(P, "嘻……泡泡……痒痒的……", emotion="giggle"),
    say(N, "（泡泡越冒越多。然后，桶底的一圈软刷慢慢转了起来，贴着脚底板一圈一圈地刷）", [tk("tub", fx="brush", n=10, iv=0.18)]),
    say(P, "诶？刷、刷子？桶底下有刷子！？", emotion="surprise"),
    say(N, "（她想把脚抽出来，可桶边太滑，屁股一溜，整个人「扑通」一下坐进了桶里）", [A("sfx", sound="puddle", volume=-2.0), A("shake", who="princess", time=0.4)]),
    say(P, "呀——！衣、衣服都湿了——！", emotion="surprise"),
    say(N, "（这下好了。桶壁上的软刷也转了起来，泡泡从四面八方冒出来——脚底、小腿、大腿根，泡泡和刷子轮流来）",
        [tk("tub", fx="brush", n=12, iv=0.14), A("tickle", who="princess", by="tub", zone="thigh", fx="lines", repeat=12, interval=0.14), pose("helpless_1")], act=3),
    say(P, "哈……哈哈……腿、腿根那里冒泡泡……不行……！", emotion="helpless_1"),
    say(N, "（她扶着桶边想站起来——水太滑，又坐了回去。站起来，坐回去，站起来，又坐回去）", [A("tickle", who="princess", by="tub", zone="thigh", fx="lines", repeat=10, interval=0.14)]),
    say(P, "这个桶……是专门让人站不起来的吧……哈哈哈……！", emotion="helpless_1"),
    say(N, "（桶壁上贴着一张泡皱了的小纸条：「站起来一次，刷子快一点」）"),
    say(P, "……又是这种规矩！这里的东西，全都是一个人做的吧！", emotion="helpless_1"),
    say(N, "（她不敢站了。可是坐着不动，泡泡就专挑大腿根冒，刷子就专挑脚心转）", [tk("tub", fx="brush", n=12, iv=0.13), A("tickle", who="princess", by="tub", zone="thigh", fx="lines", repeat=12, interval=0.13)]),
    say(P, "站也不行……坐也不行……那我到底该怎么样啊……哈哈哈！", emotion="helpless_1"),
    say(N, "（刷子越转越快。泡泡钻进脚趾缝里「啵、啵」地破，大腿根下面的那排冒泡口一阵一阵地喷）",
        [tk("tub", fx="brush", n=16, iv=0.1), A("tickle", who="princess", by="tub", zone="thigh", fx="lines", repeat=16, interval=0.1), pose("helpless_2")]),
    say(P, "哈哈哈哈！脑、脑子洗干净了！洗得一干二净了！放我出去——哈哈哈！", emotion="helpless_2"),
    say(P, "我、我认错——不对，我不认错——哈哈哈，我也不知道了——！", emotion="helpless_2"),
    say(N, "（热水、泡泡、刷子，一起往上涌的还有魔力——）", [tk("tub", fx="brush", n=12, iv=0.1)]),
    burst("（星光在水面上炸开，热水「哗」地溅了满地……哈啊……哈……暖暖的……全放出去了……好舒服……）"),
    say(N, "（木桶「咕嘟」一声，又冒出一大串泡泡。刚释放完的身体泡在热水里，每一颗泡泡破掉都像有人在挠）", [tk("tub", fx="lines", n=12, iv=0.13), pose("helpless_2")], act=4),
    say(P, "……泡、泡泡也……一颗一颗地……哈哈……！", emotion="helpless_2"),
    say(N, "（软刷又贴着脚心转了一圈，慢慢的，像是在给她擦干净）", [tk("tub", fx="brush", n=10, iv=0.16), A("tickle", who="princess", by="tub", zone="thigh", fx="lines", repeat=8, interval=0.16)]),
    say(P, "哈哈……哈……慢、慢慢的更……不要擦了……我自己擦……！", emotion="helpless_2"),
    say(N, "（水终于凉了。泡泡停了，刷子也停了。她趴在桶边，湿淋淋地喘着气）", [pose("helpless_1")]),
    say(P, "……洗洗脑子……洗得我……脑子里全是泡泡……", emotion="helpless_1"),
    say(P, "……我才不会认错。……可是衣服要晾一晾。", emotion="sad"),
])

# ---------------------------------------------------------------- 5 猫咪看守：哄它叼钥匙，反被舔脚心、尾巴扫腿
CAT_T = theater("门口的橘猫", {
    "princess": dict(PRINCESS, at=[-8, 8]),
    "cat": {"kind": "trap:cat_guard", "at": [12, 10]},
}, [
    say(N, "（门口趴着一只胖乎乎的橘猫。它脖子上挂着一个小铃铛，铃铛旁边……拴着一把钥匙）", act=1),
    say(P, "……钥匙！", emotion="surprise"),
    say(P, "猫咪～猫咪乖～把钥匙给姐姐好不好～", emotion="happy"),
    say(CAT, "喵。"),
    say(N, "（橘猫看了她一眼，打了个哈欠，把头埋回了爪子里）"),
    say(P, "……它在瞧不起我。", emotion="angry"),
    say(P, "哼，我可是很会哄小动物的。……来，挠挠下巴……", emotion="happy"),
    say(N, "（她蹲下来伸出手。橘猫抬起头，蹭了蹭她的手指——然后顺势一翻身，把她的手压在了肚子底下）", [A("shake", who="princess", time=0.3)], act=2),
    say(P, "诶？压、压住了！好重！你好重！", emotion="surprise"),
    say(N, "（她一屁股坐在地上，想把手抽出来。橘猫慢悠悠地转过头，看见了她晃来晃去的脚）"),
    say(P, "……你看哪里。你在看哪里。", emotion="surprise"),
    say(N, "（橘猫用爪子把她的鞋扒了下来，凑过去闻了闻脚心……然后伸出粗粗的小舌头，「唰」地舔了一下）", [tk("cat", fx="lines", n=4, iv=0.25), pose("giggle")]),
    say(P, "呀啊！舌、舌头好粗——！", emotion="giggle"),
    say(N, "（猫舌头上全是小倒刺。一下，两下，像一把小小的软刷，从脚跟舔到脚尖）", [tk("cat", fx="lines", n=10, iv=0.18)]),
    say(P, "嘻嘻……嘻……不、不要舔……我又不是小鱼干……！", emotion="giggle"),
    say(N, "（橘猫的尾巴也闲不住，绕过来，毛茸茸的尾巴尖在她小腿和膝盖窝上扫来扫去）",
        [A("tickle", who="princess", by="cat", zone="thigh", fx="feather", repeat=10, interval=0.16), pose("helpless_1")], act=3),
    say(P, "哈……哈哈……尾巴……尾巴也来……你到底有几只手啊……！", emotion="helpless_1"),
    say(N, "（她另一只手去推猫——橘猫「喵」地一声，干脆整只趴到她的腿上，压住了，然后继续舔另一只脚）", [tk("cat", fx="lines", n=12, iv=0.14)]),
    say(P, "趾、趾缝！不要一根一根地舔——哈哈哈！", emotion="helpless_1"),
    say(N, "（舌头钻进脚趾缝里，粗粗地刷过去。尾巴一下一下地扫着膝盖窝。铃铛叮铃叮铃地响）",
        [tk("cat", fx="lines", n=14, iv=0.11), A("tickle", who="princess", by="cat", zone="thigh", fx="feather", repeat=14, interval=0.11), pose("helpless_2")]),
    say(P, "哈哈哈哈！投、投降！我不要钥匙了！不要了——哈哈哈哈！", emotion="helpless_2"),
    say(CAT, "喵～"),
    say(N, "（它听起来很得意。舌头一刻也没停）", [tk("cat", fx="lines", n=14, iv=0.1)]),
    burst("（星光「砰」地炸开，橘猫被吓得毛全竖了起来，「喵嗷」一声跳到了一边……哈啊……哈……全放出去了……好舒服……）"),
    say(N, "（橘猫舔了舔爪子，冷静下来，又迈着步子走了回来——这一次，它凑近的是刚释放完、红通通的脚心）", [pose("helpless_2")], act=4),
    say(P, "不、不要……现在……现在真的不行……！", emotion="helpless_2"),
    say(N, "（「唰」——只舔了一下。她整个人在地上缩成了一团，笑得说不出话）", [tk("cat", fx="lines", n=6, iv=0.14), A("shake", who="princess", time=0.5)]),
    say(P, "……哈哈哈……哈……一下就……猫、猫大人……饶了我……", emotion="helpless_2"),
    say(N, "（橘猫又舔了好几下，舔够了，才心满意足地回到门口，把钥匙压在肚子底下，眯起了眼睛）", [tk("cat", fx="lines", n=8, iv=0.18), pose("helpless_1")]),
    say(P, "……这只猫……绝对是队长养的。一样的坏心眼。", emotion="angry"),
    say(P, "……我才不会认错。……也不会再跟猫抢钥匙了。", emotion="sad"),
])

# ---------------------------------------------------------------- 6 队长的旧战利品箱：笑笑袖套 / 会笑的袜子 / 握握手短裤 + 旧照片
CHEST_T = theater("队长的旧战利品箱", {
    "princess": dict(PRINCESS, at=[0, 8]),
    "chest": {"kind": "trap:trophy_chest", "at": [14, 10]},
}, [
    say(N, "（角落里有一口旧木箱，锁头锈得一碰就掉。箱盖上贴着一张褪色的纸：「没收品——别碰」）", act=1),
    say(P, "别碰。……「别碰」就是让人碰的意思。", emotion="happy"),
    say(N, "（箱子里整整齐齐叠着几件奇怪的东西：一对长袖套、一双白袜子、一条旧短裤。每件上面都挂着小牌子，写着从谁那里收来的）", [A("pose", who="chest", visual="active")]),
    say(P, "……队长年轻的时候，收了这么多痒痒装备啊。……试一下，就试一下。", emotion="happy"),
    # —— 笑笑袖套
    say(N, "（第一件：笑笑袖套。小牌子上写着「从笑声小偷那里收来的」。她把袖套套上胳膊——里面一层软毛，暖暖的）"),
    say(P, "……还挺舒服的嘛。", emotion="happy"),
    say(N, "（她一抬手。袖套内侧的软毛「唰」地蹭过了腋窝和腰侧）", [A("tickle", who="princess", by="chest", zone="armpit", fx="feather", repeat=6, interval=0.2), pose("giggle")], act=2),
    say(P, "呀！胳、胳肢窝！", emotion="giggle"),
    say(N, "（她赶紧想把袖套扒下来——可要脱袖套，就得把胳膊抬起来；一抬起来，软毛就蹭得更厉害）",
        [A("tickle", who="princess", by="chest", zone="armpit", fx="feather", repeat=10, interval=0.15), A("tickle", who="princess", by="chest", zone="waist", fx="feather", repeat=8, interval=0.18)]),
    say(P, "越、越想脱越痒……这是什么坏心眼的设计……嘻嘻嘻……！", emotion="giggle"),
    say(N, "（她夹着胳膊，扭着身子，用牙咬着袖口，一点一点把它拽了下来）"),
    say(P, "……呼……呼……下一件……下一件肯定正常。", emotion="giggle"),
    # —— 会笑的袜子
    say(N, "（第二件：一双白袜子。小牌子上写着「会笑的袜子」，尺码那一栏写着——「二十二码半」）"),
    say(P, "……二十二码半。……和我的脚一样大。", emotion="surprise"),
    say(N, "（她换上袜子。刚好。……然后袜子自己「咯咯」地笑了起来）", [A("sfx", sound="giggle", volume=-6.0)]),
    say(P, "袜、袜子在笑！？", emotion="surprise"),
    say(N, "（袜底的线头像活过来一样，在脚心上蹭来蹭去，钻进每一道趾缝里扭）", [tk("chest", fx="lines", n=12, iv=0.14), pose("helpless_1")]),
    say(P, "噗……哈哈……袜子笑……我也笑……我笑袜子也笑……哈哈哈！", emotion="helpless_1"),
    say(N, "（她坐在地上扯袜子，袜子笑得更欢了，线头在脚心正中央打起了转）", [tk("chest", fx="lines", n=14, iv=0.12)]),
    say(P, "脱、脱下来了……！哈……哈……袜子还在地上笑……", emotion="helpless_1"),
    # —— 握握手短裤
    say(N, "（第三件：一条旧的潜行短裤。小牌子上没写从谁那里收来的，只写着：「最后一件。不要穿。」）", act=3),
    say(P, "……写得这么吓人。越写不要，越想试。", emotion="question"),
    say(N, "（她套上短裤。里面一层软软的衬里——不对，是十几只小小的布手，整整齐齐地缝在里面。它们一起，轻轻地，握了握她的大腿）",
        [A("tickle", who="princess", by="chest", zone="thigh", fx="hand", repeat=8, interval=0.16), pose("helpless_1")]),
    say(P, "……握、握手？短裤在跟我握手……？", emotion="surprise"),
    say(N, "（握完手，小布手们就开始挠了。大腿根、屁股，十几只手一起，每只都很小，每只都很认真）",
        [A("tickle", who="princess", by="chest", zone="thigh", fx="hand", repeat=14, interval=0.11), A("tickle", who="princess", by="chest", zone="butt", fx="hand", repeat=14, interval=0.11)]),
    say(P, "哈哈哈哈！十几只——十几只一起——哈哈哈哈！", emotion="helpless_1"),
    say(N, "（她想夹紧腿挡住——小手们反而更勤快了，夹得越紧，挠得越快）", [A("tickle", who="princess", by="chest", zone="thigh", fx="hand", repeat=16, interval=0.1), pose("helpless_2")]),
    say(P, "夹、夹腿没用——哈哈哈！越夹越快——脱、脱不下来——哈哈哈哈！", emotion="helpless_2"),
    say(N, "（她在地上滚来滚去，小手们一路跟着挠：腿根、屁股、腿根、屁股……魔力一点一点地涨满了）",
        [A("tickle", who="princess", by="chest", zone="butt", fx="hand", repeat=14, interval=0.1), A("tickle", who="princess", by="chest", zone="thigh", fx="hand", repeat=14, interval=0.1)]),
    burst("（星光「轰」地炸开，短裤被冲得松开，小布手们一只只松了手……哈啊……全放出去了……好舒服……）"),
    say(N, "（可还有三只小手没松开。它们挂在短裤边上，轻轻地、慢慢地，挠着刚释放完、敏感得发烫的腿根）",
        [A("tickle", who="princess", by="chest", zone="thigh", fx="hand", repeat=10, interval=0.15), pose("helpless_2")], act=4),
    say(P, "……三、三只也……三只也不行……哈哈哈……！", emotion="helpless_2"),
    say(N, "（她咬着牙，一只一只地把小手掰开。最后一只松开以前，还在她的屁股上捏了一下，像是在道别）", [A("tickle", who="princess", by="chest", zone="butt", fx="hand", repeat=4, interval=0.2), A("shake", who="princess", time=0.3)]),
    say(P, "……哈……哈……总、总算脱下来了……", emotion="helpless_1"),
    say(N, "（她把短裤翻过来。内侧用褪了色的线，绣着一行小小的字：「给小不点——等你长大了再穿」）", [pose("helpless_1")]),
    say(P, "……小不点？", emotion="question"),
    say(N, "（箱子最底下，压着一张旧照片。照片上，年轻的队长抱着一个小女孩，站在一扇很大很大的门前。门上，是王宫的徽记）"),
    say(N, "（小女孩的脸看不清。只看得见，她扎着两个小辫子，脚上穿着一双白色的小袜子）"),
    say(P, "……这是……", emotion="surprise"),
    say(P, "……", emotion="sad"),
    say(P, "……我才不会认错。……可是，这张照片，我要问清楚。", emotion="sad"),
])

THEATERS = {"penance_stocks": STOCKS, "penance_doll": DOLL_T, "penance_bed": BED_T, "penance_tub": TUB_T, "penance_cat": CAT_T, "penance_chest": CHEST_T}

# ---------------------------------------------------------------- 调查点的对话：没玩过 → 小剧场；玩过 → 一句短台词
SPOT_TEXT = {
    "stocks": ("反省足枷凳", "（一张矮木凳，前面一块带缺口的木板。「坐下，说出你的错」）", "坐上去？",
               "……坐一下而已。", "（刻字底下多了一道新的划痕。……是她刚才踢的）"),
    "doll": ("床头的布偶", "（床头坐着一只旧布偶，纽扣眼睛亮亮的）", "抱着它睡一会儿？",
             "……反正也睡不着。", "（布偶背后绣着两个手拉手的小人。它好像朝她眨了一下眼睛）"),
    "bed": ("反省床", "（一张长木床，床尾一块带缺口的木板，床边一根红色拉杆。「反省床，分四档」）", "躺上去试试？",
            "……有停止拉杆，不怕。", "（说明被她揉成一团扔在角落里。……拉杆往下是加速，记住了）"),
    "tub": ("痒痒浴桶", "（一只冒着热气的大木桶。木牌：「洗洗脑子。——队长」）", "泡一下脚？",
            "……就泡一下脚。", "（水已经凉了。桶底的刷子安安静静的……暂时）"),
    "cat": ("门口的橘猫", "（门口趴着一只胖橘猫，铃铛旁边拴着一把钥匙）", "哄它把钥匙给你？",
            "猫咪～猫咪乖～", "（橘猫把钥匙压在肚子底下，眯着眼睛看她。……不去了，不去了）"),
    "chest": ("队长的旧战利品箱", "（一口旧木箱，锁头锈得快掉了。「没收品——别碰」）", "打开看看？",
              "「别碰」就是让人碰的意思。", "（照片收好了。年轻的队长、小女孩、王宫的大门……）"),
}


def _spot_file(sid):
    name, look, prompt, yes, again = SPOT_TEXT[sid]
    return dfile("", name, {
        "default": {"lines": [L(look, N)], "prompt": prompt, "choices": [
            {"text": yes, "next": "go"}, {"text": "……先不了", "next": "no"}]},
        "go": {"lines": [L(yes, P)], "theater": "penance_" + sid},
        "no": {"lines": [L("……我才不上当。", P)]},
        "again": {"lines": [L(again, N)]},
    }, entries=[{"if": {"flag": "cg_seen_theater:penance_" + sid}, "node": "again"}, {"node": "default"}])


DIALOGUES = {("penance_" + sid): _spot_file(sid) for sid in SPOT_TEXT}

# 墙缝里的挠脚鼠：六件都玩过（penance_all_done）才探出头；按以前在地牢放没放过它（cg_seen_theater:prison_rat）分两种开场
DIALOGUES["penance_rat"] = dfile("", RAT, {
    "squeak": {"lines": [L("（墙角有一道裂缝。里面传来细细的「吱吱」声……好像有什么东西在等着）", N)]},
    "met": {"lines": [L("吱吱！又是你！公主！", RAT),
                      L("……地牢里那只挠痒鼠！？你怎么在这里！", P, "surprise"),
                      L("叫我挠脚鼠。挠痒鼠是小名。……上次放我出来的谢礼，还满意吗？吱吱。", RAT),
                      L("一、一点都不满意！你钻进鞋里挠了我一路！", P, "angry"),
                      L("那是谢礼呀。挠脚鼠一族，有恩必报。……这次也报。", RAT)],
            "next": "offer"},
    "stranger": {"lines": [L("吱。哼。原来是你。", RAT),
                           L("……地牢里那只挠痒鼠！？", P, "surprise"),
                           L("是挠脚鼠。……上次你不放我出来，害我被守卫抓住，又关了三天。三天！", RAT),
                           L("那、那是因为你会捣乱嘛……", P, "sad"),
                           L("哼。不过挠脚鼠一族心胸宽广。……想出去？我可以帮你。只是——要收报酬。", RAT)],
                 "next": "offer"},
    "offer": {"lines": [L("这道缝后面，有一条很老很老的洞，能通到外面。只有我知道怎么走。", RAT),
                        L("……能出去？真的？", P, "surprise"),
                        L("真的。不过洞很窄，你得把鞋子和裤子换了——换成我的「家」。我住在你身上，给你带路。", RAT),
                        L("……住、住在我身上？", P, "surprise"),
                        L("吱吱。就这么说定了？", RAT)],
              "prompt": "答应挠脚鼠？", "choices": [
                  {"text": "……成交。我要出去。", "next": "deal"},
                  {"text": "再、再想一想", "next": "wait"}]},
    "deal": {"lines": [L("……成交。只要能出去，什么都行。", P, "angry"),
                       L("吱吱！有恩必报，有约必守！", RAT)], "set": {"call": "penance_rat_outfit"}},
    "wait": {"lines": [L("……我再想一想。", P, "sad"), L("吱。我就在这里。反正你也跑不掉。", RAT)]},
}, entries=[{"if": {"flag": ["penance_all_done", "cg_seen_theater:prison_rat"]}, "node": "met"},
            {"if": {"flag": "penance_all_done"}, "node": "stranger"},
            {"node": "squeak"}])

# 南墙的牢门
DIALOGUES["penance_objects"] = dfile("", "反省室", {
    "default": {"lines": [L("（牢门）", N)]},
    "gate": {"lines": [L("（铁门锁得死死的。门外传来保卫队员打呵欠的声音）", N),
                       L("……放我出去——！", P, "angry"),
                       L("（……没人理她）", N)]},
})


def crawl():
    """换上鼠鼠装、钻进墙缝 → 章末画面 → 按 E 进第二章·鼠洞（鼠鼠装一直穿着，到第三章出了水道才脱）。"""
    s = [
        {"actions": [A("camera", to=[16, 3], zoom=1.2, time=0.5)], "wait": 0.5},
        line(N, "（挠脚鼠从墙缝里钻出来，「嗖」地顺着她的腿爬了上去）"),
        line(P, "呀、呀啊！爬、爬上来了！", "surprise", [A("shake", who="princess", time=0.4)]),
        line(RAT, "别动别动。……「家」来啦。", None, [A("flash", time=0.4), A("sfx", sound="puff", volume=-3.0)]),
        line(N, "（一阵白烟。等烟散开，她的鞋子变成了一双露着脚趾的灰色鼠爪拖鞋，裙子底下多了一条毛茸茸的鼠鼠短裤，后面还拖着一条会动的尾巴）"),
        line(P, "……这、这是什么啊——！！", "surprise"),
        line(RAT, "（从短裤里探出头）吱吱。鼠鼠短裤，鼠爪鞋。我的家。……很合身吧？", None, [A("bubble", who="princess", kind="shy")]),
        line(P, "脱、脱不下来！？", "angry", [A("shake", who="princess", time=0.3)]),
        line(RAT, "出了洞才能脱。……对了，我住在里面，偶尔会跑一跑。别介意。", None),
        line(N, "（短裤里，有什么东西「嗖」地从屁股窜到了大腿根）", None, [A("tickle", who="princess", zone="thigh", fx="hand", repeat=6, interval=0.15), A("shake", who="princess", time=0.4)]),
        line(P, "噫——！哈、哈哈……这叫「偶尔」！？", "helpless_1"),
        line(RAT, "吱吱。走吧，公主。洞口在这里。", None),
        line(N, "（她趴下来，把头钻进墙缝。缝比看起来宽一点点——刚好够一个人爬进去）", None, [A("move", who="princess", to=[17, 2], time=0.8)]),
        line(P, "……队长。我没有认错。……我是去找答案的。", "sad"),
        line(N, "（橘猫在门口睁开了一只眼睛，看着那条毛茸茸的尾巴消失在墙缝里，舔了舔嘴巴）"),
        {"actions": [A("fade_out", time=1.0)], "wait": 1.0},
        {"actions": [A("chapter_end", title="第一章　反省牢房　完", subtitle="——墙缝的另一头，是一条很老很老的洞", next="floor_06_rat_tunnel")], "wait": 1.4},
    ]
    return {"name": "钻进墙缝", "letterbox": True, "skippable": False, "steps": s}


CUTSCENES = {"penance_crawl": crawl}
