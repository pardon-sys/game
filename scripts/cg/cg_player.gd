extends CanvasLayer
## 笑倒 CG 播放器（Autoload 名为 CG，场景 scenes/ui/cg_player.tscn）。
## 数据是一个总文件 data/cgs.json（格式见文件顶部 _说明，以及 docs/ARCHITECTURE.md「笑倒 CG」）：
##   portraits  CG 立绘接口：id -> {file 素材路径, placeholder 素材缺失时用的公主状态立绘}
##   actors     怪物演员：来源键 -> {scene 怪物场景, sprite 覆盖 hframes / region / scale / offset / frame}
##   death      笑倒时按最后一次挠痒来源选 CG：{by_source: {键: CG id}, default: CG id}
##   cgs        CG id -> {name, cast 演员表, steps 步骤}
## 每一步：portrait 换立绘；actions 演绎指令（并行）；speaker/text/emotion 台词（等玩家推进）；
##        wait 无台词步骤的时长；auto 台词自动前进秒数；await_actions 先演完再出台词。
## 演出在画面右上的独立小舞台里进行（地牢地面 + 聚光），对话框与立绘沿用 Dialogue。
## 看过的 CG（剧情标记 cg_seen_<id>）可以按 Esc 跳过。

signal started(id: String)
signal step_started(index: int, step: Dictionary)
signal finished(id: String)

const PATH := "res://data/cgs.json"
const FX_TEX := preload("res://assets/generated/cg_fx.png")
const TILESET := preload("res://assets/tilesets/dungeon.tres")
## 舞台框（屏幕坐标）：立绘右边、对话框上面。
const FRAME_RECT := Rect2(120, 6, 352, 180)
## 舞台地面中心在舞台框里的位置。
const ORIGIN := Vector2(176, 100)
## 舞台基础放大倍数：camera 的 zoom 1 = 2 倍，1.5 = 3 倍，2 = 4 倍（始终取整数倍，保持像素清晰）。
const BASE_ZOOM := 2.0
const ACTIONS := ["enter", "exit", "move", "hop", "shake", "face", "pose", "tickle", "bubble", "say", "taunt",
	"sfx", "voice", "camera", "flash", "fade_in", "fade_out", "wait"]
const FX_FRAMES := {"lines": [0, 1, 2], "feather": [3], "hand": [4], "heart": [5]}

var data := {}
var current := ""
var step_index := -1
var actors := {}
var source_key := ""
var _playing := false
var _skip := false
var _can_skip := false

var background: ColorRect
var frame: Control
var view: Node2D
var cast_root: Node2D
var fx_root: Node2D
var curtain: ColorRect
var flash_rect: ColorRect
var skip_label: Label
var voice: AudioStreamPlayer


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = _load()
	_build()
	hide()


func _load() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("cgs.json 解析失败")
		return {}
	return parsed


# ------------------------------------------------------------------ 舞台
func _build() -> void:
	background = ColorRect.new()
	background.color = Color(0.03, 0.02, 0.05)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	frame = Control.new()
	frame.name = "Stage"
	frame.position = FRAME_RECT.position
	frame.size = FRAME_RECT.size
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	view = Node2D.new()
	view.position = ORIGIN
	frame.add_child(view)
	var floor := TileMapLayer.new()
	floor.tile_set = TILESET
	view.add_child(floor)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for x in range(-11, 11):
		floor.set_cell(Vector2i(x, -5), 1, Vector2i(0, 0))                                  # 墙顶
		var flags := 0
		floor.set_cell(Vector2i(x, -4), 2, Vector2i([0, 0, 0, 1, 3][rng.randi() % 5], flags))  # 墙面
		for y in range(-3, 5):
			var tile: int = 50 if y == -3 else ([49, 51, 42][rng.randi() % 3] if rng.randf() < 0.12 else 48)
			floor.set_cell(Vector2i(x, y), 0, Vector2i(tile % 12, tile / 12))
	cast_root = Node2D.new()
	cast_root.y_sort_enabled = true
	view.add_child(cast_root)
	fx_root = Node2D.new()
	fx_root.z_index = 5
	view.add_child(fx_root)
	# 聚光：四周压暗的径向渐变
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.02, 0.01, 0.04, 0.85))
	g.add_point(0.45, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.55)
	gt.fill_to = Vector2(1.0, 0.55)
	gt.width = int(FRAME_RECT.size.x)
	gt.height = int(FRAME_RECT.size.y)
	var vignette := TextureRect.new()
	vignette.texture = gt
	vignette.size = FRAME_RECT.size
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(vignette)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 0.9, 0.96, 0)
	flash_rect.size = FRAME_RECT.size
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(flash_rect)
	curtain = ColorRect.new()
	curtain.color = Color(0.03, 0.02, 0.05, 1)
	curtain.size = FRAME_RECT.size
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(curtain)
	var border := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0.95, 0.72, 0.84)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	border.add_theme_stylebox_override("panel", sb)
	border.position = FRAME_RECT.position - Vector2(2, 2)
	border.size = FRAME_RECT.size + Vector2(4, 4)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)
	skip_label = Label.new()
	skip_label.text = "Esc 跳过"
	skip_label.position = FRAME_RECT.position + Vector2(FRAME_RECT.size.x - 64, 4)
	skip_label.add_theme_color_override("font_color", Color(1, 0.9, 0.96, 0.8))
	add_child(skip_label)
	voice = AudioStreamPlayer.new()
	voice.volume_db = -8.0
	add_child(voice)


# ------------------------------------------------------------------ 数据
func cgs() -> Dictionary:
	return data.get("cgs", {})


func death_cg_for(key: String) -> String:
	var death: Dictionary = data.get("death", {})
	return str(death.get("by_source", {}).get(key, death.get("default", "")))


## CG 立绘接口：素材文件存在就用它（导入过的资源或直接读 png），否则用 placeholder 指定的公主状态立绘。
func portrait_texture(id: String) -> Texture2D:
	var info: Dictionary = data.get("portraits", {}).get(id, {})
	var file := str(info.get("file", ""))
	if file != "":
		if ResourceLoader.exists(file):
			return load(file) as Texture2D
		if FileAccess.file_exists(file):
			var img := Image.load_from_file(file)
			if img:
				return ImageTexture.create_from_image(img)
	return Dialogue.portrait_for(str(info.get("placeholder", "helpless_1")))


func has_portrait_file(id: String) -> bool:
	var file := str(data.get("portraits", {}).get(id, {}).get("file", ""))
	return file != "" and (ResourceLoader.exists(file) or FileAccess.file_exists(file))


## 检查 cgs.json 里的引用（测试用），返回问题列表。
func validate() -> Array[String]:
	var errors: Array[String] = []
	var death: Dictionary = data.get("death", {})
	for id in [death.get("default", "")] + death.get("by_source", {}).values():
		if not cgs().has(id):
			errors.append("death 指向不存在的 CG: %s" % id)
	var portraits: Dictionary = data.get("portraits", {})
	for pid in portraits:
		if not GameState.VISUALS.has(str(portraits[pid].get("placeholder", ""))):
			errors.append("立绘 %s 的 placeholder 不是公主的状态" % pid)
	for id in cgs():
		var cg: Dictionary = cgs()[id]
		var cast: Dictionary = cg.get("cast", {})
		for who in cast:
			var k := str(cast[who].get("kind", ""))
			if not (k == "princess" or k == "source" or (k.begins_with("monster:") and data.get("actors", {}).has(k.substr(8)))):
				errors.append("%s: 演员 %s 的 kind 无效: %s" % [id, who, k])
		for i in cg.get("steps", []).size():
			var step: Dictionary = cg["steps"][i]
			var where := "%s 第 %d 步" % [id, i + 1]
			var p := str(step.get("portrait", ""))
			if p != "" and p != "none" and not portraits.has(p):
				errors.append("%s: 立绘 id 不存在: %s" % [where, p])
			for a in step.get("actions", []):
				var d := str(a.get("do", ""))
				if not ACTIONS.has(d):
					errors.append("%s: 未知指令 %s" % [where, d])
				for key in ["who", "by"]:
					if a.has(key) and not cast.has(str(a[key])):
						errors.append("%s: %s 指向不存在的演员 %s" % [where, d, a[key]])
				if d == "camera" and a.get("focus") is String and not cast.has(str(a["focus"])):
					errors.append("%s: camera 聚焦不存在的演员 %s" % [where, a["focus"]])
				if d == "sfx" and not Audio.SOUNDS.has(str(a.get("sound", ""))):
					errors.append("%s: 音效不存在 %s" % [where, a.get("sound")])
				if d == "camera" and a.has("anchor") and not (a["anchor"] is Array and a["anchor"].size() == 2):
					errors.append("%s: camera 的 anchor 应为 [x, y]" % where)
				if d == "pose" and a.has("visual") and not GameState.VISUALS.has(str(a["visual"])):
					errors.append("%s: 姿势状态不存在 %s" % [where, a["visual"]])
	return errors


# ------------------------------------------------------------------ 播放
func is_playing() -> bool:
	return _playing


func can_skip() -> bool:
	return _can_skip


## 笑倒：按最后一次挠痒的来源键选 CG 并播放（await 到结束）。
func play_death(key: String) -> void:
	await play(death_cg_for(key), key)


func play(id: String, source := "") -> void:
	var cg: Dictionary = cgs().get(id, {})
	if _playing or cg.is_empty():
		if cg.is_empty():
			push_warning("没有 CG: " + id)
		return
	_playing = true
	_skip = false
	current = id
	source_key = source
	step_index = -1
	_can_skip = GameState.has_flag("cg_seen_" + id)
	GameState.in_cutscene = true
	GameState.in_dialogue = true
	GameState.princess_reacted.emit("", 0.0)
	Audio.set_voice_state("")
	skip_label.visible = _can_skip
	curtain.color.a = 1.0
	flash_rect.color.a = 0.0
	background.modulate.a = 0.0
	_reset_view()
	_build_cast(cg.get("cast", {}))
	show()
	create_tween().tween_property(background, "modulate:a", 1.0, 0.3)
	started.emit(id)
	var steps: Array = cg.get("steps", [])
	for i in steps.size():
		if _skip:
			break
		step_index = i
		var step: Dictionary = steps[i]
		step_started.emit(i, step)
		_apply_portrait(step)
		var dur := _run_actions(step.get("actions", []))
		if step.get("await_actions", false):
			await _sleep(dur)
		if _skip:
			break
		if step.has("text"):
			var line := {"speaker": step.get("speaker", ""), "text": step["text"]}
			if step.has("emotion"):
				line["emotion"] = step["emotion"]
			Dialogue.start_lines([line], "cg:" + id)
			if step.has("auto"):
				_auto_advance(float(step["auto"]), i)
			await Dialogue.finished
		else:
			await _sleep(float(step.get("wait", dur)))
	GameState.set_flag("cg_seen_" + id)
	_finish()


## 跳过（看过的 CG 才允许）：结束当前台词，停止演出。
func skip() -> void:
	if not _playing or not _can_skip:
		return
	_skip = true
	Dialogue.close()


func _finish() -> void:
	var id := current
	Dialogue.close()
	Dialogue.set_portrait_override(null)
	voice.stop()
	for a in actors.values():
		a.queue_free()
	actors.clear()
	for c in fx_root.get_children():
		c.queue_free()
	_playing = false
	current = ""
	step_index = -1
	GameState.in_cutscene = false
	GameState.in_dialogue = false
	finished.emit(id)
	# 调用方在 finished 时复活公主；这里再把舞台淡出
	var tw := create_tween()
	tw.tween_property(background, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(frame, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		if not _playing:
			hide()
		frame.modulate.a = 1.0)


func _input(event: InputEvent) -> void:
	if _playing and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		skip()


func _sleep(t: float) -> void:
	var left := t
	while left > 0.0 and not _skip:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _auto_advance(t: float, index: int) -> void:
	await get_tree().create_timer(t).timeout
	if _playing and step_index == index and Dialogue.is_active():
		Dialogue.close()


func _apply_portrait(step: Dictionary) -> void:
	if not step.has("portrait"):
		return
	var p := str(step["portrait"])
	if p == "none":
		Dialogue.set_portrait_override(null)
		return
	# 横版大图只有在正式素材存在时才用大框；缺素材时的占位是普通立绘
	var wide: bool = data.get("portraits", {}).get(p, {}).get("wide", false) and has_portrait_file(p)
	Dialogue.set_portrait_override(portrait_texture(p), wide)


func _reset_view() -> void:
	view.scale = Vector2(BASE_ZOOM, BASE_ZOOM)
	view.position = (ORIGIN - Vector2(0, -12) * BASE_ZOOM).round()


## 镜头：zoom（相对基础倍数）把舞台坐标 focus 对准舞台框里的 anchor 位置（默认舞台中心）。
func _camera_target(zoom: float, focus: Vector2, anchor := ORIGIN) -> Array:
	var s := maxf(1.0, roundf(BASE_ZOOM * zoom))
	return [Vector2(s, s), (anchor - focus * s).round()]


func _build_cast(cast: Dictionary) -> void:
	for who in cast:
		var info: Dictionary = cast[who]
		var k := str(info.get("kind", ""))
		var a: CGActor
		if k == "princess":
			a = CGActor.make_princess(who)
			a.set_pose(str(info.get("visual", "helpless_1")), str(info.get("anim", "helpless")), str(info.get("dir", "down")))
		else:
			var key := source_key if k == "source" else k.substr(8)
			var actor_info: Dictionary = data.get("actors", {}).get(key, data.get("actors", {}).get("slime", {}))
			a = CGActor.make_monster(who, key, actor_info)
			if info.has("scale"):
				a.sprite.scale = Vector2.ONE * float(info["scale"])
			if info.has("dir"):
				a.set_dir(str(info["dir"]))
		a.position = _v(info.get("at", [0, 0]))
		a.visible = not info.get("hidden", false)
		cast_root.add_child(a)
		actors[who] = a


func _v(p: Variant) -> Vector2:
	if p is Array and p.size() >= 2:
		return Vector2(float(p[0]), float(p[1]))
	return Vector2.ZERO


# ------------------------------------------------------------------ 演绎指令
func _run_actions(list: Array) -> float:
	var longest := 0.0
	for a in list:
		longest = maxf(longest, _act(a))
	return longest


func _act(a: Dictionary) -> float:
	var who: CGActor = actors.get(str(a.get("who", "")))
	var t := float(a.get("time", 0.0))
	var d := str(a.get("do", ""))
	if who == null and d in ["enter", "exit", "move", "hop", "shake", "face", "pose", "tickle", "bubble", "say", "taunt"]:
		push_warning("CG %s: %s 找不到演员 %s" % [current, d, a.get("who", "")])
		return 0.0
	match d:
		"enter":
			t = maxf(t, 0.25)
			who.visible = true
			if a.has("at"):
				who.position = _v(a["at"])
			var target := who.position
			if a.has("from"):
				who.position = target + _v(a["from"])
			who.modulate.a = 0.0
			var tw := who.create_tween().set_parallel()
			tw.tween_property(who, "modulate:a", 1.0, t)
			tw.tween_property(who, "position", target, t).set_trans(Tween.TRANS_SINE)
		"exit":
			t = maxf(t, 0.25)
			var tw := who.create_tween()
			tw.tween_property(who, "modulate:a", 0.0, t)
			tw.tween_callback(func(): who.visible = false)
		"move":
			t = maxf(t, 0.05)
			who.create_tween().tween_property(who, "position", _v(a.get("to", [0, 0])), t).set_trans(Tween.TRANS_SINE)
		"hop":
			var n := int(a.get("count", 1))
			var h := float(a.get("height", 6))
			t = 0.24 * n
			var tw := who.create_tween()
			for i in n:
				tw.tween_property(who.sprite, "position:y", -h, 0.12).set_ease(Tween.EASE_OUT)
				tw.tween_property(who.sprite, "position:y", 0.0, 0.12).set_ease(Tween.EASE_IN)
		"shake":
			t = t if t > 0.0 else 0.3
			who.shake(t)
			if who.kind == "princess":
				Dialogue.shake_portrait(3.0, t)
		"face":
			who.set_dir(str(a.get("dir", "down")))
		"pose":
			if who.kind == "princess":
				who.set_pose(str(a.get("visual", "")), str(a.get("anim", "")), str(a.get("dir", "")))
			else:
				who.style = str(a.get("style", "idle"))
		"tickle":
			var by: CGActor = actors.get(str(a.get("by", "")))
			var n := int(a.get("repeat", 3))
			var every := float(a.get("interval", 0.35))
			var fx := str(a.get("fx", "lines"))
			t = n * every
			if by:
				by.style = "wiggle"
			var tw := create_tween()
			for i in n:
				tw.tween_callback(func():
					if not is_instance_valid(who):
						return
					Audio.play("tickle", -3.0, 0.1, by.tickle_pitch if is_instance_valid(by) else 1.0)
					who.shake(0.2)
					if who.kind == "princess":
						Dialogue.shake_portrait()  # 第三幕的横版 CG 图跟着挠痒一起抖
					_spawn_fx(who, fx))
				tw.tween_interval(every)
			tw.tween_callback(func():
				if is_instance_valid(by):
					by.style = str(a.get("after", "idle")))
		"bubble":
			t = t if t > 0.0 else 1.4
			who.bubble(str(a.get("kind", "laugh")), t)
		"say":
			SpeechBubble.say(who, str(a.get("text", "")), who.top_height())
			t = maxf(t, 0.0)
		"taunt":
			var lines := ReactionDB.taunts(who.reaction_key if who.reaction_key != "" else str(a.get("key", "")))
			if not lines.is_empty():
				SpeechBubble.say(who, str(lines.pick_random()), who.top_height())
		"sfx":
			Audio.play(str(a.get("sound", "")), float(a.get("volume", 0.0)), 0.05, float(a.get("pitch", 1.0)))
		"voice":
			_set_voice(str(a.get("state", "")))
		"camera":
			var z := float(a.get("zoom", 1.0))
			var focus := Vector2(0, -12)
			if a.get("focus") is String and actors.has(a["focus"]):
				focus = actors[a["focus"]].position + Vector2(0, -12)
			elif a.has("focus"):
				focus = _v(a["focus"])
			var target := _camera_target(z, focus, _v(a["anchor"]) if a.has("anchor") else ORIGIN)
			if t > 0.0:
				var tw := view.create_tween().set_parallel()
				tw.tween_property(view, "scale", target[0], t)
				tw.tween_property(view, "position", target[1], t)
			else:
				view.scale = target[0]
				view.position = target[1]
		"flash":
			t = t if t > 0.0 else 0.3
			flash_rect.color.a = 0.8
			create_tween().tween_property(flash_rect, "color:a", 0.0, t)
		"fade_in":
			t = t if t > 0.0 else 0.5
			create_tween().tween_property(curtain, "color:a", 0.0, t)
		"fade_out":
			t = t if t > 0.0 else 0.5
			create_tween().tween_property(curtain, "color:a", 1.0, t)
		"wait":
			pass
		_:
			push_warning("CG %s: 未知指令 %s" % [current, d])
	return t


func _spawn_fx(target: CGActor, kind: String) -> void:
	var frames: Array = FX_FRAMES.get(kind, FX_FRAMES["lines"])
	var s := Sprite2D.new()
	s.texture = FX_TEX
	s.hframes = 6
	s.frame = frames[0]
	fx_root.add_child(s)
	s.position = (target.position + Vector2(randf_range(-10, 10), randf_range(-22, -6))).round()
	var tw := s.create_tween()
	for f in frames.slice(1):
		tw.tween_interval(0.08)
		tw.tween_callback(func(): s.frame = f)
	tw.tween_property(s, "position:y", s.position.y - 6, 0.25)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.25)
	tw.tween_callback(s.queue_free)


func _set_voice(state: String) -> void:
	if state == "":
		voice.stop()
		return
	var stream := Audio.loop_stream(state)
	if stream and (voice.stream != stream or not voice.playing):
		voice.stream = stream
		voice.play()
