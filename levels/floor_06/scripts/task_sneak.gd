class_name TaskSneak
extends Node2D
## 骑士篇 D「夜探地牢」（保卫队的地牢 floor_06_after_prison，夜里）：从通风口溜进来，躲开巡逻的队员（StealthDirector / PatrolGuard / 木箱躲藏 / 丢石子），
## 走到最里面那间牢房（CELL 格，NEAR 以内）→ 隔着栏杆和骑士说话（对话 floor_06/after_knight 的 cell：三个问题都问过以后蓝色公主走出来）→ 完成。
##   被发现（警觉满）：被按上挠痒审问椅（InterrogationChairShow，小游戏画面）挠一阵 → 送回通风口（SPAWN）重新潜入；caught +1。没有失败结局。
## 状态 vars.task_sneak_caught。测试：caught_now()、talk_now()、auto_chair（审问椅直接给结果）。

signal finished(ok: bool)

const CELL := Vector2i(36, 6)
const SPAWN := Vector2i(3, 18)
const NEAR := 22.0
const CAUGHT_KEY := "task_sneak_caught"

static var auto_chair := false

var aborted := false
var started := false
var talking := false
var _emitted := false
var _busy := false
var _director: StealthDirector
var oddities: PrisonOddities


static func caught() -> int:
	return int(GameState.vars.get(CAUGHT_KEY, 0))


static func reset_items() -> void:
	pass


static func status_text() -> String:
	return "被抓过 %d 次" % caught()


func _ready() -> void:
	var lv := get_parent().get_parent()
	for n in lv.find_children("*", "StealthDirector", true, false):
		_director = n
	if _director:
		_director.caught.connect(_on_caught)
	for f in ["knight_asked_night", "knight_asked_fall", "knight_asked_why"]:
		GameState.set_flag(f, false)
	# 牢房里那些奇怪的东西（挠痒鼠、痒痒手套、审讯椅、马凳）
	oddities = PrisonOddities.new()
	get_parent().add_child.call_deferred(oddities)
	started = true


func _process(_delta: float) -> void:
	if _emitted or _busy or not started or GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if is_instance_valid(p) and p.global_position.distance_to(Cutscene.cell_to_world(CELL)) <= NEAR:
		talk_now()


## 走到牢房门口：隔着栏杆说话（三个问题问完、蓝色公主走出来，对话结束 = 完成）
func talk_now() -> void:
	if _busy or _emitted:
		return
	_busy = true
	talking = true
	Dialogue.runner.talk("floor_06/after_knight", "cell")
	while Dialogue.runner.is_running():
		await get_tree().process_frame
	talking = false
	_busy = false
	if GameState.has_flag("knight_asked_night") and GameState.has_flag("knight_asked_fall") and GameState.has_flag("knight_asked_why"):
		_emit(true)


func _on_caught(_by: Node) -> void:
	caught_now()


## 被发现：审问椅 → 送回通风口
func caught_now() -> void:
	if _busy or _emitted:
		return
	_busy = true
	GameState.vars[CAUGHT_KEY] = caught() + 1
	if not auto_chair:
		var show := InterrogationChairShow.new()
		get_tree().root.add_child(show)
		await show.play()
		if is_instance_valid(show):
			show.queue_free()
	if not is_inside_tree():
		return
	var p := GameState.player
	if is_instance_valid(p):
		p.global_position = Cutscene.cell_to_world(SPAWN)
		if p.laugh:
			p.laugh.set_value(p.laugh.max_value * 0.3)
		if p.camera:
			p.camera.reset_smoothing()
	if _director:
		_director.reset()
	_busy = false


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)
