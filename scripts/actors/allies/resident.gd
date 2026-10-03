class_name Resident
extends Actor
## 小镇居民 / 关键人物（友军，不打怪、不挠人）。行走图来自人物表 data/actors/npcs.json（npc_id）。
## 在出生点 wander 格半径内慢慢溜达；公主靠近按 E 对话（Dialogue.talk(dialogue)），说话时停下、转向公主。
## 构建器图例：X = npc id=<人物> dialogue=<楼层组>/<文件> [wander=格数] [dir=down/left/right/up] [hidden_flag=标记] [show_flag=标记]
##   show_flag：有这个剧情标记才出现；hidden_flag：有这个标记就不出现（剧情前后换位置用）。

@export var npc_id := "granny"
@export var dialogue := ""
## 溜达半径（格，0 = 站着不动）。
@export var wander := 2.0
@export var speed := 22.0
@export var dir := "down"
@export var show_flag := ""
@export var hidden_flag := ""

var talking := false
## 过场里被脚本移动时播走路动画（Cutscene 的 move 设置）。
var puppet_walking := false
var _home := Vector2.ZERO
var _goal := Vector2.ZERO
var _think := 0.0
var _t := 0.0
var _princess_sheet := false
var _row := 0


func _setup() -> void:
	faction = Faction.Type.ALLY
	_home = global_position
	_goal = global_position
	_think = randf_range(0.5, 2.5)
	facing = Trap.dir_vector(dir)
	var info: Dictionary = Dialogue.npcs.get(npc_id, {})
	if sprite and ResourceLoader.exists(str(info.get("sprite", ""))):
		sprite.texture = load(str(info["sprite"]))
		_princess_sheet = info.get("princess_sheet", false)
		if _princess_sheet:
			sprite.hframes = 16
			sprite.vframes = 11
			sprite.offset = Vector2(0, -16)
		else:
			sprite.hframes = 4
			sprite.vframes = 4
			sprite.offset = Vector2(0, -14)
	if info.has("light"):
		# 身上带灯（篝火派对的主人的灯笼）
		var c: Array = info["light"]
		var light := PointLight2D.new()
		light.texture = preload("res://assets/lights/light_soft.tres")
		light.color = Color(float(c[0]), float(c[1]), float(c[2]))
		light.energy = 0.55
		light.texture_scale = 0.6
		light.position = Vector2(9, -22)
		add_child(light)
	var it := get_node_or_null("Interactable") as Interactable
	if it:
		it.interacted.connect(func(p: Node): talk(p))
	_refresh_visibility()
	GameState.flag_changed.connect(func(_f: String): _refresh_visibility())


func display_name() -> String:
	return str(Dialogue.npcs.get(npc_id, {}).get("name", npc_id))


func _refresh_visibility() -> void:
	var show := (show_flag == "" or GameState.has_flag(show_flag)) and (hidden_flag == "" or not GameState.has_flag(hidden_flag))
	visible = show
	var it := get_node_or_null("Interactable") as Interactable
	if it:
		it.enabled = show and dialogue != ""
	process_mode = Node.PROCESS_MODE_INHERIT if show else Node.PROCESS_MODE_DISABLED


func talk(player: Node) -> void:
	if talking or dialogue == "" or Dialogue.runner.is_running():
		return
	talking = true
	velocity = Vector2.ZERO
	if player is Node2D:
		var d := ((player as Node2D).global_position - global_position)
		facing = d.normalized() if d.length() > 0.1 else facing
	_animate(0.0)
	await Dialogue.talk(dialogue)
	talking = false
	_refresh_visibility()


func _tick(delta: float) -> void:
	_t += delta
	if talking or GameState.in_dialogue or wander <= 0.0:
		velocity = Vector2.ZERO
	else:
		_think -= delta
		if _think <= 0.0:
			_think = randf_range(1.5, 4.0)
			_goal = _home + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * wander * 16.0 if randf() < 0.7 else global_position
		var to := _goal - global_position
		velocity = to.normalized() * speed if to.length() > 2.0 else Vector2.ZERO
		if velocity != Vector2.ZERO:
			facing = velocity.normalized()
	move_and_slide()
	if get_slide_collision_count() > 0:
		_goal = global_position
	_animate(delta)


func _animate(_delta: float) -> void:
	if sprite == null or sprite.texture == null:
		return
	var moving := velocity.length() > 1.0 or puppet_walking
	var d := dir4()
	var row := 0
	if d == Vector2.LEFT:
		row = 1
	elif d == Vector2.RIGHT:
		row = 2
	elif d == Vector2.UP:
		row = 3
	var step := int(_t * 6.0) % 4 if moving else 0
	sprite.flip_h = false
	sprite.frame = row * 4 + step
