class_name HandGate
extends StaticBody2D
## 千手之门（第八层夜迷宫）：刻满手印的门，挡着一条捷径。她身上至少有 NEED 只手时按 E 推得开（和她「补偿」的剧情对应：
## 主动让它们找到自己）；推开的瞬间门后伸出手贴上来（挠一下大腿，来源键 hand_gate）。同组（group_name）的门一起开。
## 不够时：「……还、还不够……」
## 图例：X = handgate group=<组名>

const TEX := preload("res://assets/generated/maze/hand_gate.png")
const NEED := 3

@export var group_name := "hgate1"

var opened := false
var sprite: Sprite2D
var reaction_key := "hand_gate"


func _ready() -> void:
	add_to_group(group_name)
	add_to_group("hand_gate")
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 16)
	shape.shape = r
	shape.position = Vector2(0, -8)
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = TEX
	sprite.hframes = 2
	sprite.scale = Vector2(0.5, 0.75)
	sprite.offset = Vector2(0, -16)
	add_child(sprite)
	if IsoView.enabled:
		# 等距楼层：紫色的方块栅栏门（和墙一样高）
		var t := IsoTheme.for_node(self)
		t.dress_cube(sprite, t.gate, t.gate_normal, 1)
		IsoView.anchor(sprite, Vector2(0, -8))
	var it := Interactable.new()
	it.prompt_offset = Vector2(0, -30)
	var ishape := CollisionShape2D.new()
	var ir := RectangleShape2D.new()
	ir.size = Vector2(24, 26)
	ishape.shape = ir
	ishape.position = Vector2(0, -4)
	it.add_child(ishape)
	add_child(it)


func on_interact(player: Node) -> void:
	if opened:
		return
	var cover := HandCover.of(player)
	if cover == null or cover.total() < NEED:
		SpeechBubble.say(player, "……还、还不够……", 28.0)
		return
	for g in get_tree().get_nodes_in_group(group_name):
		if g.has_method("set_open"):
			g.set_open(true)
	# 门后伸出手贴上来
	var h := HitData.make_tickle(self, 8.0)
	h.zone = "thigh"
	player.receive_hit(h)
	SpeechBubble.say(player, "……门、门后面……也有……", 28.0)


func set_open(value: bool) -> void:
	if not value or opened:
		return
	opened = true
	if IsoView.enabled:
		var tw := create_tween().set_parallel()
		tw.tween_property(sprite, "offset:y", sprite.offset.y + 12.0, 0.4)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.4)
	else:
		sprite.frame = 1
	(get_node("Shape") as CollisionShape2D).set_deferred("disabled", true)
	Audio.play("door", -4.0, 0.0, 0.8)
