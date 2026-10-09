class_name GlowMoth
extends Monster
## 夜光羽蛾（第八层夜迷宫）：扑扇着发光的翅膀飞来飞去，往大腿上撒鳞粉（来源键 glow_moth，部位权重以大腿为主）。
## 撒中时她憋不住轻笑一下：笑声半径亮一下（LaughRadius.boost 1.4 倍 1.5 秒）。自带一点暖黄的光，能照亮身边一小片路。

const SHEET := preload("res://assets/generated/maze/glow_moth.png")


func _setup() -> void:
	super()
	sprite.texture = SHEET
	sprite.hframes = 2
	sprite.region_enabled = false


func _on_tickle_performed(t: Node) -> void:
	Fx.burst(get_parent(), (t as Node2D).global_position + Vector2(0, -6), "crystal", 6, 24.0, 0.6, Vector2(0, 20), Color(0.95, 1.0, 0.6))
	var r := t.get_node_or_null("LaughRadius") as LaughRadius
	if r:
		r.boost(1.4, 1.5)


func _animate(_delta: float) -> void:
	sprite.frame = int(_t * 10.0) % 2
	sprite.position.y = sin(_t * 4.0) * 2.0
