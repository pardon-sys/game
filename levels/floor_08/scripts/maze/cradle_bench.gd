class_name CradleBench
extends Node2D
## 摇篮长椅（第八层夜迷宫）：按 E 坐下，轻轻地摇。坐着的时候闷笑和魔力疲倦慢慢降（休息点）；
## 但坐满 SAFE 秒后，椅子下面伸出一只手挠屁股（每 0.6 秒，来源键 cradle_bench），再坐 COVER 秒就直接盖一只屁股手。
## 按方向键起来。
## 图例：X = cradle

const TEX := preload("res://assets/generated/maze/cradle_bench.png")
const SAFE := 5.0
const COVER := 2.5

var sprite: Sprite2D
var sitter: PlayableCharacter
var reaction_key := "cradle_bench"
var _sit_t := 0.0
var _tick := 0.0
var _covered := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("cradle_bench")
	sprite = Sprite2D.new()
	sprite.texture = TEX
	sprite.offset = Vector2(0, -8)
	add_child(sprite)
	var it := Interactable.new()
	it.prompt_offset = Vector2(0, -22)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 14)
	shape.shape = rect
	shape.position = Vector2(0, -4)
	it.add_child(shape)
	add_child(it)


func on_interact(player: Node) -> void:
	if sitter or not (player is PlayableCharacter):
		return
	sit(player)


func sit(p: PlayableCharacter) -> void:
	sitter = p
	_sit_t = 0.0
	_covered = 0.0
	p.global_position = global_position + Vector2(0, -2)
	if p.status:
		p.status.apply_root(999.0)
	SpeechBubble.say(p, "……坐一会儿。", 26.0)


func stand() -> void:
	if sitter == null:
		return
	if sitter.status:
		sitter.status.clear_root()
	sitter.global_position = global_position + Vector2(0, 12)
	sitter = null


func is_sitting() -> bool:
	return sitter != null


func _process(delta: float) -> void:
	_t += delta
	sprite.rotation = sin(_t * 1.6) * (0.06 if sitter else 0.02)
	if sitter == null or GameState.in_dialogue:
		return
	if not is_instance_valid(sitter) or not sitter.is_alive():
		sitter = null
		return
	_sit_t += delta
	sitter.global_position = global_position + Vector2(0, -2)
	# 按方向键起来（坐下 0.3 秒后才算，免得刚坐下就起来）
	if _sit_t > 0.3 and Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO:
		stand()
		return
	if sitter.laugh:
		sitter.laugh.reduce(4.0 * delta)
	var f: MagicFatigue = sitter.get("fatigue")
	if f:
		f.value = maxf(0.0, f.value - 6.0 * delta)
	if _sit_t >= SAFE:
		_tick += delta
		if _tick >= 0.6:
			_tick = 0.0
			var h := HitData.make_tickle(self, 2.5)
			h.zone = "butt"
			sitter.receive_hit(h)
		_covered += delta
		if _covered >= COVER:
			_covered = 0.0
			var dir := get_tree().get_first_node_in_group("maze_director")
			if dir and dir.has_method("cover_zone"):
				dir.cover_zone("butt")
