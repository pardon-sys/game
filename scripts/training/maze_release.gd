extends CanvasLayer
## 训练二：魔力疲倦释放（训练迷宫）。TrainingDB.run 创建、await run(训练, "")。
## 流程：营地里走到训练场东边的迷宫入口（地图过场）→ 换到训练迷宫 floor_06_training → 玩家操控公主去主动触发房间里的组合
## → 逃到出口 / Esc / 倒下结束 → 回到营地迷宫入口旁，返回 {successes, gained, reason}。
## 规则：
##   每触发一次迷宫里的组合（COMBOS，ComboTracker.triggered）：魔力疲倦上限 -1、疲倦释放强度 +0.5%（per_success，立刻记上）。
##   组合触发后 DEVOTION_WINDOW 秒内魔力疲倦满了释放 → 这次的提升 ×5（再补 4 份），播这个组合的奉献小剧场 train_release_<组合>。
##   逃离冲动：每隔一阵（越触发越频繁）公主会忍不住往出口跑——控制权被抢走（EscapeController 沿 BFS 最短路跑向出口），
##     连按空格拖慢她（最近 1 秒按得越多越慢），方向键还能把她往陷阱那边拽；冲动持续的时间、跑的速度随触发次数增加。
##   公主逃到出口 = 失败，这一轮结束（已经拿到的保留）。训练中不播组合的第一次小演出（ComboTracker.play_scenes）。
## 测试可以直接调 start_escape() / stop_escape() / mash() / quit()，time_scale 加速。

const MAZE := "floor_06_training"
const CAMP := "floor_06_camp"
const GATE_CELL := Vector2i(46, 20)
const COMBOS := ["boots_clamp_crawl", "legloop_lick", "foot_thigh_lock", "pincer_stocks", "rack_crawl", "swing_frenzy",
	"ring_binding", "foot_bubble", "bath_trio", "spring_feather", "saddle_brush", "scissor_brush"]
const DEVOTION_WINDOW := 6.0
const DEVOTION_MULT := 5
const URGE_LINES := ["不、不行……太痒了，我要出去！", "腿、腿自己往外跑了——！", "再待下去会笑坏的……出口在哪……！",
	"脚……脚不听使唤了！", "只、只跑一下下……！"]
const CALM_LINES := ["……呼。不行，要坚持训练。", "回、回来了……再试一次。", "为了变强……忍住……！"]
const PINK := Color(1, 0.72, 0.86)
const GOLD := Color(1, 0.86, 0.4)
const TEXT := Color(0.95, 0.92, 0.98)
const BAD := Color(1.0, 0.4, 0.45)


## 逃离冲动时的输入：沿 BFS 最短路跑向出口（每 0.5 秒重新找一次路），速度 = pace；方向键再加一点拽力。
class EscapeController extends WanderController:
	var exit_pos := Vector2.ZERO
	var _repath := 0.0

	func _ready() -> void:
		super()
		_wait = 0.0
		pace = 0.6

	func _physics_process(delta: float) -> void:
		_repath -= delta
		if _repath <= 0.0:
			_repath = 0.5
			path.clear()
			_wait = 0.0
		super(delta)

	func _pick_target() -> void:
		var lv := _level()
		if lv == null:
			_wait = 0.5
			return
		_blocked_cache.clear()   # 门会被打开
		var route := _bfs(_cell(body.global_position), _cell(exit_pos), lv.get_node("Walls"), lv.get_node("Floor"))
		path.clear()
		for c in route:
			path.append(_center(c))
		if path.is_empty():
			_wait = 0.3

	func _arrive() -> void:
		_wait = 0.1

	func get_move_vector() -> Vector2:
		if GameState.in_dialogue or GameState.in_cutscene:
			return Vector2.ZERO
		var pull := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		return (_move + pull * 0.5).limit_length(1.0)


var t: Dictionary = {}
var stage_info: Dictionary = {}
var successes := 0
var gained := {}
var devotions := 0
## esc 自己结束 / escaped 逃到出口 / down 倒下
var reason := ""
var playing := false
var quitting := false
var escaping := false
var time_scale := 1.0
var player: PlayableCharacter
var main: Node
var rng := RandomNumberGenerator.new()
var urge_t := 8.0
var urge_left := 0.0
var escape_ctrl: EscapeController
var last_combo := ""
var last_combo_t := -INF
var exit_pos := Vector2.ZERO
var _clock := 0.0
var _mash: Array[float] = []
var _orig_ctrl: CharacterController
var _play_scenes := true
var _panel: Panel
var _info: Label
var _urge_label: Label
var _urge_bar: ColorRect


func run(info: Dictionary, _zone: String) -> Dictionary:
	t = info
	stage_info = TrainingStats.stage(t)
	rng.randomize()
	layer = 12
	main = get_tree().get_first_node_in_group("main")
	_build_ui()
	await _intro()
	_begin()
	while not quitting:
		await get_tree().process_frame
	await _end()
	return {"successes": successes, "gained": gained, "reason": reason}


func quit(why := "esc") -> void:
	if playing and not quitting:
		reason = why
		quitting = true


# ------------------------------------------------------------------ 进出迷宫
func _level() -> Node:
	return main.get("level") if main else null


func _in_level(id: String) -> bool:
	var lv := _level()
	return lv != null and str(lv.scene_file_path) == Floors.scene(id)


func _intro() -> void:
	if _in_level(CAMP) and is_instance_valid(GameState.player):
		await Cutscene.play_data("training_maze_in", {"name": "去训练迷宫", "skippable": true, "steps": [
			{"actions": [{"do": "camera", "to": [GATE_CELL.x, GATE_CELL.y], "time": 0.8},
				{"do": "move", "who": "princess", "to": [GATE_CELL.x, GATE_CELL.y], "speed": 60}]},
			{"speaker": "保卫队员", "text": "魔力疲倦释放训练——迷宫里每个房间都有一组机关。主动去踩，忍不住想逃的时候就连按空格拖住自己！"},
			{"speaker": "公主", "text": "主、主动去踩……为了变强，我会努力的！", "emotion": "shy"},
		]})
	if not _in_level(MAZE) and main:
		GameState.pending_spawn = "maze_start"
		await main.change_level(Floors.scene(MAZE))
		await get_tree().process_frame
	_find_spawn_points()


func _find_spawn_points() -> void:
	player = GameState.player
	var lv := _level()
	if lv == null:
		return
	for n in lv.find_children("*", "", true, false):
		if n is SpawnPoint and (n as SpawnPoint).id == "maze_exit":
			exit_pos = (n as Node2D).global_position
		elif n.get("target_level") != null and n.has_method("resolve_target"):
			n.set("_used", true)   # 训练中出口的楼梯不直接换地图（由这里判定逃离）


func _begin() -> void:
	_play_scenes = ComboTracker.play_scenes
	ComboTracker.play_scenes = false
	if is_instance_valid(player):
		player.combo.triggered.connect(_on_combo)
		player.magic_event.connect(_on_magic)
		player.died.connect(_on_died)
	urge_t = _urge_delay() + 2.0
	_panel.show()
	playing = true
	_update_ui()


func _end() -> void:
	playing = false
	stop_escape(false)
	ComboTracker.play_scenes = _play_scenes
	if is_instance_valid(player):
		for sig in [[player.combo.triggered, _on_combo], [player.magic_event, _on_magic], [player.died, _on_died]]:
			if sig[0].is_connected(sig[1]):
				sig[0].disconnect(sig[1])
	_panel.hide()
	# 等演出 / 倒下 CG 播完
	var g := 0
	while (CG.is_busy() or Cutscene.is_playing()) and g < 1200:
		await get_tree().process_frame
		g += 1
	if is_instance_valid(player):
		if not player.is_alive():
			player.revive()
		if player.status and player.status.is_grabbed():
			player.status.release(true)
	if main and not _in_level(CAMP):
		GameState.pending_spawn = "from_training"
		await main.change_level(Floors.scene(CAMP))
		await get_tree().process_frame
	player = GameState.player
	var line: String = str({"esc": "今天就练到这儿！触发了 %d 次——辛苦了。", "escaped": "……跑回出口了啊。没关系，触发了 %d 次，下次再坚持久一点！",
		"down": "笑、笑晕过去了？！……先休息吧，触发了 %d 次。"}.get(reason, "辛苦了！触发了 %d 次。")) % successes
	if is_instance_valid(player) and _level() != null:
		await Cutscene.play_data("training_maze_out", {"name": "训练结束", "skippable": true, "steps": [{"speaker": "保卫队员", "text": line}]})


# ------------------------------------------------------------------ 规则
func _urge_delay() -> float:
	return maxf(3.0, rng.randf_range(7.0, 12.0) * pow(0.93, successes))


func urge_duration() -> float:
	return minf(6.0, 2.5 + successes * 0.25)


func base_pace() -> float:
	return minf(1.0, 0.55 + successes * 0.04)


## 最近 1 秒连按空格的次数 → 速度打折（每下 -16%，最低 12%）。
func mash_rate() -> int:
	return _mash.filter(func(x): return _clock - x <= 1.0).size()


func pace_now() -> float:
	return base_pace() * clampf(1.0 - mash_rate() * 0.16, 0.12, 1.0)


func mash() -> void:
	_mash.append(_clock)
	if _mash.size() > 20:
		_mash = _mash.slice(-20)


func start_escape() -> void:
	if escaping or not is_instance_valid(player):
		return
	escaping = true
	urge_left = urge_duration()
	_orig_ctrl = player.controller
	escape_ctrl = EscapeController.new()
	escape_ctrl.name = "EscapeController"
	escape_ctrl.exit_pos = exit_pos
	player.add_child(escape_ctrl)
	player.controller = escape_ctrl
	escape_ctrl.pace = pace_now()
	SpeechBubble.say(player, URGE_LINES[rng.randi() % URGE_LINES.size()], 30.0)
	GameState.emote("helpless_1", 1.5, false)
	Audio.play("swish", -4.0, 0.1, 0.8)


func stop_escape(calm := true) -> void:
	if not escaping:
		return
	escaping = false
	if is_instance_valid(player):
		if is_instance_valid(_orig_ctrl):
			player.controller = _orig_ctrl
		if calm:
			SpeechBubble.say(player, CALM_LINES[rng.randi() % CALM_LINES.size()], 30.0)
	if is_instance_valid(escape_ctrl):
		escape_ctrl.queue_free()
	escape_ctrl = null
	urge_t = _urge_delay()


func _gain(mult: float) -> Dictionary:
	var got := {}
	var per: Dictionary = t.get("per_success", {})
	for k in per:
		var a := TrainingStats.add(str(k), float(per[k]) * mult)
		got[k] = a
		gained[k] = float(gained.get(k, 0.0)) + a
	return got


func _on_combo(id: String) -> void:
	if not playing or not (id in COMBOS):
		return
	successes += 1
	last_combo = id
	last_combo_t = _clock
	_gain(1.0)
	GameState.notify("触发「%s」：魔力疲倦上限 -1，释放强度 +0.5%%" % ReactionDB.combo(id).get("name", id))
	Audio.play("chime", -6.0)
	_update_ui()


## 组合触发后不久魔力疲倦满了释放：这次的提升 ×5，播奉献小剧场。
func _on_magic(kind: String, _level_i: int) -> void:
	if not playing or kind != "fatigue_burst" or last_combo == "" or _clock - last_combo_t > DEVOTION_WINDOW:
		return
	var combo := last_combo
	last_combo = ""
	devotions += 1
	_gain(DEVOTION_MULT - 1.0)
	GameState.notify("为了训练坚持到魔力释放——这次的提升 ×%d！" % DEVOTION_MULT)
	stop_escape(false)
	_update_ui()
	var id := "train_release_" + combo
	if CG.has_theater(id):
		CG.play_theater(id)


func _on_died(_a: Actor) -> void:
	quit("down")


func _input(event: InputEvent) -> void:
	if not playing or quitting or CG.is_playing() or Dialogue.is_active():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var kc: int = (event as InputEventKey).keycode
	if kc == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		quit("esc")
	elif kc == KEY_SPACE and escaping:
		get_viewport().set_input_as_handled()
		mash()


func _process(delta: float) -> void:
	if not playing or quitting:
		return
	_update_ui()
	if GameState.in_dialogue or CG.is_playing():
		return
	var dt := delta * time_scale
	_clock += dt
	tick(dt)


func tick(dt: float) -> void:
	if not is_instance_valid(player):
		return
	if exit_pos != Vector2.ZERO and player.global_position.distance_to(exit_pos) < 14.0:
		quit("escaped")
		return
	if escaping:
		urge_left -= dt
		if is_instance_valid(escape_ctrl):
			escape_ctrl.pace = pace_now()
		if urge_left <= 0.0:
			stop_escape()
	else:
		urge_t -= dt
		if urge_t <= 0.0:
			if player.status and player.status.is_grabbed():
				urge_t = 0.5   # 被困着跑不了：松开再说
			else:
				start_escape()


# ------------------------------------------------------------------ 界面（右上角的小面板）
func _build_ui() -> void:
	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.16, 0.88)
	sb.border_color = GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(152, 4)
	_panel.size = Vector2(176, 50)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.hide()
	add_child(_panel)
	_info = Label.new()
	_info.add_theme_color_override("font_color", TEXT)
	_info.add_theme_font_size_override("font_size", 8)
	_info.position = Vector2(5, 2)
	_panel.add_child(_info)
	_urge_label = Label.new()
	_urge_label.add_theme_color_override("font_color", BAD)
	_urge_label.add_theme_font_size_override("font_size", 8)
	_urge_label.position = Vector2(5, 26)
	_panel.add_child(_urge_label)
	_urge_bar = ColorRect.new()
	_urge_bar.color = BAD
	_urge_bar.position = Vector2(5, 42)
	_urge_bar.size = Vector2(0, 3)
	_panel.add_child(_urge_bar)


func _update_ui() -> void:
	if _info == null:
		return
	_info.text = "魔力疲倦释放训练　触发 %d 次\n上限 -%d　强度 +%.1f%%　Esc 结束" % [successes,
		roundi(float(gained.get("train_fatigue_down", 0.0))), float(gained.get("train_burst_power", 0.0))]
	if escaping:
		_urge_label.text = "逃离冲动！连按空格拖住她（%d）" % mash_rate()
		_urge_bar.size.x = roundf(166.0 * clampf(urge_left / maxf(urge_duration(), 0.1), 0.0, 1.0))
	else:
		_urge_label.text = ""
		_urge_bar.size.x = 0.0
