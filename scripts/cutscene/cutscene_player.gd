extends CanvasLayer
## 地图内过场动画（Autoload：Cutscene）。和笑倒 CG 不同，直接在当前地图里演：上下滑入黑框（电影感），
## 镜头在地图上移动，演员是公主、关卡里的节点（按节点名）和临时生成的演员。
## 数据：data/cutscenes/<楼层组>/<id>.json（每层一个文件夹，id 是文件名，全局唯一）—— {name, skippable, hide_hud, steps}，steps 格式同 data/cgs.json：
##   每一步可写 actions（同时开始）、speaker / text / emotion（台词，等玩家推进；auto 秒后自动前进）、wait（没有台词时停留秒数）。
## 播放期间 GameState.in_cutscene / in_dialogue 为真：陷阱、怪物、巢穴、组合都暂停，公主不能操作；动作只做表现，不走真实效果。
## 看过的过场按 Esc 跳过（跳过时剩下步骤里的 set_flag / chapter_end / spawn / despawn / move / carry 照样生效）。
## 触发：关卡 [level] 段 intro_cutscene = <id>；图例 trigger cutscene=<id>；代码 Cutscene.play(id)。
##
## 动作（do）：
##   move（who, to [格x,格y], time 或 speed）  face（who, dir）  pose（who=princess：emotion / laugh 百分比 / faint true|false）
##   camera（to [格] 或 who；time；zoom 倍数；reset = true 回到公主）  shake（time, strength）  fade_out / fade_in / flash（time）
##   bubble（who, kind）  say（who, text）  tickle（who=princess, by 节点, repeat, interval, fx, add 百分比）
##   trap（who 陷阱节点名）：陷阱演一次发动（只有表现）  spawn（id, kind = shadow | monster:<来源键>, at [格], dir）  despawn（who）
##   carry（who 抱人的演员, on = true / false）：抱起公主一起移动  wait（time）  sfx（sound, volume, pitch）  voice（state）
##   set_flag（flag）  notify（text）  chapter_end（title, subtitle）：章节结束画面

signal started(id: String)
signal finished(id: String)

const DIR := "res://data/cutscenes/"
const BAR_H := 28.0
const ACTIONS := ["move", "face", "pose", "camera", "shake", "fade_out", "fade_in", "flash", "bubble", "say", "tickle", "trap",
	"spawn", "despawn", "carry", "wait", "sfx", "voice", "set_flag", "notify", "chapter_end", "hold"]
const BUBBLE_TEXT := {"surprise": "！", "question": "？", "laugh": "哈哈哈", "dots": "……", "sad": "呜……", "angry": "哼！", "shy": "///", "happy": "♪"}
## 黑影的颜色（复制公主的精灵后蒙上）。
const SHADOW_COLOR := Color(0.07, 0.03, 0.1, 0.95)

var current := ""
var step_index := -1
## 临时演员：id -> Node2D
var spawned := {}
var _playing := false
var _skip := false
var _can_skip := false
var _carrier: Node2D
var _cam_tween: Tween
var _hud_was_visible := true
## 公主镜头原来的位置 / 缩放（过场结束时还原）。
var _cam_base := Vector2.ZERO
var _cam_zoom := Vector2(2, 2)

var top_bar: ColorRect
var bottom_bar: ColorRect
var curtain: ColorRect
var flash_rect: ColorRect
var skip_label: Label
var chapter_screen: Control
var chapter_hint: Label
## 章节结束画面按 E 后进入的楼层（chapter_end 的 next，空 = 停在结束画面）。
var chapter_next := ""
var chapter_title: Label
var chapter_sub: Label


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	curtain = _rect(Color(0.03, 0.02, 0.05, 0.0))
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect = _rect(Color(1, 1, 1, 0.0))
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_bar = _rect(Color(0, 0, 0, 1))
	bottom_bar = _rect(Color(0, 0, 0, 1))
	var vs := Vector2(480, 270)
	top_bar.size = Vector2(vs.x, BAR_H)
	bottom_bar.size = Vector2(vs.x, BAR_H)
	top_bar.position = Vector2(0, -BAR_H)
	bottom_bar.position = Vector2(0, vs.y)
	skip_label = Label.new()
	skip_label.text = "Esc 跳过"
	skip_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.85))
	skip_label.position = Vector2(vs.x - 56, 6)
	skip_label.hide()
	add_child(skip_label)
	chapter_screen = Control.new()
	chapter_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	chapter_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := _rect(Color(0.02, 0.01, 0.03, 1.0), chapter_screen)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	chapter_title = Label.new()
	chapter_title.add_theme_color_override("font_color", Color(1, 0.8, 0.9))
	chapter_title.add_theme_font_size_override("font_size", 24)
	chapter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_title.size = Vector2(vs.x, 40)
	chapter_title.position = Vector2(0, 100)
	chapter_screen.add_child(chapter_title)
	chapter_sub = Label.new()
	chapter_sub.add_theme_color_override("font_color", Color(0.75, 0.68, 0.82))
	chapter_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_sub.size = Vector2(vs.x, 30)
	chapter_sub.position = Vector2(0, 146)
	chapter_screen.add_child(chapter_sub)
	chapter_hint = Label.new()
	chapter_hint.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	chapter_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_hint.size = Vector2(vs.x, 20)
	chapter_hint.position = Vector2(0, 210)
	chapter_hint.text = "按 E 继续"
	chapter_hint.hide()
	chapter_screen.add_child(chapter_hint)
	chapter_screen.hide()
	# 章节结束画面放在最上层（盖住常驻立绘和对话框）
	var top := CanvasLayer.new()
	top.layer = 30
	add_child(top)
	top.add_child(chapter_screen)


func _rect(col: Color, parent: Node = null) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else self).add_child(r)
	return r


# ------------------------------------------------------------------ 公共接口
var _index := {}


## id -> 文件路径（递归扫描 data/cutscenes/ 下各层的文件夹）。
func index() -> Dictionary:
	if _index.is_empty():
		_scan(DIR)
	return _index


func _scan(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			_index[f.get_basename()] = dir + f
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir + sub + "/")


func has_cutscene(id: String) -> bool:
	return index().has(id)


func load_cutscene(id: String) -> Dictionary:
	if not has_cutscene(id):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(index()[id]))
	return parsed if parsed is Dictionary else {}


## 所有过场 id。
func ids() -> Array[String]:
	var out: Array[String] = []
	for id in index():
		out.append(str(id))
	return out


func is_playing() -> bool:
	return _playing


func is_letterboxed() -> bool:
	return top_bar.position.y > -BAR_H + 0.5


## 检查过场数据：动作都认识、有台词或动作。返回问题列表。
func validate(id: String) -> Array[String]:
	var errors: Array[String] = []
	var cs := load_cutscene(id)
	if cs.is_empty():
		errors.append("过场 %s 不存在或解析失败" % id)
		return errors
	for st in cs.get("steps", []):
		for a in st.get("actions", []):
			if not ACTIONS.has(str(a.get("do", ""))):
				errors.append("过场 %s：不认识的动作 %s" % [id, a.get("do", "")])
	return errors


func play(id: String) -> void:
	var cs := load_cutscene(id)
	if cs.is_empty():
		push_warning("没有过场: " + id)
		return
	await play_data(id, cs)


## 直接播放一段过场数据（测试、代码生成的过场用）。
func play_data(id: String, cs: Dictionary) -> void:
	if _playing:
		return
	_playing = true
	_skip = false
	current = id
	_can_skip = bool(cs.get("skippable", true)) and GameState.has_flag("cutscene_seen_" + id)
	GameState.in_cutscene = true
	GameState.in_dialogue = true
	started.emit(id)
	var hud := _hud()
	if hud and cs.get("hide_hud", true):
		_hud_was_visible = hud.visible
		hud.hide()
	skip_label.visible = _can_skip
	if is_instance_valid(GameState.player) and GameState.player.camera:
		_cam_base = GameState.player.camera.position
		_cam_zoom = GameState.player.camera.zoom
	var tw := create_tween().set_parallel()
	tw.tween_property(top_bar, "position:y", 0.0, 0.4)
	tw.tween_property(bottom_bar, "position:y", 270.0 - BAR_H, 0.4)
	await tw.finished
	var steps: Array = cs.get("steps", [])
	for i in steps.size():
		step_index = i
		if _skip:
			_run_instant(steps.slice(i))
			break
		await _run_step(steps[i])
	await _finish(id, cs)


# ------------------------------------------------------------------ 步骤
func _run_step(st: Dictionary) -> void:
	var longest := 0.0
	for a in st.get("actions", []):
		longest = maxf(longest, _do(a, false))
	# 过场里接人物对话（带选项，选择记忆）或小剧场：演完再往下走
	if st.has("talk"):
		var tk: Dictionary = st["talk"]
		await Dialogue.talk(str(tk.get("file", "")), str(tk.get("node", "")))
	if st.has("theater"):
		await CG.play_theater(str(st["theater"]))
	if st.has("text"):
		var line := {"speaker": st.get("speaker", ""), "text": st["text"]}
		if st.has("emotion"):
			line["emotion"] = st["emotion"]
		if st.has("npc"):
			line["npc"] = st["npc"]
		Dialogue.start_lines([line], "cutscene:" + current)
		if st.has("auto"):
			await _wait(float(st["auto"]))
			if Dialogue.is_active():
				Dialogue.advance()
				Dialogue.advance()
		else:
			while Dialogue.is_active() and not _skip:
				await get_tree().process_frame
	else:
		await _wait(float(st.get("wait", longest)))


## 跳过：剩下步骤里会改变结果的动作立即生效。
func _run_instant(steps: Array) -> void:
	if Dialogue.is_active():
		Dialogue.advance()
		Dialogue.advance()
	for st in steps:
		for a in st.get("actions", []):
			if str(a.get("do", "")) in ["set_flag", "chapter_end", "spawn", "despawn", "move", "carry", "pose", "face"]:
				_do(a, true)


func _finish(id: String, cs: Dictionary) -> void:
	GameState.set_flag("cutscene_seen_" + id)
	_reset_camera(0.3)
	var keep_screen := chapter_screen.visible
	var tw := create_tween().set_parallel()
	tw.tween_property(top_bar, "position:y", -BAR_H, 0.35)
	tw.tween_property(bottom_bar, "position:y", 270.0, 0.35)
	if not keep_screen:
		tw.tween_property(curtain, "color:a", 0.0, 0.35)
	await tw.finished
	var hud := _hud()
	if hud and cs.get("hide_hud", true) and _hud_was_visible and not keep_screen:
		hud.show()
	skip_label.hide()
	if is_instance_valid(GameState.player):
		GameState.player.set("puppet_walking", false)
	_carrier = null
	GameState.in_cutscene = false
	GameState.in_dialogue = Dialogue.is_active()
	_playing = false
	step_index = -1
	finished.emit(id)


## 章节结束画面：按 E 进入下一章（chapter_end 写了 next）。
func continue_chapter() -> void:
	if chapter_next == "" or not chapter_screen.visible:
		return
	var next := chapter_next
	chapter_next = ""
	chapter_hint.hide()
	var main := get_tree().get_first_node_in_group("main")
	if main:
		await main.change_level(Floors.scene(next))
	chapter_screen.hide()
	curtain.color.a = 0.0
	var hud := _hud()
	if hud:
		hud.show()


func _input(event: InputEvent) -> void:
	if chapter_screen.visible and chapter_next != "" and not _playing and event.is_pressed() and not event.is_echo() \
			and (event.is_action("interact") or event.is_action("ui_accept") or event.is_action("attack")):
		get_viewport().set_input_as_handled()
		continue_chapter()
		return
	if not _playing or not _can_skip or not event.is_pressed() or event.is_echo():
		return
	if event.is_action("pause") or event.is_action("ui_cancel"):
		_skip = true
		get_viewport().set_input_as_handled()


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()


func _process(_delta: float) -> void:
	# 抱着公主走
	if _carrier and is_instance_valid(_carrier) and is_instance_valid(GameState.player):
		GameState.player.global_position = _carrier.global_position + Vector2(0, -8)


# ------------------------------------------------------------------ 动作
func _do(a: Dictionary, instant: bool) -> float:
	var d := str(a.get("do", ""))
	var who := _actor(str(a.get("who", "")))
	var t := 0.0 if instant else float(a.get("time", 0.0))
	match d:
		"move":
			if who == null:
				return 0.0
			var to := cell_to_world(a["to"]) if a.has("to") else who.global_position
			var dur := t
			if a.has("speed") and not instant:
				dur = who.global_position.distance_to(to) / maxf(float(a["speed"]), 1.0)
			if dur <= 0.0:
				who.global_position = to
				return 0.0
			_face(who, (to - who.global_position).normalized())
			var walks := "puppet_walking" in who
			if walks:
				who.set("puppet_walking", true)
			# 演员的 tween（演员被 despawn 时跟着停）
			var tw := who.create_tween()
			tw.tween_property(who, "global_position", to, dur)
			if walks:
				tw.tween_callback(who.set.bind("puppet_walking", false))
			return dur
		"face":
			if who:
				_face(who, Trap.dir_vector(str(a.get("dir", "down"))))
		"pose":
			var p := GameState.player
			if not is_instance_valid(p):
				return 0.0
			if a.has("emotion"):
				GameState.emote(str(a["emotion"]), 0.0)
			if a.has("laugh") and p.laugh:
				p.laugh.set_value(p.laugh.max_value * float(a["laugh"]) / 100.0)
			if a.has("faint"):
				_faint(p, bool(a["faint"]))
			# 被刑具固定的姿势：restrain = {rotation 弧度, offset [x, y]}，false = 恢复
			if a.has("restrain"):
				var r: Variant = a["restrain"]
				if r is Dictionary:
					p.pose_rotation = float(r.get("rotation", 0.0))
					var o: Array = r.get("offset", [0, 0])
					p.pose_offset = Vector2(float(o[0]), float(o[1]))
				else:
					p.pose_rotation = 0.0
					p.pose_offset = Vector2.ZERO
		"camera":
			return _camera(a, t)
		"shake":
			if not instant:
				_shake(t if t > 0.0 else 0.4, float(a.get("strength", 3.0)))
		"fade_out", "fade_in":
			var target := 1.0 if d == "fade_out" else 0.0
			if t <= 0.0:
				curtain.color.a = target
			else:
				create_tween().tween_property(curtain, "color:a", target, t)
		"flash":
			flash_rect.color.a = 0.8
			create_tween().tween_property(flash_rect, "color:a", 0.0, t if t > 0.0 else 0.3)
		"bubble":
			if who == GameState.player:
				GameState.bubble_requested.emit(str(a.get("kind", "surprise")))
			elif who:
				SpeechBubble.say(who, str(BUBBLE_TEXT.get(str(a.get("kind", "")), "！")), 24.0)
		"say":
			if who:
				SpeechBubble.say(who, str(a.get("text", "")), 30.0)
		"tickle":
			return _tickle(a, instant)
		"trap":
			if who is Trap:
				_trap_show(who as Trap, float(a.get("time", 0.8)))
		"hold":
			_hold(who, bool(a.get("on", true)), bool(a.get("place", true)))
		"spawn":
			_spawn(a)
		"despawn":
			if who and who != GameState.player:
				spawned.erase(str(a.get("who", "")))
				# 淡出再删掉（走到一半离场也不突兀）
				var tw := who.create_tween()
				tw.tween_property(who, "modulate:a", 0.0, 0.0 if instant else 0.3)
				tw.tween_callback(who.queue_free)
		"carry":
			_carrier = who if bool(a.get("on", true)) else null
			if _carrier:
				_process(0.0)
		"wait":
			return t
		"sfx":
			if not instant:
				Audio.play(str(a.get("sound", "")), float(a.get("volume", 0.0)), 0.0, float(a.get("pitch", 1.0)))
		"voice":
			Audio.set_voice_state(str(a.get("state", "")))
		"set_flag":
			GameState.set_flag(str(a.get("flag", "")))
		"notify":
			if not instant:
				GameState.notify(str(a.get("text", "")))
		"chapter_end":
			chapter_title.text = str(a.get("title", "完"))
			chapter_sub.text = str(a.get("subtitle", ""))
			chapter_next = str(a.get("next", ""))
			chapter_hint.visible = chapter_next != ""
			chapter_screen.modulate.a = 0.0 if not instant else 1.0
			chapter_screen.show()
			if not instant:
				create_tween().tween_property(chapter_screen, "modulate:a", 1.0, 1.2)
				return 1.2
	return t


## 格子 -> 世界坐标（角色脚下：格子中心往下 4 像素，和构建器放角色的位置一致）。
static func cell_to_world(c: Variant) -> Vector2:
	return Vector2(float(c[0]) * 16.0 + 8.0, float(c[1]) * 16.0 + 12.0)


func _level() -> Node:
	var m := get_tree().get_first_node_in_group("main")
	return m.get("level") if m else null


func _hud() -> CanvasLayer:
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n is HUD:
			return n
	return null


func _actor(actor_name: String) -> Node2D:
	if actor_name == "":
		return null
	if actor_name == "princess":
		return GameState.player
	if spawned.has(actor_name) and is_instance_valid(spawned[actor_name]):
		return spawned[actor_name]
	var lv := _level()
	return lv.find_child(actor_name, true, false) as Node2D if lv else null


func _face(who: Node2D, dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	if "facing" in who:
		who.set("facing", dir)
	var spr := who.get_node_or_null("Sprite") as Sprite2D
	if spr and absf(dir.x) > 0.1 and not (who is PlayableCharacter):
		spr.flip_h = dir.x < 0.0


## 昏迷：小人躺倒变暗；faint = false 时起身。
func _faint(p: PlayableCharacter, on: bool) -> void:
	if p.sprite == null:
		return
	if on:
		Audio.set_voice_state("")
		var tw := create_tween().set_parallel()
		tw.tween_property(p.sprite, "rotation", PI / 2.0, 0.4)
		tw.tween_property(p.sprite, "modulate", Color(0.6, 0.55, 0.7), 0.6)
		p.set_meta("fainted", true)
	else:
		p.sprite.rotation = 0.0
		p.sprite.modulate = Color.WHITE
		p.remove_meta("fainted")


func _camera(a: Dictionary, t: float) -> float:
	var p := GameState.player
	if not is_instance_valid(p) or p.camera == null:
		return 0.0
	var cam := p.camera
	if _cam_tween:
		_cam_tween.kill()
	if a.get("reset", false):
		_reset_camera(t)
		return t
	var target := cam.global_position
	if a.has("to"):
		target = cell_to_world(a["to"]) - Vector2(0, 4)
	elif a.has("who") and _actor(str(a["who"])):
		target = _actor(str(a["who"])).global_position
	var offset := target - p.global_position + Vector2(0, _cam_base.y)
	if t <= 0.0:
		_cam_tween = null
		cam.position = offset
		if a.has("zoom"):
			cam.zoom = Vector2.ONE * 2.0 * float(a["zoom"])
		return 0.0
	_cam_tween = create_tween().set_parallel()
	_cam_tween.tween_property(cam, "position", offset, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if a.has("zoom"):
		_cam_tween.tween_property(cam, "zoom", Vector2.ONE * 2.0 * float(a["zoom"]), t)
	return t


func _reset_camera(t: float) -> void:
	var p := GameState.player
	if not is_instance_valid(p) or p.camera == null:
		return
	var cam := p.camera
	if t <= 0.0:
		cam.position = _cam_base
		cam.zoom = _cam_zoom
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(cam, "position", _cam_base, t)
	tw.tween_property(cam, "zoom", _cam_zoom, t)


func _shake(time: float, strength: float) -> void:
	var p := GameState.player
	if not is_instance_valid(p) or p.camera == null:
		return
	var cam := p.camera
	var tw := create_tween()
	var steps := maxi(2, int(time / 0.05))
	for i in steps:
		var k := 1.0 - float(i) / steps
		tw.tween_property(cam, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * k, 0.05)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)


## 公主的表现挠痒：抖动、命中特效、果冻音效、立绘抖动；add = 每下加的闷笑百分比。
func _tickle(a: Dictionary, instant: bool) -> float:
	var p := GameState.player
	if instant or not is_instance_valid(p):
		return 0.0
	var by := _actor(str(a.get("by", "")))
	var n := int(a.get("repeat", 3))
	var every := float(a.get("interval", 0.3))
	var fx := str(a.get("fx", HitFx.kind_of(by) if by else "feather"))
	var add := float(a.get("add", 0.0))
	# zone：挠的部位（部位专属特效、立绘上的部位贴片和飘字）
	var zone := str(a.get("zone", ""))
	var tw := create_tween()
	for i in n:
		tw.tween_callback(func():
			if not is_instance_valid(p):
				return
			p.shake(0.2)
			Audio.play("tickle", -3.0, 0.1)
			HitFx.play(fx if fx != "" else "feather", p.get_parent(), p.global_position + Vector2(randf_range(-6, 6), -10))
			if zone != "":
				ZoneFx.play(zone, p.get_parent(), ZoneFx.body_point(p, zone), 1.0, true)
				Dialogue.portrait_fx.cutscene_tickle(fx, zone)
			else:
				Dialogue.shake_portrait(3.0, 0.18)
			if add > 0.0 and p.laugh:
				p.laugh.set_value(minf(p.laugh.value + p.laugh.max_value * add / 100.0, p.laugh.max_value * 0.99)))
		tw.tween_interval(every)
	return n * every


## 刑具一直扣着公主（只有表现，直到 hold on=false）：合上刑具、把公主放到刑具上（place）、摆刑具的姿势、播被困动画。
func _hold(trap: Node, on: bool, place: bool) -> void:
	var p := GameState.player
	if not (trap is Trap) or not is_instance_valid(p):
		return
	var spr: Sprite2D = trap.get("sprite")
	if spr and spr.hframes > 1:
		spr.frame_coords.x = 1 if on else 0
	if on:
		if place:
			p.global_position = trap.call("_hold_point") if trap.has_method("_hold_point") else (trap as Node2D).global_position
			p.pose_offset = trap.get("pose_offset") if trap.get("pose_offset") != null else Vector2.ZERO
			p.pose_rotation = float(trap.get("pose_rotation")) if trap.get("pose_rotation") != null else 0.0
		p.set("puppet_anim", "grabbed")
		Audio.play("stocks", -4.0, 0.08)
	else:
		p.pose_offset = Vector2.ZERO
		p.pose_rotation = 0.0
		p.set("puppet_anim", "")


## 陷阱演一次发动（只有表现：GameState.in_dialogue 期间陷阱不会真的生效）。
func _trap_show(trap: Trap, time: float) -> void:
	if trap.has_method("play_show"):
		trap.call("play_show", time)
		return
	trap._enter(Trap.Phase.ACTIVE)
	var ref: WeakRef = weakref(trap)
	get_tree().create_timer(time).timeout.connect(func():
		var tr: Trap = ref.get_ref()
		if tr:
			tr._enter(Trap.Phase.IDLE))


func _spawn(a: Dictionary) -> void:
	var id := str(a.get("id", ""))
	var kind := str(a.get("kind", "shadow"))
	var lv := _level()
	if id == "" or lv == null:
		return
	var parent: Node = lv.get_node_or_null("Entities")
	if parent == null:
		parent = lv
	var n: Node2D
	if kind == "shadow":
		n = make_shadow()
	elif kind.begins_with("npc:"):
		var r: Node2D = load("res://scenes/actors/allies/resident.tscn").instantiate()
		r.set("npc_id", kind.trim_prefix("npc:"))
		r.set("wander", 0.0)
		n = r
	elif kind.begins_with("monster:"):
		var path := str(CG.data.get("actors", {}).get(kind.trim_prefix("monster:"), {}).get("scene", ""))
		if path == "" or not ResourceLoader.exists(path):
			return
		n = load(path).instantiate()
		n.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		return
	n.name = "Cutscene_" + id
	parent.add_child(n)
	n.global_position = cell_to_world(a.get("at", [0, 0]))
	if a.has("dir"):
		_face(n, Trap.dir_vector(str(a["dir"])))
	spawned[id] = n


## 黑影：复制公主当前的精灵、蒙上近黑的紫色，脚下飘暗紫色的粒子。
func make_shadow() -> Node2D:
	var root := Node2D.new()
	var p := GameState.player
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	if is_instance_valid(p) and p.sprite:
		spr.texture = p.sprite.texture
		spr.hframes = p.sprite.hframes
		spr.vframes = p.sprite.vframes
		spr.frame = p.sprite.frame
		spr.offset = p.sprite.offset
		spr.region_enabled = p.sprite.region_enabled
		spr.region_rect = p.sprite.region_rect
	spr.modulate = SHADOW_COLOR
	spr.scale = Vector2(1.15, 1.15)
	root.add_child(spr)
	Fx.emitter(root, "dust", 10, 1.0, {"offset": Vector2(0, -4), "extents": Vector2(6, 2), "dir": Vector2.UP, "speed": [6.0, 14.0],
			"color": Color(0.35, 0.1, 0.5, 0.8), "z": 1})
	root.set_meta("shadow", true)
	return root
