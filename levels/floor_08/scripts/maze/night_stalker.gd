class_name NightStalker
extends CharacterBody2D
## 夜啼追手（第八层夜迷宫的追逐怪）：一团长满手臂的影子，约两格高，两只紫眼。靠声音找人。
##   游荡：慢慢在走廊里晃。
##   听到她：她的笑声圈 × HEAR_MULT 够到它，或者 SIGHT 像素内看到她（墙挡视线）→ 沿走廊（GridPath）追过来：
##           速度 BASE_SPEED，她身上每有一只手 +HAND_SPEED，最多 MAX_SPEED（她平时走路约 76）。
##   跟丢：听不到也看不到她——她在憋笑（HoldLaugh）超过 LOSE_HOLD 秒，或者 LOSE_QUIET 秒都没动静 → 去最后听见的地方，
##         搜 SEARCH 秒，再回去游荡。
##   月光灯：不进去（她躲进灯里就在灯外徘徊一会儿再走）。冰晶结界冻住它 3 秒（maze_magic_reactive）。
##   抓到她：导演放一段小剧场（f8_maze_stalker_1 / 2 轮流）、身上加 2 只手、闷笑 +25；然后它缩回黑暗 RETREAT 秒。
##   第一次开追：屏幕中间黄字 + 低沉的轰鸣；追的时候配乐里多一层紧张的鼓点。
##   固定追逐（scripted_chase）：从她身后冒出来，一直追（不用听），直到她走进月光灯。
## 图例：X = nightstalker

signal caught_her
signal state_changed(s: String)

const TEX := preload("res://assets/generated/maze/night_stalker.png")
const LIGHT_TEX := preload("res://assets/lights/light_soft.tres")
const BASE_SPEED := 70.0
const HAND_SPEED := 4.0
const MAX_SPEED := 95.0
const SCRIPTED_SPEED := 72.0
const WANDER_SPEED := 18.0
const HEAR_MULT := 1.2
const SIGHT := 80.0
const CATCH := 12.0
const LOSE_HOLD := 2.0
const LOSE_QUIET := 6.0
const SEARCH := 4.0
const RETREAT := 25.0
const LAMP_MARGIN := 10.0

var state := "wander"
var director: MazeDirector
var last_heard := Vector2.INF
var sprite: Sprite2D
var glow: PointLight2D
var _t := 0.0
var _quiet := 0.0
var _search_t := 0.0
var _frozen := 0.0
var _retreat_t := 0.0
var _path: Array[Vector2] = []
var _repath := 0.0
var _dir := Vector2.ZERO
var _think := 0.0
var _scripted := false
var _drums: AudioStreamPlayer
var _drum_vol := -40.0


func _ready() -> void:
	add_to_group("night_stalker")
	add_to_group("maze_magic_reactive")
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 4.0
	shape.shape = c
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = TEX
	sprite.hframes = 3
	sprite.offset = Vector2(0, -18)
	add_child(sprite)
	glow = PointLight2D.new()
	glow.texture = LIGHT_TEX
	glow.texture_scale = 0.45
	glow.energy = 0.6
	glow.color = Color(0.75, 0.35, 1.0)
	glow.position = Vector2(0, -24)
	add_child(glow)
	_drums = AudioStreamPlayer.new()
	_drums.stream = Audio.loop_stream("chase_drums")
	_drums.volume_db = -40.0
	add_child(_drums)


func _dir_node() -> MazeDirector:
	if director == null or not is_instance_valid(director):
		director = MazeDirector.instance
	return director


func _set_state(s: String) -> void:
	if s == state:
		return
	var was := state
	state = s
	if s == "chase" and was != "chase":
		Audio.play("rumble", -4.0, 0.05, 1.1)
		if not GameState.has_flag("f8m_hint_stalker"):
			GameState.set_flag("f8m_hint_stalker")
			GameState.hint("有什么……在追我……")
		elif not _scripted:
			GameState.princess_reacted.emit(MazeLines.pick("stalker_seen"), 2.2)
	if was == "chase" and s == "search":
		GameState.princess_reacted.emit(MazeLines.pick("stalker_lost"), 2.2)
	state_changed.emit(s)


func is_chasing() -> bool:
	return state == "chase"


func on_ice(time: float) -> void:
	_frozen = maxf(_frozen, minf(time, 3.0))
	sprite.modulate = Color(0.7, 0.88, 1.35)


func is_frozen() -> bool:
	return _frozen > 0.0


## 她现在听得到 / 看得到吗（返回她的位置；听不到返回 INF）。
func sense() -> Vector2:
	var d := _dir_node()
	var p := GameState.player as PlayableCharacter
	if d == null or not is_instance_valid(p) or not p.is_alive():
		return Vector2.INF
	var dist := p.global_position.distance_to(global_position)
	var r := d.radius.radius() if d.radius else 0.0
	if r > 0.0 and dist <= r * HEAR_MULT:
		return p.global_position
	if dist <= SIGHT and not (d.light_at(p.global_position) is Vector2) and not _wall_between(p.global_position):
		return p.global_position
	return Vector2.INF


func _wall_between(to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -4), to + Vector2(0, -4), 1)
	q.collide_with_areas = false
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and not (hit.get("collider") is CharacterBody2D)


func chase_speed() -> float:
	if _scripted:
		return SCRIPTED_SPEED
	var p := GameState.player
	var hands := HandCover.of(p).total() if HandCover.of(p) else 0
	return minf(MAX_SPEED, BASE_SPEED + HAND_SPEED * hands)


## 固定追逐：从这里冒出来，一直追到她进月光灯。
func scripted_chase(from: Vector2) -> void:
	global_position = from
	_retreat_t = 0.0
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
	_scripted = true
	_set_state("chase")


## 抓到之后：缩回黑暗 RETREAT 秒，再从远处冒出来游荡。
func retreat(sec := RETREAT) -> void:
	_scripted = false
	_set_state("retreat")
	_retreat_t = sec
	_path.clear()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): visible = false)


func _physics_process(delta: float) -> void:
	_t += delta
	sprite.frame = 2 if state == "chase" and int(_t * 6.0) % 3 == 0 else int(_t * 4.0) % 2
	sprite.position.y = sin(_t * 3.0) * 1.0
	_update_drums(delta)
	var d := _dir_node()
	if d == null or GameState.in_dialogue or CG.is_busy() or Cutscene.is_playing() or d._busy:
		return
	if _frozen > 0.0:
		_frozen -= delta
		if _frozen <= 0.0:
			sprite.modulate = Color.WHITE
		return
	if state == "retreat":
		_retreat_t -= delta
		if _retreat_t <= 0.0:
			_reappear()
		return
	var p := GameState.player as PlayableCharacter
	if not is_instance_valid(p):
		return
	# 她在月光灯里：固定追逐到此为止；平时在灯外徘徊一会儿
	if d.light_at(p.global_position) is Vector2:
		if _scripted:
			_scripted = false
			GameState.princess_reacted.emit("……灯……！……呼……到、到了……", 2.4)
			retreat(10.0)
			return
		if state == "chase":
			last_heard = p.global_position
			_set_state("search")
			_search_t = SEARCH
	var heard := sense() if not _scripted else p.global_position
	if heard != Vector2.INF:
		last_heard = heard
		_quiet = 0.0
		_set_state("chase")
	elif state == "chase":
		_quiet += delta
		var holding := HoldLaugh.of(p) != null and HoldLaugh.of(p).holding
		if (holding and _quiet >= LOSE_HOLD) or _quiet >= LOSE_QUIET:
			_set_state("search")
			_search_t = SEARCH
	match state:
		"chase":
			_go_to(p.global_position if heard != Vector2.INF else last_heard, chase_speed(), delta)
			if p.global_position.distance_to(global_position) < CATCH and p.is_alive() and not d._busy:
				_catch(p)
		"search":
			_search_t -= delta
			if last_heard != Vector2.INF and global_position.distance_to(last_heard) > 6.0:
				_go_to(last_heard, BASE_SPEED * 0.6, delta)
			else:
				_wander(delta)
			if _search_t <= 0.0:
				_set_state("wander")
		_:
			_wander(delta)


func _go_to(goal: Vector2, speed: float, delta: float) -> void:
	var d := _dir_node()
	_repath -= delta
	if _repath <= 0.0 or _path.is_empty():
		_repath = 0.4
		_path = GridPath.find(d.level(), global_position, goal, 2500)
	while not _path.is_empty() and _path[0].distance_to(global_position) < 5.0:
		_path.remove_at(0)
	var step_to := goal if _path.is_empty() or goal.distance_to(global_position) < 18.0 else _path[0]
	var v := (step_to - global_position).normalized() * speed
	# 不进月光灯
	var next := global_position + v * delta
	for l in get_tree().get_nodes_in_group("moon_lamp"):
		var lamp := l as MoonLamp
		if lamp and lamp.lit and next.distance_to(lamp.global_position) < MoonLamp.RADIUS + LAMP_MARGIN:
			v = Vector2.ZERO
	velocity = v
	move_and_slide()


func _wander(delta: float) -> void:
	_think -= delta
	if _think <= 0.0 or get_slide_collision_count() > 0:
		_think = randf_range(1.2, 2.8)
		_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.75 else Vector2.ZERO
	velocity = _dir * WANDER_SPEED
	move_and_slide()


func _catch(p: PlayableCharacter) -> void:
	caught_her.emit()
	var d := _dir_node()
	if d and d.has_method("stalker_caught"):
		d.stalker_caught(self)
	else:
		retreat()


## 从离她远的地面上冒出来（不在光里）。
func _reappear() -> void:
	var d := _dir_node()
	var p := GameState.player as Node2D
	var best := global_position
	if d and is_instance_valid(p):
		for i in 40:
			var c: Vector2i = d._floor_cells.pick_random() if not d._floor_cells.is_empty() else GridPath.cell(global_position)
			var pos := GridPath.center(c)
			if pos.distance_to(p.global_position) > 220.0 and not (d.light_at(pos) is Vector2):
				best = pos
				break
	global_position = best
	visible = true
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)
	_set_state("wander")


func _update_drums(delta: float) -> void:
	if _drums.stream == null:
		return
	var want := -6.0 if state == "chase" and visible and not CG.is_busy() else -40.0
	_drum_vol = move_toward(_drum_vol, want, 40.0 * delta)
	_drums.volume_db = _drum_vol
	if _drum_vol > -39.0 and not _drums.playing:
		_drums.play()
	elif _drum_vol <= -39.0 and _drums.playing:
		_drums.stop()
