class_name BuildPad
extends Node2D
## 攻防战的冰塔基座（运行时生成：粉色公主在战场上任何能建的地方按 B，SiegeDirector.try_build）。两个人一起造：
##   1. 选塔（6 种，显示价格）/ 已经有塔时（站在旁边按 B 或 E）：升级（同一种再造一次 = 2 级）/ 拆掉（返还一半）；付冰晶。
##   2. 基座进入「等冰光」：蓝色公主（AI 自动走过来；玩家操控时走到基座正上方的城墙上按 E）从城墙射冰光——
##      BEAM_TIME 秒，离城墙每多 BEAM_STEP 像素加 1 秒。冰吟诵学徒（SiegeSoldier 的 mage）也会走过来帮忙，效率是蓝色公主的一半
##      （HELPER_RATE；每座最多 MAX_HELPERS 个）；几个人一起放就加起来（progress 每秒 + 1 + 0.5 × 学徒数，够 beam_time() 就造好）。
##   3. 冰塔破冰而出（IceTower）。
## 冰塔布置随 GameState.vars["siege_towers"] 保存（[{x, y, kind, level}]），失败重来时保留。

const BEAM_TIME := 3.0
const BEAM_STEP := 160.0
const BEAM_FREE := 200.0
const HELPER_RATE := 0.5
const MAX_HELPERS := 2

@export var index := 0

var tower: IceTower
## 等蓝色公主冰光的那座塔：{kind, upgrade: bool}；空 = 没在等
var pending := {}
## 蓝色公主正在放冰光
var beaming := false
## 冰光进度（按蓝色公主的速度算的秒数），够 _need 就造好
var progress := 0.0
var _need := 0.0
var _blue: PlayableCharacter
var _blue_locked := false
## 正在帮忙的冰吟诵学徒（站到位了的）；reserved：认领了旁边位置的（第几个就站第几个位置，不会挤在一起）
var helpers: Array = []
var reserved: Array = []
var _lines := {}
var _spr: Sprite2D
var _area: Interactable
var _blue_area: Interactable
var _label: Label


func _ready() -> void:
	add_to_group("siege_pad")
	z_index = -1
	_spr = SiegeArt.sprite("pad_0")
	_spr.offset = Vector2(0, -8)
	# 基座是地上的图：放进地板上面一层（SiegeDirector.decals()），不然 z -1 会被地板盖住、z 0 又会盖住站在上面的塔和人
	var dec: Node2D = SiegeDirector.current.decals() if SiegeDirector.current else null
	if dec:
		dec.add_child(_spr)
		_spr.global_position = global_position
		tree_exiting.connect(_spr.queue_free)
	else:
		add_child(_spr)
	_area = _make_area(Vector2(0, -8), Vector2(22, 14))
	_area.interacted.connect(func(p: Node): on_pink(p))
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 7)
	_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.2))
	_label.add_theme_constant_override("outline_size", 3)
	_label.position = Vector2(-30, -42)
	_label.size = Vector2(60, 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.z_index = 30
	add_child(_label)
	await get_tree().process_frame
	await get_tree().process_frame
	var d := SiegeDirector.current
	if d:
		# 蓝色公主那一头：格子正上方的城墙顶
		_blue_area = _make_area(Vector2(0, d.wall_top_y() - global_position.y), Vector2(28, 16))
		_blue_area.interacted.connect(func(p: Node): if p is PlayableCharacter: blue_beam(p))
		_blue_area.enabled = false


func _make_area(at: Vector2, sz: Vector2) -> Interactable:
	var a := Interactable.new()
	a.position = at
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = sz
	cs.shape = r
	a.add_child(cs)
	add_child(a)
	return a


func _process(delta: float) -> void:
	var waiting := not pending.is_empty()
	_spr.region_rect = SiegeArt.region("pad_1" if waiting or beaming else "pad_0")
	if _spr.get_parent() != self:
		_spr.global_position = global_position   # 在地贴层里：跟着基座的位置（生成后才设位置也没关系）
	if _blue_area:
		_blue_area.enabled = waiting and not beaming
	_area.enabled = not waiting and not beaming
	if waiting and not SiegeTools.paused():
		_beam_tick(delta)
	var pct := int(clampf(progress / maxf(_need, 0.01), 0.0, 1.0) * 100.0)
	if not waiting:
		_label.text = ""
	elif beaming or not helpers.is_empty():
		_label.text = "冰光 %d%%" % pct
	else:
		_label.text = "等冰光……" if progress <= 0.0 else "等冰光 %d%%" % pct


## 冰光进度：蓝色公主每秒 1、每个学徒每秒 HELPER_RATE；够了就造好。
func _beam_tick(delta: float) -> void:
	if beaming and (not is_instance_valid(_blue) or not _blue.is_alive() or Downed.is_downed(_blue)):
		_stop_blue()
	helpers = helpers.filter(func(h): return _helper_valid(h) and reserved.has(h) and h.global_position.distance_to(helper_spot(reserved.find(h))) <= SiegeSoldier.MAGE_LEAVE)
	reserved = reserved.filter(func(h): return _helper_valid(h))
	var rate := 1.0 if beaming else 0.0
	for h in helpers: rate += h.build_rate()
	progress += rate * delta
	_draw_lines()
	if rate > 0.0 and randf() < delta * 8.0:
		Fx.burst(get_parent(), global_position + Vector2(randf_range(-8, 8), -6), "snow", 2, 20.0, 0.5, Vector2(0, -10), Color(0.85, 0.97, 1.0))
	if progress >= _need:
		_complete()


## 放冰光的人到基座的光线（蓝色公主粗一点，学徒细一点）。
func _draw_lines() -> void:
	var srcs: Array = helpers.duplicate()
	if beaming and is_instance_valid(_blue):
		srcs.append(_blue)
	for k in _lines.keys():
		if not srcs.has(k) or not is_instance_valid(k):
			(_lines[k] as Line2D).queue_free()
			_lines.erase(k)
	for s in srcs:
		if not _lines.has(s):
			var l := Line2D.new()
			l.width = 3.0 if s == _blue else 2.0
			l.default_color = Color(0.65, 0.9, 1.0, 0.9) if s == _blue else Color(0.75, 0.95, 1.0, 0.9)
			l.z_as_relative = false
			l.z_index = 20
			add_child(l)
			_lines[s] = l
		var line := _lines[s] as Line2D
		var flick := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 60.0 + float(line.get_instance_id() % 7))
		line.modulate.a = flick
		line.points = PackedVector2Array([to_local((s as Node2D).global_position + Vector2(0, -12)), Vector2(0, -8)])


func _clear_lines() -> void:
	for k in _lines.keys():
		if is_instance_valid(_lines[k]):
			(_lines[k] as Line2D).queue_free()
	_lines.clear()


## 冰吟诵学徒认领一个旁边的位置：返回位置序号（0 左 / 1 右），满了返回 -1。
func reserve(s: Node) -> int:
	reserved = reserved.filter(func(h): return _helper_valid(h))
	if pending.is_empty():
		return -1
	var i := reserved.find(s)
	if i >= 0:
		return i
	if reserved.size() >= MAX_HELPERS:
		return -1
	reserved.append(s)
	return reserved.size() - 1


## 学徒站的位置。
func helper_spot(slot: int) -> Vector2:
	return global_position + Vector2(-18.0 if slot == 0 else 18.0, 8.0)


## 站到位了：开始帮忙放冰光。
func helper_join(s: Node) -> bool:
	if pending.is_empty() or not reserved.has(s) or not _helper_valid(s):
		return false
	if not helpers.has(s):
		helpers.append(s)
		Audio.play("chant", -12.0, 0.1, 1.5)
	return true


## 走开（被挠跑了 / 去别处）：位置也让出来。
func helper_leave(s: Node) -> void:
	helpers.erase(s)
	reserved.erase(s)


func helper_slots() -> int:
	reserved = reserved.filter(func(h): return _helper_valid(h))
	return MAX_HELPERS - reserved.size() if not pending.is_empty() else 0


func _helper_valid(h: Variant) -> bool:
	return is_instance_valid(h) and h is SiegeSoldier and not h.is_queued_for_deletion() and h.can_build()


func _stop_blue() -> void:
	if is_instance_valid(_blue):
		_blue.set_meta("siege_beaming", false)
	if _blue_locked:
		PlayerInputController.movement_locked = false
	_blue_locked = false
	_blue = null
	beaming = false


func _exit_tree() -> void:
	_stop_blue()


func waiting() -> bool:
	return not pending.is_empty() and not beaming


## 粉色公主按 B / E：选塔 / 升级 / 拆掉（ScrollPicker：带滚动的选择界面，和商店同一个模板）。
func on_pink(p: Node) -> void:
	var d := SiegeDirector.current
	if d == null or not (p is PlayableCharacter) or (p as PlayableCharacter).character_id != "pink" or ScrollPicker.current != null:
		return
	if tower == null:
		var ks := IceTower.kinds()
		var opts: Array = []
		for k in ks:
			var inf := IceTower.info(k)
			var cost := int(inf.get("cost", 10))
			if not IceTower.unlocked(k):
				# 还没解锁：灰色一行，不能选
				opts.append({"text": "%s　第 %d 波解锁" % [inf.get("name", k), IceTower.unlock_wave(k)], "desc": str(inf.get("desc", "")),
					"enabled": false})
				continue
			opts.append({"text": "%s　❄%d　%s" % [inf.get("name", k), cost, inf.get("short", "")],
				"desc": str(inf.get("desc", "")) + ("" if d.crystals >= cost else "（冰晶不够）")})
		opts.append({"text": "算了", "desc": "不建了。"})
		var pick := await ScrollPicker.ask("造哪一种冰塔？（冰晶 ×%d）" % d.crystals, opts, "", self)
		if pick >= 0 and pick < ks.size():
			request(ks[pick])
		discard_if_empty()
	else:
		var inf := IceTower.info(tower.kind)
		var opts: Array = []
		var can_up := tower.level < IceTower.MAX_LEVEL
		if can_up:
			opts.append({"text": "升级成 %d 级　❄%d" % [tower.level + 1, _upgrade_cost(inf, tower.level)],
				"desc": str(inf.get("desc", "")) + "（范围和伤害变大）"})
		opts.append({"text": "拆掉（返还 ❄%d）" % int(int(inf.get("cost", 10)) / 2), "desc": "拆掉这座塔，返还一半冰晶，基座也一起收掉。"})
		opts.append({"text": "算了", "desc": ""})
		var pick := await ScrollPicker.ask("%s（%d 级）　冰晶 ×%d" % [inf.get("name", tower.kind), tower.level, d.crystals], opts, "", self)
		var off := 0 if can_up else -1
		if can_up and pick == 0:
			request(tower.kind, true)
		elif pick == 1 + off:
			d.add_crystals(int(int(inf.get("cost", 10)) / 2))
			tower.queue_free()
			tower = null
			_save()
			queue_free()


## 升级的价格：升到 3 级再贵一半。
func _upgrade_cost(inf: Dictionary, cur_level: int) -> int:
	var base := int(inf.get("upgrade", 12))
	return base if cur_level < 2 else int(base * 1.5)


## 付冰晶、等蓝色公主的冰光。返回是否成功。
func request(kind: String, upgrade := false, reserve_crystals := 0, announce := true) -> bool:
	var d := SiegeDirector.current
	var inf := IceTower.info(kind)
	if d == null or inf.is_empty() or not pending.is_empty() or not IceTower.unlocked(kind): return false
	if not upgrade and is_instance_valid(tower): return false
	var cost := _upgrade_cost(inf, tower.level) if upgrade and tower else int(inf.get("upgrade" if upgrade else "cost", 10))
	if d.crystals < cost + reserve_crystals or not d.spend(cost):
		if announce:
			GameState.notify("冰晶不够（要 %d）" % cost)
			Audio.play("locked", -6.0)
		return false
	pending = {"kind": kind, "upgrade": upgrade}
	progress = 0.0
	_need = beam_time()
	Audio.play("chime", -6.0, 0.0, 1.3)
	if not announce: return true
	var blue: PlayableCharacter = d.blue
	if blue and blue.is_controlled():
		GameState.rule("蓝色公主：走到冰塔基座正上方的城墙上按 E 放冰光")
	else:
		GameState.notify("等蓝色公主从城墙上放冰光……（冰吟诵学徒也会来帮忙）")
	return true


## 蓝色公主放冰光（AI 走到附近时调用；玩家操控时在城墙上的交互点按 E）：放到造好为止（被打倒就停下，进度留着）。
func blue_beam(blue: PlayableCharacter) -> void:
	if pending.is_empty() or beaming or blue == null or Downed.is_downed(blue):
		return
	beaming = true
	_blue = blue
	if _need <= 0.0:
		_need = beam_time()
	Fx.burst(get_parent(), global_position + Vector2(0, -6), "snow", 18, 30.0, 0.8, Vector2(0, -10), Color(0.85, 0.97, 1.0))
	Audio.play("chant", -6.0, 0.0, 1.3)
	_blue_locked = blue.is_controlled()
	if _blue_locked:
		PlayerInputController.movement_locked = true
	blue.set_meta("siege_beaming", true)


## 进度够了：冰塔破冰而出 / 升级。
func _complete() -> void:
	var job := pending
	pending = {}
	progress = 0.0
	_stop_blue()
	helpers.clear()
	reserved.clear()
	_clear_lines()
	if job.is_empty():
		return
	if bool(job.get("upgrade", false)) and tower:
		tower.upgrade()
	else:
		_build(str(job["kind"]), 1)
	Audio.play("tower_build", -2.0)
	if SiegeDirector.current:
		SiegeDirector.current.intel.discover("tower_" + str(job["kind"]))
	_save()


## 冰光要多久：离城墙越远越久。
func beam_time() -> float:
	var d := SiegeDirector.current
	var dist := global_position.y - d.wall_foot_y() if d else 0.0
	return BEAM_TIME + maxf(0.0, dist - BEAM_FREE) / BEAM_STEP


func _build(kind: String, lvl: int, _quiet := false) -> void:
	if tower:
		tower.queue_free()
	tower = IceTower.new()
	tower.kind = kind
	tower.level = lvl
	tower.pad = self
	var ents := get_parent()
	ents.add_child(tower)
	tower.global_position = global_position + Vector2(0, -2)


func tower_gone() -> void:
	tower = null
	_save()
	queue_free()


## 塔被抢掠小队拆了：基座留着（按 B 在这里重新造）。
func tower_raided() -> void:
	tower = null
	_save()
	queue_redraw()


## 存档：所有基座上的塔一起写（[{x, y, kind, level}]）。
func _save() -> void:
	var out := []
	for pd in get_tree().get_nodes_in_group("siege_pad"):
		var p := pd as BuildPad
		if p == null or p.is_queued_for_deletion() or p.tower == null or not is_instance_valid(p.tower) or p.tower.is_queued_for_deletion():
			continue
		out.append({"x": p.global_position.x, "y": p.global_position.y, "kind": p.tower.kind, "level": p.tower.level})
	GameState.vars["siege_towers"] = out


## 取消（选塔菜单里选了「算了」、或者塔被拆掉）且基座上没东西：基座也收掉。
func discard_if_empty() -> void:
	if tower == null and pending.is_empty() and not beaming:
		queue_free()
