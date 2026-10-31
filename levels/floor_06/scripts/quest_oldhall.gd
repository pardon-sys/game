class_name QuestOldHall
extends QuestRunner
## 支线「夜里的栅栏」第五段「旧会堂」（floor_06_after_oldhall，很暗）：她举着火把（PointLight2D），火光照到的手印会退开。
##   火把每秒烧掉 1/BURN 的油（fuel），越烧越暗（光的半径 LIGHT_MIN ~ LIGHT_MAX）；墙边的旧烛台（CANDLES）旁按 E 续满。
##   手印（CurseHand，HANDS）：在光里就躲开；火灭了（fuel = 0）全都扑上来贴着挠，续上火才退。
##   高台底下的手印团（HandCluster，CLUSTER）：打它 / 蓝色公主冻它 → 裂成几块碎片，按住 Y 笑把碎片引过来收进瓶子（同手印样本）。
##   收齐 → 过场 kq_fence_hall_end（壁画上的人像全被刮花了）→ 这一段做完。
## 测试：fuel、light_r()、hands、cluster、shards、got、refuel_near()。

## 地图上的点（QuestMaps：旧会堂的布局在 tools/build/quest_maps.py）
static var CANDLES: Array[Vector2i] = QuestMaps.cells("floor_06_after_oldhall", "candles")
static var HANDS: Array[Vector2i] = QuestMaps.cells("floor_06_after_oldhall", "hands")
static var CLUSTER: Vector2i = QuestMaps.cell("floor_06_after_oldhall", "cluster")
const BURN := 22.0
const LIGHT_MIN := 14.0
const LIGHT_MAX := 56.0
const CANDLE_R := 18.0
const SEEK_R := 120.0

var fuel := 1.0
var hands: Array = []
var cluster: HandCluster
var shards: Array = []
var need := HandCluster.SPLIT
var got := 0
var _light: PointLight2D
var _out := false
var _warned := false


func hl() -> Dictionary:
	return q.get("hall", {})


func setup() -> void:
	fuel = 1.0
	if is_instance_valid(pink):
		_light = PointLight2D.new()
		_light.name = "HallTorch"
		_light.texture = preload("res://assets/lights/light_soft.tres")
		_light.color = Color(1.0, 0.75, 0.45)
		_light.energy = 1.4
		_light.position = Vector2(0, -10)
		pink.add_child(_light)
	for c in HANDS:
		var h := put(CurseHand.new(), Cutscene.cell_to_world(c)) as CurseHand
		hands.append(h)
	cluster = put(HandCluster.new(), Cutscene.cell_to_world(CLUSTER)) as HandCluster
	cluster.lines = {"split_line": [hl().get("split", "")]}
	cluster.split_into.connect(_on_split)
	_intro()


func _intro() -> void:
	if GameState.has_flag("kq_fence_hall_intro"):
		return
	GameState.set_flag("kq_fence_hall_intro")
	await get_tree().process_frame
	await TrainingDB.wait_dialogue_free()
	Dialogue.start_lines(hl().get("intro", []), "kq_hall_intro")


func cleanup() -> void:
	if is_instance_valid(_light):
		_light.queue_free()


func light_r() -> float:
	return lerpf(LIGHT_MIN, LIGHT_MAX, clampf(fuel, 0.0, 1.0)) if fuel > 0.0 else 0.0


func status() -> String:
	return str(hl().get("status", "%d%% %d/%d")) % [int(fuel * 100.0), got, need]


func _process(delta: float) -> void:
	if not live() or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink):
		return
	tick(delta)
	var p := GameState.player
	if Input.is_action_just_pressed("interact"):
		refuel_near(p)
		for s in shards:
			if is_instance_valid(s):
				(s as HandShard).bottle(p)
	if Input.is_action_just_pressed("attack") and is_instance_valid(cluster) and not cluster.done:
		if p == blue and cluster.global_position.distance_to(p.global_position) <= 40.0:
			cluster.split()
		else:
			cluster.try_hit(p)
	if p == pink and KnightLaugh.tick(pink, delta):
		for s in shards:
			if is_instance_valid(s):
				(s as HandShard).lure(pink)


func tick(delta: float) -> void:
	fuel = maxf(0.0, fuel - delta / BURN)
	if is_instance_valid(_light):
		_light.texture_scale = (light_r() * 1.4 / 80.0 + 0.05 * sin(Time.get_ticks_msec() / 70.0)) * IsoView.ground_scale().x
		_light.visible = fuel > 0.0
	if fuel < 0.25 and not _warned:
		_warned = true
		say(hl().get("dim", []), 1.6)
	if fuel <= 0.0 and not _out:
		_out = true
		say(hl().get("out", ""), 2.4)
	var r := light_r()
	for hh in hands:
		if not is_instance_valid(hh):
			continue
		var h := hh as CurseHand
		if h.state in ["gone", "frozen"]:
			continue
		var d := h.global_position.distance_to(pink.global_position)
		if r > 0.0 and d <= r:
			if h.state == "latched":
				h.release()
			if h.state != "flee":
				h.flee(pink.global_position)
		elif fuel <= 0.0 and h.state in ["wander", "flee"] and d <= SEEK_R:
			h.seek(pink)
		elif h.state == "flee" and d > r + 30.0:
			h.state = "wander"


## 在旧烛台旁按 E：续满火把
func refuel_near(who: Node2D) -> bool:
	for c in CANDLES:
		if who.global_position.distance_to(Cutscene.cell_to_world(c)) <= CANDLE_R:
			fuel = 1.0
			_out = false
			_warned = false
			say(hl().get("relit", ""), 1.6)
			Audio.play("torch", -6.0)
			return true
	return false


func _on_split(arr: Array) -> void:
	for s in arr:
		var sh := s as HandShard
		sh.caught_by.connect(_on_caught)
		spawned.append(sh)
		shards.append(sh)


func _on_caught(_s: HandShard) -> void:
	got += 1
	Audio.play("pickup", -4.0)
	if got >= need:
		_finish()


func _finish() -> void:
	var cut := str(q.get("hall_end", ""))
	if cut != "" and Cutscene.has_cutscene(cut):
		await TrainingDB.wait_dialogue_free()
		await Cutscene.play(cut)
	advance()
