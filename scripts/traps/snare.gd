class_name SnareTrap
extends RestraintTrap
## 倒吊绳套：踩中绳圈就套住脚踝把人倒吊起来（脚心朝天）。露出部位：脚心 ×1.5。


func _restraint_setup() -> void:
	exposed = exposed if not exposed.is_empty() else {"sole": 1.5}


func _hold_point() -> Vector2:
	return global_position + Vector2(0, 2)


func _on_restrain(_a: Actor) -> void:
	Audio.play("swish", -2.0, 0.05, 0.7)
	Fx.burst(get_parent(), global_position, "dust", 6, 30.0, 0.4)


func _while_held(_delta: float) -> void:
	_rope_to(victim.global_position + Vector2(0, -6), Vector2(0, -48))


func _on_free(_a: Actor) -> void:
	_hide_rope()
