class_name LaughJar
extends Monster
## 笑声收集瓶（第八层夜迷宫）：会跑的小瓶子，跟在她身边（不贴脸），她在笑（笑声半径 > 0 且在半径里）时把笑声装进去。
## 装满（fill = 1）→「啵」地打开：放出 BURST_RADIUS 的一大圈笑声（LaughRadius.burst），把附近所有紫手都叫过来，再刷几只。
## 偶尔戳一下腰（来源键 laugh_jar）。挨 2 下就碎（MonsterStats max_hp）。组合「镜中笑瓶」直接把它灌满（fill_now）。

const SHEET := preload("res://assets/generated/maze/laugh_jar.png")
const FILL_TIME := 8.0
const BURST_RADIUS := 220.0
const KEEP := 34.0

var fill := 0.0


func _setup() -> void:
	super()
	add_to_group("laugh_jar")
	sprite.texture = SHEET
	sprite.hframes = 4
	sprite.region_enabled = false


func fill_now() -> void:
	fill = 1.0
	_burst()


func _tick(delta: float) -> void:
	super(delta)
	var p := GameState.player as PlayableCharacter
	if not is_instance_valid(p) or GameState.in_dialogue:
		return
	var r := p.get_node_or_null("LaughRadius") as LaughRadius
	var d := p.global_position.distance_to(global_position)
	# 保持一点距离跟着
	if d < KEEP * 0.6:
		velocity = (global_position - p.global_position).normalized() * 30.0
	if r and r.radius() > 0.0 and d <= r.radius() + 16.0:
		fill = minf(1.0, fill + delta / FILL_TIME)
		if fill >= 1.0:
			_burst()


func _burst() -> void:
	fill = 0.0
	Audio.play("pop", -2.0, 0.0, 0.7)
	Fx.burst(get_parent(), global_position + Vector2(0, -8), "heart", 12, 60.0, 0.8, Vector2(0, 20), Color(1, 0.6, 0.85))
	SpeechBubble.say(self, "啵——！", 22.0)
	var p := GameState.player as Node2D
	if is_instance_valid(p):
		var r := p.get_node_or_null("LaughRadius") as LaughRadius
		if r:
			r.burst(BURST_RADIUS, 2.0)
	var dir: Node = get_tree().get_first_node_in_group("maze_director")
	if dir and dir.has_method("summon_near"):
		dir.summon_near(2)


func _animate(_delta: float) -> void:
	sprite.frame = clampi(int(fill * 4.0), 0, 3)
