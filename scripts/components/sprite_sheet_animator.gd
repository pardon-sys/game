class_name SpriteSheetAnimator
extends Node
## 按 SpriteSheetConfig 驱动 Sprite2D 的帧（朝向 x 表情行 x 动画）。节点名 "Animator"。

@export var config: SpriteSheetConfig
@export var sprite_path := NodePath("../Sprite")

var sprite: Sprite2D
var current := ""
var time := 0.0


func _ready() -> void:
	sprite = get_node(sprite_path) as Sprite2D


func play(anim: String) -> void:
	if anim != current:
		current = anim
		time = 0.0


func is_finished() -> bool:
	var a := config.get_animation(current)
	return not a.get("loop", true) and time * float(a.get("fps", 1.0)) >= a.get("frames", [0]).size()


## 每帧调用：dir_name = "down"/"up"/"side"，facing_left 决定侧面翻转，emotion_row 为当前表情行。
func update(delta: float, dir_name: String, facing_left: bool, emotion_row: int) -> void:
	if config == null or sprite == null:
		return
	time += delta
	var a := config.get_animation(current)
	if a.is_empty():
		return
	var frames: Array = a.get("frames", [0])
	var fps: float = a.get("fps", 1.0)
	var idx := int(time * fps)
	idx = idx % frames.size() if a.get("loop", true) else mini(idx, frames.size() - 1)
	var directional: bool = a.get("directional", true)
	var direction := dir_name
	var explicit_side := config.directions.has("left") and config.directions.has("right")
	if direction == "side" and explicit_side:
		direction = "left" if facing_left else "right"
	var col: int = int(frames[idx]) + (int(config.directions.get(direction, 0)) if directional else 0)
	var row := emotion_row
	if a.has("row"):
		row = maxi(config.row_names.find(a["row"]), 0)
	sprite.flip_h = directional and dir_name == "side" and facing_left and not explicit_side
	sprite.frame_coords = Vector2i(col, row)
	var shake: float = a.get("shake", 0.0)
	sprite.position.x = roundf(sin(time * 45.0) * shake) if shake > 0.0 else 0.0
