class_name TrainingStage
extends CanvasLayer
## 训练小游戏的共用基类（训练一 / 三 / 四：qte_endure / qte_resist / qte_sensitize 继承它）。TrainingDB.run 创建、await run(训练, 部位)。
## 一轮的流程：
##   1. 地图过场：公主走到营地训练场的训练位置（不在营地时就地），刑具（演出版，active = false）把她固定，卫兵走到两边。
##   2. 小游戏画面（盖住地图）：右边小舞台（CGActor 的公主、刑具、卫兵），左上面板（按键队列 / 忍笑条 / 方向冲动，子类画），
##      下面是魔力疲倦 / 闷笑条、成功次数和本轮收获。左下角沿用 Dialogue 的常驻立绘（挠到部位时有立绘反馈）。
##   3. 魔力疲倦满（训练一）或闷笑满（训练三、四）→ 惩罚小剧场（阶段表的 punish 里随机一段，{zone} / {zone_name} / {device} / {successes} 换成本轮的）→ 继续。
##   4. Esc 结束：地图过场放开公主、卫兵离开，返回 {successes, gained}。疲倦 / 闷笑恢复到训练前。
## 子类实现：world_devices() / stage_cast() / intro_lines() / panel_title()、_tick(delta)、_on_key(键名)、_after_punish(种类)。
## 每成功一次调 succeed(数值键, 量)（立刻记上，到上限为止）。测试可以直接调 press(键名) / quit()，time_scale 加速。

signal finished

const FRAME_RECT := Rect2(120, 6, 352, 180)
const ORIGIN := Vector2(176, 100)
const ZOOM := 2.0
const PANEL_RECT := Rect2(4, 6, 110, 104)
const INFO_Y := 190.0
const TILESET := preload("res://assets/tilesets/dungeon.tres")
const PINK := Color(1, 0.72, 0.86)
const GOLD := Color(1, 0.86, 0.4)
const TEXT := Color(0.95, 0.92, 0.98)
const DIM := Color(0.6, 0.55, 0.65)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.4, 0.45)
const FATIGUE_COL := Color(0.72, 0.5, 1.0)
const LAUGH_COL := Color(1.0, 0.55, 0.75)
## 营地训练场的训练位置（格）、卫兵站位（相对训练位置）。
const CAMP_LEVEL := "floor_06_camp"
const CAMP_SPOT := Vector2i(37, 19)
const GUARD_OFFSETS := [Vector2i(-2, 0), Vector2i(2, 0)]
## 刑具在小舞台上相对公主的位置（同 gen_combo_scenes.py 的 TRAP_AT）。
const STAGE_AT := {"stocks": [0, 11], "clamp": [0, 10], "cuffs": [0, 4], "supine": [0, 10], "cushion": [0, 10],
	"thigh_pincer": [0, -6], "foot_thigh_rack": [0, 10], "feather_swing": [0, 8], "thigh_brush_ring": [0, 9], "foot_bath": [0, 10],
	"sitz_bath": [0, 10], "spring_seat": [0, 10], "saddle_bench": [0, 10], "scissor_stand": [0, 10]}
const PRINCESS_AT := Vector2(0, 8)
const KEY_NAMES := {KEY_A: "A", KEY_D: "D", KEY_Q: "Q", KEY_E: "E", KEY_J: "J", KEY_K: "K", KEY_W: "W", KEY_S: "S",
	KEY_SPACE: "SPACE", KEY_LEFT: "LEFT", KEY_RIGHT: "RIGHT", KEY_UP: "UP", KEY_DOWN: "DOWN"}

var t: Dictionary = {}
var zone := ""
var stage_info: Dictionary = {}
var successes := 0
var gained := {}
var time_scale := 1.0
## 小游戏进行中（不在过场 / 小剧场里）。
var playing := false
## 正在演惩罚小剧场。
var busy := false
var quitting := false
var punish_count := 0
var player: PlayableCharacter
var rng := RandomNumberGenerator.new()
var device_key := ""
var devices: Array[Node2D] = []
var _punish_request := ""
var _start_fatigue := 0.0
var _start_laugh := 0.0
var _return_pos := Vector2.ZERO
var _spot := Vector2i.ZERO

var root: Control
var frame: Control
var view: Node2D
var cast_root: Node2D
var fx_root: Node2D
var flash_rect: ColorRect
var panel: Panel
var panel_body: Control
var title_label: Label
var count_label: Label
var hint_label: Label
var fatigue_bar: Array = []
var laugh_bar: Array = []
var actors := {}
## 舞台上的字（台词气泡、飘字）放在不缩放的这一层：和界面文字一样大。
var overlay: Control
var _bubbles := {}
var _mood := ""


# ------------------------------------------------------------------ 子类接口
## 地图上要摆出来的刑具（陷阱场景名）；第一个用来固定公主。
func world_devices() -> Array:
	return [device_key] if device_key != "" else []


## 小舞台的演员表（同小剧场 cast 的格式：kind = princess / trap:<键> / npc:<人物>，at，dir）。
func stage_cast() -> Dictionary:
	return {}


## 过场里卫兵说的话（[[说话人, 台词], …]）。
func intro_lines() -> Array:
	return []


func panel_title() -> String:
	return str(t.get("name", "训练"))


func key_hint() -> String:
	return ""


func _tick(_delta: float) -> void:
	pass


func _on_key(_k: String) -> void:
	pass


func _after_punish(_kind: String) -> void:
	pass


## 立绘表情跟着哪个数值走（0~1）：默认闷笑，训练一是魔力疲倦。
func mood_ratio() -> float:
	return player.laugh.ratio() if is_instance_valid(player) and player.laugh else 0.0


# ------------------------------------------------------------------ 流程
func run(info: Dictionary, z: String) -> Dictionary:
	t = info
	zone = z
	stage_info = TrainingStats.stage(t)
	player = GameState.player
	rng.randomize()
	layer = 14
	_choose_device()
	_build_ui()
	root.visible = false
	if is_instance_valid(player):
		_return_pos = player.global_position
		_start_fatigue = player.fatigue.value if player.fatigue else 0.0
		_start_laugh = player.laugh.value if player.laugh else 0.0
	await _intro()
	_enter_game()
	while not quitting:
		await get_tree().process_frame
	await _exit_game()
	await _outro()
	finished.emit()
	return {"successes": successes, "gained": gained}


## 部位类训练：这个部位的刑具候选里随机挑一个。
func _choose_device() -> void:
	if zone == "":
		return
	var pool := TrainingDB.devices_for(zone)
	if not pool.is_empty():
		device_key = str(pool[rng.randi() % pool.size()])


func quit() -> void:
	if playing and not busy:
		quitting = true


func press(k: String) -> void:
	if playing and not busy and not quitting:
		_on_key(k)


func _input(event: InputEvent) -> void:
	if not playing or busy or quitting or CG.is_playing():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var kc: int = (event as InputEventKey).keycode
	if kc == KEY_ESCAPE or event.is_action("pause"):
		quit()
		return
	if KEY_NAMES.has(kc):
		press(KEY_NAMES[kc])


func _process(delta: float) -> void:
	if not playing or busy or quitting:
		return
	_update_bars()
	if _punish_request != "":
		var kind := _punish_request
		_punish_request = ""
		_punish(kind)
		return
	_tick(delta * time_scale)


func succeed(key: String, amount: float) -> float:
	successes += 1
	var got := TrainingStats.add(key, amount)
	gained[key] = float(gained.get(key, 0.0)) + got
	_update_count()
	return got


# ------------------------------------------------------------------ 地图过场
func _level() -> Node:
	var main := get_tree().get_first_node_in_group("main")
	return main.get("level") if main else null


func _in_camp() -> bool:
	var lv := _level()
	return lv != null and str(lv.scene_file_path).contains(CAMP_LEVEL)


func _cell(v: Vector2) -> Vector2i:
	return Vector2i(floori(v.x / 16.0), floori(v.y / 16.0))


func _arr(c: Vector2i) -> Array:
	return [c.x, c.y]


func _spawn_devices() -> void:
	var lv := _level()
	if lv == null:
		return
	var parent: Node = lv.get_node_or_null("Entities")
	if parent == null:
		parent = lv
	var keys := world_devices()
	for i in keys.size():
		var path := "res://scenes/traps/%s.tscn" % keys[i]
		if not ResourceLoader.exists(path):
			continue
		var d: Node2D = load(path).instantiate()
		d.set("active", false)
		d.name = "TrainDevice%d" % i
		parent.add_child(d)
		d.global_position = Cutscene.cell_to_world(_arr(_spot))
		devices.append(d)


func _intro() -> void:
	_spot = CAMP_SPOT if _in_camp() else (_cell(player.global_position) if is_instance_valid(player) else Vector2i.ZERO)
	_spawn_devices()
	if not is_instance_valid(player) or _level() == null:
		return
	var g1 := _spot + GUARD_OFFSETS[0]
	var g2 := _spot + GUARD_OFFSETS[1]
	var steps: Array = [
		{"actions": [{"do": "camera", "to": _arr(_spot), "time": 0.8}, {"do": "move", "who": "princess", "to": _arr(_spot), "speed": 60}]},
		{"actions": [{"do": "spawn", "id": "train_g1", "kind": "npc:guard", "at": _arr(g1 + Vector2i(-3, 1)), "dir": "right"},
			{"do": "spawn", "id": "train_g2", "kind": "npc:guard", "at": _arr(g2 + Vector2i(3, 1)), "dir": "left"}], "wait": 0.1},
		{"actions": [{"do": "move", "who": "train_g1", "to": _arr(g1), "speed": 55}, {"do": "move", "who": "train_g2", "to": _arr(g2), "speed": 55}]},
	]
	if not devices.is_empty():
		steps.append({"actions": [{"do": "hold", "who": str(devices[0].name), "on": true}, {"do": "pose", "emotion": "shy"},
			{"do": "face", "who": "train_g1", "dir": "right"}, {"do": "face", "who": "train_g2", "dir": "left"}], "wait": 0.5})
	for l in intro_lines():
		steps.append({"speaker": l[0], "text": l[1]})
	await Cutscene.play_data("training_" + str(t.get("id", "")), {"name": panel_title(), "skippable": true, "steps": steps})


func _outro() -> void:
	if not is_instance_valid(player) or _level() == null:
		_free_devices()
		return
	var g1 := _spot + GUARD_OFFSETS[0]
	var g2 := _spot + GUARD_OFFSETS[1]
	var back := _cell(_return_pos)
	var steps: Array = []
	if not devices.is_empty():
		steps.append({"actions": [{"do": "hold", "who": str(devices[0].name), "on": false}, {"do": "pose", "emotion": "sad"}], "wait": 0.4})
	steps.append({"speaker": "保卫队员", "text": _outro_line()})
	steps.append({"actions": [{"do": "move", "who": "train_g1", "to": _arr(g1 + Vector2i(-4, 1)), "speed": 60},
		{"do": "move", "who": "train_g2", "to": _arr(g2 + Vector2i(4, 1)), "speed": 60},
		{"do": "move", "who": "princess", "to": _arr(back), "speed": 60}]})
	steps.append({"actions": [{"do": "despawn", "who": "train_g1"}, {"do": "despawn", "who": "train_g2"}, {"do": "pose", "emotion": "normal"}], "wait": 0.3})
	await Cutscene.play_data("training_end", {"name": "训练结束", "skippable": true, "steps": steps})
	_free_devices()


func _outro_line() -> String:
	if successes == 0:
		return "今天就到这儿吧。……下次再加油。"
	return "辛苦了！今天成功了 %d 次——进步很明显哦。" % successes


func _free_devices() -> void:
	for d in devices:
		if is_instance_valid(d):
			d.queue_free()
	devices.clear()
	for id in ["train_g1", "train_g2"]:
		var n: Node = Cutscene.spawned.get(id)
		if is_instance_valid(n):
			n.queue_free()
		Cutscene.spawned.erase(id)


func _enter_game() -> void:
	GameState.in_dialogue = true
	_build_cast(stage_cast())
	_update_bars()
	_update_count()
	root.visible = true
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.3)
	playing = true


func _exit_game() -> void:
	playing = false
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.3)
	await tw.finished
	root.visible = false
	if is_instance_valid(player):
		if player.fatigue:
			player.fatigue.set_value(_start_fatigue)
		if player.laugh:
			player.laugh.set_value(_start_laugh)
	GameState.in_dialogue = false


# ------------------------------------------------------------------ 数值
func add_fatigue(amount: float) -> void:
	if not is_instance_valid(player) or player.fatigue == null:
		return
	var f := player.fatigue
	f.set_value(minf(f.value + amount, f.max_value))
	if f.value >= f.max_value and _punish_request == "":
		_punish_request = "fatigue"


## cap_ratio < 1：只涨到上限的这个比例（不触发惩罚）。
func add_laugh(amount: float, cap_ratio := 1.0) -> void:
	if not is_instance_valid(player) or player.laugh == null:
		return
	var l := player.laugh
	l.notify_attacked()
	l.set_value(minf(l.value + amount, l.max_value * cap_ratio))
	if cap_ratio >= 1.0 and l.value >= l.max_value and _punish_request == "":
		_punish_request = "laugh"


func fatigue_max() -> float:
	return player.fatigue.max_value if is_instance_valid(player) and player.fatigue else 500.0


func laugh_max() -> float:
	return player.laugh.max_value if is_instance_valid(player) and player.laugh else 150.0


func _punish(kind: String) -> void:
	busy = true
	punish_count += 1
	flash(Color(1, 0.85, 1, 0.9), 0.6)
	pop(actors.get("princess"), "魔力释放！" if kind == "fatigue" else "笑到撑不住了……", GOLD if kind == "fatigue" else PINK, 1.4)
	Audio.play("star_burst" if kind == "fatigue" else "laugh", -2.0)
	var p: CGActor = actors.get("princess")
	if p:
		p.set_pose("helpless_2", "helpless")
		p.shake(0.6)
	await _sleep(0.9)
	var ids: Array = stage_info.get("punish", [])
	if not ids.is_empty():
		var id := str(ids[rng.randi() % ids.size()])
		await CG.play_theater_subst(id, theater_subs())
	GameState.in_dialogue = true   # 小剧场结束时会清掉
	if is_instance_valid(player):
		if kind == "fatigue" and player.fatigue:
			player.fatigue.clear()
		if player.laugh:
			player.laugh.set_value(0.0)
	if p:
		p.set_pose("helpless_1", "helpless")
	_after_punish(kind)
	busy = false


func theater_subs() -> Dictionary:
	var dev := device_key if device_key != "" else "stocks"
	var at := device_at(dev)
	return {"zone": zone if zone != "" else "sole", "zone_name": TickleZones.zone_name(zone) if zone != "" else "脚心", "device": dev,
		"device_x": at[0], "device_y": at[1], "successes": successes}


func _sleep(sec: float) -> void:
	await get_tree().create_timer(sec / time_scale if time_scale > 0.0 else sec).timeout


# ------------------------------------------------------------------ 舞台
func _build_cast(cast: Dictionary) -> void:
	for a in actors.values():
		a.queue_free()
	actors.clear()
	for who in cast:
		var info: Dictionary = cast[who]
		var k := str(info.get("kind", ""))
		var a: CGActor
		if k == "princess":
			a = CGActor.make_princess(who)
			a.set_pose(str(info.get("visual", "helpless_1")), str(info.get("anim", "helpless")), str(info.get("dir", "down")))
		elif k.begins_with("trap:"):
			a = CGActor.make_trap(who, k.substr(5), CG.data.get("trap_actors", {}).get(k.substr(5), {}))
		elif k.begins_with("npc:"):
			a = CGActor.make_npc(who, k.substr(4), Dialogue.npcs.get(k.substr(4), {}))
			if info.has("dir"):
				a.set_dir(str(info["dir"]))
		else:
			continue
		var at: Array = info.get("at", [0, 0])
		a.position = Vector2(float(at[0]), float(at[1]))
		cast_root.add_child(a)
		actors[who] = a


## 刑具演员在舞台上的位置（相对公主）。
func device_at(key: String) -> Array:
	var o: Array = STAGE_AT.get(key, [0, 10])
	return [PRINCESS_AT.x + o[0], PRINCESS_AT.y + o[1]]


## 舞台上挠公主一下：by = 演员 id，z = 部位；crit 暴击（大特效、立绘大抖）。
func tickle(by: String, z: String, crit := false) -> void:
	var p: CGActor = actors.get("princess")
	if p == null:
		return
	var b: CGActor = actors.get(by)
	p.shake(0.3 if crit else 0.15)
	Audio.play("tickle_special" if crit else "tickle", -2.0 if crit else -6.0, 0.1, b.tickle_pitch if b else 1.0)
	if b:
		b.style = "wiggle"
		if b.kind == "trap":
			b.activate(0.5)
		var ref: WeakRef = weakref(b)
		get_tree().create_timer(0.4).timeout.connect(func():
			var bb: CGActor = ref.get_ref()
			if bb:
				bb.style = "idle")
	var kind := b.hit_fx if b and b.hit_fx != "" else "hand"
	var hf := HitFx.play(kind, fx_root, Vector2.ZERO)
	if hf:
		hf.position = (p.position + Vector2(randf_range(-8, 8), randf_range(-18, -6))).round()
	var zf := ZoneFx.play(z, fx_root, Vector2.ZERO, 1.4 if crit else 1.0, not crit)
	if zf:
		var body: Variant = TickleZones.info(z).get("body", [0, -12])
		var off := Vector2(float(body[0]), float(body[1])) if body is Array and body.size() == 2 else Vector2(0, -12)
		zf.position = (p.position + off * Vector2(-1 if randf() < 0.5 else 1, 1)).round()
	Dialogue.portrait_fx.cutscene_tickle(kind, z)
	if crit:
		Dialogue.shake_portrait(5.0, 0.3)
		pop(p, "暴击！", GOLD)
		flash(Color(1, 0.6, 0.7, 0.45), 0.25)


## 舞台坐标 → 舞台框里的界面坐标（overlay 用）。
func to_frame(p: Vector2) -> Vector2:
	return view.position + p * ZOOM


func _outlined(text: String, col: Color) -> Label:
	var l := _label(col)
	l.text = text
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.12))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(l)
	l.reset_size()
	return l


## 舞台上飘一行字（在演员头上，往上飘再淡出）。
func pop(at: Node2D, text: String, col := TEXT, time := 0.9) -> Label:
	var l := _outlined(text, col)
	var base := to_frame((at.position if at else PRINCESS_AT) + Vector2(0, -26))
	l.position = (base - Vector2(l.size.x / 2.0, l.size.y)).round()
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 14, time)
	tw.parallel().tween_property(l, "modulate:a", 0.0, time * 0.5).set_delay(time * 0.5)
	tw.tween_callback(l.queue_free)
	return l


## 演员说一句（头上的气泡，同一个人新说的替换旧的）。
func say(who: String, text: String) -> void:
	var a: CGActor = actors.get(who)
	if a == null:
		return
	var old: Variant = _bubbles.get(who)
	if is_instance_valid(old):
		old.queue_free()
	var l := _outlined(text, Color(1, 0.95, 0.85))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.16, 0.85)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	l.add_theme_stylebox_override("normal", sb)
	l.reset_size()
	var base := to_frame(a.position + Vector2(0, -a.top_height() - 2))
	l.position = Vector2(clampf(base.x - l.size.x / 2.0, 2, FRAME_RECT.size.x - l.size.x - 2), base.y - l.size.y).round()
	_bubbles[who] = l
	var tw := l.create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func flash(col: Color, time: float) -> void:
	flash_rect.color = col
	create_tween().tween_property(flash_rect, "color:a", 0.0, time)


# ------------------------------------------------------------------ 界面
func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	# 小舞台
	frame = Control.new()
	frame.name = "Stage"
	frame.position = FRAME_RECT.position
	frame.size = FRAME_RECT.size
	frame.clip_contents = true
	root.add_child(frame)
	view = Node2D.new()
	view.scale = Vector2(ZOOM, ZOOM)
	view.position = (ORIGIN + Vector2(0, 12) * ZOOM).round()
	frame.add_child(view)
	var floor := TileMapLayer.new()
	floor.tile_set = TILESET
	view.add_child(floor)
	var r := RandomNumberGenerator.new()
	r.seed = 11
	for x in range(-11, 11):
		floor.set_cell(Vector2i(x, -5), 1, Vector2i(0, 0))
		floor.set_cell(Vector2i(x, -4), 2, Vector2i([0, 0, 0, 1, 3][r.randi() % 5], 0))
		for y in range(-3, 5):
			var tile: int = 50 if y == -3 else ([49, 51, 42][r.randi() % 3] if r.randf() < 0.12 else 48)
			floor.set_cell(Vector2i(x, y), 0, Vector2i(tile % 12, tile / 12))
	cast_root = Node2D.new()
	cast_root.y_sort_enabled = true
	cast_root.z_index = 2
	view.add_child(cast_root)
	fx_root = Node2D.new()
	fx_root.z_index = 5
	view.add_child(fx_root)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.size = FRAME_RECT.size
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(flash_rect)
	overlay = Control.new()
	overlay.size = FRAME_RECT.size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(overlay)
	root.add_child(_border(Rect2(FRAME_RECT.position - Vector2(2, 2), FRAME_RECT.size + Vector2(4, 4)), PINK))
	# 左上面板
	panel = _border(PANEL_RECT, GOLD, Color(0.12, 0.08, 0.16, 0.97))
	root.add_child(panel)
	title_label = _label(GOLD, 8)
	title_label.position = Vector2(4, 2)
	title_label.size = Vector2(PANEL_RECT.size.x - 8, 12)
	title_label.clip_text = true
	panel.add_child(title_label)
	panel_body = Control.new()
	panel_body.position = Vector2(4, 16)
	panel_body.size = PANEL_RECT.size - Vector2(8, 20)
	panel.add_child(panel_body)
	# 下方信息栏
	fatigue_bar = _bar(Vector2(FRAME_RECT.position.x, INFO_Y), FATIGUE_COL, "魔力疲倦")
	laugh_bar = _bar(Vector2(FRAME_RECT.position.x, INFO_Y + 14), LAUGH_COL, "闷笑")
	count_label = _label(TEXT, 8)
	count_label.position = Vector2(FRAME_RECT.position.x, INFO_Y + 30)
	root.add_child(count_label)
	hint_label = _label(DIM, 8)
	hint_label.position = Vector2(FRAME_RECT.position.x, INFO_Y + 44)
	hint_label.size = Vector2(FRAME_RECT.size.x, 30)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	root.add_child(hint_label)
	title_label.text = panel_title()
	hint_label.text = key_hint() + ("　" if key_hint() != "" else "") + "Esc 结束训练"


func _label(col: Color, font_size := 0) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", col)
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _border(rect: Rect2, col: Color, fill := Color(0, 0, 0, 0)) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", sb)
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## 一根数值条：[底, 填充, 文字]。
func _bar(pos: Vector2, col: Color, title: String) -> Array:
	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.12, 0.22)
	bg.position = pos + Vector2(56, 3)
	bg.size = Vector2(FRAME_RECT.size.x - 56 - 70, 7)
	root.add_child(bg)
	var fill := ColorRect.new()
	fill.color = col
	fill.size = Vector2(0, 7)
	bg.add_child(fill)
	var name_l := _label(col, 8)
	name_l.text = title
	name_l.position = pos
	root.add_child(name_l)
	var val := _label(TEXT, 8)
	val.position = bg.position + Vector2(bg.size.x + 6, -3)
	root.add_child(val)
	return [bg, fill, val]


func _set_bar(b: Array, v: float, m: float) -> void:
	if b.is_empty():
		return
	var bg: ColorRect = b[0]
	(b[1] as ColorRect).size.x = roundf(bg.size.x * clampf(v / maxf(m, 1.0), 0.0, 1.0))
	(b[2] as Label).text = "%d / %d" % [roundi(v), roundi(m)]


func _update_bars() -> void:
	if not is_instance_valid(player):
		return
	var r := mood_ratio()
	var mood := "giggle" if r < 0.4 else ("helpless_1" if r < 0.75 else "helpless_2")
	if mood != _mood:
		_mood = mood
		GameState.emote(mood, 0.0, false)
	if player.fatigue:
		_set_bar(fatigue_bar, player.fatigue.value, player.fatigue.max_value)
	if player.laugh:
		_set_bar(laugh_bar, player.laugh.value, player.laugh.max_value)


func _update_count() -> void:
	if count_label == null:
		return
	var parts: Array = []
	for k in stage_info.get("caps", {}):
		var key := TrainingStats.zone_key(str(k), zone) if t.get("per_zone", false) else str(k)
		var c := TrainingStats.cap(key)
		var v := TrainingStats.value(key)
		parts.append(("%.3f / %.3f" if c < 1.0 else "%d / %d") % [v, c])
	count_label.text = "成功抵抗 %d 次　　%s%s" % [successes, (TickleZones.zone_name(zone) + "　") if zone != "" else "", "　".join(parts)]
