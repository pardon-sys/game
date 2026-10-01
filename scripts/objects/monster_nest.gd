class_name MonsterNest
extends StaticBody2D
## 怪物巢穴（可复用的基类；子类在 _configure() 里配种类、生成的怪物和贴图行，也可以重写 _prepare(怪物) 加特别行为）。
## 可打碎、挡路（墙层 + breakable 层）。
##   普通生成：公主在 wake_range 内时每 spawn_interval 秒生成一只，同时最多 max_alive 只（只数普通生成的）。
##   吟唱联动：公主吟唱（弱点暴露）且巢穴在她的 expose_radius 内时额外生成怪物，不占普通上限：
##             第一只在 surge_start 秒后，之后间隔每次 ×surge_mult，最快 surge_min 秒；额外的同时最多 surge_max 只。
##             额外怪物一出来就锁定公主；吟唱结束 surge_linger 秒后没被打倒的额外怪物缩回巢穴；巢穴打碎时立刻全部缩回。
##   拖进巢穴：公主失控时，贴身的巢穴怪物抓住她往巢穴拖（drag_speed，每多一只一起拖 +drag_speed_per）。
##             连按 drag_presses 次挣脱；闷笑降到失控以下、巢穴被打碎、拖人的怪物都没了也会松手。
##             拖到巢穴口（swallow_dist 内）：公主倒下，播这种巢穴的过场 CG（CG.play_nest(kind)），然后在检查点复活。
##   血 max_hp，权杖可以打；满蓄力（3 档）星光爆发直接打碎，低档扣 2（MagicReactive）。打碎后停止生成，按 drops 掉落。

signal smashed

const SHEET := preload("res://assets/generated/nests.png")
const SIZE := 24

## 巢穴种类（过场 CG 用：data/cgs.json 的 nest 表）。
@export var kind := ""
@export var monster_scene := ""
## nests.png 里的行。
@export var sheet_row := 0
@export var max_hp := 4
@export var wake_range := 140.0
@export var spawn_interval := 6.0
@export var max_alive := 2
@export_group("吟唱联动")
## 吟唱最长 2 秒：0.4 秒起、每只 ×0.7、最快 0.15 秒 → 蓄 1 档约 2 只、2 档约 4 只、满蓄力约 6 只。
@export var surge_start := 0.4
@export var surge_mult := 0.7
@export var surge_min := 0.15
@export var surge_max := 6
@export var surge_linger := 3.0
@export_group("拖进巢穴")
@export var drag_speed := 25.0
@export var drag_speed_per := 15.0
@export var drag_presses := 10
## 怪物离公主这么近才能抓住她（像素）。
@export var contact_dist := 16.0
@export var swallow_dist := 12.0
## 挣脱后这么久不会再被同一个巢穴抓。
@export var regrab_delay := 2.0
@export_group("")
@export var drops: Array[ItemDrop] = []

var hp := 4
var broken := false
var magic_radius := 10.0
## 正在被拖的公主。
var victim: PlayableCharacter
## 一起拖人的怪物。
var draggers: Array[Monster] = []
var _spawned: Array[Monster] = []
var _extras: Array[Monster] = []
var _spawn_cd := 1.0
var _surge_cd := 0.0
var _surge_gap := 0.0
var _since_channel := 0.0
var _regrab_cd := 0.0
var _anim := 0.0
var _trail_t := 0.0

var sprite: Sprite2D


func _ready() -> void:
	_configure()
	hp = max_hp
	collision_layer = 33
	collision_mask = 0
	add_to_group("monster_nest")
	add_to_group("magic_reactive")
	sprite = Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = 3
	sprite.vframes = 5
	sprite.offset = Vector2(0, -SIZE / 2.0)
	sprite.frame_coords = Vector2i(0, sheet_row)
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 10)
	cs.shape = rect
	cs.position = Vector2(0, -5)
	add_child(cs)
	_surge_gap = surge_start
	_surge_cd = surge_start


## 子类钩子：设定 kind / monster_scene / sheet_row 等。
func _configure() -> void:
	pass


## 子类钩子：怪物加进场景之前的准备（例如让宝箱怪醒着）。
func _prepare(_m: Monster) -> void:
	pass


## 巢穴口（拖到这里就被拖进去）。
func mouth() -> Vector2:
	return global_position + Vector2(0, -4)


## ArenaZone 用：没打碎的巢穴也算房间里的敌人。
func is_alive() -> bool:
	return not broken


func spawned_alive() -> Array[Monster]:
	_spawned.assign(_spawned.filter(func(m): return is_instance_valid(m) and m.is_alive()))
	return _spawned


func extras_alive() -> Array[Monster]:
	_extras.assign(_extras.filter(func(m): return is_instance_valid(m) and m.is_alive()))
	return _extras


## 普通生成的（不含吟唱额外生成的）。
func regular_alive() -> Array[Monster]:
	var ex := extras_alive()
	var out: Array[Monster] = []
	out.assign(spawned_alive().filter(func(m): return not ex.has(m)))
	return out


func is_dragging() -> bool:
	return is_instance_valid(victim)


func _physics_process(delta: float) -> void:
	_anim += delta
	if GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player as PlayableCharacter
	if is_dragging():
		_update_drag(delta)
	if broken or not is_instance_valid(p) or not p.is_alive():
		if not extras_alive().is_empty():
			_retreat_extras()
		_show(0)
		return
	_regrab_cd = maxf(_regrab_cd - delta, 0.0)
	_update_spawn(p, delta)
	_update_surge(p, delta)
	if not is_dragging():
		_try_grab(p)
	_show(1 if is_dragging() or _surge_gap < surge_start else 0)


func _show(frame: int) -> void:
	if broken:
		return
	sprite.frame_coords = Vector2i(frame if int(_anim * 6.0) % 2 == 0 else 0, sheet_row)
	sprite.position.x = roundf(sin(_anim * 50.0)) if is_dragging() else 0.0


# ------------------------------------------------------------------ 生成
func _update_spawn(p: PlayableCharacter, delta: float) -> void:
	if global_position.distance_to(p.global_position) > wake_range or regular_alive().size() >= max_alive:
		return
	_spawn_cd -= delta
	if _spawn_cd <= 0.0:
		_spawn_cd = spawn_interval
		spawn(false)


func _update_surge(p: PlayableCharacter, delta: float) -> void:
	var exposed := p.is_channeling() and global_position.distance_to(p.global_position) <= p.expose_radius
	if exposed:
		_since_channel = 0.0
		_surge_cd -= delta
		if _surge_cd <= 0.0 and extras_alive().size() < surge_max:
			var m := spawn(true)
			if m:
				m.target = p
				m.state = Monster.State.CHASE
			_surge_gap = maxf(surge_min, _surge_gap * surge_mult)
			_surge_cd = _surge_gap
		return
	_surge_gap = surge_start
	_surge_cd = surge_start
	if extras_alive().is_empty():
		return
	_since_channel += delta
	if _since_channel >= surge_linger:
		_retreat_extras()


## 生成一只怪物（extra = 吟唱时额外生成的）。
func spawn(extra: bool) -> Monster:
	if monster_scene == "" or not is_inside_tree():
		return null
	var m: Monster = load(monster_scene).instantiate()
	m.home_nest = self
	m.add_to_group("nest_spawn")
	_prepare(m)
	get_parent().add_child(m)
	m.global_position = global_position + Vector2(randf_range(-8.0, 8.0), 10.0)
	_spawned.append(m)
	if extra:
		_extras.append(m)
		m.add_to_group("nest_extra")
	Fx.puff(get_parent(), m.global_position + Vector2(0, -6))
	Audio.play("puff", -8.0, 0.1)
	return m


## 额外生成的怪物缩回巢穴（缩小、淡出、移到巢穴口后消失）。
func _retreat_extras() -> void:
	for m in extras_alive():
		_retreat(m)
	_extras.clear()
	_since_channel = 0.0


func _retreat(m: Monster) -> void:
	draggers.erase(m)
	m.remove_from_group("enemy")
	m.set_physics_process(false)
	m.process_mode = Node.PROCESS_MODE_ALWAYS
	m.collision_layer = 0
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "global_position", mouth(), 0.35)
	tw.tween_property(m, "scale", Vector2(0.2, 0.2), 0.35)
	tw.tween_property(m, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(m.queue_free)


# ------------------------------------------------------------------ 拖进巢穴
func _contact(p: PlayableCharacter) -> Array[Monster]:
	var out: Array[Monster] = []
	out.assign(spawned_alive().filter(func(m): return m.global_position.distance_to(p.global_position) <= contact_dist and not m.is_stunned()))
	return out


func _try_grab(p: PlayableCharacter) -> void:
	if _regrab_cd > 0.0 or p.laugh == null or not p.laugh.is_helpless() or not p.can_be_grabbed():
		return
	var touching := _contact(p)
	if touching.is_empty() or not p.status.grab(self, 0.0, drag_presses):
		return
	victim = p
	draggers = touching
	p.add_collision_exception_with(self)  # 拖到巢穴口时不被巢穴本身挡住
	p.status.released.connect(_on_released, CONNECT_ONE_SHOT)
	Audio.play("grab", -2.0, 0.05, 1.1)
	SpeechBubble.say(draggers[0], "拖回去～", 18.0)
	if not GameState.has_flag("hint_nest_drag"):
		GameState.set_flag("hint_nest_drag")
		GameState.notify(ReactionDB.hint("nest_drag"))


func _update_drag(delta: float) -> void:
	var p := victim
	if not is_instance_valid(p) or not p.is_alive() or not p.status.is_grabbed_by(self):
		_end_drag()
		return
	# 新贴上来的巢穴怪物一起拖
	for m in _contact(p):
		if not draggers.has(m):
			draggers.append(m)
	draggers.assign(draggers.filter(func(m): return is_instance_valid(m) and m.is_alive() and not m.is_stunned()))
	if broken or draggers.is_empty() or p.laugh == null or not p.laugh.is_helpless():
		p.status.release(false)
		return
	var to := mouth() - p.global_position
	if to.length() <= swallow_dist:
		_swallow(p)
		return
	var speed := drag_speed + drag_speed_per * (draggers.size() - 1)
	var step := to.normalized() * minf(speed * delta, to.length())
	var before := p.global_position
	p.move_and_collide(step)
	var moved := p.global_position - before
	for m in draggers:
		m.global_position += moved
	_trail_t -= delta
	if _trail_t <= 0.0:
		_trail_t = 0.12
		Fx.burst(get_parent(), p.global_position, "dust", 2, 12.0, 0.3, Vector2.ZERO)


func _on_released(src: Node, broke_free: bool) -> void:
	if src != self:
		return
	if broke_free:
		_regrab_cd = regrab_delay
		Audio.play("swish", -4.0)
	_end_drag()


func _end_drag() -> void:
	if is_instance_valid(victim):
		victim.remove_collision_exception_with(self)
		if victim.status.released.is_connected(_on_released):
			victim.status.released.disconnect(_on_released)
	victim = null
	draggers.clear()
	sprite.position.x = 0.0


## 拖进巢穴：公主倒下，播这种巢穴的过场 CG。
func _swallow(p: PlayableCharacter) -> void:
	_end_drag()
	p.status.release(false)
	Audio.play("chomp", 0.0, 0.05, 0.8)
	Fx.puff(get_parent(), mouth())
	_retreat_extras()
	if p.has_method("dragged_into_nest"):
		p.dragged_into_nest(self)
	else:
		p.health.damage(p.health.hp)


# ------------------------------------------------------------------ 受击
func receive_hit(hit: HitData) -> bool:
	if broken or hit.kind != HitData.Kind.ATTACK:
		return false
	if hit.is_burst():
		return true  # 星光爆发由 on_magic_burst 处理
	damage(maxi(1, hit.damage))
	return true


## MagicReactive：满蓄力直接打碎，低档扣 2。
func on_magic_burst(tier: int, _caster: Node) -> void:
	if tier >= 3:
		smash()
	else:
		damage(2)


func damage(n: int) -> void:
	if broken:
		return
	hp -= n
	Audio.play("hit", -4.0, 0.1, 0.8)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.6, 1.3, 1.3), 0.05)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if hp <= 0:
		smash()


func smash() -> void:
	if broken:
		return
	broken = true
	hp = 0
	if is_dragging():
		victim.status.release(false)
	_retreat_extras()
	sprite.frame_coords = Vector2i(2, sheet_row)
	sprite.position.x = 0.0
	collision_layer = 0
	Fx.burst(get_parent(), global_position + Vector2(0, -10), "chip", 10, 50.0, 0.5)
	Fx.puff(get_parent(), global_position + Vector2(0, -8))
	Audio.play("break", -2.0, 0.05)
	ItemDrop.roll(drops, get_parent(), global_position + Vector2(0, 6))
	smashed.emit()
