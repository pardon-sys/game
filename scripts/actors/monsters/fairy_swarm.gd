class_name FairySwarm
extends Monster
## 羽毛小精灵群：一团绕圈飞的小精灵，只挠痒不攻击，高频小量（数值见 data/monsters/fairy_swarm.tres）。
## 普通攻击有 dodge_chance 概率被闪开；魔法必中，满蓄力星光爆发（3 档）直接击散整群（MagicReactive）。

const SHEET := preload("res://assets/generated/fairy.png")

@export_range(0.0, 1.0) var dodge_chance := 0.7
@export var fairy_count := 5
@export var orbit := 7.0

var magic_radius := 6.0
var _fairies: Array[Sprite2D] = []


func _setup() -> void:
	super()
	add_to_group("magic_reactive")
	sprite.texture = SHEET
	sprite.hframes = 2
	sprite.region_enabled = false
	for i in fairy_count - 1:
		var f := Sprite2D.new()
		f.texture = SHEET
		f.hframes = 2
		f.material = sprite.material
		add_child(f)
		_fairies.append(f)


func receive_hit(hit: HitData) -> bool:
	if hit.kind == HitData.Kind.ATTACK and not hit.is_magic() and randf() < dodge_chance:
		Audio.play("chime", -8.0, 0.1, 1.3)
		SpeechBubble.say(self, "闪开啦~", 18.0)
		return false
	return super(hit)


## MagicReactive：3 档星光爆发把整群击散。
func on_magic_burst(tier: int, caster: Node) -> void:
	if tier >= 3 and is_alive():
		var h := HitData.make_attack(caster, health.hp, 0.0)
		h.tag = "magic_%d" % tier
		_attack_invuln = 0.0
		super.receive_hit(h)


## 轻飘飘地飞：带一点上下浮动的蛇形。
func _move(dir: Vector2, speed: float, delta: float) -> void:
	if dir != Vector2.ZERO:
		dir = (dir + dir.orthogonal() * sin(_t * 4.0) * 0.5).normalized()
	super(dir, speed, delta)


func _on_tickle_performed(_t: Node) -> void:
	if randf() < 0.3:
		Audio.play("chime", -12.0, 0.15)


func _animate(_delta: float) -> void:
	var frame := int(_t * 12.0) % 2
	sprite.frame = frame
	sprite.offset = Vector2(0, -12.0 + roundf(sin(_t * 5.0) * 2.0))
	for i in _fairies.size():
		var f := _fairies[i]
		var a := _t * 3.0 + i * TAU / _fairies.size()
		f.frame = (frame + i) % 2
		f.position = (Vector2(cos(a), sin(a) * 0.5) * orbit + Vector2(0, -12.0 + sin(_t * 6.0 + i) * 2.0)).round()
