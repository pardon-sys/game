class_name PalaceGarden
extends PalaceRoom
## 第四章·后花园（floor_06_palace_garden；台词 penance_text/palace7.py；图 garden_props.png / npcs/flower_keeper.png）：
##   前厅东北角柱子后面的暗门进来（前厅 exit secret=true，unlock_flag = GARDEN_CLUE：石像三问全对以后告诉你）。
##   双人秋千（swing）：garden_swing 对话 → 小剧场 garden_swing（藤蔓挠脚心）。
##   天使喷泉的水路（cherubs ×3、fountain）：按 E 转小天使 90°（turn(i)）；转到错误方向会被水柱喷脚底；三尊都对准喷泉 → FLOW_FLAG，
##     喷泉有水、凉亭（gazebo）里的宝箱能开（garden_gazebo → open_gazebo()：薄荷糖 ×2 + 金币 ×30 + 卡片）。
##   花园小店主（keeper，小花精玩偶）：想浇花 → KEEPER_ASKED → 厨房水槽边出现小水壶（kitchen_watering_can）→ 带回来浇花（water()）
##     → 小剧场 garden_petals（花瓣挠痒）→ 线索。
##   花丛里的小精灵：生成器放的 fairy_swarm。
## 测试：dirs、turn(i)、flowing()、open_gazebo()、water()。

const MAP := "floor_06_palace_garden"
const GARDEN_CLUE := "palace_garden_clue"
const FLOW_FLAG := "palace_fountain_flow"
const GAZEBO_FLAG := "palace_gazebo_done"
const KEEPER_ASKED := "palace_keeper_asked"
const KEEPER_DONE := "palace_keeper_done"
const PROPS := "res://assets/generated/garden_props.png"   # 0 秋千 / 1 小天使 / 2 凉亭 / 3 花坛 / 4 水壶 / 5 干喷泉
const KEEPER_TEX := "res://assets/generated/npcs/flower_keeper.png"
## 小天使的朝向：0 东 / 1 南 / 2 西 / 3 北；每尊对准喷泉的方向（按 cells("cherubs") 的顺序，见 RIGHT_DIR()）
const DIR_VEC := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
const SPRAY_ROOT := 0.5
const DECOR_BEDS := [Vector2i(14, 7), Vector2i(18, 15), Vector2i(38, 15), Vector2i(42, 7), Vector2i(14, 33), Vector2i(18, 25),
		Vector2i(38, 25), Vector2i(8, 20), Vector2i(48, 21), Vector2i(23, 33), Vector2i(33, 33)]

var dirs: Array = []
var _cherub_views: Array = []
var _fountain_view: Node2D
var _keeper_view: Node2D
var _beds: Array = []


func map_id() -> String:
	return MAP


func _ready() -> void:
	super()
	var fc := cells("fountain")[0]
	_fountain_view = sheet_view(PROPS, 6, 5, fc, [], 1.4)
	var w := WaterView.new()
	w.room = self
	w.position = world(fc)
	add_view(w)
	sheet_view(PROPS, 6, 0, cells("swing")[0], [], 1.2)
	_spot("floor_06/garden_swing", cells("swing")[0], -40.0)
	sheet_view(PROPS, 6, 2, cells("gazebo")[0], [], 1.3)
	_spot("floor_06/garden_gazebo", cells("gazebo")[0], -40.0, GAZEBO_FLAG)
	for c in cells("beds"):
		_beds.append(sheet_view(PROPS, 6, 3, c, [], 0.9))
	# 装饰：沿着树篱摆几圈花坛（不能互动；浇过花一起亮起来）
	for c in DECOR_BEDS:
		if GridPath.walkable(lv, c):
			_beds.append(sheet_view(PROPS, 6, 3, c, [], 0.75))
	var i := 0
	for c in cells("cherubs"):
		var right := _right_dir(c)
		# 开始时都朝着不对的方向（固定：转一下 / 两下 / 三下）
		dirs.append((right + 1 + i) % 4)
		var cv := CherubView.new()
		cv.room = self
		cv.idx = i
		cv.position = world(c)
		add_view(cv)
		_cherub_views.append(cv)
		var it := Interactable.new()
		it.prompt_offset = Vector2(0, -30)
		var sh := CollisionShape2D.new()
		var cs := CircleShape2D.new()
		cs.radius = 14.0
		sh.shape = cs
		it.add_child(sh)
		var idx := i
		it.interacted.connect(func(_who): turn(idx))
		add_child(it)
		it.global_position = world(c)
		i += 1
	if GameState.has_flag(FLOW_FLAG):
		for k in dirs.size():
			dirs[k] = _right_dir(cells("cherubs")[k])
	var kc := cells("keeper")[0]
	_keeper_view = KeeperView.new()
	(_keeper_view as KeeperView).room = self
	_keeper_view.position = world(kc)
	add_view(_keeper_view)
	_spot("floor_06/garden_keeper", kc, -36.0)
	_refresh_beds()


func _spot(dialogue: String, c: Vector2i, py := -22.0, done := "") -> void:
	var sp := PrisonOddities.Spot.new()
	sp.dialogue = dialogue
	sp.prompt_y = py
	sp.done_flag = done
	add_child(sp)
	sp.global_position = world(c)


func _right_dir(c: Vector2i) -> int:
	var to := Vector2(cells("fountain")[0] - c)
	if absf(to.x) >= absf(to.y):
		return 0 if to.x > 0 else 2
	return 1 if to.y > 0 else 3


func flowing() -> bool:
	return GameState.has_flag(FLOW_FLAG)


## 转第 i 尊小天使 90°（顺时针）：转到对准喷泉 → 这一股水流进去；三股都通 → FLOW_FLAG。转到别的方向 → 水柱喷在转它的人脚底
func turn(i: int) -> void:
	if flowing() or busy():
		return
	dirs[i] = (int(dirs[i]) + 1) % 4
	Audio.play("gear", -6.0, 0.0, 1.3)
	var c := cells("cherubs")[i]
	var pc := GameState.player as PlayableCharacter
	if int(dirs[i]) == _right_dir(c):
		Audio.play("splash", -6.0)
		if is_instance_valid(pc):
			SpeechBubble.say(pc, "……对上了。", 30.0, 1.0)
		if dirs.size() == cells("cherubs").size() and range(dirs.size()).all(func(k): return int(dirs[k]) == _right_dir(cells("cherubs")[k])):
			GameState.set_flag(FLOW_FLAG)
			Audio.play("water_release", -2.0)
			GameState.notify("三股水流进了喷泉——凉亭那边传来「咕噜咕噜」的水车声")
			if is_instance_valid(pc):
				PalaceRoom.say_random(pc, "garden_flow")
		return
	# 水柱朝着别处喷：转它的人（就站在旁边）被喷了一脚底
	if is_instance_valid(pc) and pc.global_position.distance_to(world(c)) <= 40.0:
		pc.status.apply_root(SPRAY_ROOT)
		for k in 2:
			var h := HitData.make_tickle(self, 2.5)
			h.zone = "sole"
			pc.receive_hit(h)
		PalaceRoom.say_random(pc, "garden_spray")
		Fx.burst(get_parent(), pc.global_position, "drop", 8, 40.0, 0.5, Vector2(0, 30), Color(0.6, 0.85, 1.0))


func open_gazebo() -> bool:
	if not flowing() or GameState.has_flag(GAZEBO_FLAG):
		return false
	GameState.set_flag(GAZEBO_FLAG)
	for id in ["mint", "mint"]:
		GameState.give_item(ItemDB.get_item(id), 1)
	GameState.give_item(ItemDB.get_item("coin"), 30)
	Audio.play("chest", -3.0)
	GameState.notify("凉亭的宝箱：薄荷糖 ×2、金币 ×30")
	return true


## 带着小水壶浇花：水壶收回去、花坛亮起来（谢礼小剧场由对话接着播）
func water() -> bool:
	if GameState.has_flag(KEEPER_DONE) or not GameState.inventory.has("watering_can"):
		return false
	GameState.inventory.remove("watering_can", 1)
	GameState.set_flag(KEEPER_DONE)
	Audio.play("splash", -4.0)
	for b in _beds:
		Fx.burst(get_parent(), (b as Node2D).position + Vector2(0, -6), "leaf", 6, 30.0, 0.6, Vector2(0, -10), Color(1, 0.8, 0.9))
	_refresh_beds()
	return true


func _refresh_beds() -> void:
	for b in _beds:
		(b as Node2D).modulate = Color.WHITE if GameState.has_flag(KEEPER_DONE) else Color(0.75, 0.7, 0.6)


func _process(_delta: float) -> void:
	if busy():
		return
	update_checkpoints()


## 小天使：画像（小天使抱水瓶）+ 一道水柱（朝着 dirs[idx]，对准喷泉时连到喷泉、亮一点）
class CherubView extends Node2D:
	var room: PalaceGarden
	var idx := 0
	var _spr: Sprite2D
	var _t := 0.0

	func _ready() -> void:
		if ResourceLoader.exists(PalaceGarden.PROPS):
			_spr = Sprite2D.new()
			_spr.texture = load(PalaceGarden.PROPS)
			_spr.hframes = 6
			_spr.frame = 1
			_spr.offset = Vector2(0, -22)
			_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_spr)

	func _process(d: float) -> void:
		_t += d
		if room == null or idx >= room.dirs.size():
			return
		var dir := int(room.dirs[idx])
		if _spr:
			_spr.flip_h = dir == 2 or dir == 3   # 原图水朝右（东）；朝西 / 朝北就翻过来
		queue_redraw()

	func _draw() -> void:
		if room == null or idx >= room.dirs.size():
			return
		var dir := int(room.dirs[idx])
		var v: Vector2 = PalaceGarden.DIR_VEC[dir]
		var ok := dir == room._right_dir(room.cells("cherubs")[idx])
		var ln := room.world(room.cells("fountain")[0]).distance_to(position) - 20.0 if ok else 22.0
		var col := Color(0.55, 0.85, 1.0, 0.85 if ok else 0.55)
		# 水柱方向是逻辑方向：画的时候换成屏幕上的偏移（等距显示里节点本身是直立的）
		var a := Vector2(0, -14) + IsoView.offset(v * 6.0)
		var b := IsoView.offset(v * ln) + Vector2(0, -4)
		draw_line(a, b, col, 3.0 if ok else 2.0)
		for k in 4:
			var p := a.lerp(b, fposmod(_t * 1.2 + k * 0.25, 1.0))
			draw_circle(p, 1.5, Color(0.85, 0.95, 1.0, 0.9))


## 喷泉里的水（三股都接通以后）
class WaterView extends Node2D:
	var room: PalaceGarden
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		if room == null or not room.flowing():
			return
		draw_set_transform(Vector2(0, -6), 0.0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, 18.0, Color(0.5, 0.8, 1.0, 0.7))
		for k in 3:
			draw_arc(Vector2.ZERO, fposmod(_t * 10.0 + k * 6.0, 18.0), 0, TAU, 20, Color(0.85, 0.95, 1.0, 0.6), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 花园小店主：站着两帧轮流；没浇花时噘嘴（第 3 帧），浇过花开心地撒花（第 4 帧）
class KeeperView extends Node2D:
	var room: PalaceGarden
	var _spr: Sprite2D
	var _t := 0.0

	func _ready() -> void:
		z_index = 1
		if ResourceLoader.exists(PalaceGarden.KEEPER_TEX):
			_spr = Sprite2D.new()
			_spr.texture = load(PalaceGarden.KEEPER_TEX)
			_spr.hframes = 4
			_spr.offset = Vector2(0, -18)
			_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_spr)

	func _process(d: float) -> void:
		_t += d
		if _spr == null:
			return
		if GameState.has_flag(PalaceGarden.KEEPER_DONE):
			_spr.frame = 3 if int(_t * 1.5) % 4 == 0 else int(_t * 2.0) % 2
		elif GameState.has_flag(PalaceGarden.KEEPER_ASKED):
			_spr.frame = 2
		else:
			_spr.frame = int(_t * 2.0) % 2
		_spr.position.y = sin(_t * 3.0) * 1.0
