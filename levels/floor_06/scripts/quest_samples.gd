class_name QuestSamples
extends QuestRunner
## 支线「手印样本」的玩法：收三块手印碎片给药剂师奶奶配安神药。
##   0 担架走过的石板路（白天的小镇）/ 1 地牢入口的铁门边（白天的小镇）：几块石头里只有一块底下藏着碎片（HandShard，走近会晃），其余是装样子的；
##   2 工房的地窖（floor_06_after_cellar）：一团手印（HandCluster），冻住或者拍散 → 裂成 HandCluster.SPLIT 块，都收进瓶子才算。
##   收法：粉色公主在旁边按住 E 故意笑（KnightLaugh）→ 碎片探头、爬到她脚边进瓶子；蓝色公主 J 冻住、E 装瓶（她靠近时碎片会逃，逼急了挠她大腿）。
##   千手解放也能冻住。最后一段：回工房找奶奶说话（report）。
## 测试：shards、cluster、need、got、freeze_near(角色)、bottle_near(角色)。

const DECOYS := 2
const FREEZE_R := 30.0
const SPOTS := [[Vector2i(40, 14), Vector2i(38, 15), Vector2i(42, 15)], [Vector2i(52, 7), Vector2i(50, 8), Vector2i(56, 8)]]
const CLUSTER := Vector2i(7, 5)

var shards: Array = []
var cluster: HandCluster
var need := 1
var got := 0


static func runs_on(floor_id: String, st: int) -> bool:
	return (st < 2 and floor_id == KnightStory.KDAY) or (st == 2 and floor_id == KnightStory.CELLAR)


static func reset_items() -> void:
	pass


func _text() -> Dictionary:
	var d := q.duplicate()
	d["split_line"] = [q.get("split", "")]
	return d


func setup() -> void:
	shards.clear()
	got = 0
	if stage() < 2:
		need = 1
		var spots: Array = SPOTS[stage()]
		var real := randi() % spots.size()
		for i in spots.size():
			var at := Cutscene.cell_to_world(spots[i])
			if i == real:
				var s := HandShard.make(get_parent(), at, "stone", _text())
				s.caught_by.connect(_on_caught)
				spawned.append(s)
				shards.append(s)
			else:
				put(Decoy.new(), at)
	else:
		need = HandCluster.SPLIT
		cluster = put(HandCluster.new(), Cutscene.cell_to_world(CLUSTER)) as HandCluster
		cluster.lines = _text()
		cluster.split_into.connect(_on_split)
		say(q.get("cluster", ""), 3.0)


func _on_split(arr: Array) -> void:
	for s in arr:
		(s as HandShard).caught_by.connect(_on_caught)
		spawned.append(s)
		shards.append(s)


func _on_caught(_s: HandShard) -> void:
	got += 1
	GameState.notify("手印样本 %d / %d" % [got, need], 1.4)
	if got >= need:
		advance()


func _process(delta: float) -> void:
	if GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	if p == pink and KnightLaugh.tick(pink, delta):
		for s in shards:
			if is_instance_valid(s):
				(s as HandShard).lure(pink)
	if Input.is_action_just_pressed("attack"):
		if p == blue:
			freeze_near(blue)
		elif is_instance_valid(cluster) and not cluster.done:
			cluster.try_hit(p)
	if Input.is_action_just_pressed("interact"):
		bottle_near(p)


## 蓝色公主 J：冻住身边的碎片 / 手印团
func freeze_near(who: PlayableCharacter) -> int:
	var n := 0
	for s in shards:
		if is_instance_valid(s) and s.state in ["peek", "crawl", "flee"] and s.global_position.distance_to(who.global_position) <= FREEZE_R:
			s.freeze()
			n += 1
	if is_instance_valid(cluster) and not cluster.done and cluster.global_position.distance_to(who.global_position) <= FREEZE_R + 8.0:
		cluster.split()
		n += 1
	if n > 0:
		Fx.burst(who.get_parent(), who.global_position, "drop", 8, 30.0, 0.4, Vector2(0, -10))
	return n


## E：把身边冻住的碎片装进瓶子
func bottle_near(who: PlayableCharacter) -> int:
	var n := 0
	for s in shards:
		if is_instance_valid(s) and (s as HandShard).bottle(who):
			n += 1
	return n


## 装样子的石头（底下什么都没有，不会晃）
class Decoy extends Node2D:
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(-6, 3), Vector2(-4, -3), Vector2(3, -3), Vector2(6, 1), Vector2(4, 4)]), Color(0.6, 0.57, 0.62))
		draw_line(Vector2(-3, -2), Vector2(2, -2), Color(0.75, 0.72, 0.78), 1.0)
