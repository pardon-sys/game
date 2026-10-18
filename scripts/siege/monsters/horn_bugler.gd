class_name HornBugler
extends SiegeMonster
## 号手小鬼（机制型难度）：吹号的指挥官，第 4 波起和一组 8~12 只小怪成套出现（配合技 bugler_squad）。
##   号手活着：整组排成几排跟着它行军（escort_of / escort_off）；号手走到离墙脚 RALLY_Y 以内就吹冲锋号——
##     整组挂 siege_rally（城墙伤害 ×1.2、移速 ×1.15），散开阵型一起冲到它那段墙下；之后每 HORN_GAP 秒再吹一次续上。
##   号手被打倒：整组乱成一团（meta scatter_until：SCATTER 秒乱走、晕头转向，见 SiegeMind.wander），之后各自重新挑墙段。

const RALLY_Y := 150.0
const HORN_GAP := 3.0
const SCATTER := 3.0

var squad: Array = []
var charging := false
var _horn_t := 0.0


func _setup() -> void:
	super()
	add_to_group("siege_bugler")
	died.connect(_on_down)


func siege_wander(mind: SiegeMind, delta: float) -> bool:
	if super(mind, delta):
		return true
	if director == null:
		return false
	squad = squad.filter(func(m): return SiegeTools.alive(m))
	if not charging and global_position.y - director.wall_foot_y() < RALLY_Y:
		charging = true
		_blow(true)
	elif charging:
		_horn_t -= delta
		if _horn_t <= 0.0:
			_blow(false)
	# 自己照常行军（SiegeMind.march 挑薄弱墙段），整组跟着它
	return false


## 吹号：给整组续上冲锋状态；第一次吹时放开阵型，大家冲到号手那段墙下。
func _blow(first: bool) -> void:
	_horn_t = HORN_GAP
	for m: Monster in squad:
		m.add_buff("siege_rally", HORN_GAP + 0.5)
		if first:
			m.remove_meta("escort_of")
			m.set_meta("march_x", global_position.x + randf_range(-40, 40))
			m.set_meta("march_lock", true)
	if director and director.on_screen(global_position):
		Audio.play("siege_horn", -8.0, 0.1, 1.3)
		SiegeFx.ring(get_parent(), global_position + Vector2(0, -6), 40.0, Color(1, 0.75, 0.3, 0.8), 0.5)
	if first:
		SpeechBubble.say(self, "嘟——嘟——全体冲锋！", 26.0, 1.4)


func _on_down(_who: Actor = null) -> void:
	var left := squad.filter(func(m): return SiegeTools.alive(m))
	if left.is_empty():
		return
	var until := (director.game_t if director else 0.0) + SCATTER
	for m: Monster in left:
		m.remove_meta("escort_of")
		m.remove_meta("march_lock")
		m.remove_buff("siege_rally")
		m.set_meta("scatter_until", until)
	SpeechBubble.say(left[0], "号、号手倒了！往哪走？！", 26.0, 1.4)
	GameState.notify("号手倒下了，那一队怪乱成一团！")
