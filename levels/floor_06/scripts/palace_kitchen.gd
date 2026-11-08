class_name PalaceKitchen
extends PalaceRoom
## 第四章③·厨房（floor_06_palace_kitchen，等距）：
##   糕点师人偶（chef，对话 kitchen_chef → 小剧场「试吃」）；试吃推销员的小摊（booth，对话 kitchen_booth → 小剧场 kitchen_promoter，第一次做完给薄荷糖 ×MINTS）；
##   打翻的奶油（cream）：踩到脚底变甜 SWEET_TIME 秒，附近的老鼠（Monster）一直被引过来（rally_to）；水槽（sink，对话 call palace_wash，或者站过去）洗掉；
##   冰窖滑道（ice 格）：站上去就往东滑（ICE_SPEED，上下还能躲），两侧羽毛扇（fans）扫到就挠脚底；
##   大奶酪（cheese）：走过去就演挠脚鼠告别（kitchen_farewell）→ 脱下鼠鼠装、穿回原来的鞋（FAREWELL_FLAG）；
##   北门（north）：通往图书馆的出口（地图里的 exit，挠脚鼠告别以后才打开：unlock_flag = FAREWELL_FLAG）。
## 测试：sweet、wash(who)、fans、farewell_done()、PAID_FLAG。

const MAP := "floor_06_palace_kitchen"
const FAREWELL_FLAG := "palace_mouse_farewell"
const PAID_FLAG := "kitchen_promoter_paid"
const MINTS := 3
const SWEET_TIME := 15.0
const RALLY_R := 120.0
const SINK_R := 14.0
## 追加事件·冷藏库：滑道尽头冻住的门（粉色公主攻击 / 施法 MELT_R 以内就融开）→ 第一次进去演 kitchen_icecream、放出冰糕精灵；
## 冰块里的生日蛋糕也要粉色公主来融（kitchen_ice_cake 对话 → melt_cake）
const COLD_FLAG := "palace_cold_open"
const COLD_IN_FLAG := "palace_cold_entered"
const CAKE_FLAG := "palace_ice_cake"
const MELT_R := 26.0
const ICE_SPRITE := "res://scenes/actors/monsters/ice_sprite.tscn"
var _cold_door: StaticBody2D
var _cold_view: Node2D
var ice_sprites: Array = []
var _cake_view: PalaceRoom.SheetView
const ICE_SPEED := 110.0
const FAN_DX := 10.0
const FAN_DY := 9.0

var sweet := {}
var _rally_t := 0.0


func map_id() -> String:
	return MAP


func _ready() -> void:
	super()
	for pair in [["chef", "floor_06/kitchen_chef"], ["booth", "floor_06/kitchen_booth"], ["sink", "floor_06/kitchen_sink"]]:
		var sp := PrisonOddities.Spot.new()
		sp.dialogue = str(pair[1])
		add_child(sp)
		sp.global_position = world(cells(str(pair[0]))[0])
	if not cells("cold_door").is_empty():
		if not GameState.has_flag(COLD_FLAG):
			_cold_door = StaticBody2D.new()
			_cold_door.collision_layer = 1
			_cold_door.collision_mask = 0
			var sh := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			r.size = Vector2(16, 16)
			sh.shape = r
			_cold_door.add_child(sh)
			add_child(_cold_door)
			_cold_door.global_position = PalaceRoom.cell_pos(cells("cold_door")[0])
			_cold_view = sheet_view(PalaceRoom.PROPS4, 6, 1, cells("cold_door")[0], [], 0.8)
		_cake_view = sheet_view(PalaceRoom.PROPS4, 6, 3 if GameState.has_flag(CAKE_FLAG) else 2, cells("ice_cake")[0], [], 0.8)
		var csp := PrisonOddities.Spot.new()
		csp.dialogue = "floor_06/kitchen_ice_cake"
		csp.done_flag = CAKE_FLAG
		add_child(csp)
		csp.global_position = world(cells("ice_cake")[0])
	# 事件点的图：糕点师人偶站在糕点台后面、水槽
	sheet_view(PalaceRoom.PROPS3, 6, 5, cells("chef")[0], [], 0.9, Vector2(0, 8))
	sheet_view(PalaceRoom.CHEF, 4, 0, cells("chef")[0], [0, 1], 1.0, Vector2(0, -6))
	sheet_view(PalaceRoom.PROPS3, 6, 4, cells("sink")[0], [], 0.8, Vector2(0, -6))
	# 第四轮·后花园：花园小店主的小水壶（店主拜托过以后才出现在水槽边，拿走就没了）
	var can_c := cells("sink")[0] + Vector2i(2, 0)
	var can_v := PalaceRoom.Events2View.new()
	can_v.tex = "res://assets/generated/item_watering_can.png"
	can_v.scale_k = 1.0
	can_v.need = ["palace_keeper_asked"]
	can_v.hide_flag = "palace_can_taken"
	can_v.position = world(can_c)
	add_view(can_v)
	var can_sp := PrisonOddities.Spot.new()
	can_sp.dialogue = "floor_06/kitchen_watering_can"
	can_sp.done_flag = "palace_can_taken"
	add_child(can_sp)
	can_sp.global_position = world(can_c)
	gate(can_sp, ["palace_keeper_asked"])
	# 追加事件·送餐潜行：糕点台旁边的托盘
	if not cells("tray").is_empty():
		var tsp := PrisonOddities.Spot.new()
		tsp.dialogue = "floor_06/kitchen_tray"
		tsp.done_flag = "palace_sheet_2"
		add_child(tsp)
		tsp.global_position = world(cells("tray")[0])
		var tv := PalaceRoom.Events2View.new()
		tv.frame = 1
		tv.hide_flag = PalaceRoom.TRAY_FLAG
		tv.position = world(cells("tray")[0])
		add_view(tv)
	for c in cells("fans"):
		var f := FanMark.new()
		f.position = world(c)
		add_view(f)
	for c in cells("ice"):
		var ic := IceCell.new()
		ic.cell = c
		ic.position = PalaceRoom.cell_pos(c)
		add_view(ic)
	for c in cells("cream"):
		var cm := CreamMark.new()
		cm.position = PalaceRoom.cell_pos(c)
		add_view(cm)


static func farewell_done() -> bool:
	return GameState.has_flag(FAREWELL_FLAG)


func _process(delta: float) -> void:
	if busy():
		return
	tick_patrols(delta)
	_tick_cold()
	# 推销员的报酬
	if GameState.has_flag("cg_seen_theater:kitchen_promoter") and not GameState.has_flag(PAID_FLAG):
		GameState.set_flag(PAID_FLAG)
		var mint := ItemDB.get_item("mint")
		if mint:
			GameState.inventory.add(mint, MINTS)
		GameState.notify("拿到了「薄荷糖」×%d" % MINTS)
	# 挠脚鼠告别
	if GameState.has_flag("cg_seen_theater:kitchen_farewell") and not farewell_done():
		GameState.set_flag(FAREWELL_FLAG)
		PenanceCell.take_off_mouse()
	if not farewell_done() and auto_theater("cheese", "kitchen_farewell", 22.0):
		return
	for m in members():
		var pc := m as PlayableCharacter
		if Downed.is_downed(pc):
			continue
		var c := GridPath.cell(pc.global_position)
		# 奶油 / 水槽
		for cc in cells("cream"):
			if pc.global_position.distance_to(world(cc)) <= 9.0 and not sweet.has(pc):
				sweet[pc] = SWEET_TIME
				PalaceRoom.say_random(pc, "cream")
		if pc.global_position.distance_to(world(cells("sink")[0])) <= SINK_R:
			wash(pc)
		if sweet.has(pc):
			sweet[pc] = float(sweet[pc]) - delta
			if float(sweet[pc]) <= 0.0:
				sweet.erase(pc)
		# 冰滑道 + 羽毛扇
		if c in cells("ice"):
			var nxt := pc.global_position + Vector2(ICE_SPEED * delta, 0)
			if GridPath.walkable(lv, GridPath.cell(nxt + Vector2(6, 0))):
				pc.global_position = nxt
			for f in cells("fans"):
				var fp := world(f)
				if absf(pc.global_position.x - fp.x) <= FAN_DX and absf(pc.global_position.y - fp.y) <= FAN_DY:
					tickle(pc, "fan" + str(f), 0.5, 4.0, "sole", delta)
	# 脚底甜甜的：附近的老鼠追过来
	_rally_t -= delta
	if _rally_t <= 0.0:
		_rally_t = 1.0
		for pc in sweet:
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Monster and (e as Node2D).global_position.distance_to((pc as Node2D).global_position) <= RALLY_R:
					(e as Monster).rally_to(pc)


# ------------------------------------------------------------------ 冷藏库
func _tick_cold() -> void:
	if cells("cold_door").is_empty():
		return
	var door := world(cells("cold_door")[0])
	if not GameState.has_flag(COLD_FLAG):
		for m in members():
			var pc := m as PlayableCharacter
			if pc.character_id == "pink" and (pc.state == PlayableCharacter.State.ATTACK or pc.state == PlayableCharacter.State.CAST) \
					and pc.global_position.distance_to(door) <= MELT_R:
				melt_door()
				return
		return
	if not GameState.has_flag(COLD_IN_FLAG):
		for m in members():
			if (m as Node2D).global_position.x > door.x + 8.0:
				enter_cold()
				return


func melt_door() -> void:
	GameState.set_flag(COLD_FLAG)
	Audio.play("water_release", -4.0)
	Fx.burst(get_parent(), world(cells("cold_door")[0]) + Vector2(0, -12), "dust", 16, 50.0, 0.7, Vector2(0, -10), Color(0.75, 0.9, 1.0))
	if is_instance_valid(_cold_door):
		_cold_door.queue_free()
	if is_instance_valid(_cold_view):
		_cold_view.queue_free()
	PalaceRoom.say_random(pink if is_instance_valid(pink) else GameState.player, "cold_melt")


## 第一次走进冷藏库：冰糕精灵们醒了（小剧场），然后放出来
func enter_cold() -> void:
	GameState.set_flag(COLD_IN_FLAG)
	await CG.play_theater("kitchen_icecream")
	var scene := load(ICE_SPRITE) as PackedScene
	for c in cells("ice_sprites"):
		var m := scene.instantiate() as Node2D
		m.position = world(c)
		add_view(m)
		ice_sprites.append(m)


## 冰块里的生日蛋糕：粉色公主的火融开（对话里叫）
func melt_cake() -> bool:
	if GameState.has_flag(CAKE_FLAG):
		return true
	if not members().any(func(m): return (m as PlayableCharacter).character_id == "pink"):
		return false
	GameState.set_flag(CAKE_FLAG)
	Audio.play("water_release", -6.0)
	if is_instance_valid(_cake_view) and _cake_view._s:
		_cake_view._s.frame = 3
	return true


func wash(pc: PlayableCharacter) -> void:
	if sweet.has(pc):
		sweet.erase(pc)
		Audio.play("bubble_pop", -6.0)
		PalaceRoom.say_random(pc, "wash")


## 冰窖滑道两侧的羽毛扇
class FanMark extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_line(Vector2(0, -2), Vector2(0, -14), Color(0.5, 0.45, 0.4), 1.5)
		for k in 4:
			var a := _t * 8.0 + k * PI / 2.0
			draw_line(Vector2(0, -14), Vector2(0, -14) + Vector2(cos(a), sin(a) * 0.5) * 7.0, Color(1, 1, 1, 0.9), 2.0)


## 冰窖滑道的冰面（屏幕空间菱形，偶尔一道反光）
class IceCell extends Node2D:
	var cell: Vector2i
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if int(_t * 10.0) % 5 == 0:
			queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array([IsoView.offset(Vector2(-8, -8)), IsoView.offset(Vector2(8, -8)), IsoView.offset(Vector2(8, 8)), IsoView.offset(Vector2(-8, 8))])
		draw_colored_polygon(pts, Color(0.75, 0.9, 1.0, 0.55))
		var k := fposmod(_t * 0.6 + cell.x * 0.13, 3.0)
		if k < 0.4:
			draw_line(IsoView.offset(Vector2(-6, -6)), IsoView.offset(Vector2(6, 6)), Color(1, 1, 1, 0.8), 1.0)


## 打翻的奶油（地上的一摊白）
class CreamMark extends Node2D:
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, IsoView.ground_scale())
		draw_circle(Vector2.ZERO, 6.0, Color(1, 0.98, 0.92, 0.9))
		draw_circle(Vector2(3, -2), 2.5, Color(1, 1, 1, 0.95))
