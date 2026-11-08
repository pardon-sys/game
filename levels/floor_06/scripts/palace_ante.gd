class_name PalaceAnte
extends PalaceRoom
## 第四章⑦·王座前厅（floor_06_palace_ante，中转；台词 penance_text/palace3.py、palace4.py）：
##   南 → 训练场、西 → 钟楼、北 → 王座间（exit，unlock_flag = palace_bells_done：钟顶敲十三下才开）、东墙的画后 → 隧道（第一次从这里进）；
##   画后面的入口画成一幅歪掉的画（PaintingDoor）。
## 追加事件（谜题连环链 + 笑脸徽记）：
##   笑声地砖（tiles，正中 3×3）：踩一块响一声笑。三片乐谱（PalaceRoom.sheets）都有了，地砖亮起来：按 TILE_SEQ 踩对 → 地下小宝库（vault）打开；
##     踩错 → 砖缝里的羽毛扫脚心、从头来。宝库：女王最喜欢的花（铃兰）+ 笑脸徽记（vault_loot）。
##   骑士石像（statue）：三道问答（十三下 / 七号 / 铃兰），答错被石手挠脚心；全对 → 女王的八音盒 + 笑脸徽记（statue_ok）。
##   许愿喷泉（fountain）：投薄荷糖 / 10 金币，随机：回复 / 水柱喷脚底 / 小鱼啄脚趾（wish）。
##   徽记台（pedestal）：七枚笑脸徽记 → 女王的羽毛发饰 + 庆祝小剧场 palace_badge_party（CG）（place_badges）。
##   空铠甲卫兵 ×2（ArmorGuard）：绕着大厅巡逻，扇形视野里看到人就冲过来举起来挠腋下；从背后按 E 推倒，散架 DOWN_TIME 秒。
## 搭档闲逛（第四轮）：没被操控的那个不跟着走，在大厅里随机闲逛 / 调查（AnteHooks.objective_for → WANDER 里的点，挑的路线不穿过地砖），
##   到了冒个「？」；地砖只认玩家操控的那个人踩。走过去按 E 和她说话 → floor_06/ante_partner_hint：按进度随机一句流程提示
##   （hint_keys() 算出当前用得上的 key，每 HINT_EVERY 秒随机写进 vars.ante_hint）。
## 测试：tile_progress、step_tile(i)、vault_open()、guards、wish(kind)、next_wish、place_badges()、wander_target(ai)、hint_keys()。

const MAP := "floor_06_palace_ante"
const TILE_SEQ := [0, 4, 8, 2, 4, 6]   # 同 palace4.py 的 TILE_SEQ（行优先：0 左上 … 8 右下）
const VAULT_FLAG := "palace_vault_open"
const VAULT_LOOT := "palace_queen_flower"
const STATUE_FLAG := "palace_statue_done"
const BADGES_FLAG := "palace_badges_done"
const GUARD_R := 6.0 * 16.0
const FOUNTAIN_COINS := 10
## 追加事件·人偶舞会：三处一起「演奏」摇篮曲 —— 训练场的铜钟（BALL_BELL）、婴儿房的旋转吊铃（LULLABY）、
## 宝库打开以后按吊铃底下的记号在地砖上踩一遍（LULLABY_SEQ → BALL_TILES）→ 前厅开舞会：
## 三波舞会人偶（BALL_WAVES），地板按拍子（BEAT）亮红一块扇区，拍子落下时站在红区里的人被羽毛扫；全打完 → BALL_DONE。
const LULLABY_SEQ := [6, 4, 2, 8, 4, 0]
const BALL_BELL := "palace_ball_bell"
const LULLABY := "palace_lullaby_heard"
const BALL_TILES := "palace_ball_tiles"
const BALL_DONE := "palace_ball_done"
const BALL_WAVES := [3, 4, 5]
const BEAT := 1.8
const BEAT_WARN := 0.8
const BALL_R := 15.0 * 16.0
const DOLL_SCENE := "res://scenes/actors/monsters/dance_doll.tscn"
var lull_progress := 0
var ball_on := false
var ball_wave := -1
var dolls: Array = []
var beat_q := -1
var _beat_t := BEAT
var _beat_view: BeatView

var tile_progress := 0
var guards: Array = []
## 测试用：下一次许愿的结果（-1 = 随机；0 回复 / 1 水柱 / 2 小鱼）
var next_wish := -1
const HINT_FILE := "floor_06/ante_partner_hint"
const HINT_EVERY := 2.5
const WANDER := [Vector2i(20, 14), Vector2i(41, 14), Vector2i(19, 25), Vector2i(42, 25), Vector2i(25, 28), Vector2i(36, 28),
		Vector2i(27, 31), Vector2i(33, 31), Vector2i(10, 19), Vector2i(50, 21), Vector2i(30, 9), Vector2i(23, 20), Vector2i(37, 20)]
const WANDER_STAY := Vector2(2.0, 4.0)
const TILE_CLEAR := 36.0
var _wander := {}            # ai 的 id → {"to": Vector2, "stay": 秒}
var _hint_t := 0.0
var _roamers: Array = []
var _old_talk := {}
var _tile_origin := Vector2i.ZERO
var _last_cell := {}
var _tiles: Array = []
var _vault_spot: Node


func map_id() -> String:
	return MAP


func _ready() -> void:
	super()
	_spot_at("floor_06/ante_statue", cells("statue")[0], STATUE_FLAG, -44.0)
	sheet_view(PalaceRoom.PROPS3, 6, 0, cells("statue")[0], [], 1.0, Vector2(0, -4))   # 抱着剑的骑士石像
	var d := PaintingDoor.new()
	d.position = world(cells("painting")[0])
	add_view(d)
	if has_marks():
		_ready_events()


func has_marks() -> bool:
	return not cells("tiles").is_empty()


func _ready_events() -> void:
	var tc := cells("tiles")
	_tile_origin = Vector2i(tc.map(func(c): return c.x).min(), tc.map(func(c): return c.y).min())
	for c in tc:
		var tv := TileView.new()
		tv.room = self
		tv.idx = (c.y - _tile_origin.y) * 3 + (c.x - _tile_origin.x)
		tv.position = world(c)
		add_view(tv)
		_tiles.append(tv)
	_spot_at("floor_06/ante_fountain", cells("fountain")[0], "", -34.0)
	add_view(_prop(3, world(cells("fountain")[0])))
	_spot_at("floor_06/ante_pedestal", cells("pedestal")[0], BADGES_FLAG, -34.0)
	var pv := PedestalView.new()
	pv.position = world(cells("pedestal")[0])
	add_view(pv)
	var vv := VaultView.new()
	vv.position = world(cells("vault")[0])
	add_view(vv)
	_vault_spot = _spot_at("floor_06/ante_vault", cells("vault")[0], VAULT_LOOT)
	_set_vault_enabled(vault_open())
	var center := (world(_tile_origin) + world(_tile_origin + Vector2i(2, 2))) * 0.5
	for k in 2:
		var g := ArmorGuard.new()
		g.room = self
		g.center = center
		g.ang = PI * k + PI * 0.5
		g.dir = 1.0 if k == 0 else -1.0
		add_view(g)
		guards.append(g)


func _spot_at(dialogue: String, c: Vector2i, done_flag := "", prompt_y := -22.0) -> Node:
	var sp := PrisonOddities.Spot.new()
	sp.dialogue = dialogue
	sp.done_flag = done_flag
	sp.prompt_y = prompt_y
	add_child(sp)
	sp.global_position = world(c)
	return sp


## palace_events.png 的一帧（0 奶酪夹 / 1 弹起的夹子 / 2 钟面 / 3 喷泉 / 4 徽记台 / 5 石堆）
static func _prop(frame: int, at: Vector2, scale_k := 1.0) -> Node2D:
	var n := Node2D.new()
	n.position = at
	if ResourceLoader.exists(ArmorGuard.PROPS):
		var s := Sprite2D.new()
		s.texture = load(ArmorGuard.PROPS)
		s.hframes = 6
		s.frame = frame
		s.offset = Vector2(0, -18)
		s.scale = Vector2.ONE * scale_k
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		n.add_child(s)
	return n


## 宝库的台阶：打开之前看不见、按不了（Spot 的 Interactable 在 _ready 里才建，所以晚一帧设）
func _set_vault_enabled(on: bool) -> void:
	if not is_instance_valid(_vault_spot):
		return
	_vault_spot.visible = on
	await get_tree().process_frame
	for c in _vault_spot.get_children():
		if c is Interactable:
			(c as Interactable).enabled = on


func vault_open() -> bool:
	return GameState.has_flag(VAULT_FLAG)


func tiles_armed() -> bool:
	return PalaceRoom.sheets() >= 3 and not vault_open()


func _process(delta: float) -> void:
	if busy() or not has_marks():
		return
	_tick_partner(delta)
	for m in members():
		var pc := m as PlayableCharacter
		if pc != GameState.player:
			continue   # 地砖只认玩家操控的那个人（闲逛的搭档路过不算）
		var c := Vector2i(floori(pc.global_position.x / 16.0), floori(pc.global_position.y / 16.0))
		var key := pc.get_instance_id()
		if _last_cell.get(key, Vector2i(-99, -99)) != c:
			_last_cell[key] = c
			var rel := c - _tile_origin
			if rel.x >= 0 and rel.x < 3 and rel.y >= 0 and rel.y < 3:
				step_tile(rel.y * 3 + rel.x, pc)
	for g in guards:
		(g as ArmorGuard).tick(delta)
	_tick_ball(delta)


## 踩到第 i 块地砖（行优先 0..8）
func step_tile(i: int, pc: PlayableCharacter = null) -> void:
	if pc == null:
		pc = pink if is_instance_valid(pink) else blue
	Audio.play("giggle", -12.0, 0.0, 0.8 + 0.08 * i)
	for tv in _tiles:
		if (tv as TileView).idx == i:
			(tv as TileView).flash = 0.4
	if vault_open() and not GameState.has_flag(BALL_TILES):
		_step_lullaby(i)
		return
	if not tiles_armed():
		if randf() < 0.15:
			PalaceRoom.say_random(pc, "tiles_note")
		return
	if i == TILE_SEQ[tile_progress]:
		tile_progress += 1
		if tile_progress >= TILE_SEQ.size():
			_open_vault()
		elif tile_progress % 2 == 0:
			PalaceRoom.say_random(pc, "tiles_right")
		return
	tile_progress = 1 if i == TILE_SEQ[0] else 0
	for k in 3:
		var h := HitData.make_tickle(self, 3.0)
		h.zone = "sole"
		pc.receive_hit(h)
	Audio.play("puff", -6.0)
	PalaceRoom.say_random(pc, "tiles_wrong")


# ------------------------------------------------------------------ 人偶舞会
func _step_lullaby(i: int) -> void:
	if i == LULLABY_SEQ[lull_progress]:
		lull_progress += 1
		if lull_progress >= LULLABY_SEQ.size():
			lull_progress = 0
			GameState.set_flag(BALL_TILES)
			Audio.play("music_box", -4.0)
			try_ball()
		return
	lull_progress = 1 if i == LULLABY_SEQ[0] else 0


## 三处都演奏过：开舞会；还差的给个提示
func try_ball() -> bool:
	if GameState.has_flag(BALL_DONE) or ball_on:
		return false
	var miss := []
	if not GameState.has_flag(BALL_BELL):
		miss.append("训练场的铜钟")
	if not GameState.has_flag(LULLABY):
		miss.append("婴儿房的吊铃")
	if not GameState.has_flag(BALL_TILES):
		miss.append("前厅的地砖")
	if not miss.is_empty():
		GameState.notify("摇篮曲好像还缺几个声部……（%s）" % "、".join(miss))
		return false
	start_ball()
	return true


func start_ball() -> void:
	ball_on = true
	_beat_t = BEAT
	beat_q = -1
	if not is_instance_valid(_beat_view):
		_beat_view = BeatView.new()
		_beat_view.room = self
		_beat_view.position = _ball_center()
		add_view(_beat_view)
	await Cutscene.play("ante_ball_in")
	while Cutscene.is_playing():
		await get_tree().process_frame
	_spawn_dolls(0)


func _ball_center() -> Vector2:
	return (world(_tile_origin) + world(_tile_origin + Vector2i(2, 2))) * 0.5


func _spawn_dolls(w: int) -> void:
	ball_wave = w
	dolls.clear()
	var scene := load(DOLL_SCENE) as PackedScene
	var n := int(BALL_WAVES[w])
	for k in n:
		var d := scene.instantiate() as Node2D
		var a := TAU * k / float(n)
		d.position = _ball_center() + Vector2(cos(a), sin(a)) * 90.0
		add_view(d)
		dolls.append(d)
	GameState.notify("人偶舞会·第 %d 支舞" % (w + 1))


func dolls_alive() -> int:
	return dolls.filter(func(d): return is_instance_valid(d) and (d as Monster).is_alive()).size()


func _tick_ball(delta: float) -> void:
	if not ball_on or ball_wave < 0:
		return
	_beat_t -= delta
	if beat_q < 0 and _beat_t <= BEAT_WARN:
		beat_q = randi() % 4
	if _beat_t <= 0.0:
		beat_sweep()
	if dolls_alive() == 0:
		if ball_wave + 1 < BALL_WAVES.size():
			_spawn_dolls(ball_wave + 1)
		else:
			_ball_won()


## 拍子落下：红色扇区里的人被羽毛扫一下
func beat_sweep() -> void:
	var q := beat_q
	_beat_t = BEAT
	beat_q = -1
	if q < 0:
		return
	Audio.play("swish", -6.0)
	for m in members():
		var pc := m as PlayableCharacter
		if in_quadrant(pc.global_position, q):
			for k in 2:
				var h := HitData.make_tickle(self, 2.5)
				h.zone = ["sole", "waist"].pick_random()
				pc.receive_hit(h)
			PalaceRoom.say_random(pc, "ball_beat")


func in_quadrant(pos: Vector2, q: int) -> bool:
	var d := pos - _ball_center()
	if d.length() > BALL_R:
		return false
	var qq := (1 if d.x >= 0.0 else 0) + (2 if d.y >= 0.0 else 0)
	return qq == q


func _end_ball() -> void:
	ball_on = false
	ball_wave = -1
	beat_q = -1
	for d in dolls:
		if is_instance_valid(d):
			(d as Node).queue_free()
	dolls.clear()


func _ball_won() -> void:
	_end_ball()
	GameState.set_flag(BALL_DONE)
	GameState.give_item(ItemDB.get_item("mint"), 3)
	Audio.play("win_fanfare", -6.0)
	GameState.notify("舞会结束了——人偶们行了个屈膝礼。得到薄荷糖 ×3")


func defeat_theater() -> String:
	return "ante_ball_fail" if ball_on else super()


func on_defeat(reason: String) -> void:
	if ball_on and not _defeat_busy:
		_defeat_busy = true
		_end_ball()
		await CG.play_theater("ante_ball_fail")
		reset_to(world(cells("south")[0]) + Vector2(0, -32))
		_defeat_busy = false
		return
	await super(reason)


func _open_vault() -> void:
	GameState.set_flag(VAULT_FLAG)
	tile_progress = 0
	Audio.play("rumble", -4.0)
	Audio.play("unlock", -2.0)
	GameState.notify("地砖一块一块地沉了下去……露出一道台阶")
	_set_vault_enabled(true)


func vault_loot() -> void:
	if GameState.has_flag(VAULT_LOOT):
		return
	GameState.set_flag(VAULT_LOOT)
	PalaceRoom.give_badge("vault")


# ------------------------------------------------------------------ 骑士石像
func statue_ok() -> void:
	if GameState.has_flag(STATUE_FLAG):
		return
	GameState.set_flag(STATUE_FLAG)
	var it := ItemDB.get_item("queen_music_box")
	if it:
		GameState.give_item(it, 1)
	GameState.notify("得到「女王的八音盒」")
	PalaceRoom.give_badge("statue")


## 答错：石头手抓住答题人的脚踝，挠脚心
func statue_wrong() -> void:
	var pc := GameState.player as PlayableCharacter
	if pc == null:
		return
	pc.status.apply_root(1.5)
	Audio.play("hand_grab", -4.0)
	for k in 4:
		var h := HitData.make_tickle(self, 3.0)
		h.zone = "sole"
		pc.receive_hit(h)
	PalaceRoom.say_random(pc, "statue_wrong")


# ------------------------------------------------------------------ 许愿喷泉
func wish(kind: String) -> bool:
	match kind:
		"mint":
			if not GameState.inventory.has("mint"):
				GameState.notify("没有薄荷糖了……")
				return false
			GameState.inventory.remove("mint", 1)
		"coin":
			if not GameState.inventory.has("coin", FOUNTAIN_COINS):
				GameState.notify("金币不够 %d 枚……" % FOUNTAIN_COINS)
				return false
			GameState.inventory.remove("coin", FOUNTAIN_COINS)
	Audio.play("puddle", -4.0)
	var r := next_wish if next_wish >= 0 else randi() % 3
	next_wish = -1
	var who: PlayableCharacter = GameState.player as PlayableCharacter
	match r:
		0:
			for m in members():
				(m as PlayableCharacter).laugh.reduce_ratio(0.6)
			GameState.notify("喷泉的水花落下来——笑意散掉了一大半")
			PalaceRoom.say_random(who, "fountain_heal")
		1:
			for m in members():
				for k in 3:
					var h := HitData.make_tickle(self, 3.0)
					h.zone = "sole"
					(m as PlayableCharacter).receive_hit(h)
			GameState.notify("喷泉「噗」地喷出一道水柱——正好喷在脚底！")
			PalaceRoom.say_random(who, "fountain_jet")
		_:
			for k in 5:
				var h := HitData.make_tickle(self, 2.0)
				h.zone = "sole"
				who.receive_hit(h)
			GameState.notify("池子里的小鱼游过来，啄起了脚趾")
			PalaceRoom.say_random(who, "fountain_fish")
	return true


# ------------------------------------------------------------------ 徽记台
func place_badges() -> bool:
	if GameState.has_flag(BADGES_FLAG):
		return true
	var n := PalaceRoom.badges()
	if n < PalaceRoom.BADGES_ALL:
		GameState.notify("笑脸徽记：%d / %d。……还差 %d 枚" % [n, PalaceRoom.BADGES_ALL, PalaceRoom.BADGES_ALL - n])
		return false
	GameState.set_flag(BADGES_FLAG)
	GameState.inventory.remove("smile_badge", GameState.inventory.count("smile_badge"))
	var it := ItemDB.get_item("equip_queen_hairpin")
	if it:
		GameState.give_item(it, 1)
	await CG.play_theater("palace_badge_party")
	GameState.notify("得到「女王的羽毛发饰」")
	await PalaceRoom.try_memory()   # 王座间已经打完：接着看女王的回忆
	return true


## 歪挂在墙上的大画（画后面是密道）——各个房间的密道入口都用这个画
class PaintingDoor extends Node2D:
	var tint := Color(0.55, 0.35, 0.45)

	func _draw() -> void:
		var r := Rect2(-9, -30, 18, 22)
		draw_set_transform(Vector2.ZERO, 0.08, Vector2.ONE)
		draw_rect(r.grow(2), Color(0.75, 0.58, 0.25))
		draw_rect(r, tint)
		draw_circle(Vector2(0, -22), 4.0, Color(0.85, 0.75, 0.7))
		draw_rect(Rect2(-5, -18, 10, 9), tint.lightened(0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(-8, -8, 16, 2), Color(0, 0, 0, 0.35))


## 一块笑声地砖：刻着小笑脸；踩上去闪一下；乐谱凑齐后（tiles_armed）一直微微发光
class TileView extends Node2D:
	var room: PalaceAnte
	var idx := 0
	var flash := 0.0

	func _ready() -> void:
		z_index = 0   # 等距地图里 z_index < 0 会被地面盖住

	func _process(delta: float) -> void:
		flash = maxf(0.0, flash - delta)
		queue_redraw()

	func _draw() -> void:
		if room == null or room.vault_open():
			return
		var glow := 0.25 + 0.15 * sin(Time.get_ticks_msec() / 300.0 + idx) if room.tiles_armed() else 0.0
		var c := Color(1.0, 0.85, 0.45, 0.18 + glow + flash)
		var pts := PackedVector2Array([IsoView.offset(Vector2(-7, -7)), IsoView.offset(Vector2(7, -7)), IsoView.offset(Vector2(7, 7)), IsoView.offset(Vector2(-7, 7))])
		draw_colored_polygon(pts, c)
		pts.append(pts[0])
		draw_polyline(pts, Color(0.75, 0.6, 0.3, 0.8), 1.0)
		draw_arc(Vector2(0, 0.5), 2.5, 0.3, PI - 0.3, 8, Color(0.45, 0.3, 0.15), 1.0)


## 徽记台：七个小凹槽，放了几枚就亮几个
class PedestalView extends Node2D:
	func _ready() -> void:
		add_child(PalaceAnte._prop(4, Vector2.ZERO, 0.9))

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var n := PalaceRoom.badges()
		for i in PalaceRoom.BADGES_ALL:
			var a := PI + PI * float(i) / float(PalaceRoom.BADGES_ALL - 1)
			var p := Vector2(cos(a) * 11.0, -34.0 + sin(a) * 5.0)
			draw_circle(p, 2.0, Color(1.0, 0.85, 0.3) if i < n else Color(0.25, 0.22, 0.25))


## 地下小宝库的台阶（打开后才画）
class VaultView extends Node2D:
	func _ready() -> void:
		z_index = 0   # 等距地图里 z_index < 0 会被地面盖住

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if not GameState.has_flag(PalaceAnte.VAULT_FLAG):
			return
		for k in 3:
			var w := 9.0 - k * 2.0
			var pts := PackedVector2Array([IsoView.offset(Vector2(-w, -w + k * 2)), IsoView.offset(Vector2(w, -w + k * 2)),
				IsoView.offset(Vector2(w, w - k * 2)), IsoView.offset(Vector2(-w, w - k * 2))])
			draw_colored_polygon(pts, Color(0.25 - k * 0.07, 0.2 - k * 0.06, 0.18 - k * 0.05))
		draw_circle(Vector2(0, -2), 2.0, Color(1.0, 0.85, 0.4, 0.6 + 0.3 * sin(Time.get_ticks_msec() / 250.0)))


## 空铠甲卫兵：绕着大厅正中巡逻（半径 PalaceAnte.GUARD_R），扇形视野（VIEW_R、VIEW_HALF）里看到人就冲过去（CHARGE_SPEED，最多 CHARGE_MAX 秒），
## 碰到就举起来挠腋下（status.grab：连按挣扎 GRAB_PRESSES 下或 GRAB_TIME 秒）；歇 COOL 秒再巡逻。从背后按 E → 散架 DOWN_TIME 秒。
class ArmorGuard extends Node2D:
	const SHEET := "res://assets/generated/npcs/armor_guard.png"
	const PROPS := "res://assets/generated/palace_events.png"
	const PATROL_W := 0.32
	const VIEW_R := 72.0
	const VIEW_HALF := 0.5
	const CHARGE_SPEED := 72.0
	const CHARGE_MAX := 2.5
	const RETURN_SPEED := 46.0
	const GRAB_R := 12.0
	const GRAB_TIME := 2.0
	const GRAB_PRESSES := 6
	const TICK := 0.3
	const COOL := 4.0
	const DOWN_TIME := 20.0
	var room: PalaceAnte
	var center := Vector2.ZERO
	var ang := 0.0
	var dir := 1.0
	var state := "patrol"   # patrol / charge / hold / return / down
	var facing := Vector2.DOWN
	var target: PlayableCharacter
	var _t := 0.0
	var _cool := 0.0
	var _tick := 0.0
	var _anim := 0.0
	var _spr: Sprite2D
	var _area: Interactable

	func _ready() -> void:
		z_index = 1
		position = path_point()
		if ResourceLoader.exists(SHEET):
			_spr = Sprite2D.new()
			_spr.texture = load(SHEET)
			_spr.hframes = 4
			_spr.vframes = 4
			_spr.offset = Vector2(0, -14)
			_spr.scale = Vector2(1.15, 1.15)
			_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_spr)
		_area = Interactable.new()
		_area.prompt_offset = Vector2(0, -40)
		var shape := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 12.0
		shape.shape = c
		_area.add_child(shape)
		add_child(_area)

	func path_point() -> Vector2:
		return center + Vector2(cos(ang), sin(ang)) * PalaceAnte.GUARD_R

	func sees(pc: PlayableCharacter) -> bool:
		if Downed.is_downed(pc) or pc.status.is_grabbed():
			return false
		var to := pc.global_position - position
		return to.length() <= VIEW_R and to.length() > 0.1 and facing.dot(to.normalized()) >= cos(VIEW_HALF)

	func tick(delta: float) -> void:
		_t += delta
		_cool = maxf(0.0, _cool - delta)
		_area.enabled = state != "down" and state != "hold"
		match state:
			"patrol":
				ang += dir * PATROL_W * delta
				_walk_to(path_point(), 999.0, delta)
				facing = Vector2(-sin(ang), cos(ang)) * dir
				if _cool <= 0.0:
					for m in room.members():
						if sees(m as PlayableCharacter):
							_charge(m as PlayableCharacter)
							break
			"charge":
				if not is_instance_valid(target) or _t > CHARGE_MAX:
					_back()
				else:
					_walk_to(target.global_position, CHARGE_SPEED, delta)
					if position.distance_to(target.global_position) <= GRAB_R:
						grab(target)
			"hold":
				if not is_instance_valid(target) or not target.status.is_grabbed_by(self):
					_back()
				else:
					_tick -= delta
					if _tick <= 0.0:
						_tick = TICK
						var h := HitData.make_tickle(self, 2.5)
						h.zone = "armpit"
						target.receive_hit(h)
			"return":
				_walk_to(path_point(), RETURN_SPEED, delta)
				if position.distance_to(path_point()) < 2.0:
					state = "patrol"
			"down":
				if _t >= DOWN_TIME:
					state = "return"
					_t = 0.0
		queue_redraw()

	func _walk_to(p: Vector2, speed: float, delta: float) -> void:
		var d := p - position
		var step := position.move_toward(p, speed * delta) if speed < 900.0 else p
		position = step
		if d.length() > 0.5:
			facing = d.normalized()
			_anim += delta * 6.0
		if _spr:
			var sd := IsoView.screen_dir(facing)
			var row := 0
			if absf(sd.x) > absf(sd.y):
				row = 1 if sd.x < 0 else 2
			else:
				row = 0 if sd.y > 0 else 3
			_spr.frame = row * 4 + int(_anim) % 4

	func _charge(pc: PlayableCharacter) -> void:
		state = "charge"
		target = pc
		_t = 0.0
		Audio.play("gate", -8.0, 0.1, 1.4)
		SpeechBubble.say(self, "……（铠甲的眼睛亮了）", 34.0, 1.2)
		PalaceRoom.say_random(pc, "armor_spot")

	func grab(pc: PlayableCharacter) -> void:
		if not pc.status.grab(self, GRAB_TIME, GRAB_PRESSES):
			_back()
			return
		state = "hold"
		target = pc
		_tick = 0.1
		Audio.play("grab", -4.0)
		PalaceRoom.say_random(pc, "armor_grab")

	func _back() -> void:
		state = "return"
		target = null
		_cool = COOL
		_t = 0.0

	## 从背后推（按 E）：散架；正面按 E 等于自投罗网
	func on_interact(player: Node) -> void:
		var pc := player as PlayableCharacter
		if pc == null or state == "down":
			return
		if (pc.global_position - position).dot(facing) < -0.2 * (pc.global_position - position).length():
			push_down()
			PalaceRoom.say_random(pc, "armor_push")
		else:
			grab(pc)

	func push_down() -> void:
		state = "down"
		_t = 0.0
		target = null
		Audio.play("break", -3.0)

	func _draw() -> void:
		if state == "down":
			for o in [Vector2(-8, -3), Vector2(6, -2), Vector2(-1, -6), Vector2(3, 2)]:
				draw_circle(o, 3.5, Color(0.72, 0.74, 0.8))
			draw_circle(Vector2(-1, -10), 4.5, Color(0.8, 0.82, 0.88))
			draw_circle(Vector2(2, -15), 2.0, Color(0.6, 0.4, 0.75))
			if _spr:
				_spr.visible = false
			return
		if _spr:
			_spr.visible = true
		if state == "patrol":
			var pts := PackedVector2Array([Vector2.ZERO])
			for k in 9:
				var a := facing.angle() - VIEW_HALF + VIEW_HALF * 2.0 * k / 8.0
				pts.append(IsoView.offset(Vector2(cos(a), sin(a)) * VIEW_R))
			draw_colored_polygon(pts, Color(0.55, 0.75, 1.0, 0.12))
		if _spr == null:
			draw_rect(Rect2(-6, -28, 12, 20), Color(0.75, 0.77, 0.82))
			draw_circle(Vector2(0, -32), 6.0, Color(0.8, 0.82, 0.88))


## 舞会的拍子：要落下的那一块扇区先亮红（BEAT_WARN 秒）
class BeatView extends Node2D:
	var room: PalaceAnte

	func _ready() -> void:
		z_index = 0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if room == null or not room.ball_on:
			return
		var q := room.beat_q
		for k in 4:
			var a0: float = [PI, PI * 1.5, PI * 0.5, 0.0][k]
			var col := Color(1.0, 0.3, 0.4, 0.28) if k == q else Color(1.0, 0.85, 0.5, 0.05)
			var pts := PackedVector2Array([Vector2.ZERO])
			for i in 9:
				var a: float = a0 + PI * 0.5 * i / 8.0
				pts.append(IsoView.offset(Vector2(cos(a), sin(a)) * PalaceAnte.BALL_R))
			draw_colored_polygon(pts, col)


# ------------------------------------------------------------------ 搭档闲逛 + 提示
func ai_hooks() -> BattleAIHooks:
	return AnteHooks.new(self)


func _tick_partner(delta: float) -> void:
	for m in members():
		var pc := m as PlayableCharacter
		if not _roamers.has(pc):
			_roamers.append(pc)
			_old_talk[pc] = pc.partner_talk
			pc.partner_talk = HINT_FILE
			pc.roam = true
		pc.refresh_partner_area()
	_hint_t -= delta
	if _hint_t <= 0.0:
		_hint_t = HINT_EVERY
		GameState.vars["ante_hint"] = str(hint_keys().pick_random())
	for k in _wander.keys():
		var w: Dictionary = _wander[k]
		var ai := instance_from_id(int(k)) as PlayableCharacter
		if ai == null or ai == GameState.player:
			continue
		if ai.global_position.distance_to(w["to"]) <= 12.0:
			if not w.get("arrived", false):
				w["arrived"] = true
				SpeechBubble.say(ai, ["？", "……？", "这是什么……", "……嗯。"].pick_random(), 30.0, 1.2)
			w["stay"] = float(w["stay"]) - delta


func _exit_tree() -> void:
	for pc in _roamers:
		if is_instance_valid(pc):
			(pc as PlayableCharacter).roam = false
			(pc as PlayableCharacter).partner_talk = str(_old_talk.get(pc, ""))
			(pc as PlayableCharacter).refresh_partner_area()
	super()


## 当前进度下用得上的提示（ANTE_HINTS 的 key；什么都做完了 = idle）
func hint_keys() -> Array:
	var ks: Array = []
	if not GameState.has_flag(PalaceClock.BELLS_FLAG):
		ks.append("bells")
	if PalaceRoom.sheets() < 3:
		ks.append("sheets")
	elif not vault_open():
		ks.append("tiles")
	if not GameState.has_flag(STATUE_FLAG):
		ks.append("statue")
	if not GameState.has_flag(BADGES_FLAG) and PalaceRoom.badges() < 7:
		ks.append("badges")
	if not GameState.has_flag(PalaceTunnels.LOST_DONE) and GameState.has_flag(PalaceTunnels.SEEN_FLAG):
		ks.append("toll")
	if GameState.inventory.has("maid_key") and not GameState.has_flag(PalaceRoom.FRIEND_FLAG):
		ks.append("maid")
	if vault_open() and not GameState.has_flag(BALL_DONE):
		ks.append("ball")
	if GameState.inventory.has("queen_music_box") and not GameState.has_flag(PalaceThrone.BOSS_FLAG):
		ks.append("box")
	if GameState.has_flag(PalaceGarden.GARDEN_CLUE) and not GameState.has_flag(LevelExit.passage_flag(MAP, PalaceGarden.MAP)):
		ks.append("garden")
	if ks.is_empty():
		ks.append("idle")
	return ks


## 闲逛的下一个点：到了、待够了才换；挑的点要让「现在的位置 → 那个点」这条线离地砖中心够远（不穿过地砖）
func wander_target(ai: PlayableCharacter) -> Vector2:
	var k := ai.get_instance_id()
	var w: Dictionary = _wander.get(k, {})
	if not w.is_empty() and float(w["stay"]) > 0.0:
		return w["to"]
	var mid := world(_tile_origin + Vector2i(1, 1))
	var pick: Array = []
	for c in WANDER:
		var to := world(c)
		if to.distance_to(ai.global_position) < 40.0:
			continue
		if Geometry2D.get_closest_point_to_segment(mid, ai.global_position, to).distance_to(mid) >= TILE_CLEAR:
			pick.append(to)
	if pick.is_empty():
		pick = WANDER.map(func(c): return world(c))
	w = {"to": pick.pick_random(), "stay": randf_range(WANDER_STAY.x, WANDER_STAY.y), "arrived": false}
	_wander[k] = w
	return w["to"]


class AnteHooks extends BattleAIHooks:
	var r: PalaceAnte

	func _init(room: PalaceAnte) -> void:
		r = room

	## 舞会打起来 / 被卫兵盯上的时候不闲逛（交给攻击 / 躲避）；其它时候自己在大厅里逛
	func objective_for(ai: PlayableCharacter) -> Variant:
		if r.ball_on:
			return null
		for g in r.guards:
			if (g as ArmorGuard).state in ["charge", "hold"]:
				return null
		return r.wander_target(ai)
