class_name ChaseRun
extends Node2D
## 巨石追逐（第八层打赢 Boss 之后的小游戏，地图里放一个：X = f8chase；第八层专属）。
##   画面：主画面和右边的小窗（SideWindow half 模式）并列、一样大，镜头不放大。主画面里是玩家操控的人（A / D 或 ← / →），
##         小窗里是另一个（AI 控制：看前方的障碍往空的地方让，反应有快有慢）。按 C 切换操控（主画面和小窗跟着换人）。
##   无限延伸：两个人在画面上方三分之一处一直往下跑，跑道（地板、两边的墙和火把）和障碍以 SPEED 的速度往上滚，
##         障碍在画面下方不停生成（像神庙逃亡），两条跑道各自随机。
##         进度越往后，人在画面里越往下（最多 DRIFT）；巨石也往下，移得比人多（BOULDER_DRIFT），但始终在人上方、画在人后面。
##   进度 0 ~ CELLS 格：两人从 START 格出发，每 STEP_TIME 秒前进一格；巨石从第 0 格开始，每 BOULDER_TIME 秒往前滚一格
##         （画面上：巨石在两人身后，离得越近越大越震）。屏幕上方有进度条。
##   碰到障碍：后退一格 + 被对应来源挠的反馈（她自己的反应、表情、笑声、特效），短暂无敌。
##   失败：巨石追上任何一人，或两人相差超过 MAX_GAP 格 → 追逐失败小剧场 → 从头再来。成功：两人都到第 CELLS 格 → 结局过场。

signal finished(ok: bool)

const CELLS := 10
const START := 3.0
const STEP_TIME := 2.2
const BOULDER_TIME := 3.0
const MAX_GAP := 4.0
const SPEED := 150.0
const LANE_HALF := 38.0
const SIDE_SPEED := 95.0
const INVULN := 1.0
## 障碍生成的间隔（秒，每条跑道）：一屏（约 1.8 秒）4~6 个
const SPAWN_GAP := Vector2(0.3, 0.45)
const RUN_Y := 90.0        # 人在画面里的高度（离画面顶，起点时）
const DRIFT := 36.0        # 从起点跑到终点，人在画面里往下移多少
const BOULDER_DRIFT := 60.0
## 巨石底边离人的脚至少这么远（盖到头顶为止，画在人后面）
const BOULDER_CLEAR := 20.0
## AI：往前看多远的障碍、多久重新决定一次往哪让（秒）、偶尔反应慢的几率
const AI_LOOK := 100.0
const AI_REACT := Vector2(0.15, 0.32)
const AI_SLOW := 0.15
const VIEW_H := 270.0
const PINK_SCENE := "res://scenes/actors/playable/princess.tscn"
const BOULDER_TEX := preload("res://assets/generated/boulder.png")
const TILES := preload("res://assets/third_party/kenney_tiny_dungeon/tilemap_packed.png")
const TORCH_SCENE := "res://scenes/objects/torch.tscn"
const OBSTACLES := {
	"glove": {"scene": "res://scenes/actors/monsters/ghost_glove.tscn", "key": "glove", "fx": "hand", "moving": true},
	"fairy": {"scene": "res://scenes/actors/monsters/fairy_swarm.tscn", "key": "fairy", "fx": "feather", "moving": true},
	"slime": {"scene": "res://scenes/actors/monsters/slime.tscn", "key": "slime", "fx": "goo"},
	"caterpillar": {"scene": "res://scenes/actors/monsters/caterpillar.tscn", "key": "caterpillar", "fx": "feather"},
	"feather": {"scene": "res://scenes/traps/feather_trap.tscn", "key": "feather", "fx": "feather"},
	"cage": {"scene": "res://scenes/traps/cage.tscn", "key": "cage", "fx": "feather"},
	"stocks": {"scene": "res://scenes/traps/stocks.tscn", "key": "stocks", "fx": "hand"},
}
## 两条跑道在世界里的位置（远离地图，互不干扰）：lane_a 在主画面，lane_b 在小窗。
const LANE_ORIGIN := {"a": Vector2(240, 3000), "b": Vector2(1240, 3000)}

## 测试里可以关掉开场倒计时 / 固定随机种子。
static var countdown := true
static var seed_value := -1

var a: PlayableCharacter
var b: PlayableCharacter
var pa := START
var pb := START
var boulder := 0.0
var running := false
var xa := 0.0
var xb := 0.0
## 跑道上的障碍：{lane, y（相对人所在高度，正数在下面）, x, base_x, node, kind, hit, phase}
var obstacles: Array[Dictionary] = []
var spawned := 0
var scroll := 0.0
var window: SideWindow
var hits := {"a": 0, "b": 0}
var _boulder_t := 0.0
var _spawn_t := {"a": 0.0, "b": 0.2}
var _inv := {"a": 0.0, "b": 0.0}
var _boulders := {}
var _tracks := {}
var _bar: Control
var _bar_layer: CanvasLayer
var _t := 0.0
var _rng := RandomNumberGenerator.new()
## 玩家操控的是哪条跑道（a = 一开始的主角，b = 另一个）；另一条 AI 控制
var player_lane := "a"
var _ai_rng := RandomNumberGenerator.new()
var _ai_target := 0.0
var _ai_t := 0.0
var _drift := {"a": 0.0, "b": 0.0}


func _ready() -> void:
	add_to_group("chase_run")
	await get_tree().process_frame
	await get_tree().process_frame
	var lv := _level()
	a = GameState.player
	b = load(PINK_SCENE).instantiate()
	b.name = "Pink"
	b.faction = Faction.Type.ALLY
	b.set_controller(ScriptedController.new())
	lv.get_node("Entities").add_child(b)
	if b.camera:
		b.camera.enabled = false
	a.set_controller(ScriptedController.new())
	# 人画在巨石和障碍上面
	for c in [a, b]:
		c.z_index = 2
	for lane in ["a", "b"]:
		_tracks[lane] = _make_track(lane)
		var s := Sprite2D.new()
		s.texture = BOULDER_TEX
		s.hframes = 4
		s.z_index = 1
		add_child(s)
		_boulders[lane] = s
	_make_bar()
	start()


func _level() -> Node2D:
	var n: Node = get_parent()
	while n and not n.has_node("Walls"):
		n = n.get_parent()
	return n as Node2D


func _exit_tree() -> void:
	if is_instance_valid(window):
		window.close(true)
	if is_instance_valid(_bar_layer):
		_bar_layer.queue_free()


# ------------------------------------------------------------------ 跑道（会滚动的地板、墙、火把）
func _atlas(idx: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = TILES
	at.region = Rect2((idx % 12) * 16, (idx / 12) * 16, 16, 16)
	return at


func _make_track(lane: String) -> Node2D:
	var root := Node2D.new()
	root.name = "Track_" + lane
	root.z_index = -1
	add_child(root)
	root.global_position = LANE_ORIGIN[lane]
	var floor_rect := TextureRect.new()
	floor_rect.texture = _atlas(48)
	floor_rect.stretch_mode = TextureRect.STRETCH_TILE
	floor_rect.size = Vector2(LANE_HALF * 2.0 + 16.0, VIEW_H + 64.0)
	floor_rect.position = Vector2(-LANE_HALF - 8.0, -RUN_Y - 32.0)
	floor_rect.name = "Floor"
	root.add_child(floor_rect)
	for side in [-1, 1]:
		var wall := TextureRect.new()
		wall.texture = _atlas(40)
		wall.stretch_mode = TextureRect.STRETCH_TILE
		wall.size = Vector2(32, VIEW_H + 64.0)
		wall.position = Vector2(-LANE_HALF - 8.0 - 32.0 if side < 0 else LANE_HALF + 8.0, -RUN_Y - 32.0)
		wall.name = "Wall%d" % side
		root.add_child(wall)
		var dark := ColorRect.new()
		dark.color = Color(0.04, 0.02, 0.06)
		dark.size = Vector2(120, VIEW_H + 64.0)
		dark.position = Vector2(-LANE_HALF - 8.0 - 32.0 - 120.0 if side < 0 else LANE_HALF + 40.0, -RUN_Y - 32.0)
		root.add_child(dark)
	# 两边墙上的火把（跟着跑道往上滚，滚出画面从下面再进来）
	var torches := Node2D.new()
	torches.name = "Torches"
	root.add_child(torches)
	for i in 4:
		for side in [-1, 1]:
			var t: Node2D = load(TORCH_SCENE).instantiate()
			t.set("lit", true)
			torches.add_child(t)
			t.position = Vector2(side * (LANE_HALF + 16.0), -RUN_Y + i * 90.0 + (45.0 if side > 0 else 0.0))
	return root


func _scroll_track(lane: String, delta: float) -> void:
	var root: Node2D = _tracks[lane]
	var off := fmod(scroll, 16.0)
	for n in ["Floor", "Wall-1", "Wall1"]:
		var r := root.get_node_or_null(n) as Control
		if r:
			r.position.y = -RUN_Y - 32.0 - off
	for t in root.get_node("Torches").get_children():
		var tn := t as Node2D
		tn.position.y -= SPEED * delta
		if tn.position.y < -RUN_Y - 30.0:
			tn.position.y += 360.0


# ------------------------------------------------------------------ 开始 / 摆位
## 从头开始（第一次 / 失败重来）。
func start() -> void:
	pa = START
	pb = START
	boulder = 0.0
	xa = 0.0
	xb = 0.0
	hits = {"a": 0, "b": 0}
	_boulder_t = 0.0
	_inv = {"a": 0.0, "b": 0.0}
	_rng.seed = seed_value if seed_value >= 0 else randi()
	for o in obstacles:
		if is_instance_valid(o["node"]):
			o["node"].queue_free()
	obstacles.clear()
	# 开场先在画面下方铺几个
	for lane in ["a", "b"]:
		var y := 70.0
		while y < VIEW_H:
			_spawn_obstacle(lane, y)
			y += _rng.randf_range(45.0, 70.0)
	for c in [a, b]:
		c.revive()
		c._set_state(PlayableCharacter.State.IDLE)
		c.facing = Vector2.DOWN
	_drift = {"a": 0.0, "b": 0.0}
	_ai_rng.seed = _rng.seed + 7
	_ai_target = 0.0
	_place()
	if not is_instance_valid(window):
		window = SideWindow.open(ai_char(), {"half": true, "zoom": 1.0, "offset": Vector2(0, VIEW_H / 2.0 - RUN_Y)})
	_setup_views()
	PlayerInputController.wasd_only = true
	if countdown:
		for n in ["3", "2", "1", "跑！"]:
			GameState.notify(n)
			Audio.play("chime", -6.0, 0.0, 1.0 if n != "跑！" else 1.4)
			await get_tree().create_timer(0.6).timeout
	running = true


func _spawn_obstacle(lane: String, y: float) -> void:
	var kinds := OBSTACLES.keys()
	var kind: String = kinds[_rng.randi() % kinds.size()]
	var n: Node2D = load(OBSTACLES[kind]["scene"]).instantiate()
	n.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(n)
	var x := _rng.randf_range(-LANE_HALF + 6.0, LANE_HALF - 6.0)
	obstacles.append({"lane": lane, "y": y, "x": x, "base_x": x, "node": n, "kind": kind, "hit": false, "phase": _rng.randf() * TAU})
	spawned += 1


func run_pos(lane: String) -> Vector2:
	return LANE_ORIGIN[lane] + Vector2(xa if lane == "a" else xb, _drift[lane])


func char_of(lane: String) -> PlayableCharacter:
	return a if lane == "a" else b


func ai_lane() -> String:
	return "b" if player_lane == "a" else "a"


func player_char() -> PlayableCharacter:
	return char_of(player_lane)


func ai_char() -> PlayableCharacter:
	return char_of(ai_lane())


# ------------------------------------------------------------------ 操控 / 镜头 / 切换
## 主画面跟着玩家操控的人，小窗跟着 AI 控制的人。
func _setup_views() -> void:
	var main := player_char()
	for c in [a, b]:
		if c.camera:
			c.camera.enabled = c == main
	if main.camera:
		var cam := main.camera
		cam.zoom = Vector2.ONE
		cam.limit_left = -100000
		cam.limit_top = -100000
		cam.limit_right = 100000
		cam.limit_bottom = 100000
		# 主画面只露出左半边：镜头往右偏 1/4 屏，人在左半屏中间；往下偏，人在画面上方三分之一
		# （用镜头的 position 偏移：offset 会被震屏改写）
		cam.position_smoothing_enabled = false
		cam.make_current()
		_update_cams()
		cam.reset_smoothing()
	if is_instance_valid(window):
		window.target = ai_char()
		window.set_hint("%s（AI）　[C] 切换" % ai_char().display_name())


## 镜头跟着画面里的位置：人往下移（drift）时镜头不跟，看起来人在画面里往下跑。
func _update_cams() -> void:
	var vp := get_viewport().get_visible_rect().size
	var main := player_char()
	if main.camera:
		main.camera.position = Vector2(vp.x / 4.0, VIEW_H / 2.0 - RUN_Y - _drift[player_lane])
	if is_instance_valid(window):
		window.cam_offset = Vector2(0, VIEW_H / 2.0 - RUN_Y - _drift[ai_lane()])


## 按 C：切换操控的人（主画面、小窗、HUD 跟着换）。
func switch_lane() -> void:
	player_lane = ai_lane()
	_ai_target = xa if ai_lane() == "a" else xb
	GameState.switch_control(player_char())
	# 跑的时候两个人的位置都由这里控制（不吃普通的移动输入，免得转向）
	for c in [a, b]:
		c.set_controller(ScriptedController.new())
	_setup_views()
	GameState.notify("操控：%s" % player_char().display_name())


func _unhandled_input(event: InputEvent) -> void:
	if not running or GameState.in_dialogue:
		return
	var k := event as InputEventKey
	if (k and k.pressed and not k.echo and k.physical_keycode == KEY_C) or event.is_action_pressed("switch_character"):
		get_viewport().set_input_as_handled()
		switch_lane()


## AI：每隔一小会儿看一眼前方 AI_LOOK 内的障碍，挑一个离障碍最远、又不用挪太远的位置；偶尔反应慢（不重新看）。
func ai_input(delta: float) -> float:
	var lane := ai_lane()
	var x := xa if lane == "a" else xb
	_ai_t -= delta
	if _ai_t <= 0.0:
		_ai_t = _ai_rng.randf_range(AI_REACT.x, AI_REACT.y)
		if _ai_rng.randf() >= AI_SLOW:
			_ai_target = ai_pick_x(lane, x)
	var diff := _ai_target - x
	return 0.0 if absf(diff) < 2.0 else clampf(diff / 8.0, -1.0, 1.0)


func ai_pick_x(lane: String, x: float) -> float:
	var best := x
	var best_cost := INF
	var cx := -LANE_HALF
	while cx <= LANE_HALF:
		var cost := absf(cx - x) * 0.02
		for o in obstacles:
			if o["lane"] != lane or o["hit"]:
				continue
			var ahead: float = o["y"] - _drift[lane]
			if ahead < -6.0 or ahead > AI_LOOK:
				continue
			var dx := absf(o["x"] - cx)
			if dx < 18.0:
				cost += (18.0 - dx) * (1.0 + (AI_LOOK - ahead) / AI_LOOK * 3.0)
		if cost < best_cost:
			best_cost = cost
			best = cx
		cx += 4.0
	return best


func _place() -> void:
	a.global_position = run_pos("a")
	b.global_position = run_pos("b")
	for o in obstacles:
		if is_instance_valid(o["node"]):
			(o["node"] as Node2D).global_position = LANE_ORIGIN[o["lane"]] + Vector2(o["x"], o["y"])
	for lane in ["a", "b"]:
		var p := pa if lane == "a" else pb
		var gap := clampf(p - boulder, 0.0, 6.0)
		var s: Sprite2D = _boulders[lane]
		s.scale = Vector2.ONE * lerpf(2.6, 1.6, gap / 6.0)
		# 巨石在身后（画面上方）：差一格约 12 像素，越近越大；随进度往下移得比人多，但底边不超过人的头顶
		var y := -26.0 - gap * 12.0 + clampf(boulder / CELLS, 0.0, 1.0) * BOULDER_DRIFT
		y = minf(y, boulder_max_y(lane, s.scale.y))
		s.global_position = LANE_ORIGIN[lane] + Vector2(0, y)
		s.frame = int(_t * 10.0) % 4


## 巨石中心最低能到哪（相对跑道原点）：底边离人的脚 BOULDER_CLEAR。
func boulder_max_y(lane: String, scale_y: float) -> float:
	var half := BOULDER_TEX.get_height() * scale_y / 2.0
	return _drift[lane] - BOULDER_CLEAR - half


func _update_drift(delta: float) -> void:
	for lane in ["a", "b"]:
		var p := pa if lane == "a" else pb
		var want := clampf((p - START) / (CELLS - START), 0.0, 1.0) * DRIFT
		_drift[lane] = move_toward(_drift[lane], want, 30.0 * delta)


# ------------------------------------------------------------------ 每帧
func _physics_process(delta: float) -> void:
	_t += delta
	if not running or GameState.in_dialogue:
		return
	var right := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var left := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var d := float(right) - float(left)
	var ai := ai_input(delta)
	if player_lane == "a":
		move(d, ai, delta)
	else:
		move(ai, d, delta)
	advance(delta)


## 左右移动（测试也直接调它）。
func move(da: float, db: float, delta: float) -> void:
	xa = clampf(xa + da * SIDE_SPEED * delta, -LANE_HALF, LANE_HALF)
	xb = clampf(xb + db * SIDE_SPEED * delta, -LANE_HALF, LANE_HALF)


## 前进一步：跑道滚动、障碍上移 / 生成、两人进度、巨石、碰撞、判定输赢。
func advance(delta: float) -> void:
	for k in _inv:
		_inv[k] = maxf(0.0, _inv[k] - delta)
	scroll += SPEED * delta
	for lane in ["a", "b"]:
		_scroll_track(lane, delta)
		_spawn_t[lane] -= delta
		if _spawn_t[lane] <= 0.0:
			_spawn_t[lane] = _rng.randf_range(SPAWN_GAP.x, SPAWN_GAP.y)
			_spawn_obstacle(lane, VIEW_H - RUN_Y + 20.0)
	pa = minf(CELLS, pa + delta / STEP_TIME)
	pb = minf(CELLS, pb + delta / STEP_TIME)
	_boulder_t += delta
	if _boulder_t >= BOULDER_TIME:
		_boulder_t -= BOULDER_TIME
		roll_boulder()
	for o in obstacles.duplicate():
		o["y"] -= SPEED * delta
		if OBSTACLES[o["kind"]].get("moving", false):
			o["x"] = clampf(o["base_x"] + sin(_t * 2.6 + o["phase"]) * 20.0, -LANE_HALF, LANE_HALF)
		if o["y"] < -RUN_Y - 30.0:
			if is_instance_valid(o["node"]):
				o["node"].queue_free()
			obstacles.erase(o)
			continue
		if o["hit"]:
			continue
		var x := xa if o["lane"] == "a" else xb
		if absf(o["y"] - _drift[o["lane"]]) < 9.0 and absf(o["x"] - x) < 13.0 and _inv[o["lane"]] <= 0.0:
			hit(o)
	for c in [a, b]:
		c.puppet_walking = true
		c.facing = Vector2.DOWN
	_update_drift(delta)
	_place()
	_update_cams()
	_bar.queue_redraw()
	check_end()


func roll_boulder() -> void:
	boulder += 1.0
	Audio.play("roll", -2.0, 0.05, 0.7)
	for c in [a, b]:
		var gap := (pa if c == a else pb) - boulder
		c.shake(0.3 if gap < 1.5 else 0.12)


## 碰到障碍：后退一格 + 被挠的反馈。
func hit(o: Dictionary) -> void:
	o["hit"] = true
	var lane: String = o["lane"]
	var c: PlayableCharacter = a if lane == "a" else b
	hits[lane] += 1
	_inv[lane] = INVULN
	if lane == "a":
		pa = maxf(0.0, pa - 1.0)
	else:
		pb = maxf(0.0, pb - 1.0)
	var info: Dictionary = OBSTACLES[o["kind"]]
	Fx.burst(c.get_parent(), c.global_position + Vector2(0, -10), str(info["fx"]), 6, 40.0, 0.5, Vector2(0, 20))
	c.shake(0.2)
	Characters.scope(c.character_id)
	var lines := ReactionDB.lines(str(info["key"]), "helpless_1")
	Characters.unscope()
	if not lines.is_empty():
		SpeechBubble.say(c, str(lines.pick_random()).left(14), 28.0)
	# 表情只换成闷笑（还在往下跑）；失控的姿势是坐倒的，跑的时候不用
	if c.emotion:
		c.emotion.request("giggle", 0.9, false)
	Audio.play(Audio.voice_key("giggle") if c == GameState.player else "tickle", -4.0, 0.05)
	var n: Node2D = o["node"]
	if is_instance_valid(n):
		var tw := n.create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 0.4)


func check_end() -> void:
	if boulder >= pa or boulder >= pb:
		end(false, "boulder")
	elif absf(pa - pb) > MAX_GAP:
		end(false, "gap")
	elif pa >= CELLS and pb >= CELLS:
		end(true, "")


func end(ok: bool, reason: String) -> void:
	if not running:
		return
	running = false
	finished.emit(ok)
	print("追逐战：%s %s" % ["成功" if ok else "失败", reason])
	for c in [a, b]:
		c.puppet_walking = false
	if ok:
		if is_instance_valid(window):
			window.close()
		PlayerInputController.wasd_only = false
		# 结局过场按一开始的主角来：操控换回去
		if player_lane != "a":
			player_lane = "a"
			GameState.switch_control(a)
			a.set_controller(ScriptedController.new())
			b.set_controller(ScriptedController.new())
		for c in [a, b]:
			c.z_index = 0
			if c.camera:
				c.camera.position = Vector2.ZERO
		GameState.set_flag("f8_done")
		await Cutscene.play("f8_ending")
		return
	GameState.vars["f8_chase_fail"] = int(GameState.vars.get("f8_chase_fail", 0)) + 1
	await get_tree().create_timer(0.5).timeout
	await CG.play_theater("f8_chase_fail")
	start()


# ------------------------------------------------------------------ 进度条（屏幕上方）
func _make_bar() -> void:
	_bar_layer = CanvasLayer.new()
	_bar_layer.layer = 13
	add_child(_bar_layer)
	_bar = Control.new()
	_bar.position = Vector2(140, 4)
	_bar.size = Vector2(200, 16)
	_bar.draw.connect(_draw_bar)
	_bar_layer.add_child(_bar)


func _draw_bar() -> void:
	var w := _bar.size.x
	_bar.draw_rect(Rect2(0, 6, w, 5), Color(0.15, 0.1, 0.2, 0.9))
	_bar.draw_rect(Rect2(w - 3, 2, 3, 13), Color(1, 0.9, 0.4))
	var font := ThemeDB.fallback_font
	for item in [[boulder, Color(0.7, 0.66, 0.72), "石"], [pa, Color(0.75, 0.85, 1.0), "蓝" if a.character_id == "blue" else "粉"],
			[pb, Color(1, 0.6, 0.8), "粉" if b.character_id == "pink" else "蓝"]]:
		var x := clampf(float(item[0]) / CELLS, 0.0, 1.0) * w
		_bar.draw_circle(Vector2(x, 8.5), 4.0, item[1])
		_bar.draw_string(font, Vector2(x - 4, 22), str(item[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, item[1])
