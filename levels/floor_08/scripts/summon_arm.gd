class_name SummonArm
extends Node2D
## 阶段三召唤小怪的演出（第八层专属）：千手的一只手臂从画面上方垂下来，落到地上（landed）放下小怪，停一下再收回去。
## 臂段和手掌用 BossLimb 的同一张图。

signal landed

const ARM := preload("res://assets/generated/thousand_hand_arm.png")
const TOP := -190.0
const DROP_TIME := 0.5

## 手掌现在的高度（相对落点，0 = 地面）
var tip_y := TOP
var _t := 0.0


func _ready() -> void:
	add_to_group("f8_summon_arm")
	z_index = 3
	var tw := create_tween()
	tw.tween_property(self, "tip_y", -8.0, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): landed.emit())
	tw.tween_interval(0.25)
	tw.tween_property(self, "tip_y", TOP, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var tip := Vector2(sin(_t * 2.3) * 3.0, tip_y)
	var top := Vector2(tip.x * 0.3, TOP - 20.0)
	var n := maxi(2, int((tip.y - top.y) / 10.0))
	for i in n:
		var p := top.lerp(tip, float(i) / n) + Vector2(sin(_t * 3.0 + i * 0.5) * 2.0, 0)
		draw_texture_rect_region(ARM, Rect2(p - Vector2(12, 12), Vector2(24, 24)), Rect2((i % 2) * 24, 0, 24, 24))
	draw_texture_rect_region(ARM, Rect2(tip - Vector2(12, 12), Vector2(24, 24)), Rect2(2 * 24, 0, 24, 24))
