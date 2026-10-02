class_name MiniTentacle
extends Monster
## 小触手（触手笼放出来的）：不会走，原地扭动，贴身就挠腋下和腰。挠痒算「痒痒触手怪」来源（reaction_key = tentacle）。


func _move(_dir: Vector2, _speed: float, _delta: float) -> void:
	velocity = Vector2.ZERO


func _animate(_delta: float) -> void:
	sprite.frame = int(_t * 4.0) % 2
