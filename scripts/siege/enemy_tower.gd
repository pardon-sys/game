class_name EnemyTower
extends Actor
## 攻防战的敌塔（敌方区域的地基 EnemySite 上：怪物聚集够多、待够久自己搭起来）。有血量，粉色公主可以拆，拆掉掉冰晶。10 种：
##   控制：vine_pull 藤蔓拉拽（勾住粉色公主拖到塔下，连按挣脱；被拖时蓝色公主可以放冰链救）/ tailor 痒痒裁缝铺（射出临时痒痒装备，打中就强制穿上）/
##         glue 黏胶喷泉（往地上喷黏胶水洼，踩上减速）/ net 吊网（网住粉色公主吊在半空，网眼里伸手挠脚心）/
##         silence 魔力干扰（城墙上这一段蓝色公主施法会被打断并挨挠：SiegeDirector.silenced）/ portal 怪物传送门（不停吐小怪）/
##         windmill 强风风车（周期性吹风，把粉色公主吹向怪群）
##   增益：totem 狂欢图腾（附近的怪加速、挠得更重；立着时蓝色公主的千手痒痒裤发作间隔 ×0.6、力度 ×1.5）
##   挠痒：thigh_tower 腿根揉揉塔（射程够到城墙，专打蓝色公主的大腿 / 屁股；穿着千手痒痒裤时裤子跟着一起动）/
##         sole_tower 脚心刷刷塔（刷子手抓住粉色公主的脚踝，扳脚趾、刷脚心、扳着脚板刮）
## 数值和手法台词在 data/siege/enemy_towers.json（{种类: {name, hp, interval, range, lines: [...]}}；gen_floor06_siege.py 生成）。
## 挠痒的来源键 = enemy_<种类>（reaction_key），三来源组合认它。图：towers 图集的 etower_<种类>。
## 能拆：受击范围覆盖整个塔身（HurtProxy），挨打时抖动 + 碎片 + 血条，拆掉时塌下去、碎木飞散；冰塔 / 弩炮 / 法术 / 士兵都会打它。
## 特效（每种塔）：常驻动画 + 地上一直画着淡淡的范围（按种类不同）+ 彩色光照 + 漂浮粒子；发动前 CHARGE 秒蓄力光，发动时各自的特效、
## 屏幕内轻微震屏（限频）。

const PATH := "res://data/siege/enemy_towers.json"
const GLUE_TIME := 8.0
const CHARGE := 0.5
## 每种塔的颜色（光照、范围、蓄力光）
const COLORS := {"vine_pull": Color(0.5, 0.95, 0.45), "tailor": Color(1, 0.6, 0.85), "glue": Color(0.8, 0.95, 0.4), "net": Color(0.95, 0.9, 0.75),
	"silence": Color(0.75, 0.45, 1.0), "portal": Color(0.9, 0.4, 1.0), "windmill": Color(0.85, 0.95, 1.0), "totem": Color(1, 0.7, 0.3),
	"thigh_tower": Color(0.8, 0.55, 1.0), "sole_tower": Color(1, 0.85, 0.55),
	"airdrop": Color(0.45, 0.85, 1.0), "brush_battery": Color(1.0, 0.65, 0.75), "resonance": Color(1.0, 0.8, 0.35)}
static var _shake_t := 0.0

static var _data := {}

@export var kind := "glue"

var site: Node2D
var director: SiegeDirector
## 威力倍数（工兵护送搭成的塔：第一次发动 ×2，发动完回到 1）
var power := 1.0
var reaction_key := ""
var _t := 1.5
var _spr: Sprite2D
var _vine: Line2D
var _dragging := false
var _spawned: Array[Node] = []
var _light: PointLight2D
var _float: CPUParticles2D
var _hit_t := 0.0
var _anim := 0.0
var _charging := false
var _blades: Node2D
var _tools: Array[WeakRef] = []
var _boosted: Array[WeakRef] = []
var _aura_left := 0.0
var _command_left := 0.0
var cooperation := {}
var _co_before := 0.0


## 受击范围（整个塔身都能打到；转给塔本身）。
class HurtProxy extends StaticBody2D:
	var tower: Node
	var faction := Faction.Type.ENEMY

	func receive_hit(hit: HitData) -> bool:
		return tower != null and is_instance_valid(tower) and tower.receive_hit(hit)


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func info(k: String) -> Dictionary:
	var e: Variant = data().get(k, {})
	return e if e is Dictionary else {}


static func kinds() -> Array:
	return ["vine_pull", "tailor", "glue", "net", "silence", "portal", "windmill", "totem", "thigh_tower", "sole_tower", "airdrop", "brush_battery", "resonance"]


func p(key: String, default: Variant = 0.0) -> Variant:
	return info(kind).get(key, default)


func _setup() -> void:
	set_faction(Faction.Type.ENEMY)
	add_to_group("siege_enemy_tower")
	add_to_group("siege_temp")
	reaction_key = "enemy_" + kind
	director = SiegeDirector.current
	collision_layer = 4 | 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(18, 10)
	shape.shape = r
	shape.position = Vector2(0, -5)
	add_child(shape)
	var hc := HealthComponent.new()
	hc.name = "Health"
	hc.max_hp = int(p("hp", 20))
	add_child(hc)
	health = hc
	hc.fill()
	hc.died.connect(_die)
	hurt_invuln_time = 0.25
	_spr = Sprite2D.new()
	_spr.texture = IceTower.TEX
	_spr.region_enabled = true
	_spr.region_rect = IceTower.region("etower_" + kind)
	_spr.offset = Vector2(0, -_spr.region_rect.size.y / 2.0 + 2.0)
	add_child(_spr)
	var col: Color = COLORS.get(kind, Color(0.9, 0.4, 0.85))
	_light = PointLight2D.new()
	_light.texture = load("res://assets/lights/light_soft.tres")
	_light.color = col
	_light.energy = 0.7
	_light.texture_scale = 0.8
	_light.position = Vector2(0, -22)
	add_child(_light)
	# 整个塔身的受击范围（layer 4 = 公主的挥击 / 士兵会扫到）
	var hp_body := HurtProxy.new()
	hp_body.tower = self
	hp_body.collision_layer = 4
	hp_body.collision_mask = 0
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(22, 36)
	if kind in ["airdrop", "brush_battery", "resonance"]:
		hr.size = Vector2(30, 46)
	hs.shape = hr
	hs.position = Vector2(0, -18)
	if kind in ["airdrop", "brush_battery", "resonance"]:
		hs.position.y = -22
	hp_body.add_child(hs)
	add_child(hp_body)
	# 漂浮在塔周围的粒子
	var pk: String = {"vine_pull": "leaf", "tailor": "thread", "glue": "bubble", "net": "thread", "silence": "spark", "portal": "ember",
		"windmill": "feather", "totem": "note", "thigh_tower": "heart", "sole_tower": "bristle",
		"airdrop": "thread", "brush_battery": "bristle", "resonance": "note"}.get(kind, "ember")
	_float = Fx.emitter(self, pk, 6, 2.0, {"offset": Vector2(0, -20), "dir": Vector2.UP, "spread": 180.0, "speed": [4.0, 12.0],
		"gravity": Vector2(0, -6), "color": col, "z": 3, "extents": Vector2(14, 12)})
	_float.emitting = true
	if kind == "windmill":
		_blades = Blades.new()
		_blades.position = Vector2(0, -32)
		_blades.z_index = 1
		add_child(_blades)
	_spr.scale = Vector2(1, 0.05)
	create_tween().tween_property(_spr, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.burst(get_parent(), global_position, "dust", 14, 50.0, 0.6, Vector2(0, -20), Color(0.6, 0.4, 0.6))
	Audio.play("rumble", -6.0, 0.1, 1.2)
	_t = float(p("interval", 6.0)) * 0.5
	if kind == "totem":
		_set_totem(true)


func _on_died() -> void:
	_clear_tools()
	if director:
		director.add_crystals(int(p("reward", 8)), global_position)
	if site and is_instance_valid(site) and site.has_method("tower_gone"):
		site.call("tower_gone")
	_release_drag()
	if kind == "totem":
		_set_totem(false)
	# 崩塌：往下沉、歪倒、碎木和尘土
	set_physics_process(false)
	if _float:
		_float.emitting = false
	var parent := get_parent()
	Fx.burst(parent, global_position + Vector2(0, -12), "wood", 22, 80.0, 0.8, Vector2(0, 140), Color(0.55, 0.32, 0.45))
	Fx.burst(parent, global_position + Vector2(0, -6), "dust", 20, 60.0, 0.9, Vector2(0, 20), Color(0.6, 0.45, 0.6))
	SiegeFx.impact(parent, global_position, 40.0, false, COLORS.get(kind, Color(0.9, 0.4, 0.85)))
	Audio.play("break", -2.0, 0.1)
	if director and director.on_screen(global_position):
		SiegeFx.screen_shake(self, 2.5, 0.3)
	remove_from_group("siege_enemy_tower")
	var tw := create_tween()
	tw.tween_property(_spr, "rotation", randf_range(-0.5, 0.5), 0.35)
	tw.parallel().tween_property(_spr, "scale", Vector2(1.1, 0.2), 0.45).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_spr, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(_light, "energy", 0.0, 0.4)
	tw.tween_callback(queue_free)


func receive_hit(hit: HitData) -> bool:
	var ok := super(hit)
	if ok and hit.kind == HitData.Kind.ATTACK:
		_hit_t = 0.25
		Fx.burst(get_parent(), global_position + Vector2(randf_range(-8, 8), -randf_range(10, 30)), "wood", 4, 40.0, 0.4, Vector2(0, 120),
			Color(0.6, 0.35, 0.5))
	return ok


## 风车的叶片（一直转，发动时转得飞快）。
class Blades extends Node2D:
	var speed := 2.0
	func _process(delta: float) -> void:
		rotation += speed * delta
		speed = move_toward(speed, 2.0, delta * 6.0)
		queue_redraw()
	func _draw() -> void:
		for i in 4:
			var a := TAU * i / 4.0
			var pts := PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a) * 13.0, Vector2.from_angle(a + 0.45) * 12.0])
			draw_colored_polygon(pts, Color(0.92, 0.9, 0.98))
			draw_polyline(pts + PackedVector2Array([Vector2.ZERO]), Color(0.4, 0.25, 0.4), 1.0)
		draw_circle(Vector2.ZERO, 2.5, Color(0.8, 0.7, 0.55))


func _exit_tree() -> void:
	_clear_tools()
	if kind == "totem":
		_set_totem(false)
	_release_drag()


func pink() -> PlayableCharacter:
	return director.pink if director else null


func blue() -> PlayableCharacter:
	return director.blue if director else null


func _alive(c: PlayableCharacter) -> bool:
	return c != null and is_instance_valid(c) and c.is_alive() and not Downed.is_downed(c)


func _tick(delta: float) -> void:
	if SiegeTools.paused():
		return
	if not cooperation.is_empty() and not cooperation_valid(cooperation):
		_cancel_cooperation()
	_anim += delta
	_hit_t = maxf(0.0, _hit_t - delta)
	if _spr:
		_spr.position.x = roundf(sin(_anim * 70.0)) * (1.0 if _hit_t > 0.0 else 0.0)
	queue_redraw()
	if director == null or director.get("state") != "fight" or not is_alive():
		return
	# 屏幕外关灯（省一点）
	if _light:
		_light.visible = director.on_screen(global_position, 80.0)
	if kind == "vine_pull":
		_drag_tick(delta)
	_command_left = maxf(0.0, _command_left - delta)
	if kind == "resonance":
		_aura_left -= delta
		if _aura_left <= 0.0:
			_aura_left = 0.25
			EnemyTowerTools.aura(self)
	var clock_delta := delta / (0.65 if EnemyTowerTools.bell_at(self) else 1.0)
	_t -= clock_delta
	_co_before = maxf(0.0, _co_before - clock_delta)
	# 发动前蓄力：光变亮、塔身抖、粒子聚拢
	if _t <= CHARGE and _t > 0.0 and not _charging:
		_charging = true
		if _light:
			create_tween().tween_property(_light, "energy", 1.6, CHARGE)
		Fx.burst(get_parent(), global_position + Vector2(0, -24), "spark", 6, 20.0, CHARGE, Vector2(0, 10), COLORS.get(kind, Color.WHITE))
	if _t > 0.0:
		return
	_charging = false
	if _light:
		create_tween().tween_property(_light, "energy", 0.7, 0.4)
	# 发动间隔按攻防战的频率倍数缩短（waves.json 的 ability_rate）
	_t = float(p("interval", 6.0)) / SiegeDirector.ability_rate() * IceTower.lamp_slow_at(get_tree(), global_position)
	if director.on_screen(global_position) and Time.get_ticks_msec() / 1000.0 - _shake_t > 1.2:
		_shake_t = Time.get_ticks_msec() / 1000.0
		SiegeFx.screen_shake(self, 1.2, 0.15)
	if _spr:
		var tw0 := create_tween()
		tw0.tween_property(_spr, "scale", Vector2(1.12, 0.9), 0.06)
		tw0.tween_property(_spr, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	var boosted := power > 1.0
	if boosted:
		Fx.burst(get_parent(), global_position + Vector2(0, -24), "ember", 14, 50.0, 0.6, Vector2(0, -20), Color(1, 0.5, 0.9))
	match kind:
		"vine_pull": _vine_throw()
		"tailor": _tailor()
		"glue": _glue()
		"net": _net()
		"silence": _silence_fx()
		"portal": _portal()
		"windmill": _windmill()
		"totem": _totem()
		"thigh_tower": _thigh()
		"sole_tower": _sole()
		"airdrop", "brush_battery", "resonance": EnemyTowerTools.attack(self)
	if boosted:
		power = 1.0
	cooperation = {}


## 联动与 Boss 都催动同一发射时钟；一次性上下文随发射消费。
func command_fire(context: Dictionary = {}) -> bool:
	var supported := kind in ["airdrop", "brush_battery", "resonance"] or (not context.is_empty() and kind in ["glue", "windmill"])
	if _command_left > 0.0 or not supported or not is_alive():
		return false
	_command_left = 2.0
	_co_before = _t
	cooperation = context
	_t = minf(_t, 0.12)
	return true


static func cooperation_valid(context: Dictionary) -> bool:
	if context.is_empty():
		return true
	var owner: Variant = context.get("owner")
	return owner is WeakRef and is_instance_valid(owner.get_ref()) and owner.get_ref().sources_alive()


func cooperation_target() -> PlayableCharacter:
	var ref: Variant = cooperation.get("focus")
	var c: Variant = ref.get_ref() if ref is WeakRef else null
	return c as PlayableCharacter if SiegeTools.alive(c) else null


func _cancel_cooperation() -> void:
	if not cooperation.is_empty():
		_t = maxf(_t, _co_before)
		cooperation = {}
		_charging = false
		if _light:
			_light.energy = 0.7


func cancel_cooperation(owner: Node) -> void:
	var ref: Variant = cooperation.get("owner")
	if ref is WeakRef and ref.get_ref() == owner:
		_cancel_cooperation()


func register_tools(n: Node) -> void:
	_tools = _tools.filter(func(ref): return is_instance_valid(ref.get_ref()))
	_tools.append(weakref(n))


func track_boost(n: Actor) -> void:
	_boosted = _boosted.filter(func(ref): return is_instance_valid(ref.get_ref()))
	if not _boosted.any(func(ref): return ref.get_ref() == n):
		_boosted.append(weakref(n))


func _clear_tools() -> void:
	for ref in _tools:
		var n: Variant = ref.get_ref()
		if is_instance_valid(n):
			if n.has_method("_end"):
				n.call("_end")
			n.queue_free()
	_tools.clear()
	if kind == "resonance" and is_inside_tree():
		EnemyTowerTools.clear_aura(self)


## 地上的范围（按种类）+ 受伤时的血条。
func _draw() -> void:
	var col: Color = COLORS.get(kind, Color(0.9, 0.4, 0.85))
	var r := float(p("range", 0.0))
	var pulse := 0.5 + 0.5 * sin(_anim * 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.55))
	match kind:
		"glue":
			# 黄绿色的黏胶地贴：一圈不规则的黏液 + 冒泡
			for i in 14:
				var a := TAU * i / 14.0
				var rr := r * (0.85 + 0.12 * sin(i * 2.3 + _anim))
				draw_circle(Vector2.from_angle(a) * rr * 0.8, r * 0.28, Color(0.75, 0.9, 0.35, 0.07))
			draw_circle(Vector2.ZERO, r, Color(0.75, 0.9, 0.35, 0.06))
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(0.8, 0.95, 0.4, 0.35 + 0.15 * pulse), 2.0)
			for i in 5:
				var bp := Vector2.from_angle(i * 1.7 + floorf(_anim) * 0.9) * r * (0.3 + 0.12 * i)
				draw_arc(bp, 2.0 + fmod(_anim * 3.0 + i, 3.0), 0, TAU, 8, Color(0.9, 1, 0.6, 0.5), 1.0)
		"windmill":
			# 风圈：一圈圈往外转的风线
			draw_circle(Vector2.ZERO, r, Color(0.85, 0.95, 1.0, 0.04))
			for i in 3:
				var a0 := _anim * (1.2 + i * 0.3) + i * 2.0
				draw_arc(Vector2.ZERO, r * (0.45 + 0.2 * i), a0, a0 + 1.6, 20, Color(0.9, 0.97, 1.0, 0.3), 1.5)
			draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(0.9, 0.97, 1.0, 0.18 + 0.1 * pulse), 1.0)
		"silence":
			draw_circle(Vector2.ZERO, 40.0, Color(0.7, 0.4, 1.0, 0.05))
			for i in 3:
				var rr2 := fmod(_anim * 20.0 + i * 14.0, 42.0)
				draw_arc(Vector2.ZERO, rr2, 0, TAU, 24, Color(0.75, 0.45, 1.0, 0.4 * (1.0 - rr2 / 42.0)), 1.0)
		"vine_pull":
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(0.5, 0.95, 0.45, 0.15 + 0.1 * pulse), 1.0)
			for i in 6:
				var a2 := TAU * i / 6.0 + sin(_anim + i) * 0.1
				draw_line(Vector2.from_angle(a2) * 8.0, Vector2.from_angle(a2 + 0.2) * 24.0, Color(0.4, 0.75, 0.35, 0.5), 1.5)
		"portal":
			for i in 4:
				var a3 := _anim * 2.0 + i * PI / 2.0
				draw_arc(Vector2.ZERO, 16.0 + i * 3.0, a3, a3 + 1.2, 10, Color(0.9, 0.4, 1.0, 0.5), 1.5)
		"totem":
			draw_circle(Vector2.ZERO, r, Color.from_hsv(fmod(_anim * 0.2, 1.0), 0.5, 1.0, 0.06))
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color.from_hsv(fmod(_anim * 0.2, 1.0), 0.6, 1.0, 0.3), 1.5)
		"resonance":
			for i in 3:
				var rr := fmod(_anim * 80 + i * 100, r)
				draw_arc(Vector2.ZERO, rr, 0, TAU, 48, Color(col.r, col.g, col.b, 0.3 * (1.0 - rr / r)), 1.5)
		"airdrop":
			for i in 4:
				var a4 := _anim + i * PI / 2
				var pt := Vector2.from_angle(a4) * 32
				draw_line(pt, pt + Vector2(0, 10), Color(col.r, col.g, col.b, 0.5), 2)
		"brush_battery":
			for i in 3:
				var pt := Vector2((i - 1) * 12, -8 - fmod(_anim * 18 + i * 7, 18))
				draw_line(pt, pt + Vector2(0, 7), Color(col.r, col.g, col.b, 0.5), 1.5)
		_:
			if r > 0.0 and r < 400.0:
				draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(col.r, col.g, col.b, 0.12 + 0.08 * pulse), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 蓄力光
	if _charging:
		draw_circle(Vector2(0, -24), 8.0 + 4.0 * pulse, Color(col.r, col.g, col.b, 0.35))
	# 血条（受伤了才显示）
	if health and health.hp < health.max_hp:
		var f := float(health.hp) / float(health.max_hp)
		draw_rect(Rect2(-12, -44, 24, 3), Color(0.1, 0.05, 0.1, 0.85))
		draw_rect(Rect2(-12, -44, 24 * f, 3), Color(1, 0.4, 0.5))
		draw_rect(Rect2(-12, -44, 24, 3), Color(1, 0.85, 0.9, 0.8), false, 1.0)


func _in_range(c: PlayableCharacter, r: float) -> bool:
	return _alive(c) and c.global_position.distance_to(global_position) <= r


func _line(c: PlayableCharacter) -> void:
	var lines: Array = p("lines", [])
	if lines.is_empty() or not _alive(c):
		return
	var t := str(lines.pick_random())
	if c.character_id == "blue":
		var bl: Array = p("lines_blue", [])
		if not bl.is_empty():
			t = str(bl.pick_random())
	if c.is_controlled():
		GameState.princess_reacted.emit(t, 2.2)
	else:
		SpeechBubble.say(c, t, 28.0, 2.0)


func _tickle(c: PlayableCharacter, amount: float, zone: String) -> void:
	if not _alive(c):
		return
	var h := HitData.make_tickle(self, amount * power)
	h.zone = zone
	c.receive_hit(h)


# ------------------------------------------------------------------ 藤蔓拉拽
func _vine_throw() -> void:
	var c := pink()
	if _dragging or not _in_range(c, float(p("range", 200.0))) or c.get_meta("siege_dragged", false):
		return
	if c.status and c.status.grab(self, 5.0, int(p("presses", 12))):
		_dragging = true
		c.set_meta("siege_dragged", true)
		c.set_meta("siege_dragger", self)
		_vine = Line2D.new()
		_vine.width = 2.0
		_vine.default_color = Color(0.45, 0.8, 0.4)
		_vine.z_index = 20
		_vine.add_to_group("siege_temp")
		get_parent().add_child(_vine)
		_vine.global_position = Vector2.ZERO
		Audio.play("vine", -4.0, 0.1)
		Fx.burst(get_parent(), global_position + Vector2(0, -24), "leaf", 10, 60.0, 0.8, Vector2(0, 60), Color(0.6, 0.95, 0.5))
		_line(c)


func _drag_tick(delta: float) -> void:
	if not _dragging:
		return
	var c := pink()
	if not _alive(c) or c.status == null or not c.status.is_grabbed_by(self):
		_release_drag()
		return
	_vine.points = PackedVector2Array([global_position + Vector2(0, -24), c.global_position + Vector2(0, -8)])
	var d := global_position + Vector2(0, 10) - c.global_position
	if c.get_meta("siege_chained", false):
		return
	if d.length() > 14.0:
		c.global_position += d.normalized() * float(p("pull", 55.0)) * delta
	elif randf() < delta * 2.5:
		_tickle(c, 5.0, ["waist", "armpit", "sole"].pick_random())


## 被救回去 / 挣脱 / 塔倒了：松开。
func _release_drag() -> void:
	_dragging = false
	if _vine and is_instance_valid(_vine):
		_vine.queue_free()
	_vine = null
	var c := pink()
	if c and is_instance_valid(c) and c.has_meta("siege_dragger") and c.get_meta("siege_dragger") == self:
		c.set_meta("siege_dragged", false)
		c.set_meta("siege_dragger", null)
		if c.status and c.status.is_grabbed_by(self):
			c.status.release(true)


func release_drag() -> void:
	_release_drag()


# ------------------------------------------------------------------ 裁缝铺
func _tailor() -> void:
	var targets: Array[PlayableCharacter] = []
	if _in_range(pink(), float(p("range", 240.0))):
		targets.append(pink())
	if _in_range(blue(), float(p("range_wall", 520.0))):
		targets.append(blue())
	if targets.is_empty():
		return
	var c: PlayableCharacter = targets.pick_random()
	var pool: Array = p("items", [])
	pool = pool.filter(func(id): return ItemDB.PATHS.has(str(id)))
	if pool.is_empty():
		return
	var id := str(pool.pick_random())
	SiegeProjectile.shoot(get_parent(), global_position + Vector2(0, -26), c, "proj_equip", 150.0, func(t: Node):
		var tc := t as PlayableCharacter
		if tc == null or not _alive(tc):
			return
		var how := Equipment.force(tc.character_id, id, Equipment.FORCE_TIME * WaveFeatures.mul_of("equip_time"))
		if how != "":
			var it := ItemDB.get_item(id)
			Fx.burst(tc.get_parent(), tc.global_position + Vector2(0, -10), "heart", 6, 30.0, 0.5, Vector2(0, -10), Color(1, 0.7, 0.9))
			Fx.burst(tc.get_parent(), tc.global_position + Vector2(0, -10), "thread", 10, 40.0, 0.6, Vector2(0, 20), Color(1, 0.7, 0.85))
			if tc.is_controlled():
				GameState.rule("被强制穿上了「%s」！（20 秒 / 搭档按住 E 帮忙解开）" % (it.display_name if it else id))
			if director and director.intel:
				director.intel.discover(id))
	Audio.play("swish", -6.0, 0.1, 1.3)


# ------------------------------------------------------------------ 黏胶喷泉
func _glue() -> void:
	var c := cooperation_target() if not cooperation.is_empty() else pink()
	var at := global_position + Vector2.from_angle(randf() * TAU) * randf_range(30.0, float(p("range", 140.0)))
	if _in_range(c, float(p("range", 140.0)) + 40.0):
		at = c.global_position + Vector2(randf_range(-10, 10), randf_range(-6, 6))
	if cooperation.has("at"):
		at = cooperation["at"]
	# 喷射：弧形黏液滴飞过去，落地成水洼
	var from := global_position + Vector2(0, -28)
	for i in 6:
		var dot := Sprite2D.new()
		dot.texture = Fx.PARTICLES["goo"]
		dot.modulate = Color(0.85, 1.0, 0.45)
		dot.scale = Vector2(2, 2)
		dot.z_index = 8
		get_parent().add_child(dot)
		var to := at + Vector2(randf_range(-8, 8), randf_range(-5, 5))
		var tw := dot.create_tween()
		tw.tween_method(func(v: float):
			if is_instance_valid(dot):
				dot.global_position = from.lerp(to, v) + Vector2(0, -sin(v * PI) * 50.0), 0.0, 1.0, 0.45 + i * 0.03)
		tw.tween_callback(dot.queue_free)
	Fx.burst(get_parent(), from, "goo", 8, 40.0, 0.5, Vector2(0, 80), Color(0.85, 1.0, 0.45))
	var wr: WeakRef = weakref(get_parent())
	var command := cooperation.duplicate()
	get_tree().create_timer(0.5, false).timeout.connect(func():
		var par := wr.get_ref() as Node
		if par and cooperation_valid(command):
			GluePuddle.spawn(par, at, GLUE_TIME)
			Fx.burst(par, at, "goo", 10, 40.0, 0.5, Vector2(0, 60), Color(0.85, 1.0, 0.45)))
	Audio.play("puddle", -6.0, 0.1)


# ------------------------------------------------------------------ 吊网
func _net() -> void:
	var c := pink()
	if not _in_range(c, float(p("range", 190.0))):
		return
	var hang := float(p("hang", 3.5))
	# 网落下来之前地上的影子
	SiegeFx.warn(get_parent(), c.global_position, "shadow", 16.0, global_position.distance_to(c.global_position) / 170.0, Color(0.95, 0.9, 0.75), 0.0, 1.2, true)
	SiegeProjectile.shoot(get_parent(), global_position + Vector2(0, -26), c, "net", 170.0, func(t: Node):
		var tc := t as PlayableCharacter
		if tc == null or not _alive(tc):
			return
		if tc.status:
			tc.status.apply_root(hang)
		tc.add_buff("lifted", hang)
		var net := Sprite2D.new()
		net.texture = IceTower.TEX
		net.region_enabled = true
		net.region_rect = IceTower.region("net")
		net.position = Vector2(0, -16)
		net.z_index = 5
		tc.add_child(net)
		tc.get_tree().create_timer(hang).timeout.connect(net.queue_free)
		_line(tc)
		# 塔被拆掉以后网眼里的手也停（弱引用，别调到已经释放的塔上）
		var me: WeakRef = weakref(self)
		var tw := tc.create_tween().set_loops(int(hang / 0.5))
		tw.tween_interval(0.5)
		tw.tween_callback(func():
			var t2 := me.get_ref() as EnemyTower
			if t2:
				t2._tickle(tc, 4.0, "sole")))
	Audio.play("swish", -4.0, 0.1, 0.8)


# ------------------------------------------------------------------ 魔力干扰
## 这个人（在城墙上）在不在干扰范围里。
func silences(c: PlayableCharacter) -> bool:
	return is_alive() and director != null and director.is_on_wall(c) and absf(c.global_position.x - global_position.x) <= float(p("width", 130.0))


func _silence_fx() -> void:
	if director == null:
		return
	var y: float = director.wall_top_y()
	SiegeFx.lane(get_parent(), global_position + Vector2(0, -30), Vector2(global_position.x, y), 2.0, Color(0.7, 0.4, 1.0), 0.8)
	SiegeFx.ring(get_parent(), Vector2(global_position.x, y), float(p("width", 130.0)), Color(0.75, 0.45, 1.0, 0.5), 0.8, 0.08)
	# 被干扰的那段墙上跳紫色电弧
	var w := float(p("width", 130.0))
	for i in 4:
		var x0 := global_position.x + randf_range(-w, w)
		var l := Line2D.new()
		l.width = 1.0
		l.default_color = Color(0.85, 0.6, 1.0, 0.9)
		var pt := Vector2(x0, y - 14.0)
		for k in 5:
			l.add_point(pt)
			pt += Vector2(randf_range(-6, 6), randf_range(3, 7))
		l.z_index = 30
		l.add_to_group("siege_temp")
		get_parent().add_child(l)
		var tw2 := l.create_tween()
		tw2.tween_property(l, "modulate:a", 0.0, 0.35)
		tw2.tween_callback(l.queue_free)


# ------------------------------------------------------------------ 传送门
func _portal() -> void:
	_spawned = _spawned.filter(func(m): return is_instance_valid(m) and m.is_alive())
	if _spawned.size() >= int(p("cap", 6)) or director == null:
		return
	var pool: Array = p("spawns", ["slime", "rat"])
	var m: Monster = director.spawn(str(pool.pick_random()), "portal", global_position + Vector2(randf_range(-10, 10), 12))
	if m:
		_spawned.append(m)
		Fx.burst(get_parent(), global_position + Vector2(0, -10), "ember", 14, 50.0, 0.5, Vector2(0, 20), Color(0.9, 0.5, 1.0))
		var rg := SiegeFx.ring(get_parent(), global_position + Vector2(0, -12), 6.0, Color(0.95, 0.6, 1.0, 0.9), 0.4, 0.3)
		if rg:
			rg.create_tween().tween_property(rg, "scale", Vector2(4, 3), 0.35)


# ------------------------------------------------------------------ 强风风车
func _windmill() -> void:
	var c := cooperation_target() if not cooperation.is_empty() else pink()
	if not _in_range(c, float(p("range", 170.0))):
		return
	var dir := global_position.direction_to(c.global_position)
	var crowd: Variant = director.densest(40.0, c.global_position, 200.0)
	if crowd is Vector2:
		dir = c.global_position.direction_to(crowd)
	c.apply_knockback(c.global_position - dir * 10.0, float(p("force", 300.0)))
	if _blades:
		(_blades as Blades).speed = 22.0
	# 整片扇形的强风：风线 + 夹着羽毛
	var from := global_position + Vector2(0, -26)
	var main := from.direction_to(c.global_position)
	for i in 9:
		var a := main.rotated(randf_range(-0.45, 0.45))
		var st := from + a * randf_range(10, 60)
		SiegeFx.lane(get_parent(), st, st + a * randf_range(80, 160), 1.0, Color(0.95, 0.97, 1.0), 0.35)
	var wind := Fx.emitter(get_parent(), "feather", 24, 0.9, {"dir": main, "spread": 25.0, "speed": [160.0, 260.0],
		"gravity": Vector2.ZERO, "color": Color(1, 1, 1), "z": 8, "extents": Vector2(6, 6)})
	wind.global_position = from
	wind.one_shot = true
	wind.explosiveness = 0.6
	wind.emitting = true
	wind.get_tree().create_timer(1.4, false).timeout.connect(wind.queue_free)
	# 被吹的人身后的拖尾
	var tr := c.create_tween().set_loops(8)
	tr.tween_callback(func():
		if is_instance_valid(c):
			Fx.burst(c.get_parent(), c.global_position + Vector2(0, -8), "feather", 2, 20.0, 0.5, -dir * 30.0, Color(1, 1, 1, 0.8)))
	tr.tween_interval(0.06)
	Fx.burst(get_parent(), c.global_position, "dust", 12, 90.0, 0.5, dir * 80.0, Color(0.9, 0.9, 1.0, 0.7))
	Audio.play("wind", -2.0, 0.1)
	_line(c)


# ------------------------------------------------------------------ 狂欢图腾
func _totem() -> void:
	for m in director.enemies_near(global_position, float(p("range", 120.0))):
		m.add_buff("siege_frenzy", 1.5)
	SiegeFx.ring(get_parent(), global_position, float(p("range", 120.0)), Color(1, 0.6, 0.3, 0.5), 0.6, 0.06)
	Fx.burst(get_parent(), global_position + Vector2(0, -30), "note", 4, 30.0, 1.0, Vector2(0, -20), Color.from_hsv(randf(), 0.5, 1.0))
	Audio.play("totem", -10.0, 0.1)


func _set_totem(on: bool) -> void:
	var b := blue()
	var fx := EquipFx.of(b) if b and is_instance_valid(b) else null
	if fx == null:
		return
	var key := "totem_%d" % get_instance_id()
	if on:
		fx.add_mod(key, 1.0 / 0.6, 1.5)
	else:
		fx.remove_mod(key)


# ------------------------------------------------------------------ 腿根揉揉塔
func _thigh() -> void:
	var c := blue()
	if not _in_range(c, float(p("range", 560.0))):
		c = pink() if _in_range(pink(), 200.0) else null
	if c == null:
		return
	Fx.burst(get_parent(), global_position + Vector2(0, -26), "heart", 5, 40.0, 0.5, Vector2(0, 20), Color(0.85, 0.6, 1.0))
	SiegeProjectile.shoot(get_parent(), global_position + Vector2(0, -26), c, "proj_hand", 170.0, func(t: Node):
		var tc := t as PlayableCharacter
		if tc == null or not _alive(tc):
			return
		var zone: String = ["thigh", "butt"].pick_random()
		for i in 3:
			_tickle(tc, float(p("amount", 6.0)), zone)
		_line(tc)
		# 穿着千手痒痒裤：裤子跟着一起动
		if tc.has_method("pants_flare") and tc.has_buff("thousand_pants"):
			tc.call("pants_flare", "knead" if zone == "thigh" else "pinch"))
	Audio.play("hand_grab", -8.0, 0.1, 1.2)


# ------------------------------------------------------------------ 脚心刷刷塔
func _sole() -> void:
	var c := pink()
	if not _in_range(c, float(p("range", 220.0))):
		return
	SiegeProjectile.shoot(get_parent(), global_position + Vector2(0, -26), c, "proj_brush", 170.0, func(t: Node):
		var tc := t as PlayableCharacter
		if tc == null or not _alive(tc):
			return
		if tc.status:
			tc.status.apply_root(1.6)
		_line(tc)
		var me: WeakRef = weakref(self)
		var amount := float(p("amount", 4.0))
		var tw := tc.create_tween().set_loops(4)
		tw.tween_interval(0.35)
		tw.tween_callback(func():
			var t2 := me.get_ref() as EnemyTower
			if t2:
				t2._tickle(tc, amount, "sole")))
	Audio.play("brush_spin", -8.0, 0.1)
	Fx.burst(get_parent(), global_position + Vector2(0, -26), "bristle", 8, 50.0, 0.6, Vector2(0, 80), Color(1, 0.95, 0.8))
