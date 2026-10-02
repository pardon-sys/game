class_name TripwireTrap
extends Trap
## 绊线：横过 tiles_w 格（vertical = true 时竖着）的细线，公主或怪物碰到就触发 targets 组里的陷阱
## （落笼、喷口、机关手……；对准公主的会落在她身上）。冲刺中、被弹在空中的公主不会碰到。触发后 rearm 秒才能再触发。

@export var tiles_w := 3
@export var vertical := false
@export var targets := ""
@export var rearm := 2.0

var fired_count := 0
var _cd := 0.0
var _line: Line2D


func _setup() -> void:
	trigger_mode = TriggerMode.CONTINUOUS
	hit_kind = HitData.Kind.TICKLE
	tickle = 0.0
	affects_enemies = true
	collision_mask = 6
	add_to_group("monster_switch")
	var rect := RectangleShape2D.new()
	var length := tiles_w * 16.0
	rect.size = Vector2(4, length) if vertical else Vector2(length, 4)
	var shape := $Shape as CollisionShape2D
	shape.shape = rect
	shape.position = (Vector2(0, length / 2.0 - 8.0) if vertical else Vector2(length / 2.0 - 8.0, 0))
	_line = Line2D.new()
	_line.width = 1.0
	_line.default_color = Color(0.85, 0.85, 1.0, 0.45)
	_line.points = PackedVector2Array([Vector2(-8, 0), Vector2(length - 8.0, 0)] if not vertical else [Vector2(0, -8), Vector2(0, length - 8.0)])
	_line.z_index = 1
	add_child(_line)


func _apply_effect(_target: Node) -> bool:
	return false


func _physics_process(delta: float) -> void:
	super(delta)
	_cd -= delta
	if _cd > 0.0 or not active or GameState.in_dialogue:
		return
	for b in get_overlapping_bodies():
		if b is PlayableCharacter:
			var pc := b as PlayableCharacter
			if pc.is_dashing() or pc.is_airborne() or not pc.is_alive():
				continue
			fire(pc)
			return
		if b is Monster and (b as Monster).is_alive():
			fire(b)
			return


## 触发 targets 组里的陷阱。
func fire(by: Node = null) -> void:
	_cd = rearm
	fired_count += 1
	Audio.play("lever", -4.0, 0.1, 1.5)
	var tw := create_tween()
	tw.tween_property(_line, "default_color", Color(1, 0.4, 0.6, 1.0), 0.05)
	tw.tween_property(_line, "default_color", Color(0.85, 0.85, 1.0, 0.45), 0.4)
	if targets == "":
		return
	for n in get_tree().get_nodes_in_group(targets):
		if n is Trap:
			(n as Trap).trigger()
		elif n.has_method("trigger"):
			n.trigger()
	if by is Monster and not GameState.has_flag("hint_tripwire_monster"):
		GameState.set_flag("hint_tripwire_monster")
		GameState.notify(ReactionDB.hint("tripwire_monster"))
