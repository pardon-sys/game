class_name LivingWall
extends Node2D
## 呼吸墙的一格（第八层夜迷宫，迷宫导演按 design.json 的呼吸墙对生成）：碰撞照常由 TerrainShifter 加在（透明的）Walls 图层上，
## 画面全由这里负责——升起时是一面带紫色脉络、会轻轻起伏的「活墙」，
## 沉下时缩回地面，留下一块紫色裂纹（地面层，不盖住人），提醒这里会长墙。
##   等距楼层：活墙是和方块墙一样大小的紫黑方块（主题的 living 图），裂纹是等距的菱形；这一格从 IsoTerrain 认领（不画普通墙块），
##     挡住主角时和墙块一样淡化。
##   set_up(升起?, 动画?)  warn(开?)：心跳前要变的地方发亮（裂纹亮 / 脉络亮）

const WALL_TEX := preload("res://assets/generated/maze/living_wall.png")
const CRACK_TEX := preload("res://assets/generated/maze/living_crack.png")
const GROW := 0.4

var cell := Vector2i.ZERO
var up := false
var warning := false
var wall: Sprite2D
var crack: Sprite2D
var _t := 0.0
var _iso: IsoTheme


## 在 level 的 cell 格放一个（墙精灵进 Entities 一起 y 排序，裂纹进 FloorObjects）。
static func make(level: Node, c: Vector2i) -> LivingWall:
	var lw := LivingWall.new()
	lw.cell = c
	lw.name = "LivingWall_%d_%d" % [c.x, c.y]
	var ents: Node = level.get_node_or_null("Entities")
	(ents if ents else level).add_child(lw)
	lw.global_position = Vector2(c.x * 16 + 8, c.y * 16 + 16)
	lw.crack = Sprite2D.new()
	lw.crack.hframes = 2
	if IsoView.enabled:
		lw.crack.texture = lw._iso.living_crack
	else:
		lw.crack.texture = CRACK_TEX
	var floor_objs: Node = level.get_node_or_null("FloorObjects")
	(floor_objs if floor_objs else level).add_child(lw.crack)
	lw.crack.global_position = Vector2(c.x * 16 + 8, c.y * 16 + 8)
	return lw


func _enter_tree() -> void:
	if IsoView.enabled and _iso == null:
		_iso = IsoTheme.for_node(get_parent())


func _ready() -> void:
	add_to_group("living_wall")
	wall = Sprite2D.new()
	if _iso:
		add_to_group(IsoTerrain.OWNER_GROUP)
		_iso.dress_cube(wall, _iso.living, _iso.living_normal, 0)
		IsoView.stand_lit(wall)
		IsoView.anchor(wall, Vector2(0, -8))
		var t := IsoTerrain.of(self)
		if t:
			t.claim(cell, self)
	else:
		wall.texture = WALL_TEX
		wall.hframes = 3
		wall.offset = Vector2(0, -16)
	wall.scale = Vector2(1, 0)
	wall.visible = false
	add_child(wall)


func _exit_tree() -> void:
	if is_instance_valid(crack):
		crack.queue_free()
	var t := IsoTerrain.of(self)
	if t and t.claimed.get(cell) == self:
		t.release(cell)


func set_up(value: bool, animate := true) -> void:
	if value == up and wall.visible == value:
		return
	up = value
	var tw := create_tween()
	if value:
		wall.visible = true
		tw.tween_property(wall, "scale:y", 1.0, GROW if animate else 0.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(wall, "scale:y", 0.0, GROW * 0.75 if animate else 0.0).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): wall.visible = false)
	crack.visible = not value


func warn(on: bool) -> void:
	warning = on


func _set_frame(f: int) -> void:
	if _iso:
		var size := _iso.cube_size()
		wall.region_rect = Rect2(f * size.x, 0, size.x, size.y)
	else:
		wall.frame = f


func _process(delta: float) -> void:
	_t += delta
	if up:
		# 脉络慢慢起伏；心跳前一直亮着
		_set_frame(2 if warning else (1 if fmod(_t, 1.6) < 0.8 else 0))
		var t := IsoTerrain.of(self) if _iso else null
		if t and IsoView.current:
			var at := IsoView.current.screen_pos(self) + wall.position
			wall.modulate.a = move_toward(wall.modulate.a, _iso.fade_alpha if t.should_fade(at) else 1.0, delta * IsoTerrain.FADE_SPEED)
	else:
		crack.frame = 1 if warning and fmod(_t, 0.3) < 0.18 else 0
