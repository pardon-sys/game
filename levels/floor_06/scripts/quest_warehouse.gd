class_name QuestWarehouse
extends QuestRunner
## 支线「没有名字的生日」第三段「旧仓库」（floor_06_after_warehouse）：找三个八音盒零件（PARTS 里随机三处，一闪一闪），走过去按 E 捡。
##   仓库角落里的旧八音盒一阵一阵地响（PLAY 秒响、STOP 秒停）：响的时候发条小手（WindupHand，HANDS）一动不动；
##   一停，看得见她的小手就爬过来挠脚心。躲在箱子 / 木桶旁边（COVERS，COVER_R 以内）它们就看不见她。
##   捡齐 → 这一段做完。
## 测试：hands、parts、got、music、take_near(角色)、set_music(on)。

const PARTS := [Vector2i(10, 4), Vector2i(18, 11), Vector2i(21, 4), Vector2i(7, 10), Vector2i(15, 8)]
const HANDS := [Vector2i(11, 7), Vector2i(17, 6), Vector2i(20, 8), Vector2i(13, 11)]
const COVERS := [Vector2i(8, 4), Vector2i(12, 9), Vector2i(16, 5), Vector2i(20, 10), Vector2i(9, 12), Vector2i(19, 3),
	Vector2i(14, 3), Vector2i(6, 11), Vector2i(22, 7)]
const COVER_R := 16.0
const PLAY := 3.2
const STOP := 2.2
const PICK_R := 14.0
const NEED := 3

var hands: Array = []
var parts: Array = []
var got := 0
var music := true
var _left := PLAY


func setup() -> void:
	hands.clear()
	parts.clear()
	got = 0
	for c in HANDS:
		var h := put(WindupHand.new(), Cutscene.cell_to_world(c)) as WindupHand
		h.target = pink
		hands.append(h)
	var pool := PARTS.duplicate()
	pool.shuffle()
	for i in NEED:
		parts.append(put(PartMark.new(), Cutscene.cell_to_world(pool[i])))
	set_music(true)


func status() -> String:
	return "零件 %d / %d　%s" % [got, NEED, "♪ 音乐响着" if music else "音乐停了！"]


func set_music(on: bool) -> void:
	music = on
	_left = PLAY if on else STOP
	for h in hands:
		if is_instance_valid(h):
			h.music = on
	if on:
		Audio.play("music_box", -8.0)


func hidden_now() -> bool:
	return COVERS.any(func(c): return pink.global_position.distance_to(Cutscene.cell_to_world(c)) <= COVER_R)


func _process(delta: float) -> void:
	if not live() or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink):
		return
	tick(delta)
	if Input.is_action_just_pressed("interact"):
		take_near(GameState.player)


func tick(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		set_music(not music)
	var hid := hidden_now()
	for h in hands:
		if is_instance_valid(h):
			h.unseen = hid


func take_near(who: Node2D) -> bool:
	for p in parts:
		if is_instance_valid(p) and not p.taken and who.global_position.distance_to(p.global_position) <= PICK_R:
			p.taken = true
			got += 1
			Audio.play("pickup", -4.0)
			GameState.notify("零件 %d / %d" % [got, NEED], 1.2)
			if got >= NEED:
				say("（三个零件都找到了。角落里的八音盒「叮」地停住了）", 2.4)
				advance()
			return true
	return false


## 一个八音盒零件（小齿轮），一闪一闪
class PartMark extends Node2D:
	var taken := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if taken:
			return
		draw_circle(Vector2(0, -3), 3.5, Color(0.86, 0.78, 0.5))
		for i in 6:
			draw_rect(Rect2(Vector2(0, -3) + Vector2.from_angle(i * TAU / 6.0 + _t) * 3.5 - Vector2(0.8, 0.8), Vector2(1.6, 1.6)), Color(0.86, 0.78, 0.5))
		draw_circle(Vector2(0, -3), 1.2, Color(0.4, 0.32, 0.2))
		draw_circle(Vector2(5, -9), 0.8 + 0.4 * sin(_t * 6.0), Color(1, 1, 0.8, 0.9))
