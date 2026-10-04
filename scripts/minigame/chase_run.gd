class_name ChaseRun
extends Node2D
## 巨石追逐（第八层打赢 Boss 之后的小游戏，地图里放一个：X = f8chase）。
##   两条并排的竖直跑道（地图里的到达点 lane_a / lane_b = 两条跑道第 0 格的中心）。主画面跟着玩家操控的人（A / D 左右），
##   右边小窗（SideWindow）跟着另一个（← / → 左右）。两个人都自动往下跑。
##   进度 0 ~ CELLS 格：两人从 START 格出发，每 STEP_TIME 秒前进一格；巨石从第 0 格开始，每 BOULDER_TIME 秒往前滚一格。
##   跑道上随机放障碍（按 seed，两条不同）：幽灵手套 / 羽毛小精灵（左右飘）、史莱姆、毛毛虫、羽毛陷阱、落笼影子、足枷台。
##   碰到障碍：后退一格 + 被对应来源挠的反馈（她自己的反应、表情、笑声、特效），短暂无敌。
##   失败：巨石追上任何一人，或两人相差超过 MAX_GAP 格 → 追逐失败小剧场 → 从头再来。成功：两人都到第 CELLS 格 → 结局过场。

signal finished(ok: bool)

const CELLS := 10
const CELL_PX := 96.0
const LANE_HALF := 34.0
const START := 3.0
const STEP_TIME := 2.2
const BOULDER_TIME := 3.0
const MAX_GAP := 4.0
const SIDE_SPEED := 80.0
const INVULN := 1.0
const PINK_SCENE := "res://scenes/actors/playable/princess.tscn"
const BOULDER_TEX := preload("res://assets/generated/boulder.png")
const OBSTACLES := {
	"glove": {"scene": "res://scenes/actors/monsters/ghost_glove.tscn", "key": "glove", "fx": "hand", "moving": true},
	"fairy": {"scene": "res://scenes/actors/monsters/fairy_swarm.tscn", "key": "fairy", "fx": "feather", "moving": true},
	"slime": {"scene": "res://scenes/actors/monsters/slime.tscn", "key": "slime", "fx": "goo"},
	"caterpillar": {"scene": "res://scenes/actors/monsters/caterpillar.tscn", "key": "caterpillar", "fx": "feather"},
	"feather": {"scene": "res://scenes/traps/feather_trap.tscn", "key": "feather", "fx": "feather"},
	"cage": {"scene": "res://scenes/traps/cage.tscn", "key": "cage", "fx": "feather"},
	"stocks": {"scene": "res://scenes/traps/stocks.tscn", "key": "stocks", "fx": "hand"},
}

## 测试里可以关掉开场倒计时 / 固定随机种子。
static var countdown := true
static var seed_value := -1

var a: PlayableCharacter
var b: PlayableCharacter
var pa := START
var pb := START
var boulder := 0.0
var running := false
var lane_a := Vector2.ZERO
var lane_b := Vector2.ZERO
var xa := 0.0
var xb := 0.0
var obstacles: Array[Dictionary] = []
var window: SideWindow
var hits := {"a": 0, "b": 0}
var _boulder_t := 0.0
var _inv := {"a": 0.0, "b": 0.0}
var _boulders: Array[Sprite2D] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("chase_run")
	await get_tree().process_frame
	await get_tree().process_frame
	var lv := _level()
	for sp in get_tree().get_nodes_in_group("spawn_point"):
		if lv.is_ancestor_of(sp):
			match str(sp.get("id")):
				"lane_a": lane_a = (sp as Node2D).global_position
				"lane_b": lane_b = (sp as Node2D).global_position
	a = GameState.player
	b = load(PINK_SCENE).instantiate()
	b.name = "Pink"
	b.faction = Faction.Type.ALLY
	b.set_controller(ScriptedController.new())
	lv.get_node("Entities").add_child(b)
	if b.camera:
		b.camera.enabled = false
	a.set_controller(ScriptedController.new())
	for i in 2:
		var s := Sprite2D.new()
		s.texture = BOULDER_TEX
		s.hframes = 4
		s.scale = Vector2(2.2, 2.2)
		s.z_index = 4
		add_child(s)
		_boulders.append(s)
	start()


func _level() -> Node2D:
	var n: Node = get_parent()
	while n and not n.has_node("Walls"):
		n = n.get_parent()
	return n as Node2D


func _exit_tree() -> void:
	if is_instance_valid(window):
		window.close(true)
	PlayerInputController.wasd_only = false


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
	_spawn_obstacles()
	for c in [a, b]:
		c.revive()
		c._set_state(PlayableCharacter.State.IDLE)
		c.facing = Vector2.DOWN
	_place()
	if a.camera:
		a.camera.zoom = Vector2(1.5, 1.5)
		a.camera.reset_smoothing()
	if not is_instance_valid(window):
		window = SideWindow.open(b, {"title": "%s  ← →" % b.display_name(), "zoom": 1.5, "offset": Vector2(0, 30)})
	PlayerInputController.wasd_only = true
	if countdown:
		for n in ["3", "2", "1", "跑！"]:
			GameState.notify(n)
			Audio.play("chime", -6.0, 0.0, 1.0 if n != "跑！" else 1.4)
			await get_tree().create_timer(0.6).timeout
	running = true


func _spawn_obstacles() -> void:
	for o in obstacles:
		if is_instance_valid(o["node"]):
			o["node"].queue_free()
	obstacles.clear()
	var kinds := OBSTACLES.keys()
	for lane in ["a", "b"]:
		var cell := START + 0.7
		while cell < CELLS - 0.4:
			var kind: String = kinds[_rng.randi() % kinds.size()]
			var info: Dictionary = OBSTACLES[kind]
			var n: Node2D = load(info["scene"]).instantiate()
			n.process_mode = Node.PROCESS_MODE_DISABLED
			add_child(n)
			var x := _rng.randf_range(-LANE_HALF + 8.0, LANE_HALF - 8.0)
			obstacles.append({"lane": lane, "cell": cell, "x": x, "base_x": x, "node": n, "kind": kind, "hit": false,
				"phase": _rng.randf() * TAU})
			cell += _rng.randf_range(0.55, 1.05)
	_place()


func _lane_origin(lane: String) -> Vector2:
	return lane_a if lane == "a" else lane_b


func pos_of(lane: String, cell: float, x: float) -> Vector2:
	return _lane_origin(lane) + Vector2(x, cell * CELL_PX)


func _place() -> void:
	a.global_position = pos_of("a", pa, xa)
	b.global_position = pos_of("b", pb, xb)
	for o in obstacles:
		if is_instance_valid(o["node"]):
			(o["node"] as Node2D).global_position = pos_of(o["lane"], o["cell"], o["x"])
	for i in _boulders.size():
		_boulders[i].global_position = pos_of(["a", "b"][i], boulder, 0.0) + Vector2(0, -12)


func _physics_process(delta: float) -> void:
	_t += delta
	if not running or GameState.in_dialogue:
		return
	# 左右：主画面的人 A / D，小窗的人 ← / →
	var da := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var db := float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
	move(da, db, delta)
	advance(delta)


## 左右移动（测试也直接调它）。
func move(da: float, db: float, delta: float) -> void:
	xa = clampf(xa + da * SIDE_SPEED * delta, -LANE_HALF, LANE_HALF)
	xb = clampf(xb + db * SIDE_SPEED * delta, -LANE_HALF, LANE_HALF)


## 前进一步：两人自动往下跑、巨石滚动、碰障碍、判定输赢。
func advance(delta: float) -> void:
	for k in _inv:
		_inv[k] = maxf(0.0, _inv[k] - delta)
	pa = minf(CELLS, pa + delta / STEP_TIME)
	pb = minf(CELLS, pb + delta / STEP_TIME)
	_boulder_t += delta
	if _boulder_t >= BOULDER_TIME:
		_boulder_t -= BOULDER_TIME
		roll_boulder()
	for o in obstacles:
		if OBSTACLES[o["kind"]].get("moving", false):
			o["x"] = clampf(o["base_x"] + sin(_t * 2.2 + o["phase"]) * 18.0, -LANE_HALF, LANE_HALF)
		if o["hit"]:
			continue
		var p := pa if o["lane"] == "a" else pb
		var x := xa if o["lane"] == "a" else xb
		if absf(o["cell"] - p) * CELL_PX < 10.0 and absf(o["x"] - x) < 13.0 and _inv[o["lane"]] <= 0.0:
			hit(o)
	for c in [a, b]:
		c.puppet_walking = true
		c.facing = Vector2.DOWN
	_place()
	check_end()


func roll_boulder() -> void:
	boulder += 1.0
	Audio.play("roll", -2.0, 0.05, 0.7)
	for s in _boulders:
		var tw := s.create_tween()
		for f in 4:
			tw.tween_callback(func(): s.frame = (s.frame + 1) % 4)
			tw.tween_interval(0.06)
	for c in [a, b]:
		c.shake(0.15)


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
	Fx.burst(_level(), c.global_position + Vector2(0, -10), str(info["fx"]), 6, 40.0, 0.5, Vector2(0, 20))
	c.shake(0.2)
	Characters.scope(c.character_id)
	var lines := ReactionDB.lines(str(info["key"]), "helpless_1")
	Characters.unscope()
	if not lines.is_empty():
		SpeechBubble.say(c, str(lines.pick_random()).left(14), 28.0)
	if c.emotion:
		c.emotion.request("helpless_1", 0.9, false)
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
		if a.camera:
			a.camera.zoom = Vector2.ONE
		GameState.set_flag("f8_done")
		await Cutscene.play("f8_ending")
		return
	GameState.vars["f8_chase_fail"] = int(GameState.vars.get("f8_chase_fail", 0)) + 1
	await get_tree().create_timer(0.5).timeout
	await CG.play_theater("f8_chase_fail")
	start()
