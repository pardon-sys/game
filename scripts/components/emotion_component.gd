class_name EmotionComponent
extends Node2D
## 表情组件：决定精灵表用哪一行（表情），并负责头顶表情气泡。挂在 Actor 下，节点名 "Emotion"，子节点 "Bubble"。
## respond_to_global = true 时响应 GameState.emote(...)（玩家角色用），并把变化广播给 HUD。
## 场景里有两个可操作角色时（公主 + 蓝色公主），只有正在操控的那一个（GameState.player）响应和广播。
## 剧情请求与实际显示分离；公主异常状态优先，HUD / 对话共同监听最终显示。

const BUBBLE_INDEX := {
	"happy": 0, "laugh": 1, "sad": 2, "shy": 3, "angry": 4,
	"question": 5, "surprise": 6, "dots": 7,
}
const BUBBLE_TIME := 1.8

@export var respond_to_global := true

@onready var bubble: Sprite2D = $Bubble

var current := "normal"
var _requested := ""
var actor: Actor
var _hold := false
var _timer := 0.0
var _bubble_timer := 0.0
var _bubble_tween: Tween


func _ready() -> void:
	actor = get_parent() as Actor
	bubble.hide()
	if respond_to_global:
		GameState.emotion_requested.connect(func(e: String, d: float, b: bool): if is_global(): request(e, d, b))
		GameState.bubble_requested.connect(func(k: String): if is_global(): show_bubble(k))


## 现在是不是代表玩家的那个表情组件。
func is_global() -> bool:
	if not respond_to_global:
		return false
	var p := GameState.player
	return not (actor is PlayableCharacter) or not is_instance_valid(p) or p == actor


## 做表情。duration <= 0 表示一直保持到下一次请求；emotion 为 "" 表示松开保持，duration 秒后回到默认。
func request(emotion: String, duration := 2.5, with_bubble := true) -> void:
	if emotion == "":
		_hold = false
		_timer = maxf(duration, 0.01)
		return
	_requested = emotion if emotion in GameState.EMOTIONS else "normal"
	refresh()
	_hold = duration <= 0.0
	_timer = duration
	if with_bubble:
		var kind: String = {"giggle": "laugh", "damaged_giggle": "laugh", "helpless_1": "laugh", "helpless_2": "laugh", "damaged": "sad"}.get(current, current)
		show_bubble(kind)


## 重新评估默认表情（血量或闷笑变化时调用）。
func refresh() -> void:
	var visual := _requested if _requested != "" else "normal"
	if actor is Princess:
		# 传入原始请求（可能为空）：有事件表情时显示事件表情，没有时才显示战损
		visual = (actor as Princess).resolve_visual(_requested)
	_apply(visual)


func default_emotion() -> String:
	return (actor as Princess).resolve_visual("") if actor is Princess else "normal"


func reset() -> void:
	_requested = ""
	_hold = false
	_timer = 0.0
	bubble.hide()
	refresh()


## 当前视觉状态在 GameState.VISUALS 里的下标（含魔法姿态）。
func row() -> int:
	return maxi(GameState.VISUALS.find(current), 0)


func show_bubble(kind: String) -> void:
	if not BUBBLE_INDEX.has(kind):
		return
	bubble.frame = BUBBLE_INDEX[kind]
	bubble.show()
	bubble.modulate.a = 1.0
	_bubble_timer = BUBBLE_TIME
	if _bubble_tween:
		_bubble_tween.kill()
	bubble.scale = Vector2(0.2, 0.2)
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(bubble, "scale", Vector2(1.2, 1.2), 0.08)
	_bubble_tween.tween_property(bubble, "scale", Vector2.ONE, 0.08)


func _apply(emotion: String) -> void:
	if emotion != current:
		current = emotion
		if is_global():
			GameState.emotion_changed.emit(emotion)


func _process(delta: float) -> void:
	if not _hold and _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			_requested = ""
			refresh()
	if bubble.visible:
		_bubble_timer -= delta
		if _bubble_timer < 0.3:
			bubble.modulate.a = maxf(_bubble_timer / 0.3, 0.0)
		if _bubble_timer <= 0.0:
			bubble.hide()
