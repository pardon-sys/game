class_name SpriteSheetConfig
extends Resource
## 精灵表动画配置（数据），给 SpriteSheetAnimator 用。换素材时只需改这个资源，不用改代码。
##
## 精灵表约定：每列一帧，每行一种表情（行顺序 = row_names）。
## directions：每个朝向的起始列；可用独立left/right，也兼容side朝右、朝左镜像。
## animations：动画名 -> {
##     "frames": [列偏移...],       相对朝向起始列（directional=false 时为绝对列）
##     "fps": 帧率,
##     "loop": 是否循环（默认 true）,
##     "directional": 是否按朝向偏移（默认 true）,
##     "row": 强制使用某个表情行（如 "normal"），省略则跟随当前表情,
##     "shake": 水平抖动幅度（像素，占位表现用）,
##     "fallback": 该动画缺失素材时改用的动画名
## }

@export var row_names: Array[String] = ["normal", "happy", "laugh", "sad", "shy", "angry"]
@export var directions := {"down": 0, "up": 12, "side": 24}
@export var animations := {}


func has_animation(anim: String) -> bool:
	return animations.has(anim)


func get_animation(anim: String) -> Dictionary:
	var a: Dictionary = animations.get(anim, {})
	if a.is_empty() or (a.has("fallback") and not a.has("frames")):
		var fb: String = a.get("fallback", "idle")
		return animations.get(fb, {})
	return a
