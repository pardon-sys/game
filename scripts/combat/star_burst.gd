class_name StarBurst
extends Node2D
## 星光爆发：公主蓄力魔法的范围判定与特效。
##   StarBurst.cast(caster, tier) -> Array[Node]   以施法者为中心判定，播放特效，返回命中的对象
## 档位 1~3（TIERS）：半径、伤害、击退；3 档额外让怪物僵直（Monster.stun）。
## 范围内 "magic_reactive" 组的节点（MagicReactive 接口）都会收到 on_magic_burst(tier, caster)，
## 由它们自己决定几档才有反应（例如 3 档才能吹散粉雾、斩断藤蔓）。

const SHEET := preload("res://assets/generated/star_burst.png")
const LIGHT_TEX := preload("res://assets/lights/light_soft.tres")
const FRAMES := 6
const FPS := 16.0
const TIERS := [
	{},
	{"radius": 42.0, "damage": 2, "knockback": 140.0, "stun": 0.0},
	{"radius": 60.0, "damage": 3, "knockback": 190.0, "stun": 0.0},
	{"radius": 84.0, "damage": 4, "knockback": 240.0, "stun": 1.5},
]
## 魔力疲倦满时的自动爆发：满蓄力档的范围、一半伤害、击退减半，范围内的怪物僵直 0.5 秒，不触发 MagicReactive。
const FATIGUE := {"radius": 84.0, "damage": 2, "knockback": 120.0, "stun": 0.5}
## 角色的身体半径：中心在这个距离内也算命中。
const BODY_ALLOWANCE := 6.0

var tier := 1
var _sprite: Sprite2D
var _light: PointLight2D
var _t := 0.0


static func params(t: int) -> Dictionary:
	return TIERS[clampi(t, 1, TIERS.size() - 1)]


static func center_of(caster: Node2D) -> Vector2:
	return caster.global_position + Vector2(0, -6)


static func cast(caster: Node2D, t: int) -> Array[Node]:
	return cast_with(caster, params(t), t, "magic_%d" % t, true)


## 疲倦爆发：满蓄力档的范围、一半伤害，紫色的爆发环、低沉的音效。
## 疲倦爆发：魔力疲倦释放训练提高强度（伤害、击退 ×倍率，范围 ×(1 + 一半加成)）。
static func cast_fatigue(caster: Node2D) -> Array[Node]:
	var p := FATIGUE.duplicate()
	var m := TrainingStats.burst_mult() if caster == GameState.player else 1.0
	if m > 1.0:
		p["damage"] = int(round(float(FATIGUE["damage"]) * m))
		p["knockback"] = float(FATIGUE["knockback"]) * m
		p["radius"] = float(FATIGUE["radius"]) * (1.0 + (m - 1.0) * 0.5)
	return cast_with(caster, p, 3, "fatigue_burst", false, Color(0.75, 0.55, 1.0), 0.7)


## 通用：params = {radius, damage, knockback, stun}；visual_tier 决定爆发环的大小；reactive = 是否通知 MagicReactive。
static func cast_with(caster: Node2D, p: Dictionary, visual_tier: int, tag: String, reactive: bool,
		tint := Color.WHITE, pitch := 1.0) -> Array[Node]:
	var t := visual_tier
	var center := center_of(caster)
	var radius: float = p["radius"]
	var hit: Array[Node] = []
	for n in caster.get_tree().get_nodes_in_group("actor"):
		var a := n as Actor
		if a == null or a == caster or not a.is_alive() or not Faction.are_hostile(caster, a):
			continue
		if a.global_position.distance_to(center) > radius + BODY_ALLOWANCE:
			continue
		var h := HitData.make_attack(caster, p["damage"], p["knockback"])
		h.origin = center
		h.tag = tag
		a.receive_hit(h)
		if p["stun"] > 0.0 and a.has_method("stun") and a.is_alive():
			a.stun(p["stun"])
		hit.append(a)
	for n in (caster.get_tree().get_nodes_in_group("magic_reactive") if reactive else []):
		if not (n is Node2D) or not Contracts.is_magic_reactive(n):
			continue
		var extra := float(n.get("magic_radius")) if n.get("magic_radius") != null else 0.0
		if (n as Node2D).global_position.distance_to(center) <= radius + extra:
			n.on_magic_burst(t, caster)
			if not hit.has(n):
				hit.append(n)
	var fx := StarBurst.new()
	fx.tier = t
	fx.modulate = tint
	caster.get_parent().add_child(fx)
	fx.global_position = center
	Audio.play("star_burst", -2.0, 0.04, pitch * (1.0 + (t - 1) * 0.08))
	# 魔力释放的水声：档位越高越响、越低沉
	Audio.play("water_release", -8.0 + t * 2.0, 0.05, pitch * (1.05 - (t - 1) * 0.06))
	return hit


func _ready() -> void:
	z_index = 5
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.hframes = FRAMES
	_sprite.vframes = 3
	_sprite.material = mat
	_sprite.frame = (tier - 1) * FRAMES
	add_child(_sprite)
	_light = PointLight2D.new()
	_light.texture = LIGHT_TEX
	_light.color = Color(1.0, 0.9, 0.6)
	_light.energy = 0.6 + tier * 0.2
	_light.texture_scale = 0.8 + tier * 0.5
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	var f := int(_t * FPS)
	if f >= FRAMES:
		queue_free()
		return
	_sprite.frame = (tier - 1) * FRAMES + f
	_light.energy = (0.6 + tier * 0.2) * (1.0 - float(f) / FRAMES)
