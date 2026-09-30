class_name Fx
extends RefCounted
## 小型一次性特效。

const FX_TEX := preload("res://assets/generated/fx.png")


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
