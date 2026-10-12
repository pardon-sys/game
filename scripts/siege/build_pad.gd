class_name BuildPad
extends Node2D
## 攻防战的冰塔基座（运行时生成：粉色公主在战场上任何能建的地方按 B，SiegeDirector.try_build）。两个人一起造：
##   1. 选塔（6 种，显示价格）/ 已经有塔时（站在旁边按 B 或 E）：升级（同一种再造一次 = 2 级）/ 拆掉（返还一半）；付冰晶。
##   2. 基座进入「等冰光」：蓝色公主（AI 自动走过来；玩家操控时走到基座正上方的城墙上按 E）从城墙射冰光——
##      BEAM_TIME 秒，离城墙每多 BEAM_STEP 像素加 1 秒。
##   3. 冰塔破冰而出（IceTower）。
## 冰塔布置随 GameState.vars["siege_towers"] 保存（[{x, y, kind, level}]），失败重来时保留。

const BEAM_TIME := 3.0
const BEAM_STEP := 160.0
const BEAM_FREE := 200.0

@export var index := 0

var tower: IceTower
## 等蓝色公主冰光的那座塔：{kind, upgrade: bool}；空 = 没在等
var pending := {}
var beaming := false
var _spr: Sprite2D
var _area: Interactable
var _blue_area: Interactable
var _label: Label


func _ready() -> void:
	add_to_group("siege_pad")
	z_index = -1
	_spr = SiegeArt.sprite("pad_0")
	_spr.offset = Vector2(0, -8)
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


func _process(_delta: float) -> void:
	var waiting := not pending.is_empty()
	_spr.region_rect = SiegeArt.region("pad_1" if waiting or beaming else "pad_0")
	if _blue_area:
		_blue_area.enabled = waiting and not beaming
	_area.enabled = not waiting and not beaming
	_label.text = "等冰光……" if waiting and not beaming else ("造塔中" if beaming else "")


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
			opts.append({"text": "%s　❄%d　%s" % [inf.get("name", k), cost, inf.get("short", "")],
				"desc": str(inf.get("desc", "")) + ("" if d.crystals >= cost else "（冰晶不够）")})
		opts.append({"text": "算了", "desc": "不建了。"})
		var pick := await ScrollPicker.ask("造哪一种冰塔？（冰晶 ×%d）" % d.crystals, opts)
		if pick >= 0 and pick < ks.size():
			request(ks[pick])
		discard_if_empty()
	else:
		var inf := IceTower.info(tower.kind)
		var opts: Array = []
		if tower.level < 2:
			opts.append({"text": "升级成 2 级　❄%d" % int(inf.get("upgrade", 12)), "desc": str(inf.get("desc", ""))})
		opts.append({"text": "拆掉（返还 ❄%d）" % int(int(inf.get("cost", 10)) / 2), "desc": "拆掉这座塔，返还一半冰晶，基座也一起收掉。"})
		opts.append({"text": "算了", "desc": ""})
		var pick := await ScrollPicker.ask("%s（%d 级）　冰晶 ×%d" % [inf.get("name", tower.kind), tower.level, d.crystals], opts)
		var off := 0 if tower.level < 2 else -1
		if tower.level < 2 and pick == 0:
			request(tower.kind, true)
		elif pick == 1 + off:
			d.add_crystals(int(int(inf.get("cost", 10)) / 2))
			tower.queue_free()
			tower = null
			_save()
			queue_free()


## 付冰晶、等蓝色公主的冰光。返回是否成功。
func request(kind: String, upgrade := false) -> bool:
	var d := SiegeDirector.current
	var inf := IceTower.info(kind)
	var cost := int(inf.get("upgrade" if upgrade else "cost", 10))
	if d == null or not d.spend(cost):
		GameState.notify("冰晶不够（要 %d）" % cost)
		Audio.play("locked", -6.0)
		return false
	pending = {"kind": kind, "upgrade": upgrade}
	Audio.play("chime", -6.0, 0.0, 1.3)
	var blue: PlayableCharacter = d.blue
	if blue and blue.is_controlled():
		GameState.rule("蓝色公主：走到冰塔基座正上方的城墙上按 E 放冰光")
	else:
		GameState.notify("等蓝色公主从城墙上放冰光……")
	return true


## 蓝色公主放冰光（AI 走到附近时调用；玩家操控时在城墙上的交互点按 E）。
func blue_beam(blue: PlayableCharacter) -> void:
	if pending.is_empty() or beaming or blue == null or Downed.is_downed(blue):
		return
	beaming = true
	var t := beam_time()
	var from := blue.global_position + Vector2(0, -12)
	SiegeFx.beam(get_parent(), from, global_position + Vector2(0, -8), Color(0.65, 0.9, 1.0, 0.9), t, 3.0)
	Fx.burst(get_parent(), global_position + Vector2(0, -6), "snow", 18, 30.0, t, Vector2(0, -10), Color(0.85, 0.97, 1.0))
	Audio.play("chant", -6.0, 0.0, 1.3)
	var was_locked := blue.is_controlled()
	if was_locked:
		PlayerInputController.movement_locked = true
	blue.set_meta("siege_beaming", true)
	await get_tree().create_timer(t).timeout
	if is_instance_valid(blue):
		blue.set_meta("siege_beaming", false)
	if was_locked:
		PlayerInputController.movement_locked = false
	var job := pending
	pending = {}
	beaming = false
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
