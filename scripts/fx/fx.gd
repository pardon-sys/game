class_name Fx
extends RefCounted
## 小型特效：一次性的烟雾、物品升起；CPUParticles2D 粒子（持续发射 emitter / 一次性爆开 burst）。

const FX_TEX := preload("res://assets/generated/fx.png")
const PARTICLES := {
	"ember": preload("res://assets/generated/particle_ember.png"),
	"goo": preload("res://assets/generated/particle_goo.png"),
	"dust": preload("res://assets/generated/particle_dust.png"),
	"chip": preload("res://assets/generated/particle_chip.png"),
	"drop": preload("res://assets/generated/particle_drop.png"),
	"heart": preload("res://assets/generated/particle_heart.png"),
	"feather": preload("res://assets/generated/particle_feather.png"),
	"bristle": preload("res://assets/generated/particle_bristle.png"),
}


## 持续发射的粒子，挂在 parent 下（跟着它移动）。opts：offset 位置、dir 方向、spread 散开角度、
## speed [最小, 最大]、gravity、extents（给了就在矩形范围里发射）、color 颜色、z 层级。
static func emitter(parent: Node, kind: String, amount := 8, lifetime := 0.8, opts := {}) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = PARTICLES.get(kind, PARTICLES["dust"])
	p.amount = amount
	p.lifetime = lifetime
	p.position = opts.get("offset", Vector2.ZERO)
	p.direction = opts.get("dir", Vector2.UP)
	p.spread = float(opts.get("spread", 30.0))
	var speed: Array = opts.get("speed", [10.0, 20.0])
	p.initial_velocity_min = float(speed[0])
	p.initial_velocity_max = float(speed[1])
	p.gravity = opts.get("gravity", Vector2.ZERO)
	if opts.has("extents"):
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = opts["extents"]
	var ramp := Gradient.new()
	var col: Color = opts.get("color", Color.WHITE)
	ramp.set_color(0, col)
	ramp.set_color(1, Color(col, 0.0))
	p.color_ramp = ramp
	p.z_index = int(opts.get("z", 2))
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(p)
	return p


## 一次性爆开的粒子（播完自动删除）。
static func burst(parent: Node, pos: Vector2, kind: String, amount := 8, speed := 40.0, lifetime := 0.5,
		gravity := Vector2(0, 90), color := Color.WHITE) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := emitter(parent, kind, amount, lifetime, {"dir": Vector2.UP, "spread": 180.0,
			"speed": [speed * 0.5, speed], "gravity": gravity, "color": color, "z": 6})
	p.one_shot = true
	p.explosiveness = 1.0
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(lifetime + 0.3, false).timeout.connect(p.queue_free)


## 烟雾：fx.png 第二行 4 帧 16x16。
static func puff(parent: Node, pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = FX_TEX
	s.region_enabled = true
	s.region_rect = Rect2(0, 32, 64, 16)
	s.hframes = 4
	s.z_index = 5
	parent.add_child(s)
	s.global_position = pos
	var tw := s.create_tween()
	for i in 4:
		tw.tween_callback(func(): s.frame = i)
		tw.tween_interval(0.07)
	tw.tween_callback(s.queue_free)


## 物品图标从 pos 升起并淡出（开箱展示）。
static func item_rise(parent: Node, pos: Vector2, icon: Texture2D) -> void:
	var s := Sprite2D.new()
	s.texture = icon
	s.z_index = 10
	parent.add_child(s)
	s.global_position = pos
	var tw := s.create_tween()
	tw.tween_property(s, "global_position", pos + Vector2(0, -18), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(s, "modulate:a", 0.0, 0.25)
	tw.tween_callback(s.queue_free)
