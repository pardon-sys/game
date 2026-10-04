class_name StealthDirector
extends Node2D
## 潜入模式（可复用，每张潜入地图放一个）：active_flag 打开时生效（没写就一直生效）。
##   警觉值 alert（0~1）：被巡逻士兵看见时按距离上涨，看不见时慢慢回落；满了 = 被发现 → caught 信号 + 剧情处理（on_caught）。
##   躲藏：木箱 / 矿车（prop action=hide）按 E 躲进去（看不见、不能动），再按 E 出来。士兵经过时有几率检查。
##   丢石子：按 F（输入动作 throw，没有就自动加上）往面朝方向丢，落点附近的士兵会去查看。
##   脚步声：走动时每 STEP_INTERVAL 秒一下（STEP_RADIUS 内的士兵过来查看，冲刺时 DASH_RADIUS），站着不动没有声音；脚下冒一圈淡淡的波纹。
##   暗处：离光源（地图里的 PointLight2D：灯、火把、蜡烛）远的地方，士兵的视野只有一半（VisionCone.lights）。
## 图例：X = stealth [active_flag=f6_escape] [on_caught=f6]

signal caught(by: Node)

const STONE_RANGE := 72.0
const NOISE_RADIUS := 150.0
const STEP_INTERVAL := 0.5
const STEP_RADIUS := 64.0
const DASH_RADIUS := 128.0

static var current: StealthDirector

@export var active_flag := ""
## 被发现后交给谁处理：f6 = F6Story.on_caught()。
@export var on_caught := ""
@export var alert_rate := 1.4
@export var alert_decay := 0.3

var alert := 0.0
var caught_done := false
var hidden_in: Node2D
var _stone_cd := 0.0
var _step_t := 0.0
var _hud: CanvasLayer
var _bar: ColorRect
var _bar_bg: ColorRect
var _mark: Label


func _ready() -> void:
	current = self
	add_to_group("stealth_director")
	if not InputMap.has_action("throw"):
		InputMap.add_action("throw")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F
		InputMap.action_add_event("throw", ev)
	_build_hud()
	_collect_lights.call_deferred()


func _exit_tree() -> void:
	if current == self:
		current = null
	if hidden_in:
		_unhide()


func is_active() -> bool:
	return active_flag == "" or GameState.has_flag(active_flag)


## node 和这个导演在同一张地图里。
func is_ancestor_of_level(node: Node) -> bool:
	var lv := get_parent()
	while lv and not lv.has_node("Walls"):
		lv = lv.get_parent()
	return lv != null and lv.is_ancestor_of(node)


func is_player_hidden() -> bool:
	return hidden_in != null


func _collect_lights() -> void:
	VisionCone.lights.clear()
	var lv := get_parent()
	while lv and not lv.has_node("Walls"):
		lv = lv.get_parent()
	if lv == null:
		return
	for l in lv.find_children("*", "PointLight2D", true, false):
		VisionCone.lights.append((l as Node2D).global_position)


# ------------------------------------------------------------------ 躲藏
static func toggle_hide(player: Node, spot: Node2D) -> void:
	if current == null or not current.is_active():
		GameState.notify("（现在没必要躲起来）")
		return
	if current.hidden_in:
		current._unhide()
	else:
		current._hide_in(player as PlayableCharacter, spot)


func _hide_in(p: PlayableCharacter, spot: Node2D) -> void:
	if p == null or caught_done:
		return
	hidden_in = spot
	p.global_position = spot.global_position + Vector2(0, 2)
	p.visible = false
	p.process_mode = Node.PROCESS_MODE_DISABLED
	Audio.play("cloth", -6.0)
	GameState.notify("躲起来了（再按 E 出来）")


func _unhide() -> void:
	var p := GameState.player
	var spot := hidden_in
	hidden_in = null
	if is_instance_valid(p):
		p.process_mode = Node.PROCESS_MODE_INHERIT
		p.visible = true
		if is_instance_valid(spot):
			p.global_position = spot.global_position + Vector2(0, 14)
	Audio.play("cloth", -6.0)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active() or caught_done or GameState.in_dialogue:
		return
	if hidden_in and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_unhide()
	elif not hidden_in and event.is_action_pressed("throw"):
		get_viewport().set_input_as_handled()
		throw_stone()


# ------------------------------------------------------------------ 丢石子
func throw_stone() -> bool:
	var p := GameState.player
	if _stone_cd > 0.0 or not is_instance_valid(p):
		return false
	_stone_cd = 1.2
	var from := p.global_position + Vector2(0, -8)
	var dir: Vector2 = p.get("facing") if p.get("facing") is Vector2 and (p.get("facing") as Vector2).length() > 0.1 else Vector2.DOWN
	var to := from + dir.normalized() * STONE_RANGE
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and not (hit.get("collider") is CharacterBody2D):
		to = (hit["position"] as Vector2) - dir.normalized() * 4.0
	var stone := Sprite2D.new()
	stone.name = "Stone"
	stone.texture = Fx.PARTICLES["chip"]
	stone.modulate = Color(0.75, 0.72, 0.7)
	stone.scale = Vector2(2, 2)
	stone.z_index = 5
	get_parent().add_child(stone)
	stone.global_position = from
	Audio.play("swish", -8.0, 0.1, 1.4)
	var tw := stone.create_tween()
	tw.tween_property(stone, "global_position", to, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		noise(to)
		stone.queue_free())
	return true


## 某处发出声音：radius 内的士兵去查看。返回被吸引过去的士兵数。footstep = 脚步声（只画波纹，声音小）。
func noise(pos: Vector2, radius := NOISE_RADIUS, footstep := false) -> int:
	if footstep:
		Audio.play("step", -14.0, 0.15, 0.9)
		_step_ring(pos + Vector2(0, 2), radius)
	else:
		Audio.play("pop", -4.0, 0.1, 0.8)
		Fx.puff(get_parent(), pos)
	var n := 0
	for g in get_tree().get_nodes_in_group("patrol_guard"):
		if is_ancestor_of_level(g) and (g as Node2D).global_position.distance_to(pos) <= radius and g.visible:
			g.investigate(pos)
			n += 1
	return n


# ------------------------------------------------------------------ 警觉
func _physics_process(delta: float) -> void:
	_stone_cd = maxf(0.0, _stone_cd - delta)
	var on := is_active() and not caught_done
	_hud.visible = on and (alert > 0.01 or hidden_in != null)
	if not on or GameState.in_dialogue:
		return
	var p := GameState.player
	if hidden_in and is_instance_valid(p):
		p.global_position = hidden_in.global_position + Vector2(0, 2)
	_footsteps(p, delta)
	var seen := 0.0
	for g in get_tree().get_nodes_in_group("patrol_guard"):
		if not is_ancestor_of_level(g):
			continue
		var s: float = g.sees(p) if is_instance_valid(p) and not hidden_in else 0.0
		g.cone.alerting = s > 0.0
		seen = maxf(seen, s)
	if seen > 0.0:
		alert = minf(1.0, alert + seen * alert_rate * delta)
	else:
		alert = maxf(0.0, alert - alert_decay * delta)
	_update_hud()
	if alert >= 1.0:
		_caught(null)


## 脚步声的波纹：从脚下扩散到声音范围的四分之一，不受暗处影响（看得清声音传多远）。
func _step_ring(pos: Vector2, radius: float) -> void:
	var l := Line2D.new()
	l.name = "StepRing"
	l.width = 1.5
	l.default_color = Color(1.0, 0.95, 0.8, 0.8)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	l.material = mat
	l.points = IceBarrier.ring_points(4.0, 24)
	l.z_index = 4
	get_parent().add_child(l)
	l.global_position = pos
	var tw := l.create_tween().set_parallel()
	tw.tween_method(func(r: float): l.points = IceBarrier.ring_points(r, 24), 4.0, radius * 0.25, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)


## 走动发出脚步声（站着不动、躲着时没有）。
func _footsteps(p: PlayableCharacter, delta: float) -> void:
	if not is_instance_valid(p) or hidden_in or p.velocity.length() < 8.0:
		_step_t = minf(_step_t, 0.15)   # 一迈步很快就有第一声
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = STEP_INTERVAL
		noise(p.global_position, DASH_RADIUS if p.is_dashing() else STEP_RADIUS, true)


## 士兵检查躲藏点时找到了人。
func found_hidden(by: Node) -> void:
	if caught_done:
		return
	SpeechBubble.say(by, "……找到了！", 26.0)
	_unhide()
	_caught(by)


func _caught(by: Node) -> void:
	if caught_done:
		return
	caught_done = true
	alert = 1.0
	_update_hud()
	Audio.play("locked", -2.0)
	caught.emit(by)
	match on_caught:
		"f6":
			F6Story.on_caught()


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 11
	add_child(_hud)
	_mark = Label.new()
	_mark.text = "！"
	_mark.position = Vector2(232, 14)
	_mark.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_hud.add_child(_mark)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.15, 0.1, 0.18, 0.85)
	_bar_bg.position = Vector2(200, 34)
	_bar_bg.size = Vector2(80, 5)
	_hud.add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = Color(1, 0.85, 0.3)
	_bar.size = Vector2(0, 5)
	_bar_bg.add_child(_bar)
	_hud.visible = false


func _update_hud() -> void:
	_bar.size.x = roundf(80.0 * alert)
	var col := Color(1, 0.85, 0.3).lerp(Color(1, 0.3, 0.3), alert)
	_bar.color = col
	_mark.add_theme_color_override("font_color", col)
	_mark.text = "（躲着）" if hidden_in and alert < 0.01 else "！"
