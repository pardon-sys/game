class_name SpriteSheetAnimator
extends Node
## 按 SpriteSheetConfig 驱动 Sprite2D 的帧（朝向 x 表情行 x 动画）。节点名 "Animator"。
## 动画可以指定 "sheet" 改用另一张图集（尺寸、帧数、朝向起始列、行名都可以不同），不指定时用 Sprite 原来的图集。

@export var config: SpriteSheetConfig
@export var sprite_path := NodePath("../Sprite")
## 按图集名换贴图（同一份配置给不同角色用，例如蓝色公主的魔法图集）：{图集名: 贴图路径}
@export var texture_overrides := {}

var sprite: Sprite2D
var current := ""
var time := 0.0
## "progress" 动画的进度（0~1），由角色设置（例如吟唱蓄力）。
var progress := 0.0
## 当前使用的图集名（"" = Sprite 默认图集）。
var sheet := ""
var _default := {}
var _textures := {}


func _ready() -> void:
	sprite = get_node(sprite_path) as Sprite2D
	if sprite:
		_default = {"texture": sprite.texture, "hframes": sprite.hframes, "vframes": sprite.vframes, "offset": sprite.offset}


func play(anim: String) -> void:
	if anim != current:
		current = anim
		time = 0.0


func is_finished() -> bool:
	var a := config.get_animation(current)
	return not a.get("loop", true) and time * float(a.get("fps", 1.0)) >= a.get("frames", [0]).size()


## 每帧调用：dir_name = "down"/"up"/"side"，facing_left 决定侧面翻转，emotion_row 为当前表情行（config.row_names 的下标）。
func update(delta: float, dir_name: String, facing_left: bool, emotion_row: int) -> void:
	if config == null or sprite == null:
		return
	time += delta
	var a := config.get_animation(current)
	if a.is_empty():
		return
	var info := _use_sheet(str(a.get("sheet", "")))
	var directions: Dictionary = info.get("directions", config.directions)
	var frames: Array = a.get("frames", [0])
	var idx := 0
	if a.get("progress", false):
		idx = clampi(int(progress * frames.size()), 0, frames.size() - 1)
	else:
		idx = int(time * float(a.get("fps", 1.0)))
		idx = idx % frames.size() if a.get("loop", true) else mini(idx, frames.size() - 1)
	var directional: bool = a.get("directional", true)
	var direction := dir_name
	var explicit_side := directions.has("left") and directions.has("right")
	if direction == "side" and explicit_side:
		direction = "left" if facing_left else "right"
	var col: int = int(frames[idx]) + (int(directions.get(direction, 0)) if directional else 0)
	var row := emotion_row
	if a.has("row"):
		row = maxi(config.row_names.find(a["row"]), 0)
	if info.has("row_names"):
		var visual := config.row_names[row] if row >= 0 and row < config.row_names.size() else ""
		row = maxi((info["row_names"] as Array).find(visual), 0)
	if row >= sprite.vframes:  # 这张图集没有该状态的行（例如切换瞬间）：用第一行
		row = 0
	sprite.flip_h = directional and dir_name == "side" and facing_left and not explicit_side
	sprite.frame_coords = Vector2i(col, row)
	var shake: float = a.get("shake", 0.0)
	sprite.position.x = roundf(sin(time * 45.0) * shake) if shake > 0.0 else 0.0


## 切换图集（只在变化时设置 Sprite），返回该图集的配置（默认图集返回空字典）。
func _use_sheet(name: String) -> Dictionary:
	var info: Dictionary = config.sheets.get(name, {}) if name != "" else {}
	if info.is_empty():
		name = ""
	if name != sheet:
		sheet = name
		sprite.frame = 0  # 先回到第 0 帧，避免改行列数时旧帧号越界
		if name == "":
			sprite.texture = _default["texture"]
			sprite.hframes = _default["hframes"]
			sprite.vframes = _default["vframes"]
			sprite.offset = _default["offset"]
		else:
			if not _textures.has(name):
				_textures[name] = load(str(texture_overrides.get(name, info["texture"])))
			sprite.texture = _textures[name]
			sprite.hframes = int(info["hframes"])
			sprite.vframes = int(info["vframes"])
			sprite.offset = info.get("offset", _default["offset"])
	return info
