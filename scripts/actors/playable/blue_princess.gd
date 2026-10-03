class_name BluePrincess
extends Princess
## 蓝色的公主：和公主同一套可操作角色（行走、表情、受挠、失控、魔法），用自己的精灵图 / 魔法图 / 立绘（portrait_set = "blue"）。
## 平时由 WanderController（AI）在小镇里溜达；走近按 E 和她说话（Dialogue.talk(dialogue)），说话时停下、转向公主。
## 测试模式按 F2（switch_character）切换成玩家操控（GameState.switch_control）。
## 图例：X = blue_princess [dialogue=…] [show_flag=…]；过场里 spawn kind=npc:blue_princess 生成的是 ai = false 的演员。

@export var dialogue := "floor_06/blue_princess"
## 有这个剧情标记才出现（开场之后）。
@export var show_flag := "f6_opening_done"
## false = 过场演员：不溜达，位置由过场控制。
@export var ai := true

var talking := false


func _setup() -> void:
	portrait_set = "blue"
	# 场景里自带的是玩家输入：换成 AI（过场演员换成脚本控制）
	if not (controller is WanderController or controller is ScriptedController):
		set_controller(make_ai_controller())
	super()
	if camera and not is_controlled():
		camera.enabled = false
	var it := get_node_or_null("Talk") as Interactable
	if it:
		it.interacted.connect(func(p: Node): talk(p))
	GameState.flag_changed.connect(func(_f: String): _refresh_visibility())
	_refresh_visibility()


func make_ai_controller() -> CharacterController:
	return WanderController.new() if ai else ScriptedController.new()


func display_name() -> String:
	return "蓝色的公主"


func _refresh_visibility() -> void:
	var show := show_flag == "" or GameState.has_flag(show_flag) or not ai
	visible = show
	process_mode = Node.PROCESS_MODE_INHERIT if show else Node.PROCESS_MODE_DISABLED
	var it := get_node_or_null("Talk") as Interactable
	if it:
		it.enabled = show and dialogue != "" and not is_controlled()


func talk(player: Node) -> void:
	if talking or dialogue == "" or is_controlled() or Dialogue.runner.is_running():
		return
	talking = true
	var wc := controller as WanderController
	if wc:
		wc.paused = true
		wc.path.clear()
	if player is Node2D:
		var d := (player as Node2D).global_position - global_position
		if d.length() > 0.1:
			facing = d.normalized()
	await Dialogue.talk(dialogue)
	talking = false
	if wc and is_instance_valid(wc):
		wc.paused = false
	_refresh_visibility()
