class_name SpriteSheetAnimator
extends Node
## 按 SpriteSheetConfig 驱动 Sprite2D 的帧（朝向 x 表情行 x 动画）。节点名 "Animator"。
## 动画可以指定 "sheet" 改用另一张图集（尺寸、帧数、朝向起始列、行名都可以不同），不指定时用 Sprite 原来的图集。
## 角色画风（UserSettings.art_style，P 键菜单）：「精细像素」时每张图集换成同名的 *_hd.png（codex 直接画的像素风，直接导入，格子是原像素图的 HD_SCALE 倍：256 / 384 格），
##   Sprite 缩到 HD_ENLARGE / HD_SCALE（人物比原像素图大一圈）、offset 放大 HD_SCALE 倍（脚底位置不变），线性过滤（画面按窗口分辨率渲染，缩小时细节不丢）；
##   没有 *_hd.png 的图集照旧用原像素图。
##   UserSettings.revision 变了（菜单里切换）就在下一帧重新选。

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
## 精细像素图集是原像素图的几倍（256 格 / 32 格）；显示时人物放大的倍数
const HD_SCALE := 8.0
const HD_ENLARGE := 1.25
## 待机眨眼（精细像素图集多出来的两列：半闭眼 / 闭眼，只有正面待机用）：每隔 BLINK_EVERY 秒（随机）眨一下，一下 BLINK_TIME 秒
const BLINK_HALF_COL := 16
const BLINK_SHUT_COL := 17
## 走路也眨眼：正面 / 左 / 右走 4 帧的闭眼版从第 18 列起（下 18-21、左 22-25、右 26-29），眨那一下换成闭眼帧
const WALK_SHUT_BASE := 18
const WALK_SHUT_DIRS := {"down": 0, "left": 1, "right": 2}
const BLINK_EVERY := Vector2(2.8, 5.0)
const BLINK_TIME := 0.16
var _blink_t := 3.0
var _base_scale := Vector2.ONE
var _base_filter := CanvasItem.TEXTURE_FILTER_PARENT_NODE
var _revision := -1
## 现在用的是不是高清图集
var hd := false


func _ready() -> void:
	sprite = get_node(sprite_path) as Sprite2D
	if sprite:
		_default = {"texture": sprite.texture, "hframes": sprite.hframes, "vframes": sprite.vframes, "offset": sprite.offset}
		_base_scale = sprite.scale
		_base_filter = sprite.texture_filter


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
	if _revision != UserSettings.revision:
		_revision = UserSettings.revision
		if sheet != "__still":
			sheet = "__restyle"   # 画风换了：下面 _use_sheet 重新选贴图
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
	col = _blink(col, delta, direction, a)
	sprite.frame_coords = Vector2i(col, row)
	var shake: float = a.get("shake", 0.0)
	sprite.position.x = roundf(sin(time * 45.0) * shake) if shake > 0.0 else 0.0


## 待机 / 走路时眨眼（精细像素图集有眨眼列才眨）：返回这一帧用的列。
## 正面待机：半闭 → 闭 → 半闭（第 16 / 17 列）；左右待机、正面 / 左右走：换成同一帧的闭眼版（WALK_SHUT_BASE 起）
func _blink(col: int, delta: float, direction: String, a: Dictionary) -> int:
	if not hd or sheet != "" or not current in ["idle", "walk"] or not WALK_SHUT_DIRS.has(direction):
		return col
	var walk_cols := sprite.hframes >= WALK_SHUT_BASE + WALK_SHUT_DIRS.size() * 4
	if sprite.hframes <= BLINK_SHUT_COL or (direction != "down" or current == "walk") and not walk_cols:
		return col
	_blink_t -= delta
	if _blink_t > 0.0:
		return col
	if _blink_t < -BLINK_TIME:
		_blink_t = randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
		return col
	if current == "idle" and direction == "down":
		var k := -_blink_t / BLINK_TIME
		return BLINK_SHUT_COL if k > 0.33 and k < 0.67 else BLINK_HALF_COL
	# 走路 / 左右待机：这一帧（方向起始列 + 帧号）的闭眼版
	var base := int(config.directions.get(direction, 0))
	var f := clampi(col - base, 0, 3)
	return WALK_SHUT_BASE + int(WALK_SHUT_DIRS[direction]) * 4 + f


## 临时换成一张单帧图（睡着的样子等）；之后 update 会自动换回正常的图集。
func show_still(tex: Texture2D) -> void:
	if sprite == null or tex == null:
		return
	sheet = "__still"
	sprite.frame = 0
	sprite.texture = tex
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.flip_h = false
	sprite.offset = _default["offset"]
	_set_hd(false)


## 切换图集（只在变化时设置 Sprite），返回该图集的配置（默认图集返回空字典）。
func _use_sheet(name: String) -> Dictionary:
	var info: Dictionary = config.sheets.get(name, {}) if name != "" else {}
	if info.is_empty():
		name = ""
	if name != sheet:
		sheet = name
		sprite.frame = 0  # 先回到第 0 帧，避免改行列数时旧帧号越界
		var offset: Vector2 = _default["offset"]
		var path := ""
		if name == "":
			var tex: Texture2D = _default["texture"]
			path = tex.resource_path if tex else ""
			sprite.hframes = _default["hframes"]
			sprite.vframes = _default["vframes"]
		else:
			path = str(texture_overrides.get(name, info["texture"]))
			sprite.hframes = int(info["hframes"])
			sprite.vframes = int(info["vframes"])
			offset = info.get("offset", _default["offset"])
		var styled := UserSettings.styled_path(path)
		var use_hd := styled != path
		if path == "":
			sprite.texture = _default["texture"]
		else:
			if not _textures.has(styled):
				_textures[styled] = load(styled)
			sprite.texture = _textures[styled]
		if use_hd and sprite.texture:
			# 精细像素图集的格子 = 原图格子 × HD_SCALE；列数按贴图宽算（多出来的眨眼列）
			var cell_w := float(_orig_size(path).x) / float(sprite.hframes) * HD_SCALE
			if cell_w > 0.0:
				sprite.hframes = maxi(1, roundi(sprite.texture.get_width() / cell_w))
		_set_hd(use_hd)
		sprite.offset = offset * (HD_SCALE if use_hd else 1.0)
	return info


## 原图（像素版）的尺寸（算精细像素图集的列数用）
var _orig_sizes := {}


func _orig_size(path: String) -> Vector2i:
	if not _orig_sizes.has(path):
		var t := load(path) as Texture2D
		_orig_sizes[path] = Vector2i(t.get_width(), t.get_height()) if t else Vector2i.ZERO
	return _orig_sizes[path]


## 精细像素图集：Sprite 缩小显示、线性过滤；2.5D / 等距楼层的光照材质按新的脚底位置更新
func _set_hd(on: bool) -> void:
	hd = on
	sprite.scale = _base_scale * HD_ENLARGE / HD_SCALE if on else _base_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if on else _base_filter
	var mat := sprite.material as ShaderMaterial
	if mat and sprite.has_meta("lit"):
		mat.set_shader_parameter("feet_y", sprite.get_rect().end.y)
