class_name PalaceBath
extends PalaceRoom
## 第四章①·旧浴场（floor_06_palace_bath，等距；布局 quest_maps._palace_bath；台词 penance_text/palace.py）：
##   蒸汽迷宫（steam 格）：站在蒸汽里画面四周一圈白雾（SteamFog），远处的笑声（laughs，按顺序）每隔一会儿响一次、冒一句「嘻嘻……」，跟着走就对了；
##   肥皂泡地板（soap 格）：踩上去顺着进来的方向一路滑（SLIDE_SPEED，自己控制不了），撞墙停下；往西滑出去掉进泡泡浴池（bubble_pool）→ 小剧场 bath_pool；
##   湿毛巾怪（towels）：追离得近的人，碰到就缠住腿（定身 + 挠），被攻击就散掉、过一会儿再冒出来；
##   雕像刷池（statues）：每尊雕像按自己的节奏「站着 → 发光预警 → 弯腰刷」，弯腰时脚边的人被刷脚底；key_statue 那一尊被攻击就碎、掉出钥匙（KEY_FLAG）；
##   东边的门（出口 east 要钥匙）；起雾的镜子（mirror，线索）；温泉（bath）：走过去就演两个人一起泡温泉的小剧场 bath_friendship（CG）。
##   水池（bubble_pool / pool 格）过不去：放看不见的墙，水面由 PoolCell 画。
## 测试：on_soap / slide_dir、towels、statues、key_broken、break_key_statue()、fog_on。

const MAP := "floor_06_palace_bath"
const KEY_FLAG := "palace_bath_key"
const SLIDE_SPEED := 120.0
const SLIDE_OVERRUN := 2.0
const LAUGH_EVERY := 2.6
const LAUGH_REACH := 24.0
const TOWEL_SPEED := 32.0
const TOWEL_CHASE := 80.0
const TOWEL_RESPAWN := 10.0
const STATUE_IDLE := 2.2
const STATUE_WARN := 0.5
const STATUE_BEND := 0.7
const STATUE_R := 16.0

var slide_dir := {}
var _overrun := {}
var towels: Array = []
var statues: Array = []
var key_broken := false
var fog_on := false
var _laugh_i := 0
var _laugh_t := 1.0
var _laugh_marks: Array = []
var _water := {}
var _fog: SteamFog


func map_id() -> String:
	return MAP


func _ready() -> void:
	super()
	key_broken = GameState.has_flag(KEY_FLAG)
	for kind in ["bubble_pool", "pool"]:
		for c in cells(kind):
			_water[c] = kind
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var sh := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			r.size = Vector2(16, 16)
			sh.shape = r
			body.add_child(sh)
			add_child(body)
			body.global_position = PalaceRoom.cell_pos(c)
			var pcell := PoolCell.new()
			pcell.kind = kind
			pcell.cell = c
			pcell.position = PalaceRoom.cell_pos(c)
			add_view(pcell)
	for c in cells("laughs"):
		var m := Node2D.new()
		m.position = world(c)
		add_view(m)
		_laugh_marks.append(m)
	for c in cells("towels"):
		var t := Towel.new()
		t.room = self
		t.home = world(c)
		t.position = t.home
		add_view(t)
		towels.append(t)
	var i := 0
	for c in cells("statues") + cells("key_statue"):
		var s := Statue.new()
		s.room = self
		s.key = c in cells("key_statue")
		s.broken = s.key and key_broken
		s.t = -float(i) * 0.6
		s.position = world(c)
		add_view(s)
		statues.append(s)
		i += 1
	var sp := PrisonOddities.Spot.new()
	sp.dialogue = "floor_06/palace_mirror"
	add_child(sp)
	sp.global_position = world(cells("mirror")[0])
	_fog = SteamFog.new()
	add_child(_fog)


func _process(delta: float) -> void:
	if busy():
		_fog.target = 0.0
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	# 蒸汽 + 笑声
	var in_steam := GridPath.cell(p.global_position) in cells("steam")
	if in_steam and not fog_on:
		PalaceRoom.say_random(p, "steam")
	fog_on = in_steam
	_fog.target = 0.85 if in_steam else 0.0
	_tick_laughs(delta, p)
	for c in members():
		var pc := c as PlayableCharacter
		if Downed.is_downed(pc):
			continue
		_tick_soap(pc, delta)
	for t in towels:
		(t as Towel).step(delta)
	for s in statues:
		(s as Statue).step(delta)
	auto_theater("bath", "bath_friendship", 20.0)


func _tick_laughs(delta: float, p: Node2D) -> void:
	if _laugh_i >= _laugh_marks.size():
		return
	var m := _laugh_marks[_laugh_i] as Node2D
	if p.global_position.distance_to(m.position) <= LAUGH_REACH:
		_laugh_i += 1
		return
	if not fog_on:
		return
	_laugh_t -= delta
	if _laugh_t <= 0.0:
		_laugh_t = LAUGH_EVERY
		Audio.play("giggle", -12.0, 0.1, 1.4)
		PalaceRoom.say_random(m, "laugh")


# ------------------------------------------------------------------ 肥皂泡地板
func on_soap(pc: Node2D) -> bool:
	return GridPath.cell(pc.global_position) in cells("soap")


func _tick_soap(pc: PlayableCharacter, delta: float) -> void:
	var on := on_soap(pc)
	var d: Vector2 = slide_dir.get(pc, Vector2.ZERO)
	if not on:
		# 滑出肥皂泡地板以后还会冲出去一小段（SLIDE_OVERRUN 格）：西边紧挨着泡泡浴池
		if d == Vector2.ZERO:
			return
		_overrun[pc] = float(_overrun.get(pc, 0.0)) + SLIDE_SPEED * delta
		if float(_overrun[pc]) > SLIDE_OVERRUN * 16.0:
			_stop_slide(pc)
			return
	else:
		_overrun.erase(pc)
	if d == Vector2.ZERO:
		var v: Vector2 = pc.velocity if pc.velocity.length() > 5.0 else (pc.get("facing") if pc.get("facing") is Vector2 else Vector2.DOWN)
		d = Vector2(signf(v.x), 0) if absf(v.x) >= absf(v.y) else Vector2(0, signf(v.y))
		if d == Vector2.ZERO:
			d = Vector2.DOWN
		slide_dir[pc] = d
		if pc == GameState.player:
			PalaceRoom.say_random(pc, "slide")
	pc.status.apply_root(0.12)
	var nxt := pc.global_position + d * SLIDE_SPEED * delta
	var nc := GridPath.cell(nxt + d * 6.0)
	if str(_water.get(nc, "")) == "bubble_pool":
		_stop_slide(pc)
		fall_in_pool(pc)
		return
	if _water.has(nc) or not GridPath.walkable(lv, nc):
		_stop_slide(pc)
		return
	pc.global_position = nxt


func _stop_slide(pc: PlayableCharacter) -> void:
	slide_dir.erase(pc)
	_overrun.erase(pc)
	pc.status.clear_root()


func fall_in_pool(pc: PlayableCharacter) -> void:
	await CG.play_theater("bath_pool")
	# 爬出来：回到肥皂泡地板东边的干地上
	var edge := cells("soap")[0]
	for c in cells("soap"):
		if c.x > edge.x:
			edge = c
	for m in members():
		(m as Node2D).global_position = world(edge + Vector2i(2, 0)) + (Vector2(10, 0) if (m as PlayableCharacter).character_id == "blue" else Vector2.ZERO)


# ------------------------------------------------------------------ 雕像钥匙
func break_key_statue() -> void:
	if key_broken:
		return
	key_broken = true
	GameState.set_flag(KEY_FLAG)
	for s in statues:
		if (s as Statue).key:
			(s as Statue).broken = true
			Fx.burst(get_parent(), (s as Node2D).position + Vector2(0, -12), "dust", 16, 50.0, 0.6, Vector2(0, -20), Color(0.9, 0.88, 0.85))
	Audio.play("break", -2.0)
	PalaceRoom.say_random(GameState.player, "key")


func ai_hooks() -> BattleAIHooks:
	return BathHooks.new(self)


class BathHooks extends BattleAIHooks:
	var r: PalaceBath

	func _init(room: PalaceBath) -> void:
		r = room

	func priority_target() -> Variant:
		var p := GameState.player
		var best: Node2D = null
		for t in r.towels:
			if is_instance_valid(t) and (t as Towel).alive() and is_instance_valid(p) and (t as Node2D).position.distance_to(p.global_position) < 80.0:
				best = t
		return best


## 浴池 / 温泉的水面（屏幕空间菱形）
class PoolCell extends Node2D:
	var kind := ""
	var cell: Vector2i
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array([IsoView.offset(Vector2(-8, -8)), IsoView.offset(Vector2(8, -8)), IsoView.offset(Vector2(8, 8)), IsoView.offset(Vector2(-8, 8))])
		var col := Color(0.85, 0.9, 1.0, 0.75) if kind == "bubble_pool" else Color(0.45, 0.75, 0.85, 0.8)
		draw_colored_polygon(pts, col)
		if kind == "bubble_pool":
			for k in 2:
				var o := IsoView.offset(Vector2(sin(_t * 2.0 + cell.x + k * 3.0) * 4.0, cos(_t * 1.7 + cell.y + k) * 4.0))
				draw_arc(o, 2.5, 0, TAU, 10, Color(1, 1, 1, 0.9), 1.0)
		else:
			var wv := IsoView.offset(Vector2(sin(_t * 1.2 + cell.y) * 4.0, 0))
			draw_line(wv + Vector2(-5, 0), wv + Vector2(5, 0), Color(1, 1, 1, 0.5), 1.0)


## 湿毛巾怪：追离得近的人，碰到就缠住腿；被攻击就散掉
class Towel extends Node2D:
	var room: PalaceBath
	var home := Vector2.ZERO
	var down := 0.0
	var _cool := 0.0
	var _t := 0.0

	func alive() -> bool:
		return down <= 0.0

	func step(delta: float) -> void:
		_t += delta
		_cool = maxf(0.0, _cool - delta)
		if down > 0.0:
			down -= delta
			if down <= 0.0:
				position = home
				show()
			return
		var near: PlayableCharacter = null
		for c in room.members():
			var pc := c as PlayableCharacter
			if Downed.is_downed(pc):
				continue
			if pc.state == PlayableCharacter.State.ATTACK and pc.global_position.distance_to(position) <= 18.0:
				poof()
				return
			if pc.global_position.distance_to(position) <= PalaceBath.TOWEL_CHASE and (near == null or pc.global_position.distance_to(position) < near.global_position.distance_to(position)):
				near = pc
		if near:
			var to := near.global_position - position
			position += to.normalized() * PalaceBath.TOWEL_SPEED * delta
			if to.length() <= 10.0 and _cool <= 0.0:
				_cool = 3.0
				near.status.apply_root(1.2)
				var h := HitData.make_tickle(self, 6.0)
				h.zone = "thigh"
				near.receive_hit(h)
				PalaceRoom.say_random(near, "towel")
		else:
			position = position.move_toward(home, PalaceBath.TOWEL_SPEED * 0.5 * delta)
		queue_redraw()

	func poof() -> void:
		down = PalaceBath.TOWEL_RESPAWN
		hide()
		Fx.burst(get_parent(), position + Vector2(0, -8), "dust", 10, 30.0, 0.5, Vector2(0, -10), Color(0.95, 0.95, 1.0))
		Audio.play("cloth", -6.0)

	func _draw() -> void:
		var w := sin(_t * 4.0) * 2.0
		var pts := PackedVector2Array([Vector2(-6, -20 + w), Vector2(6, -20 - w), Vector2(7, -4), Vector2(-7, -4)])
		draw_colored_polygon(pts, Color(0.95, 0.95, 0.98))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.6, 0.65, 0.75), 1.0)
		for k in 3:
			draw_line(Vector2(-6 + k * 6, -4), Vector2(-6 + k * 6 + sin(_t * 5.0 + k) * 2.0, 0), Color(0.85, 0.9, 1.0), 1.5)
		draw_circle(Vector2(-2, -14 + w * 0.5), 1.0, Color(0.2, 0.2, 0.3))
		draw_circle(Vector2(2, -14 + w * 0.5), 1.0, Color(0.2, 0.2, 0.3))


## 池边的雕像：站着 → 发光预警 → 弯腰刷脚底；钥匙雕像被攻击就碎
class Statue extends Node2D:
	var room: PalaceBath
	var key := false
	var broken := false
	var t := 0.0
	var phase := "idle"
	var _spr: Sprite2D
	const TEX := "res://assets/generated/palace_statue.png"

	func _ready() -> void:
		# 新素材（tools/art/gen_palace_sprites.py）：3 帧——站着 / 发光预警 / 弯腰刷；没有贴图时用下面 _draw 的简笔
		if ResourceLoader.exists(TEX):
			_spr = Sprite2D.new()
			_spr.texture = load(TEX)
			_spr.hframes = 3
			_spr.offset = Vector2(0, -22)
			_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_spr)

	func step(delta: float) -> void:
		queue_redraw()
		if broken:
			return
		if key:
			for c in room.members():
				var pc := c as PlayableCharacter
				if pc.state == PlayableCharacter.State.ATTACK and pc.global_position.distance_to(position) <= 20.0:
					room.break_key_statue()
					return
		t += delta
		var cyc := PalaceBath.STATUE_IDLE + PalaceBath.STATUE_WARN + PalaceBath.STATUE_BEND
		var k := fposmod(t, cyc)
		phase = "idle" if k < PalaceBath.STATUE_IDLE else ("warn" if k < PalaceBath.STATUE_IDLE + PalaceBath.STATUE_WARN else "bend")
		if phase == "bend":
			for c in room.members():
				var pc := c as PlayableCharacter
				if not Downed.is_downed(pc) and pc.global_position.distance_to(position) <= PalaceBath.STATUE_R:
					room.tickle(pc, "statue", 0.35, 3.0, "sole", delta, self)

	func _draw() -> void:
		if _spr:
			_spr.visible = not broken
			_spr.frame = {"idle": 0, "warn": 1, "bend": 2}.get(phase, 0)
			_spr.modulate = Color(1.0, 0.95, 0.7) if key and not broken else Color.WHITE
		if broken:
			for k in 4:
				draw_circle(Vector2(-6 + k * 4, -2), 2.5, Color(0.8, 0.78, 0.75))
			if key:
				draw_circle(Vector2(0, -6), 2.0, Color(1, 0.85, 0.3))
			return
		if _spr:
			return
		var bend := 6.0 if phase == "bend" else 0.0
		var c := Color(0.88, 0.86, 0.82) if phase != "warn" else Color(1.0, 0.95, 0.75)
		draw_rect(Rect2(-5, -6, 10, 6), Color(0.7, 0.68, 0.65))
		draw_rect(Rect2(-4, -24 + bend, 8, 18 - bend), c)
		draw_circle(Vector2(0, -28 + bend * 1.5), 4.0, c)
		draw_line(Vector2(3, -18 + bend), Vector2(8, -10 + bend * 1.6), c, 2.0)
		draw_line(Vector2(8, -10 + bend * 1.6), Vector2(8, -6 + bend * 1.6), Color(0.95, 0.85, 0.6), 2.0)
		if key:
			draw_circle(Vector2(0, -16 + bend), 1.5, Color(1, 0.85, 0.3, 0.8))


## 蒸汽：画面四周的一圈白雾（站在蒸汽格里时慢慢浮出来）
class SteamFog extends CanvasLayer:
	var target := 0.0
	var _rect: TextureRect

	func _ready() -> void:
		layer = 3
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.0))
		g.set_color(1, Color(0.92, 0.94, 0.97, 1.0))
		g.add_point(0.35, Color(1, 1, 1, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 256
		tex.height = 256
		_rect = TextureRect.new()
		_rect.texture = tex
		_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_rect.modulate.a = 0.0
		add_child(_rect)

	func _process(delta: float) -> void:
		_rect.modulate.a = move_toward(_rect.modulate.a, target, delta * 1.5)
