extends Node2D
## 委托「捡苹果」（水果摊的商贩）的玩法节点：TIME 秒内把滚了一地的 APPLES 个苹果捡回来（走过去自动捡），有几个滚到了痒痒草旁边
## （TickleGrass：踩到被缠住挠几秒）。捡齐 = 做完；时间到没捡齐 = 失败（商贩拿掸子挠一下，可以再接）。

const TIME := 40.0
const APPLES := [[5, 17], [10, 16], [17, 17], [3, 28], [9, 30], [14, 29], [19, 24], [20, 31], [6, 33], [17, 34]]
## 痒痒草（贴着几个苹果）
const GRASS := [[17, 18], [4, 29], [19, 30], [7, 33], [11, 16]]
const PICK_R := 12.0

var errand_id := "apples"
var left_t := TIME
var got := 0
var _apples: Array[Node2D] = []
var _grass: Array[Node2D] = []
var _done := false


func _ready() -> void:
	for c in APPLES:
		var a := Node2D.new()
		a.set_script(preload("res://levels/floor_06/scripts/errand_apple.gd"))
		get_parent().add_child(a)
		a.global_position = Cells.to_world(c)
		_apples.append(a)
	for c in GRASS:
		var g := TickleGrass.new()
		get_parent().add_child(g)
		g.global_position = Cells.to_world(c)
		_grass.append(g)


func _exit_tree() -> void:
	for n in _apples + _grass:
		if is_instance_valid(n):
			n.queue_free()


func _process(delta: float) -> void:
	if _done or GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	left_t -= delta
	for a in _apples:
		if is_instance_valid(a) and a.visible and a.global_position.distance_to(p.global_position) <= PICK_R:
			a.visible = false
			got += 1
			Audio.play("pickup", -8.0, 0.1)
	GameState.vars["errand_apples_text"] = "苹果 %d / %d　还剩 %d 秒" % [got, APPLES.size(), ceili(maxf(left_t, 0.0))]
	if got >= APPLES.size():
		_done = true
		Dialogue.start_lines([{"speaker": "水果摊的商贩", "text": "一个不少！手脚挺麻利嘛——比摊子被踩烂那天麻利多了。"},
			{"speaker": "公主", "text": "（……被草缠住的那几下，腰到现在还在痒……）", "emotion": "shy"}], "errand_apples")
		AfterErrands.complete(errand_id)
		queue_free()
	elif left_t <= 0.0:
		_done = true
		if p.laugh:
			p.laugh.add(p.laugh.max_value * 0.3)
		p.shake(0.4)
		Dialogue.start_lines([{"speaker": "水果摊的商贩", "text": "时间到！才捡回来 %d 个？——罚你尝尝我的鸡毛掸子！" % got},
			{"speaker": "公主", "text": "哈、哈哈！掸子别扫脖子——！再、再来一次就是了！", "emotion": "helpless_1"}], "errand_apples")
		AfterErrands.fail(errand_id, "苹果没捡齐……再找水果摊的商贩说一次就能重来。")
		queue_free()
