class_name QuestShoes
extends QuestRunner
## 支线「骑士救公主」的玩法（白天的骑士篇小镇 floor_06_knight_day）：鞋被孩子们抢走了，光着脚（meta barefoot + 状态 barefoot）找三处。
##   一直摆着：三片光脚地面（BareFloor：草垛院子的稻草垫、广场彩带下的羽毛堆、西边的鹅卵石小路）、举着羽毛「长矛」偷袭的小孩（AfterKid，光着脚就扑上来挠脚心）。
##   0 草垛：站在草垛边按住 E 翻 SEARCH_TIME 秒（翻的时候脚下的稻草一直扎）。
##   1 彩带：站在羽毛堆上按住 E 够 REACH_TIME 秒。
##   2 小路尽头：走到小莉莉身边 → 「谁先笑」（LilyDuelShow），赢了鞋还回来 → 过场 kq_shoes_invite（大人不让玩的游戏）。
##   3 没有灯的小巷「灯全灭了」（QuestHide）/ 4 集市里追回小莉莉的宝贝盒（QuestBox）→ 做完（骑士勋章、红绳 → 引向主线）。
## 测试：search_held（这一帧当成按住了 E）、progress、spot、lily、duel()。

const SEARCH_TIME := 2.2
const REACH_TIME := 1.6
const SPOT_R := 14.0
const DUEL_R := 20.0
## 三片光脚地面：[种类, 左上角的格, 大小（格）]
const FLOORS := [["straw", Vector2i(49, 29), Vector2i(5, 3)], ["feather", Vector2i(35, 21), Vector2i(4, 3)], ["pebble", Vector2i(7, 29), Vector2i(9, 3)]]
const KIDS := [Vector2i(45, 31), Vector2i(31, 24), Vector2i(17, 31)]
const LILY := Vector2i(5, 30)
const KID_SHEET := preload("res://assets/generated/npcs/kid.png")

var search_held := false
var progress := 0.0
var spot: SpotMark
var lily: Sprite2D
var duel_running := false


static func runs_on(floor_id: String, _stage: int) -> bool:
	return floor_id == KnightStory.KDAY


## 放下 / 做完：鞋穿回去了
static func reset_items() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for c in tree.get_nodes_in_group("player_chars"):
		if c.has_meta(&"barefoot"):
			c.remove_meta(&"barefoot")
		if c.has_method("remove_buff"):
			c.remove_buff("barefoot")


func setup() -> void:
	if not is_instance_valid(pink):
		return
	pink.set_meta(&"barefoot", true)
	pink.add_buff("barefoot", -1.0)
	for f in FLOORS:
		var bf := BareFloor.make(get_parent(), str(f[0]), f[1], f[2], q.get("%s_react" % f[0], []))
		spawned.append(bf)
	for at in KIDS:
		var k := AfterKid.spawn(get_parent(), Cutscene.cell_to_world(at), 3.0)
		k.lure = func() -> bool: return is_instance_valid(pink) and pink.has_meta(&"barefoot") and pink.laugh and pink.laugh.ratio() < 0.85
		k.pick_zone = func(_k) -> String: return "sole"
		k.caption = func(_k, _z) -> String: return str((q.get("kid_captions", [""]) as Array).pick_random())
		k.chase_words = q.get("kid_lines", ["公主不许跑！"])
		k.tickle_words = q.get("kid_lines", ["嘿嘿！"])
		spawned.append(k)
	progress = 0.0
	var st: Array = (q.get("stages", []) as Array)[mini(stage(), 2)]["cell"]
	if stage() < 2:
		spot = put(SpotMark.new(), cell(st)) as SpotMark
		spot.kind = "hay" if stage() == 0 else "ribbon"
		spot.runner = self
	else:
		lily = put(Sprite2D.new(), Cutscene.cell_to_world(LILY) + Vector2(0, -10)) as Sprite2D
		lily.texture = KID_SHEET
		lily.region_enabled = true
		lily.region_rect = Rect2(64, 32, 32, 32)
		lily.modulate = Color(1.0, 0.9, 0.95)


func cleanup() -> void:
	if not KnightQuests.is_active(quest_id):
		reset_items()


func _process(delta: float) -> void:
	if duel_running or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink) or GameState.player != pink:
		return
	if stage() < 2 and is_instance_valid(spot):
		var near := pink.global_position.distance_to(spot.global_position) <= SPOT_R
		if stage() == 1:
			near = near and _on_feathers()
		if near and (search_held or Input.is_action_pressed("interact")):
			progress += delta
			if stage() == 0 and pink.laugh and randf() < delta * 3.0:
				pink.laugh.add(pink.laugh.max_value * BareFloor.STRAW_LAUGH)
				ZoneFx.play("sole", pink.get_parent(), ZoneFx.body_point(pink, "sole"), 0.6, false)
			if progress >= (SEARCH_TIME if stage() == 0 else REACH_TIME):
				var lines: Array = q.get("found", [])
				say(lines[stage()] if stage() < lines.size() else "")
				Audio.play("pickup", -4.0)
				advance()
		else:
			progress = maxf(0.0, progress - delta)
		spot.queue_redraw()
	elif stage() == 2 and is_instance_valid(lily) and pink.global_position.distance_to(lily.global_position + Vector2(0, 10)) <= DUEL_R:
		duel()


func _on_feathers() -> bool:
	for f in spawned:
		if f is BareFloor and (f as BareFloor).kind == "feather" and (f as BareFloor).inside(pink):
			return true
	return false


## 和小莉莉比「谁先笑」：赢了这一段（也是最后一段）做完；输了 / 中途退出就站在原地，走开再走回来可以再比
func duel() -> bool:
	if duel_running:
		return false
	duel_running = true
	var show := LilyDuelShow.new()
	get_tree().root.add_child(show)
	var ok: bool = await show.play()
	if is_instance_valid(show):
		show.queue_free()
	if ok:
		reset_items()
		if Cutscene.has_cutscene("kq_shoes_invite"):
			await TrainingDB.wait_dialogue_free()
			await Cutscene.play("kq_shoes_invite")
		await advance()
	elif is_instance_valid(pink) and is_instance_valid(lily):
		pink.global_position = lily.global_position + Vector2(36, 10)
	duel_running = false
	return ok


## 藏鞋的地方：草垛 / 挂着鞋的彩带，按住 E 的进度圈
class SpotMark extends Node2D:
	var kind := "hay"
	var runner: QuestShoes
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if kind == "hay":
			draw_circle(Vector2(0, -2), 9.0, Color("d9b45f"))
			draw_circle(Vector2(-5, 0), 6.0, Color("e8c870"))
			draw_circle(Vector2(5, 0), 6.0, Color("c9a04e"))
			for i in 5:
				draw_line(Vector2(-8 + i * 4, -6), Vector2(-6 + i * 4, -11), Color("f2dc96"), 1.0)
		else:
			draw_line(Vector2(-14, -22), Vector2(14, -20), Color("ff7aa8"), 1.0)
			var sway := sin(_t * 2.0) * 1.5
			draw_rect(Rect2(Vector2(-3 + sway, -19), Vector2(6, 4)), Color("c75a7a"))
			draw_rect(Rect2(Vector2(-3 + sway, -16), Vector2(7, 2)), Color("8a3550"))
		# 一闪一闪的提示
		draw_circle(Vector2(8, -16), 1.2 + 0.6 * sin(_t * 6.0), Color(1, 0.95, 0.6, 0.9))
		if runner and runner.progress > 0.0:
			var need := QuestShoes.SEARCH_TIME if kind == "hay" else QuestShoes.REACH_TIME
			draw_arc(Vector2(0, -26), 5.0, -PI / 2.0, -PI / 2.0 + TAU * minf(1.0, runner.progress / need), 20, Color(1, 0.9, 0.5), 2.0)
