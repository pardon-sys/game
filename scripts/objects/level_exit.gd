extends Area2D
## 关卡出口 / 楼梯：公主走进来时（可先播放一段对话）切换到 target_level。
## target_level 为 "next" 时按 data/floors.json 进入当前楼层的下一层。
## spawn：到了新地图站在同名的到达点（SpawnPoint）上（第六层小镇的楼梯用）；down：楼梯的样子（往下 / 往上）。
## locked：封住的出口（只播 dialogue，不走）。
## lock_flag：有这个剧情标记时锁住（比如夜里小屋的门）；unlock_flag：有这个标记才打开（比如拿到钥匙）。
## 锁住时播 locked_dialogue（没写就播 dialogue）；打开时播 dialogue（可以不写）。

@export var target_level := ""
@export var dialogue := ""
@export var size := Vector2(16, 16)
@export var spawn := ""
@export var down := true:
	set(v):
		down = v
		var look := get_node_or_null("Look")
		if look:
			look.set("kind", "stairs_down" if v else "stairs_up")
@export var locked := false
@export var lock_flag := ""
@export var unlock_flag := ""
@export var locked_dialogue := ""
## 打开后第一次走进来播的对话（比如「用钥匙……打开了！」），只播一次。
@export var open_dialogue := ""

var _used := false
var _retry := 0.0
## 上次走进来时没处理（正在对话 / main 正忙），人还在里面就再试
var _pending := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = size
	$Shape.shape = shape
	body_entered.connect(_on_body_entered)


## 走进来那一刻正好有对话 / 换图被拒（main 正忙）时，人还站在出口里：空下来以后再试一次（以前会一直卡在出口上走不了）
func _physics_process(delta: float) -> void:
	if _used or not _pending:
		return
	_retry -= delta
	if _retry > 0.0:
		return
	_retry = 0.3
	if Dialogue.is_active() or GameState.in_dialogue or GameState.in_cutscene:
		return
	_pending = false
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			_on_body_entered(b)
			return


func _on_body_entered(body: Node) -> void:
	if _used or not body.is_in_group("player"):
		return
	if Dialogue.is_active():
		_pending = true
		return
	_used = true
	var is_locked := is_locked_now()
	var say := locked_dialogue if is_locked and locked_dialogue != "" else dialogue
	if not is_locked and open_dialogue != "" and not GameState.has_flag("opened_" + open_dialogue):
		GameState.set_flag("opened_" + open_dialogue)
		say = open_dialogue
	if say != "":
		Dialogue.start(say)
		await Dialogue.finished
	if is_locked:
		await get_tree().create_timer(1.0).timeout
		_used = false
		return
	GameState.pending_spawn = spawn
	var path := resolve_target()
	var main := get_tree().get_first_node_in_group("main")
	if main and path != "":
		if bool(main.get("_busy")):
			# 正在换别的图：这次不算，等一会儿再试
			await get_tree().create_timer(0.5).timeout
			_used = false
			_pending = true
			return
		main.change_level(path)


## 现在是不是锁着（locked、lock_flag、unlock_flag 一起判断）。
func is_locked_now() -> bool:
	if locked:
		return true
	if lock_flag != "" and GameState.has_flag(lock_flag):
		return true
	return unlock_flag != "" and not GameState.has_flag(unlock_flag)


func resolve_target() -> String:
	if target_level != "next":
		return target_level
	var next := Floors.next_of(str(owner.get("floor_id")) if owner else "")
	return Floors.scene(next) if next != "" else ""
