class_name QuestBorrow
extends QuestRunner
## 支线「没有名字的生日」第一段「借东西」（骑士篇的小镇）：彩带（商人）、点心（女仆）、蜡烛（工匠）——每个人身边摆一个「借」的提示（BorrowSpot，Interactable），
##   按 E → 那个人要你先帮个忙（PartyShow：duster / taste / wheel），赢了就借到（vars.kq_host_got 记着，跨图不丢）。
##   三样都借到 → 过场 kq_host_box（她的八音盒坏了）→ 这一段做完。
## 测试：spots、got()、borrow(玩法)。

const GOT_KEY := "kq_host_got"

var spots: Dictionary = {}
var running := false


func bw() -> Dictionary:
	return q.get("borrow", {})


static func got() -> Array:
	return GameState.vars.get(GOT_KEY, [])


static func reset_items() -> void:
	GameState.vars[GOT_KEY] = []


func setup() -> void:
	spots.clear()
	var who: Dictionary = bw().get("spots", {})
	for mode in who:
		if got().has(mode):
			continue
		var r := _lv.find_child(str(who[mode]), true, false) as Node2D
		if r == null:
			continue
		var sp := put(BorrowSpot.new(), r.global_position + Vector2(14, 4)) as BorrowSpot
		sp.runner = self
		sp.mode = str(mode)
		sp.follow = r
		spots[mode] = sp


func status() -> String:
	var marks := []
	for m in ["duster", "taste", "wheel"]:
		marks.append("✔" if got().has(m) else "—")
	return str(bw().get("status", "%s %s %s")) % marks


## 借一样（先帮那个人一个忙：PartyShow）
func borrow(mode: String) -> bool:
	if running or got().has(mode) or not live():
		return false
	running = true
	var show := PartyShow.new()
	show.mode = mode
	get_tree().root.add_child(show)
	var ok: bool = await show.play()
	if is_instance_valid(show):
		show.queue_free()
	running = false
	if not ok:
		return false
	var g := got().duplicate()
	g.append(mode)
	GameState.vars[GOT_KEY] = g
	say(str(bw().get("got", "%s")) % str(bw().get("names", {}).get(mode, mode)), 1.8)
	if spots.has(mode) and is_instance_valid(spots[mode]):
		(spots[mode] as Node).queue_free()
	spots.erase(mode)
	if g.size() >= 3:
		var cut := str(bw().get("broke_cut", ""))
		if cut != "" and Cutscene.has_cutscene(cut):
			await TrainingDB.wait_dialogue_free()
			await Cutscene.play(cut)
		advance()
	return true


## 「借」的提示：跟着那个人（他会在附近走动），靠近面向它出「E」
class BorrowSpot extends Node2D:
	var runner: QuestBorrow
	var mode := ""
	var follow: Node2D
	var area: Interactable
	var _t := 0.0

	func _ready() -> void:
		z_index = 2
		area = Interactable.new()
		var shape := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 9.0
		shape.shape = c
		area.add_child(shape)
		add_child(area)

	func _process(delta: float) -> void:
		_t += delta
		if is_instance_valid(follow):
			global_position = follow.global_position + Vector2(14, 4)
		queue_redraw()

	func on_interact(_player: Node) -> void:
		if is_instance_valid(runner):
			runner.borrow(mode)

	func _draw() -> void:
		draw_circle(Vector2(0, -6), 5.0 + sin(_t * 4.0), Color(1, 0.85, 0.4, 0.25))
		draw_string(ThemeDB.fallback_font, Vector2(-4, -3), "借", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.95, 0.7))
