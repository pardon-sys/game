class_name QuestBox
extends QuestRunner
## 支线「骑士救公主」第五段「小莉莉的宝贝盒」（骑士篇的小镇，白天夜里都行；西边集市）：
##   宝贝盒被拆成 PIECES 块，搬着碎片的手印（HandShard，tease）躲在集市的货摊布帘底下（STALLS 里随机挑）。
##   粉色公主在旁边按住 Y 故意笑 → 手印探头、爬过来挠一下脚心，然后抱着碎片晃悠 HandShard.DAZED_TIME 秒——这时候按 E 抢回来；
##   蓝色公主冻住（J / 冰晶结界）也能按 E 拿。拿齐 → 过场 kq_shoes_box_end（发卡）→ 这一段做完（也是支线的最后一段）。
## 测试：shards、got、take_near(角色)。

const PIECES := 3
const STALLS := [Vector2i(8, 23), Vector2i(12, 23), Vector2i(6, 27), Vector2i(10, 27), Vector2i(14, 26)]
const FREEZE_R := 30.0

var shards: Array = []
var got := 0


func b() -> Dictionary:
	return q.get("box", {})


func setup() -> void:
	shards.clear()
	got = 0
	var spots := STALLS.duplicate()
	spots.shuffle()
	var text := {"peek": b().get("peek", []), "caught": b().get("got", []), "flee": [], "corner": []}
	for i in PIECES:
		var s := HandShard.make(get_parent(), Cutscene.cell_to_world(spots[i]), "stall", text)
		s.tease = true
		s.caught_by.connect(_on_caught)
		s.teased.connect(func(_s): say(b().get("tickle", []), 1.6))
		spawned.append(s)
		shards.append(s)
	_intro()


func _intro() -> void:
	if GameState.has_flag("kq_shoes_box_intro"):
		return
	GameState.set_flag("kq_shoes_box_intro")
	await get_tree().process_frame
	await TrainingDB.wait_dialogue_free()
	Dialogue.start_lines(b().get("intro", []), "kq_box_intro")


func status() -> String:
	return str(b().get("status", "%d / %d")) % [got, PIECES]


func _on_caught(_s: HandShard) -> void:
	got += 1
	var lines: Array = b().get("got", [])
	say(lines[mini(got - 1, lines.size() - 1)] if not lines.is_empty() else "", 1.6)
	Audio.play("pickup", -4.0)
	if got >= PIECES:
		_finish()


func _finish() -> void:
	var cut := str(b().get("end_cut", ""))
	if cut != "" and Cutscene.has_cutscene(cut):
		await TrainingDB.wait_dialogue_free()
		await Cutscene.play(cut)
	advance()


func _process(delta: float) -> void:
	if not live() or GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	if p == pink and KnightLaugh.tick(pink, delta):
		for s in shards:
			if is_instance_valid(s):
				(s as HandShard).lure(pink)
	if Input.is_action_just_pressed("attack") and p == blue:
		freeze_near(blue)
	if Input.is_action_just_pressed("interact"):
		take_near(p)


## 蓝色公主 J：冻住身边的搬盒子手印
func freeze_near(who: PlayableCharacter) -> int:
	var n := 0
	for s in shards:
		if is_instance_valid(s) and s.state in ["peek", "crawl", "flee"] and s.global_position.distance_to(who.global_position) <= FREEZE_R:
			s.freeze()
			n += 1
	return n


## 按 E：把晃悠着 / 冻住的手印怀里的碎片抢回来
func take_near(who: PlayableCharacter) -> int:
	var n := 0
	for s in shards:
		if is_instance_valid(s) and (s as HandShard).bottle(who):
			n += 1
	return n
