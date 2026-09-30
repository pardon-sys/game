class_name SplitSlime
extends Slime
## 分裂史莱姆：粉色大史莱姆，被打倒时分裂成 split_count 只小史莱姆（is_mini）。
## 被满蓄力星光爆发（3 档）打倒时直接蒸发，不会分裂。数值见 data/monsters/split_slime(_mini).tres。

const MINI_STATS := preload("res://data/monsters/split_slime_mini.tres")

@export var is_mini := false
@export var split_count := 2

var _base_scale := 1.5


func _setup() -> void:
	if is_mini:
		stats = MINI_STATS
		_base_scale = 0.85
	super()


func _animate(delta: float) -> void:
	super(delta)
	sprite.scale *= _base_scale


func _on_died() -> void:
	if not is_mini and not (last_hit and last_hit.magic_tier() >= 3):
		_split()
	super()


func _split() -> void:
	var scene: PackedScene = load(scene_file_path)
	Audio.play("pop", -2.0)
	for i in split_count:
		var m: SplitSlime = scene.instantiate()
		m.is_mini = true
		var off := Vector2.from_angle(i * TAU / split_count + randf() * 0.5) * 10.0
		get_parent().add_child.call_deferred(m)
		m.set_deferred("global_position", global_position + off)
		m.set_deferred("velocity", off.normalized() * 90.0)
