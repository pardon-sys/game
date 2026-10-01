class_name FatiguePuddle
extends Area2D
## 魔力疲倦水液：疲倦爆发（以及魔力水母、女王、组合技）在地上留下的一滩紫色水液。
## 怪物站在里面持续获得「力量」增益（挠痒冷却 ×0.6，离开后还剩 10 秒）；对公主没有直接效果。
## 持续 lifetime 秒，最后 3 秒淡出。加入 "fatigue_puddle" 组。

const SHEET := preload("res://assets/generated/fatigue_puddle.png")

@export var lifetime := 30.0
@export var radius := 24.0
@export var buff_id := "strength"

var _age := 0.0
var _sprite: Sprite2D


## 在 pos 处生成一滩水液。
## 关卡里有 FloorObjects（地面物件层，在地面之上、角色之下）时放进那里，保证水液画在角色脚下。
static func spawn(parent: Node, pos: Vector2, life := 30.0, r := 24.0) -> FatiguePuddle:
	var floor_objs := parent.get_parent().get_node_or_null("FloorObjects") if parent.get_parent() else null
	var host: Node = floor_objs if floor_objs else parent
	var p := FatiguePuddle.new()
	p.lifetime = life
	p.radius = r
	p.position = (host as Node2D).to_local(pos) if host is Node2D else pos
	host.add_child(p)
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4          # 怪物层
	monitorable = false
	add_to_group("fatigue_puddle")
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.hframes = 3
	_sprite.scale = Vector2.ONE * (radius / 24.0)
	add_child(_sprite)
	Fx.emitter(self, "goo", 4, 1.2, {"extents": Vector2(radius * 0.6, radius * 0.25), "speed": [3.0, 6.0],
			"spread": 15.0, "color": Color(0.8, 0.65, 1.0), "z": 1})
	Audio.play("puddle", -4.0)


func _physics_process(delta: float) -> void:
	if GameState.in_dialogue:
		return
	_age += delta
	_sprite.frame = int(_age * 4.0) % 3
	if _age > lifetime - 3.0:
		_sprite.modulate.a = clampf((lifetime - _age) / 3.0, 0.0, 1.0)
	if _age >= lifetime:
		queue_free()
		return
	for body in get_overlapping_bodies():
		if body is Monster and (body as Monster).is_alive():
			(body as Monster).add_buff(buff_id)


func time_left() -> float:
	return lifetime - _age
