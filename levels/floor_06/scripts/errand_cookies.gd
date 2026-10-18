extends Node2D
## 委托「送饼干」（面包店奶奶 → 守城门的队员）的玩法节点（AfterErrands.make_runner，导演摆进小镇）：
##   篮子里 COOKIES 块饼干（vars.errand_cookies_left）。路上的小孩（AfterKid）闻到香味就跑过来挠你，挠完拿走一块；
##   走到他身边按 E 也能分一块把他打发走（不用被挠）；冲刺能甩掉。走到守城门的队员身边 = 送到（剩几块都算，剩得多有额外的话）。
##   饼干被分光 = 失败（回奶奶那里再拿一篮）。

const COOKIES := 6
const KIDS := [[37, 30], [31, 33], [26, 30]]
const GUARD := "after_guard_gate"

var errand_id := "cookies"
var kids: Array[AfterKid] = []
var _done := false


func _ready() -> void:
	if not GameState.vars.has("errand_cookies_left") or int(GameState.vars["errand_cookies_left"]) <= 0:
		GameState.vars["errand_cookies_left"] = COOKIES
	for c in KIDS:
		var k := AfterKid.spawn(get_parent(), Cutscene.cell_to_world(c), 2.0)
		k.lure = func() -> bool: return left() > 0
		k.on_catch = _on_caught
		k.on_shoo = func(kid: AfterKid): _take(kid, "谢谢姐姐！")
		k.pick_zone = func(_k) -> String: return ["waist", "armpit", "waist"].pick_random()
		k.chase_words = ["好香！是饼干！", "姐姐分我一块！", "饼干饼干！"]
		k.tickle_words = ["给不给？给不给？", "咯吱咯吱～", "不给就一直挠！"]
		k.caption = func(_k, zone: String) -> String:
			return "（小孩扑上来，小手钻进腰侧乱挠，一边挠一边伸手去够篮子里的饼干）" if zone == "waist" \
				else "（小孩踮着脚，咯吱咯吱地挠她的胳肢窝——篮子被挠得一晃一晃）"
		kids.append(k)


func _exit_tree() -> void:
	for k in kids:
		if is_instance_valid(k):
			k.queue_free()


static func left() -> int:
	return int(GameState.vars.get("errand_cookies_left", 0))


func _on_caught(k: AfterKid) -> void:
	_take(k, "嘿嘿，饼干到手～")


## 分一块（被挠走或者按 E 给的）
func _take(k: AfterKid, words: String) -> void:
	if left() <= 0:
		return
	GameState.vars["errand_cookies_left"] = left() - 1
	SpeechBubble.say(k, words, 26.0, 1.2)
	Audio.play("pickup", -8.0)
	GameState.notify("饼干还剩 %d 块" % left(), 1.5)
	if left() <= 0 and not _done:
		_done = true
		AfterErrands.fail(errand_id, "饼干被分光了……回面包店奶奶那里再拿一篮吧。")
		queue_free()


func _process(_delta: float) -> void:
	if _done or GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	var g := get_parent().find_child(GUARD, true, false) as Node2D
	if g and g.global_position.distance_to(p.global_position) < 22.0:
		_deliver()


func _deliver() -> void:
	_done = true
	var n := left()
	GameState.vars.erase("errand_cookies_left")
	var lines := [{"speaker": "守城门的队员", "text": "这是……面包店奶奶的饼干？还热乎着！"}]
	if n >= 4:
		lines.append({"speaker": "守城门的队员", "text": "一路上那群小鬼没抢走几块？厉害厉害。"})
	else:
		lines.append({"speaker": "守城门的队员", "text": "……怎么就剩 %d 块了？算了，被那群小鬼截胡了吧。" % n})
	lines.append({"speaker": "公主", "text": "呼……送到了。腰、腰还在痒……", "emotion": "shy"})
	Dialogue.start_lines(lines, "errand_cookies")
	AfterErrands.complete(errand_id, "（剩 %d 块）" % n)
	queue_free()
