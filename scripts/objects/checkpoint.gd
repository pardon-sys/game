extends Area2D
## 检查点：地上的粉色魔法阵 + 漂浮的小水晶（assets/generated/checkpoint.png / crystal.png）。
## 公主走进来时记录复活位置：魔法阵亮起、冒一圈光粒、提示「记下了复活位置」。
## 当前复活点的水晶一直发光、转动；其它检查点变暗（GameState.checkpoint_changed）。

const CIRCLE := preload("res://assets/generated/checkpoint.png")
const CRYSTAL := preload("res://assets/generated/crystal.png")

var circle: Sprite2D
var gem: Sprite2D
var light: PointLight2D
var _t := 0.0


func _ready() -> void:
	circle = Sprite2D.new()
	circle.texture = CIRCLE
	circle.hframes = 2
	circle.z_index = 0
	add_child(circle)
	gem = Sprite2D.new()
	gem.texture = CRYSTAL
	gem.hframes = 4
	gem.z_index = 1
	gem.position = Vector2(0, -12)
	add_child(gem)
	light = PointLight2D.new()
	light.texture = preload("res://assets/lights/light_soft.tres")
	light.color = Color(1.0, 0.6, 0.85)
	light.energy = 0.0
	light.texture_scale = 0.6
	light.position = Vector2(0, -8)
	add_child(light)
	body_entered.connect(_on_body_entered)
	GameState.checkpoint_changed.connect(func(_p: Vector2): _refresh())
	_refresh()


## 这里是不是当前的复活点。
func is_current() -> bool:
	return GameState.checkpoint.distance_to(global_position) < 1.0


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or is_current():
		return
	GameState.set_checkpoint(global_position)
	Fx.burst(get_parent(), global_position + Vector2(0, -6), "heart", 10, 40.0, 0.6, Vector2(0, -40), Color(1, 0.75, 0.9))
	Audio.play("chime", -6.0, 0.05, 1.2)
	GameState.notify("记下了复活位置")


func _refresh() -> void:
	var cur := is_current()
	circle.frame = 1 if cur else 0
	gem.modulate = Color.WHITE if cur else Color(0.6, 0.55, 0.7)
	light.energy = 0.7 if cur else 0.0


func _process(delta: float) -> void:
	_t += delta
	gem.position.y = -12.0 + roundf(sin(_t * 2.5) * 1.5)
	if is_current():
		gem.frame = int(_t * 6.0) % 4
