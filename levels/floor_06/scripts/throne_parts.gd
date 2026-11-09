class_name ThroneParts
extends RefCounted
## 王座间 Boss 第五轮加的零件（PalaceThrone 生成、每帧 step / 自己 _process）：
##   技能：Vortex（画框吸引的旋涡，预警 + 吸）、PaintWave（颜料浪潮：从南往北推，留缺口；被卷到 = 推到北墙边 + 挠脚心）、
##         PaintClone（临摹分身：抄本体的精灵图，追着本体挠腰，一下就碎）。
##   小怪：FrameSoldier（画框小兵，两下才倒，三只一列往前戳）、BrushSprite（羽毛画笔精，绕着人刷脖子，身后留颜料轨迹）。
##   小画像用的：SlipPaint（蓝框留下的滑颜料）、DiveMark（俯冲的预警圈）。
##   画中世界：PaintWorld（迷宫里的颜料格 + 画像之眼的光带 + 颜料星 + 出口画框 + 画架 + 颜料镜像）。
## 图：throne_fx2.png（0 画像之眼 / 1 光带 / 2 颜料星 / 3 出口画框 / 4 画架 / 5 护盾 / 6 吸引旋涡 / 7 颜料浪）、frame_soldier.png、brush_sprite.png。

const FX2 := "res://assets/generated/throne_fx2.png"


static func fx_sprite(frame: int, scale_k := 0.6) -> Sprite2D:
	var s := Sprite2D.new()
	if ResourceLoader.exists(FX2):
		s.texture = load(FX2)
		s.hframes = 8
		s.frame = frame
	s.scale = Vector2.ONE * scale_k
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


## 等距显示里画一块「逻辑坐标的矩形」（相对节点自己）
static func iso_rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var pts := PackedVector2Array([IsoView.offset(r.position), IsoView.offset(Vector2(r.end.x, r.position.y)),
		IsoView.offset(r.end), IsoView.offset(Vector2(r.position.x, r.end.y))])
	ci.draw_colored_polygon(pts, col)


## 推人：用物理移动（撞墙停下），冲刺中不受影响
static func shove(pc: PlayableCharacter, v: Vector2) -> void:
	if pc == null or pc.is_dashing():
		return
	pc.move_and_collide(v)


# ================================================================ 画框吸引的旋涡（画在画像脚下）
class Vortex extends Node2D:
	var room: PalaceThrone
	var warn := 1.0
	var life := 2.5
	var _t := 0.0
	var _spr: Sprite2D

	func _ready() -> void:
		z_index = 2
		_spr = ThroneParts.fx_sprite(6, 0.3)
		_spr.offset = Vector2(0, -4)
		add_child(_spr)
		Audio.play("wind", -4.0, 0.0, 0.8)

	func active() -> bool:
		return _t >= warn and _t < warn + life

	func _process(d: float) -> void:
		if room == null or room.win:
			queue_free()
			return
		if room.busy():
			return
		_t += d
		position = room.weak_point()
		_spr.rotation -= d * (2.0 if not active() else 7.0)
		_spr.scale = Vector2.ONE * (0.3 + minf(_t / warn, 1.0) * 0.5)
		_spr.modulate.a = 0.6 if not active() else 0.95
		if active() and fmod(_t, 0.2) < d:
			Fx.burst(get_parent(), position + Vector2(randf_range(-60, 60), randf_range(-40, 40)), "dust", 2, 30.0, 0.5, Vector2.ZERO, Color(1, 0.85, 0.6))
		if _t >= warn + life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		# 预警：一圈往里收的箭头纹
		var k := fposmod(_t * 1.5, 1.0)
		for i in 8:
			var a := TAU * i / 8.0 + _t
			var r := 70.0 * (1.0 - k) + 14.0
			var p := IsoView.offset(Vector2.from_angle(a) * r)
			var q := IsoView.offset(Vector2.from_angle(a) * (r - 10.0))
			draw_line(p, q, Color(1, 0.8, 0.4, 0.8 if active() else 0.45), 2.0)


# ================================================================ 颜料浪潮：从南往北推，留 1~2 个缺口
class PaintWave extends Node2D:
	const SPEED := 64.0
	const WARN := 1.2
	const SHEET := "res://assets/generated/paint_wave.png"   # 4 帧：涌起 / 卷浪 + 泡沫 / 浪头碎开 / 落下滴落（第六轮，codex）
	const SEG := 22.0     # 浪头图一段的宽度（逻辑像素）
	var _segs: Array = []
	var room: PalaceThrone
	var y0 := 0.0          # 起点（南）
	var y1 := 0.0          # 终点（北墙边）
	var x0 := 0.0
	var x1 := 0.0
	var gaps: Array = []   # [[x_from, x_to], ...]
	var y := 0.0
	var carried := {}
	var _t := 0.0

	func _ready() -> void:
		z_index = 2
		y = y0
		position = Vector2((x0 + x1) * 0.5, y0)
		# 沿浪线一段一段摆浪头图（缺口不摆）；每段自己是一个投影根，跟着浪走
		if ResourceLoader.exists(SHEET):
			var tex: Texture2D = load(SHEET)
			var x := x0 + SEG * 0.5
			var i := 0
			while x < x1:
				if not in_gap(x):
					var n := Node2D.new()
					n.z_index = 3
					var sp := Sprite2D.new()
					sp.texture = tex
					sp.hframes = 4
					sp.frame = i % 4
					sp.offset = Vector2(0, -14)
					sp.scale = Vector2(0.62, 0.62)
					sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					n.add_child(sp)
					n.position = Vector2(x, y0)
					n.modulate.a = 0.0
					room.add_view(n)
					_segs.append(n)
				x += SEG
				i += 1

	func in_gap(x: float) -> bool:
		for g in gaps:
			if x >= float(g[0]) and x <= float(g[1]):
				return true
		return false

	func _process(d: float) -> void:
		if room == null or room.win:
			_end()
			return
		if room.busy():
			return
		_t += d
		queue_redraw()
		# 浪头图：预警时淡淡地冒出来，涨起来以后播帧、跟着浪往北走
		var k := 0
		for n in _segs:
			if is_instance_valid(n):
				(n as Node2D).modulate.a = 0.35 if _t < WARN else 1.0
				(n as Node2D).position.y = y
				var sp := (n as Node2D).get_child(0) as Sprite2D
				sp.frame = (int(_t * 9.0) + k) % 4
				sp.position.y = sin(_t * 8.0 + k) * 1.5
			k += 1
		if _t >= WARN and fmod(_t, 0.15) < d:
			# 浪前一排泡沫 / 颜料滴
			var fx := randf_range(x0, x1)
			if not in_gap(fx):
				Fx.burst(room.get_parent(), Vector2(fx, y - 4.0), "drop", 3, 26.0, 0.5, Vector2(0, -20), Color(1.0, 0.75, 0.9))
		if _t < WARN:
			return
		y = maxf(y1, y - SPEED * d)
		position.y = y
		for m in room.members():
			var pc := m as PlayableCharacter
			if pc == room.inside or Downed.is_downed(pc):
				continue
			var px := pc.global_position.x
			if not carried.has(pc) and absf(pc.global_position.y - y) <= 10.0 and not in_gap(px) and not pc.is_dashing():
				carried[pc] = true
				PalaceRoom.say_random(pc, "paintwave")
				ThroneFx.splash(room.get_parent(), pc.global_position, false, 0.7)
			if carried.has(pc):
				ThroneParts.shove(pc, Vector2(0, (y - 6.0) - pc.global_position.y))
		if y <= y1:
			_end()

	func _end() -> void:
		for n in _segs:
			if is_instance_valid(n):
				(n as Node).queue_free()
		_segs.clear()
		if room:
			for pc in carried:
				if is_instance_valid(pc):
					room.painted[pc] = PalaceThrone.PAINTED
					for k in 3:
						var h := HitData.make_tickle(room, 3.0)
						h.zone = "sole"
						(pc as PlayableCharacter).receive_hit(h)
		queue_free()

	func _draw() -> void:
		var col := Color(0.92, 0.45, 0.75, 0.75 if _t >= WARN else 0.25)
		var top := Color(1, 0.8, 0.95, 0.9 if _t >= WARN else 0.3)
		var xs: Array = [x0]
		for g in gaps:
			xs.append(float(g[0]))
			xs.append(float(g[1]))
		xs.append(x1)
		for i in range(0, xs.size(), 2):
			var a: float = xs[i] - position.x
			var b: float = xs[i + 1] - position.x
			if b <= a:
				continue
			ThroneParts.iso_rect(self, Rect2(a, -8, b - a, 14), col)
			ThroneParts.iso_rect(self, Rect2(a, -10, b - a, 3), top)
			# 浪头的小泡泡
			for k in int((b - a) / 14.0):
				var p := IsoView.offset(Vector2(a + 7 + k * 14, -10)) + Vector2(0, -3 - absf(sin(_t * 6.0 + k)) * 4.0)
				draw_circle(p, 2.5, Color(1, 0.85, 0.95, 0.9))


# ================================================================ 临摹分身：抄本体的样子，追着本体挠腰
class PaintClone extends Node2D:
	const SPEED := 36.0
	var room: PalaceThrone
	var owner_pc: PlayableCharacter
	var _cool := 1.0
	var _spr: Sprite2D
	var _t := 0.0

	func _ready() -> void:
		z_index = 1
		_spr = Sprite2D.new()
		_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_spr.modulate = Color(1.0, 0.55, 0.85, 0.75)
		add_child(_spr)
		ThroneFx.splash(get_parent(), position, false, 0.8)

	func hurt() -> void:
		Audio.play("bubble_pop", -4.0)
		ThroneFx.splash(get_parent(), position, true, 0.9)
		queue_free()

	func step(d: float) -> void:
		_t += d
		if not is_instance_valid(owner_pc):
			queue_free()
			return
		_cool = maxf(0.0, _cool - d)
		var src: Sprite2D = owner_pc.sprite
		if src and _spr:
			_spr.texture = src.texture
			_spr.hframes = src.hframes
			_spr.vframes = src.vframes
			_spr.frame = src.frame
			_spr.flip_h = src.flip_h
			_spr.offset = src.offset
			_spr.scale = src.scale
			_spr.position = src.position
		var to := owner_pc.global_position - position
		if to.length() > 8.0:
			position += to.normalized() * SPEED * d
		elif _cool <= 0.0:
			_cool = 1.0
			var h := HitData.make_tickle(self, 3.0)
			h.zone = "waist"
			owner_pc.receive_hit(h)
			PalaceRoom.say_random(owner_pc, "clone")
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, 8.0, Color(0.9, 0.4, 0.7, 0.4 + sin(_t * 5.0) * 0.1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ================================================================ 画框小兵：纸片小兵，三只一列往前戳；两下才倒
class FrameSoldier extends Node2D:
	const SHEET := "res://assets/generated/frame_soldier.png"
	const SPEED := 26.0
	var room: PalaceThrone
	var hp := 2
	var delay := 0.0
	var _cool := 0.6
	var _poke := 0.0
	var _t := 0.0
	var _spr: Sprite2D

	func _ready() -> void:
		z_index = 1
		if ResourceLoader.exists(SHEET):
			_spr = Sprite2D.new()
			_spr.texture = load(SHEET)
			_spr.hframes = 4
			_spr.offset = Vector2(0, -14)
			_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_spr)
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.4)

	func hurt() -> void:
		hp -= 1
		Audio.play("paper", -4.0, 0.0, 1.3)
		modulate = Color(1.8, 1.8, 1.8)
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
		if hp <= 0:
			ThroneFx.shards(get_parent(), position, 4)
			queue_free()

	func step(d: float) -> void:
		_t += d
		if delay > 0.0:
			delay -= d
			return
		_cool = maxf(0.0, _cool - d)
		_poke = maxf(0.0, _poke - d)
		var near := room._nearest_member(position)
		if near == null:
			return
		var to := near.global_position - position
		if to.length() > 16.0:
			position += to.normalized() * SPEED * d
		elif _cool <= 0.0:
			_cool = 1.2
			_poke = 0.3
			var h := HitData.make_tickle(self, 3.0)
			h.zone = "waist"
			near.receive_hit(h)
			PalaceRoom.say_random(near, "soldier")
		if _spr:
			_spr.frame = 3 if _poke > 0.0 else int(_t * 6.0) % 3
			_spr.flip_h = to.x < 0.0


# ================================================================ 羽毛画笔精：绕着人转圈刷脖子，身后留颜料轨迹
class BrushSprite extends Node2D:
	const SHEET := "res://assets/generated/brush_sprite.png"
	var room: PalaceThrone
	var target: PlayableCharacter
	var _ang := 0.0
	var _trail := 0.4
	var _cool := 1.0
	var _t := 0.0
	var _spr: Sprite2D

	func _ready() -> void:
		z_index = 2
		_ang = randf() * TAU
		if ResourceLoader.exists(SHEET):
			_spr = Sprite2D.new()
			_spr.texture = load(SHEET)
			_spr.hframes = 4
			_spr.offset = Vector2(0, -22)
			_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_spr)

	func hurt() -> void:
		Audio.play("bubble_pop", -6.0, 0.0, 1.4)
		ThroneFx.splash(get_parent(), position, false, 0.5)
		queue_free()

	func step(d: float) -> void:
		_t += d
		if not is_instance_valid(target) or target == room.inside:
			target = room._nearest_member(position)
		if target == null:
			return
		_ang += d * 2.6
		var want := target.global_position + Vector2.from_angle(_ang) * 22.0
		position = position.move_toward(want, 90.0 * d)
		_trail -= d
		if _trail <= 0.0:
			_trail = 0.45
			room.spawn_trail(position)
		_cool = maxf(0.0, _cool - d)
		if _cool <= 0.0 and target.global_position.distance_to(position) <= 28.0:
			_cool = 1.3
			var h := HitData.make_tickle(self, 2.0)
			h.zone = "neck"
			target.receive_hit(h)
		if _spr:
			_spr.frame = 3 if _cool > 1.1 else int(_t * 8.0) % 3
			_spr.flip_h = cos(_ang) > 0.0


# ================================================================ 蓝框留下的滑颜料：踩到 = 顺着走的方向滑出去一段
class SlipPaint extends Node2D:
	var room: PalaceThrone
	var life := 6.0

	func _process(d: float) -> void:
		if room == null or room.busy():
			return
		life -= d
		if life <= 0.0:
			queue_free()
			return
		for m in room.members():
			var pc := m as PlayableCharacter
			if pc != room.inside and not room.slides.has(pc) and pc.global_position.distance_to(position) <= 9.0:
				var dir := pc.velocity.normalized() if pc.velocity.length() > 5.0 else Vector2.from_angle(randf() * TAU)
				room.slides[pc] = [dir, 0.6]
				PalaceRoom.say_random(pc, "slip")
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, 7.0, Color(0.4, 0.7, 1.0, 0.55 * minf(life, 1.0)))
		draw_circle(Vector2(2, -1), 2.0, Color(0.9, 0.97, 1.0, 0.7 * minf(life, 1.0)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ================================================================ 小画像俯冲的预警圈（danger 组：AI 会躲）
class DiveMark extends Node2D:
	var life := 0.8
	var _t := 0.0

	func _ready() -> void:
		add_to_group("danger")
		set_meta("radius", 16.0)

	func _process(d: float) -> void:
		_t += d
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / life
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
		draw_arc(Vector2.ZERO, 16.0, 0, TAU, 24, Color(1, 0.85, 0.3, 0.9), 2.0)
		draw_circle(Vector2.ZERO, 16.0 * k, Color(1, 0.85, 0.3, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ================================================================ 画中世界：颜料格 / 画像之眼 / 颜料星 / 出口 / 画架 / 颜料镜像
class PaintWorld extends Node2D:
	const PAINT_EVERY := 3.0
	const PAINT_COUNT := 4
	const PAINT_WARN := 1.0
	const PAINT_MAX := 0.32       # 最多涂掉多少比例的路
	const EYE_PERIOD := 7.0
	const SEEN_TIME := 3.0
	const MIRROR_SPEED := 70.0
	var room: PalaceThrone
	var cells: Array = []         # 迷宫里能走的格子
	var paint := {}               # 格子 → 秒（< 0 = 预警中，>= 0 = 已经涂掉）
	var stars: Array = []         # 还没拿的星星（格子）
	var stars_got := 0
	var easels: Array = []
	var seen_t := 0.0
	var band_y := 0.0
	var mirror: Node2D
	var _paint_t := 1.5
	var _tick := {}
	var _t := 0.0
	var _rect := Rect2i()
	var _star_views := {}
	var _exit_view: Sprite2D
	var _owned: Array = []

	func setup(r: PalaceThrone) -> void:
		room = r
		z_index = 1   # 光带画在最上面（它是光）；颜料格各自是一个节点，按所在格子排前后
		_rect = PalaceThrone.MAZE
		position = room.world(_rect.position)
		for y in range(_rect.position.y, _rect.end.y):
			for x in range(_rect.position.x, _rect.end.x):
				var c := Vector2i(x, y)
				if GridPath.walkable(room.lv, c):
					cells.append(c)
		for c in room.cells("paint_stars"):
			stars.append(c)
			_star_views[c] = _put(c, 2, 0.35, -28.0)
		for c in room.cells("easels"):
			easels.append(c)
			_put(c, 4, 0.45, -24.0)
		var ex := _put(room.cells("paint_exit")[0], 3, 0.5, -26.0)
		_exit_view = ex.get_child(0) as Sprite2D
		_put(Vector2i(_rect.position.x + _rect.size.x / 2, _rect.position.y), 0, 0.8, -60.0)

	## 每样东西各自是一个投影根（等距显示里子节点不投影，所以不能挂在 PaintWorld 底下）
	func _put(c: Vector2i, frame: int, scale_k: float, lift: float) -> Node2D:
		var n := Node2D.new()
		n.position = room.world(c)
		n.z_index = 1
		var sp := ThroneParts.fx_sprite(frame, scale_k)
		sp.offset = Vector2(0, lift / scale_k)
		n.add_child(sp)
		room.add_view(n)
		_owned.append(n)
		return n

	func _exit_tree() -> void:
		for n in _owned:
			if is_instance_valid(n):
				(n as Node).queue_free()
		if is_instance_valid(mirror):
			mirror.queue_free()

	func exit_open() -> bool:
		return stars_got >= 3

	func cell_of(p: Vector2) -> Vector2i:
		return Vector2i(floori(p.x / 16.0), floori(p.y / 16.0))

	func painted_at(c: Vector2i) -> bool:
		return float(paint.get(c, -99.0)) >= 0.0

	func hidden_at(c: Vector2i) -> bool:
		for e in easels:
			if absi((e as Vector2i).x - c.x) <= 1 and absi((e as Vector2i).y - c.y) <= 1:
				return true
		return false

	func step(d: float) -> void:
		_t += d
		var p := room.inside
		if not is_instance_valid(p):
			return
		var pc := cell_of(p.global_position)
		# 颜料星
		for c in stars.duplicate():
			if p.global_position.distance_to(room.world(c)) <= 14.0:
				stars.erase(c)
				stars_got += 1
				Audio.play("chime", -3.0, 0.0, 1.2 + stars_got * 0.1)
				ThroneFx.gold(room.get_parent(), room.world(c))
				if _star_views.has(c):
					(_star_views[c] as Node).queue_free()
				GameState.notify("颜料星 %d / 3%s" % [stars_got, "——出口的画框亮了！" if stars_got >= 3 else ""])
		if _exit_view:
			_exit_view.modulate = Color(1.3, 1.2, 1.0) if exit_open() else Color(0.45, 0.42, 0.5, 0.8)
		# 画布一块块被涂掉
		for c in paint.keys():
			if float(paint[c]) < 0.0:
				paint[c] = minf(0.0, float(paint[c]) + d)
		_paint_t -= d
		if _paint_t <= 0.0:
			_paint_t = PAINT_EVERY
			_paint_some(pc)
		if painted_at(pc):
			p.status.apply_slow(0.5, 0.3)
			room.tickle(p, "maze_paint", 0.6, 2.0, "sole", d)
		# 画像之眼的光带：上下来回扫，照到（不在画架旁边）→ 画笔冲过来
		var k := 0.5 - 0.5 * cos(_t * TAU / EYE_PERIOD)
		band_y = _rect.position.y + k * (_rect.size.y - 1)
		seen_t = maxf(0.0, seen_t - d)
		if absf(pc.y - band_y) <= 1.5 and not hidden_at(pc):
			if seen_t <= 0.0:
				SpeechBubble.say(p, "被、被看到了——！", 30.0, 1.0)
				Audio.play("gate", -6.0, 0.0, 0.7)
			seen_t = SEEN_TIME
		# 颜料镜像
		if is_instance_valid(mirror):
			var mid := room.world(Vector2i(_rect.position.x + _rect.size.x / 2, 0)).x
			var want := Vector2(2.0 * mid - p.global_position.x, p.global_position.y)
			var nxt := mirror.position.move_toward(want, MIRROR_SPEED * d)
			if GridPath.walkable(room.lv, cell_of(nxt)):
				mirror.position = nxt
			if mirror.position.distance_to(p.global_position) <= 10.0:
				room.tickle(p, "mirror", 0.8, 4.0, "waist", 1.0)
				ThroneParts.shove(p, (p.global_position - mirror.position).normalized() * 14.0)
		queue_redraw()

	func _paint_some(pc: Vector2i) -> void:
		var done := paint.size()
		if done >= int(cells.size() * PAINT_MAX):
			return
		var keep: Array = stars.duplicate()
		keep.append(room.cells("paint_exit")[0])
		keep.append(pc)
		var picks := 0
		for i in 30:
			if picks >= PAINT_COUNT:
				break
			var c: Vector2i = cells.pick_random()
			if paint.has(c):
				continue
			var near := false
			for q in keep:
				if absi((q as Vector2i).x - c.x) + absi((q as Vector2i).y - c.y) <= 2:
					near = true
					break
			if near:
				continue
			paint_cell(c)
			picks += 1

	## 涂掉一格（先闪 PAINT_WARN 秒）
	func paint_cell(c: Vector2i, warn := PAINT_WARN) -> void:
		if paint.has(c):
			return
		paint[c] = -warn
		var pv := PaintCell.new()
		pv.world = self
		pv.cell = c
		pv.position = room.world(c)
		room.add_view(pv)
		_owned.append(pv)

	func _draw() -> void:
		# 光带
		if room:
			var y := (band_y - _rect.position.y) * 16.0 - 16.0
			var br := Rect2(-8, y, _rect.size.x * 16.0, 48.0)
			ThroneParts.iso_rect(self, br, Color(1, 0.95, 0.6, 0.3 if seen_t <= 0.0 else 0.5))
			# 光带上下两条亮边
			draw_line(IsoView.offset(br.position), IsoView.offset(Vector2(br.end.x, br.position.y)), Color(1, 0.97, 0.75, 0.8), 2.0)
			draw_line(IsoView.offset(Vector2(br.position.x, br.end.y)), IsoView.offset(br.end), Color(1, 0.97, 0.75, 0.8), 2.0)


## 被涂掉的一格画布（自己是一个投影根，按所在格子排前后）：先闪（预警），再变成一滩颜料
class PaintCell extends Node2D:
	var world: PaintWorld
	var cell := Vector2i.ZERO
	var _t := 0.0

	func _ready() -> void:
		z_index = 1   # 迷宫是一格宽的路、墙很高：等距里地面会被南边的墙挡住，颜料格画在墙上面（当作警示标记）

	func _process(d: float) -> void:
		_t += d
		if not is_instance_valid(world):
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var v := float(world.paint.get(cell, -1.0))
		var r := Rect2(-7, -7, 14, 14)
		var pts := PackedVector2Array([IsoView.offset(r.position), IsoView.offset(Vector2(r.end.x, r.position.y)), IsoView.offset(r.end),
			IsoView.offset(Vector2(r.position.x, r.end.y)), IsoView.offset(r.position)])
		if v < 0.0:
			# 预警：白色描边一闪一闪
			draw_polyline(pts, Color(1, 1, 1, 0.5 + 0.5 * absf(sin(_t * 12.0))), 2.0)
			return
		ThroneParts.iso_rect(self, r, Color(0.98, 0.25, 0.62, 0.95))
		draw_polyline(pts, Color(0.45, 0.05, 0.3, 0.95), 1.5)
		draw_circle(IsoView.offset(Vector2(3, -2)), 2.0, Color(1, 0.85, 0.95, 1.0))
		draw_circle(IsoView.offset(Vector2(-3, 2)), 1.2, Color(1, 0.85, 0.95, 0.9))


## 颜料镜像（画里的另一个「自己」）：抄本体的精灵图，青色半透明
class MirrorSelf extends Node2D:
	var room: PalaceThrone
	var _spr: Sprite2D

	func _ready() -> void:
		z_index = 1
		_spr = Sprite2D.new()
		_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_spr.modulate = Color(0.5, 0.9, 1.0, 0.7)
		add_child(_spr)

	func _process(_d: float) -> void:
		var p := room.inside if room else null
		if not is_instance_valid(p) or p.sprite == null:
			return
		var src: Sprite2D = p.sprite
		_spr.texture = src.texture
		_spr.hframes = src.hframes
		_spr.vframes = src.vframes
		_spr.frame = src.frame
		_spr.flip_h = not src.flip_h
		_spr.offset = src.offset
		_spr.scale = src.scale
		_spr.position = src.position
