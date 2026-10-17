class_name WaveFeatures
extends Node
## 每波的特色机制（data/siege/waves.json：顶层 features 是定义，每波 features 是这一波开着的 id；后面的波次叠加前面出现过的）。
## SiegeDirector 每波开打时 begin(ids)，下一波开打时换成新的一组。怪 / 陷阱 / 敌塔比重由 gen_floor06_siege.py 直接写进波次表，
## 这里只做持续的机制：
##   fog       迷雾之夜：画面变暗（关卡的 Darkness 补间到暗紫色）
##   corps     攻城大队：每 CORPS_GAP 秒两排共 9~11 辆攻城车（各带 2 只盾甲螃蟹）从底边同时出发，先亮红色预警线；最终波一直开着
##   gale      狂风肆虐：每 GUST_GAP 秒一阵 GUST_TIME 秒的横扫强风（屏幕风线 + 羽毛），把粉色公主和小怪往一边吹
##   equip     痒痒装备日：临时装备时长 ×1.5（mul("equip_time")）
##   engineers 工兵狂潮：搭敌塔快 50%（mul("build_speed")），每立起一座敌塔响号角（on_tower_built）
##   raiders   抢掠小队：每 RAID_GAP 秒一队 6 只举红旗的小怪（RaiderMind），专拆冰塔、打士兵
##   feathers  羽毛暴风雪：满屏羽毛；开阔地上粉色公主闷笑每秒 +FEATHER_RATE（墙下 / 冰塔旁 / 薄荷冰泉 / 温泉范围里安全，地上画安全圈）
##   carnival  狂欢节：所有怪 siege_carnival（移速 +25%、挠痒间隔 -20%），满屏彩带，配乐音高 +6%
## 波次开始时屏幕中间大字（SiegeFx.big_title），SiegeHud 在小地图下面挂这一波的特色标签（鼠标停上去看说明）。

const CORPS_GAP := 14.0
## 攻城大队一次几辆（第十轮：9~11 辆，第 10 波起 11 辆）
const CORPS_MIN := 9
const CORPS_MAX := 11
const FINAL_FIXED := ["carnival", "corps"]
const GUST_GAP := 8.0
const GUST_TIME := 1.6
const GUST_PINK := 75.0
const GUST_MOB := 55.0
const GUST_BUBBLE := 110.0 # 轻泡泡可被逆风吹回，不能只与自身漂移相抵。
const RAID_GAP := 20.0
const RAID_SIZE := 6
const FEATHER_RATE := 0.015
const SAFE_WALL := 40.0
const SAFE_TOWER := 60.0
const DARK := Color(0.3, 0.26, 0.42)
const TEX := preload("res://assets/generated/siege/features.png")
const ICON := 12

var director: SiegeDirector
var active: Array[String] = []
## 测试用：各机制发动过几次
var counts := {}
var gust_left := 0.0
var gust_dir := Vector2.RIGHT
var _t := {}
var _layer: CanvasLayer
var _wind: Control
var _fx: Node2D
var _safe: Node2D
var _day := Color.WHITE
var _dark_on := false
var rotation_left := 30.0
var rotating := false
var rotation_seed := -1 # >=0：测试可复现；重进从同一个 seed 重新抽。
var generation := 0
var rng := RandomNumberGenerator.new()
var jobs: Array[Dictionary] = []
var feature_towers: Array = []



static func current() -> WaveFeatures:
	return SiegeDirector.current.features if SiegeDirector.current else null


## 定义：{name, color, desc, icon}
static func info(id: String) -> Dictionary:
	var d := SiegeDirector.current
	if d == null:
		return {}
	return (d.data.get("features", {}) as Dictionary).get(id, {})


static func icon_rect(id: String) -> Rect2:
	return Rect2(int(info(id).get("icon", 0)) * ICON, 0, ICON, ICON)


## 其它系统查倍率：build_speed（工兵狂潮 1.5）、equip_time（痒痒装备日 1.5）。没有攻防战时 1。
static func mul_of(key: String) -> float:
	var f := current()
	return f.mul(key) if f else 1.0


func is_on(id: String) -> bool:
	return active.has(id)


func mul(key: String) -> float:
	match key:
		"build_speed": return 1.5 if is_on("engineers") else 1.0
		"equip_time": return 1.5 if is_on("equip") else 1.0
	return 1.0


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 3
	add_child(_layer)
	_wind = Control.new()
	_wind.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wind.draw.connect(_draw_wind)
	_layer.add_child(_wind)
	_fx = Node2D.new()
	_layer.add_child(_fx)


## 这一波开着哪些特色（换波时整组替换）。
func begin(ids: Array) -> void:
	if director.is_final_fortress():
		if rotation_seed >= 0:
			rng.seed = rotation_seed
		else:
			rng.randomize()
		active.clear()
		rotate_features()
	else:
		_apply(ids)


func _apply(ids: Array) -> void:
	end()
	for id in ids:
		active.append(str(id))
	_t = {"corps": 2.0 if director.is_final_fortress() else 6.0, "raiders": 8.0, "gale": 5.0, "feathers": 0.5, "carnival": 0.0}
	if active.is_empty():
		return
	var names: Array[String] = []
	for id in active:
		names.append(str(info(id).get("name", id)))
	var first := info(active[0])
	# 一个特色：「第 N 波：名字」+ 说明；几个特色叠在一起：「第 N 波」+ 名字一行（说明看右上角的标签，鼠标停上去）
	if active.size() == 1:
		SiegeFx.big_title(director, "第 %d 波：%s" % [director.wave, names[0]], Color(str(first.get("color", "#ffd966"))), str(first.get("desc", "")))
	else:
		SiegeFx.big_title(director, "第 %d 波" % director.wave, Color(str(first.get("color", "#ffd966"))), " · ".join(names))
	if is_on("fog"):
		_set_dark(true)
	if is_on("feathers"):
		_emit("feather", 60, 5.0, Color(1, 0.96, 0.85), Vector2(30, 40), [20.0, 40.0])
		_safe = Node2D.new()
		_safe.z_index = -1
		_safe.draw.connect(_draw_safe)
		director.entities().add_child(_safe)
	if is_on("carnival"):
		for c in [Color(1, 0.4, 0.5), Color(1, 0.85, 0.3), Color(0.5, 0.9, 1.0), Color(0.6, 1, 0.6)]:
			_emit("confetti", 10, 4.0, c, Vector2(0, 50), [10.0, 30.0])
		Audio.set_music_pitch(1.06)


## 关掉这一波的全部持续效果。
func end() -> void:
	generation += 1
	jobs.clear()
	rotating = false
	active.clear()
	gust_left = 0.0
	for c in _fx.get_children():
		c.queue_free()
	if _safe and is_instance_valid(_safe):
		_safe.queue_free()
	_safe = null
	_set_dark(false)
	Audio.set_music_pitch(1.0)
	if _wind:
		_wind.queue_redraw()


func _exit_tree() -> void:
	Audio.set_music_pitch(1.0)


## 满屏飘落的粒子（屏幕坐标，挂在 CanvasLayer 上）。
func _emit(kind: String, amount: int, life: float, col: Color, grav: Vector2, speed: Array) -> void:
	var vs := get_viewport().get_visible_rect().size
	var p := Fx.emitter(_fx, kind, amount, life, {"offset": Vector2(vs.x / 2.0, -10), "dir": Vector2(0.3, 1), "spread": 40.0,
		"speed": speed, "gravity": grav, "color": col, "z": 0, "extents": Vector2(vs.x / 2.0 + 20, 4)})
	p.emitting = true


func _set_dark(on: bool) -> void:
	if on == _dark_on:
		return
	var lv := director.level() if director else null
	var dark := lv.get_node_or_null("Darkness") as CanvasModulate if lv else null
	if dark == null:
		return
	if on:
		_day = dark.color
	_dark_on = on
	var tw := dark.create_tween()
	tw.tween_property(dark, "color", DARK if on else _day, 1.5)


func _process(delta: float) -> void:
	if director == null or active.is_empty():
		return
	if director.state != "fight" or GameState.in_dialogue or CG.is_busy() or GameState.in_cutscene:
		return
	if rotating:
		rotation_left -= delta
		if rotation_left <= 0.0:
			rotate_features()
	_tick_jobs(delta)
	for k in _t.keys():
		_t[k] = float(_t[k]) - delta
	if is_on("corps") and float(_t["corps"]) <= 0.0:
		_t["corps"] = CORPS_GAP
		corps()
	if is_on("raiders") and float(_t["raiders"]) <= 0.0:
		_t["raiders"] = RAID_GAP
		raid()
	if is_on("gale"):
		if float(_t["gale"]) <= 0.0:
			_t["gale"] = GUST_GAP
			gust()
		_gust_tick(delta)
	if is_on("feathers") and float(_t["feathers"]) <= 0.0:
		_t["feathers"] = 0.5
		_feather_tick(0.5)
	if is_on("carnival") and float(_t["carnival"]) <= 0.0:
		_t["carnival"] = 1.0
		for m in director.monsters:
			if is_instance_valid(m) and m.is_alive():
				m.add_buff("siege_carnival", 1.5)


func _count(k: String) -> void:
	counts[k] = int(counts.get(k, 0)) + 1


# ------------------------------------------------------------------ 攻城大队
func corps() -> void:
	_count("corps")
	var ms := director.map_size()
	var n := CORPS_MAX if director.wave >= 10 else randi_range(CORPS_MIN, CORPS_MAX)
	var spots: Array[Vector2] = []
	for i in n:
		# 两排错开：单号车在前排，双号车在后排
		var y := ms.y - (40.0 if i % 2 == 0 else 90.0)
		spots.append(Vector2(lerpf(120.0, ms.x - 120.0, (i + 0.5) / n) + randf_range(-16, 16), y))
	for p in spots:
		SiegeFx.lane(director.entities(), p, Vector2(p.x, director.wall_foot_y() + 20.0), 26.0, Color(1, 0.3, 0.25), 1.4, true)
	GameState.notify("攻城大队来了！%d 辆攻城车一起冲过来！" % n)
	Audio.play("siege_horn", -4.0, 0.05, 0.8)
	jobs.append({"left": 1.4, "source": "corps", "generation": generation, "spots": spots})



# ------------------------------------------------------------------ 抢掠小队
func raid() -> Array[Monster]:
	_count("raiders")
	var made: Array[Monster] = []
	var from: String = ["bottom", "left", "right"].pick_random()
	var at := director.spawn_pos(from)
	for i in RAID_SIZE:
		var m := director.spawn("rat" if i % 2 == 0 else "squirrel", "", director.clamp_in_map(at + Vector2(randf_range(-24, 24), randf_range(-16, 16))))
		if m == null:
			continue
		make_raider(m)
		made.append(m)
	GameState.notify("抢掠小队来拆冰塔了！（举红旗的小怪）")
	return made


func make_raider(m: Monster) -> void:
	m.mind = RaiderMind.new(director)
	m.set_meta("raider", true)
	var flag := Polygon2D.new()
	flag.polygon = PackedVector2Array([Vector2(0, 0), Vector2(7, 2.5), Vector2(0, 5)])
	flag.color = Color(1, 0.25, 0.25)
	flag.position = Vector2(1, -26)
	var pole := Line2D.new()
	pole.points = PackedVector2Array([Vector2(0, -26), Vector2(0, -16)])
	pole.width = 1.0
	pole.default_color = Color(0.45, 0.3, 0.2)
	m.add_child(pole)
	m.add_child(flag)
	var tw := flag.create_tween().set_loops()
	tw.tween_property(flag, "scale:x", 0.7, 0.25)
	tw.tween_property(flag, "scale:x", 1.0, 0.25)


# ------------------------------------------------------------------ 狂风肆虐
func gust() -> void:
	_count("gale")
	gust_dir = Vector2.RIGHT if randf() < 0.5 else Vector2.LEFT
	gust_left = GUST_TIME
	Audio.play("wind", -2.0, 0.1, 0.9)
	var vs := get_viewport().get_visible_rect().size
	var p := Fx.emitter(_fx, "feather", 24, 1.2, {"offset": Vector2(vs.x / 2.0 - gust_dir.x * vs.x / 2.0, vs.y / 2.0), "dir": gust_dir,
		"spread": 12.0, "speed": [260.0, 360.0], "gravity": Vector2.ZERO, "color": Color(1, 1, 1, 0.9), "z": 0, "extents": Vector2(4, vs.y / 2.0)})
	p.one_shot = true
	p.explosiveness = 0.6
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _gust_tick(delta: float) -> void:
	if gust_left <= 0.0 or SiegeTools.paused() or director.state != "fight":
		return
	delta = minf(delta,gust_left)
	gust_left -= delta
	_wind.queue_redraw()
	for n in get_tree().get_nodes_in_group("siege_wind_bubbles"):
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			(n as HazardBubbles).blow(gust_dir * GUST_BUBBLE * delta)
	var p := director.pink
	if p and is_instance_valid(p) and p.is_alive() and not Downed.is_downed(p) and not director.is_on_wall(p) \
			and p.is_physics_processing() and not (p.status and p.status.is_grabbed()):
		p.move_and_collide(gust_dir * GUST_PINK * delta)
	for m in director.monsters:
		if not SiegeTools.displaceable(m, true):
			continue
		m.global_position += gust_dir * GUST_MOB * delta


func _draw_wind() -> void:
	if gust_left <= 0.0:
		return
	var vs := _wind.get_viewport_rect().size
	var a := clampf(gust_left / GUST_TIME, 0.0, 1.0) * 0.7
	var ph := Time.get_ticks_msec() / 1000.0 * 600.0
	for i in 18:
		var y := fmod(i * 37.0, vs.y)
		var x := fmod(i * 91.0 + ph * gust_dir.x, vs.x + 80.0) - 40.0
		_wind.draw_line(Vector2(x, y), Vector2(x - gust_dir.x * (30 + i % 3 * 12), y), Color(1, 1, 1, a), 1.0)


# ------------------------------------------------------------------ 羽毛暴风雪
## 这个位置安全吗（墙下 / 冰塔旁 / 薄荷冰泉 / 温泉范围里）。
func feather_safe(pos: Vector2) -> bool:
	if pos.y <= director.wall_foot_y() + SAFE_WALL:
		return true
	for n in get_tree().get_nodes_in_group("siege_tower"):
		var t := n as IceTower
		if t == null:
			continue
		var r := SAFE_TOWER
		if t.kind in ["mint", "hotspring"]:
			r = maxf(r, float(t.p("radius", SAFE_TOWER)))
		if t.global_position.distance_to(pos) <= r:
			return true
	return false


func _feather_tick(dt: float) -> void:
	_count("feathers")
	if _safe and is_instance_valid(_safe):
		_safe.queue_redraw()
	var p := director.pink
	if p == null or not is_instance_valid(p) or not p.is_alive() or Downed.is_downed(p) or director.is_on_wall(p) or p.laugh == null:
		return
	if feather_safe(p.global_position):
		return
	p.laugh.add(p.laugh.max_value * FEATHER_RATE * dt)
	if randf() < 0.5:
		Fx.burst(p.get_parent(), p.global_position + Vector2(randf_range(-6, 6), -14), "feather", 2, 20.0, 0.5, Vector2(0, 20))


func _draw_safe() -> void:
	if not is_instance_valid(_safe) or _safe.is_queued_for_deletion():
		return
	var ms := director.map_size()
	var col := Color(0.7, 1.0, 0.85, 0.12)
	_safe.draw_rect(Rect2(0, director.wall_foot_y(), ms.x, SAFE_WALL), col)
	for n in get_tree().get_nodes_in_group("siege_tower"):
		var t := n as IceTower
		if t == null:
			continue
		var r := SAFE_TOWER
		if t.kind in ["mint", "hotspring"]:
			r = maxf(r, float(t.p("radius", SAFE_TOWER)))
		_safe.draw_circle(t.global_position, r, col)
		_safe.draw_arc(t.global_position, r, 0.0, TAU, 40, Color(0.7, 1.0, 0.85, 0.35), 1.0)


# ------------------------------------------------------------------ 工兵狂潮
func on_tower_built(site: Node2D) -> void:
	if not is_on("engineers"):
		return
	_count("engineers")
	Audio.play("siege_horn", -6.0, 0.05, 1.3)
	GameState.hint("工兵狂潮：又立起一座敌塔！")
	Fx.burst(site.get_parent(), site.global_position + Vector2(0, -16), "spark", 10, 50.0, 0.5, Vector2(0, 60), Color(1, 0.8, 0.4))


func rotate_features() -> void:
	var previous := active.duplicate()
	# 最终波固定开着狂欢节和攻城大队（要塞登场前后都有车队冲墙），另外轮换两个
	var pool: Array = director.data.get("features", {}).keys().filter(func(k): return not FINAL_FIXED.has(k) and not previous.has(k))
	var selected: Array = FINAL_FIXED.duplicate()
	for i in mini(2, pool.size()):
		var index := rng.randi_range(0, pool.size() - 1)
		selected.append(pool.pop_at(index))
	_apply(selected)
	rotating = true
	rotation_left = 30.0
	feature_towers = director.wave_data().get("enemy_towers", []).duplicate()
	var payloads: Dictionary = director.data.get("feature_payloads", {})
	for id in active:
		var payload: Dictionary = payloads.get(id, {})
		feature_towers.append_array(payload.get("enemy_towers", []))
		for group in payload.get("groups", []):
			for i in int(group.get("count", 1)):
				var at := float(group.get("delay", 0)) + i * float(group.get("interval", 1))
				if at < 30.0:
					jobs.append({"source": id, "generation": generation, "left": at, "group": group})
		for hazard in payload.get("hazards", []):
			if float(hazard["t"]) < 30.0:
				jobs.append({"source": id, "generation": generation, "left": float(hazard["t"]), "hazard": hazard})
	if not previous.is_empty():
		var incoming := active.filter(func(k): return not previous.has(k)).map(func(k): return str(info(k).get("name", k)))
		var outgoing := previous.filter(func(k): return not active.has(k)).map(func(k): return str(info(k).get("name", k)))
		GameState.notify("换入：%s；换出：%s" % ["、".join(incoming), "、".join(outgoing)])


func _tick_jobs(delta: float) -> void:
	for job in jobs.duplicate():
		if job["generation"] != generation or not is_on(job["source"]):
			jobs.erase(job)
			continue
		job["left"] -= delta
		if job["left"] > 0:
			continue
		jobs.erase(job)
		if job.has("spots"):
			for p in job["spots"]:
				var cart := director.spawn("cart", "", p)
				if cart == null:
					continue
				var escorts: Array = []
				for side in [-1.0, 1.0]:
					var crab := director.spawn("shield_crab", "", p + Vector2(side * 18.0, -18.0))
					if crab:
						crab.set_meta("escort_of", cart)
						crab.set_meta("escort_off", Vector2(side * 18.0, -18.0))
						escorts.append(crab)
				cart.set_meta("escorts", escorts)
		elif job.has("group"):
			var g: Dictionary = job["group"]
			if g.has("formation"):
				director.teamwork.spawn_formation(g["formation"], director.spawn_pos(g.get("from", "bottom")))
			else:
				director.spawn(g["monster"], g.get("from", "bottom"))
		elif job.has("hazard"):
			var h: Dictionary = job["hazard"]
			if h.has("combo"):
				director.spawn_hazard_combo(h["combo"])
			else:
				director.spawn_hazard(h["kind"])
