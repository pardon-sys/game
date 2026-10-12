class_name TownBuffShow
extends Node2D
## 镇民支援的过场（TownBuffs.grant 放；期间整个游戏暂停，自己 PROCESS_MODE_ALWAYS）：
##   镜头推到城门 → 镇民从城门走出来、头顶冒喊话 → 镜头拉远看全战线，镇民身上散出一串金色光点飞到每个友军身上落下闪一下
##   → 顶部横幅「镇民支援：××」+ 说明 → 镜头回到人物。镇长的祭典狂欢（once.fireworks）另放满天烟花。
## 约 DURATION 秒；E / Esc / 鼠标左键跳过。测试里可以把 enabled 关掉（直接生效、不放过场）。

signal finished

const DURATION := 4.6
## 镜头关键帧：[时间, 位置键, 倍数]（start = 原来的位置，gate = 城门口，wide = 城门往下的全景）
const CAM_KEYS := [[0.0, "start", 1.0], [0.6, "gate", 1.0], [1.4, "gate", 1.0], [2.3, "wide", 0.5], [3.8, "wide", 0.5], [4.6, "start", 1.0]]
const NPC_AT := 0.6
const ORBS_AT := 1.5
const NPC_DIR := "res://assets/generated/npcs/"

static var enabled := true

var director: SiegeDirector
var entry: Dictionary = {}
var _t := 0.0
var _done := false
var _cam: Camera2D
var _cam_saved := {}
var _was_paused := false
var _npc: Sprite2D
var _npc_from := Vector2.ZERO
var _orbs: Array = []     # [{from, to, t0, life, col}]
var _flashes: Array = []  # [{at, t0}]
var _fireworks: Array = []  # [{at, t0, col, n}]
var _banner: CanvasLayer
var _spots := {}
var _said := false
var _sent := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 90
	_was_paused = get_tree().paused
	get_tree().paused = true
	_cam = GameState.player.camera if GameState.player else null
	if _cam:
		_cam_saved = {"top": _cam.top_level, "pos": _cam.position, "zoom": _cam.zoom, "smooth": _cam.position_smoothing_enabled,
			"l": _cam.limit_left, "t": _cam.limit_top, "r": _cam.limit_right, "b": _cam.limit_bottom}
		_cam.top_level = true
		_cam.position_smoothing_enabled = false
		_cam.limit_left = -100000
		_cam.limit_top = -100000
		_cam.limit_right = 100000
		_cam.limit_bottom = 100000
	var gate := director.gate_pos + Vector2(0, 10)
	var start := _cam.global_position if _cam else gate
	_spots = {"start": start, "gate": gate, "wide": director.gate_pos + Vector2(0, 30)}
	# 镇民
	_npc = Sprite2D.new()
	var sheet := NPC_DIR + str(entry.get("sheet", "captain")) + ".png"
	_npc.texture = load(sheet) if ResourceLoader.exists(sheet) else load(NPC_DIR + "captain.png")
	_npc.hframes = 4
	_npc.vframes = 4
	_npc.offset = Vector2(0, -14)
	_npc.z_index = 5
	add_child(_npc)
	_npc_from = director.gate_pos + Vector2(0, -6)
	_npc.global_position = _npc_from
	_npc.visible = false
	_make_banner()
	Audio.play("chime", -2.0, 0.0, 1.3)


func _make_banner() -> void:
	_banner = CanvasLayer.new()
	_banner.layer = 60
	add_child(_banner)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.06, 0.1, 0.78)
	bg.position = Vector2(60, 34)
	bg.size = Vector2(360, 46)
	bg.name = "Bg"
	_banner.add_child(bg)
	var t := Label.new()
	t.text = "镇民支援：%s（%s）" % [str(entry.get("name", "")), str(entry.get("who", ""))]
	t.position = Vector2(60, 36)
	t.size = Vector2(360, 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	t.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.02))
	t.add_theme_constant_override("outline_size", 5)
	_banner.add_child(t)
	var d := Label.new()
	d.text = str(entry.get("desc", ""))
	d.position = Vector2(64, 56)
	d.size = Vector2(352, 22)
	d.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_theme_font_size_override("font_size", 9)
	d.add_theme_color_override("font_color", Color(1, 0.96, 0.9))
	_banner.add_child(d)
	var hint := Label.new()
	hint.text = "E / Esc 跳过"
	hint.position = Vector2(380, 250)
	hint.add_theme_font_size_override("font_size", 8)
	hint.modulate.a = 0.7
	_banner.add_child(hint)
	for n in _banner.get_children():
		(n as CanvasItem).modulate.a = 0.0


func _input(event: InputEvent) -> void:
	if _done or _t < 0.3:
		return
	if event.is_pressed() and not event.is_echo() and (event.is_action("interact") or event.is_action("pause") or event.is_action("ui_cancel")
			or (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)):
		get_viewport().set_input_as_handled()
		_finish()


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	# 镜头：按关键帧平滑移动（先看城门的镇民，再拉远看光点飞到所有友军身上）
	if _cam:
		var tt := minf(_t, DURATION)
		for i in CAM_KEYS.size() - 1:
			var a: Array = CAM_KEYS[i]
			var b: Array = CAM_KEYS[i + 1]
			if tt >= float(a[0]) and tt <= float(b[0]):
				var f := smoothstep(0.0, 1.0, (tt - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])))
				var pa: Vector2 = _spots[a[1]]
				var pb: Vector2 = _spots[b[1]]
				_cam.global_position = pa.lerp(pb, f)
				var z := lerpf(float(a[2]), float(b[2]), f)
				_cam.zoom = Vector2(z, z)
				break
		_cam.reset_smoothing()
	# 横幅淡入
	for n in _banner.get_children():
		(n as CanvasItem).modulate.a = clampf(_t * 3.0, 0.0, 1.0) * (0.7 if n is Label and (n as Label).text.begins_with("E /") else 1.0)
	# 镇民：从城门走出来，挥手喊话
	if _t > NPC_AT:
		_npc.visible = true
		var walk := clampf((_t - NPC_AT) / 0.6, 0.0, 1.0)
		_npc.global_position = _npc_from + Vector2(0, 26.0 * walk)
		_npc.frame = (int(_t * 6.0) % 4) if walk < 1.0 else (int(_t * 3.0) % 2) * 2
		if not _said and walk >= 1.0:
			_said = true
			SpeechBubble.say(_npc, str(entry.get("line", "加油！")), 26.0, 2.6)
			Audio.play("cheer", -4.0, 0.05)
	# 光点飞向每个友军（镜头这时正在拉远）
	if _t > ORBS_AT and not _sent:
		_sent = true
		var col := Color(str(entry.get("color", "#ffd966")))
		var t0 := _t
		for a in director.town.allies():
			for j in 3:
				_orbs.append({"from": _npc.global_position + Vector2(randf_range(-6, 6), -14), "to": a.global_position + Vector2(0, -12),
					"t0": t0 + j * 0.08 + randf() * 0.25, "life": 1.1 + randf() * 0.4, "col": col, "who": a})
		if bool(entry.get("once", {}).get("fireworks", false)):
			for j in 14:
				_fireworks.append({"at": director.gate_pos + Vector2(randf_range(-260, 260), randf_range(-180, 40)), "t0": t0 + j * 0.16,
					"col": Color.from_hsv(randf(), 0.6, 1.0), "n": 18})
	for o in _orbs:
		if not o.get("landed", false) and _t >= float(o["t0"]) + float(o["life"]):
			o["landed"] = true
			_flashes.append({"at": o["to"], "t0": _t})
	queue_redraw()
	if _t >= DURATION + (1.2 if not _fireworks.is_empty() else 0.0):
		_finish()


func _draw() -> void:
	# 光点：弧线飞行 + 拖尾
	for o in _orbs:
		var lt := (_t - float(o["t0"])) / float(o["life"])
		if lt < 0.0 or lt > 1.0:
			continue
		var from: Vector2 = o["from"]
		var to: Vector2 = o["to"]
		var col: Color = o["col"]
		for tail in 6:
			var u := clampf(lt - tail * 0.035, 0.0, 1.0)
			var p := from.lerp(to, u) + Vector2(0, -sin(u * PI) * 70.0)
			if tail == 0:
				draw_circle(to_local(p), 7.0, Color(col.r, col.g, col.b, 0.25))   # 光晕
				draw_circle(to_local(p), 2.0, Color(1, 1, 1, 0.95))
			draw_circle(to_local(p), 4.5 - tail * 0.6, Color(col.r, col.g, col.b, 0.95 - tail * 0.14))
	# 落下的闪光
	for f in _flashes:
		var a := 1.0 - (_t - float(f["t0"])) / 0.5
		if a <= 0.0:
			continue
		var c := to_local(f["at"])
		draw_circle(c, 16.0 * (1.2 - a), Color(1, 0.95, 0.6, a * 0.5))
		for i in 8:
			var ang := TAU * i / 8.0 + _t * 3.0
			draw_line(c, c + Vector2.from_angle(ang) * 20.0 * (1.2 - a), Color(1, 1, 0.8, a), 2.0)
	# 烟花
	for fw in _fireworks:
		var lt2 := (_t - float(fw["t0"])) / 1.1
		if lt2 < 0.0 or lt2 > 1.0:
			continue
		var c2 := to_local(fw["at"])
		var col2: Color = fw["col"]
		if lt2 < 0.25:
			draw_circle(c2 + Vector2(0, 80.0 * (1.0 - lt2 / 0.25)), 2.0, Color(1, 0.9, 0.7))
		else:
			var r := (lt2 - 0.25) / 0.75
			for i in int(fw["n"]):
				var ang := TAU * i / float(fw["n"])
				var p2 := c2 + Vector2.from_angle(ang) * 46.0 * r + Vector2(0, 14.0 * r * r)
				draw_circle(p2, 2.0 * (1.0 - r) + 0.6, Color(col2.r, col2.g, col2.b, 1.0 - r))


func _finish() -> void:
	if _done:
		return
	_done = true
	if _cam and is_instance_valid(_cam):
		_cam.top_level = bool(_cam_saved.get("top", false))
		_cam.position = _cam_saved.get("pos", Vector2.ZERO)
		_cam.zoom = _cam_saved.get("zoom", Vector2.ONE)
		_cam.position_smoothing_enabled = bool(_cam_saved.get("smooth", true))
		_cam.limit_left = int(_cam_saved.get("l", 0))
		_cam.limit_top = int(_cam_saved.get("t", 0))
		_cam.limit_right = int(_cam_saved.get("r", 100000))
		_cam.limit_bottom = int(_cam_saved.get("b", 100000))
		_cam.reset_smoothing()
	if not _was_paused:
		get_tree().paused = false
	# 每个友军身上再落一下（游戏恢复后在世界里放，能看到）
	for a in director.town.allies():
		if is_instance_valid(a):
			Fx.burst(a.get_parent(), a.global_position + Vector2(0, -12), "crystal", 6, 30.0, 0.5, Vector2(0, -20), Color(str(entry.get("color", "#ffd966"))))
	finished.emit()
	queue_free()
