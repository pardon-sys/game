class_name CGActor
extends Node2D
## CG 舞台上的演员：公主（princess.png + SpriteSheetAnimator，按视觉状态名选行）或怪物（复制怪物场景里的 Sprite，不带 AI）。
## 由 CGPlayer 按 data/cgs.json 的 cast / actions 创建和驱动。

const PRINCESS_TEX := preload("res://assets/generated/princess.png")
const PRINCESS_CONFIG := preload("res://data/actors/princess_sprites.tres")
const EMOTES := preload("res://assets/generated/emotes.png")
const BUBBLE_INDEX := {"happy": 0, "laugh": 1, "sad": 2, "shy": 3, "angry": 4, "question": 5, "surprise": 6, "dots": 7}

var id := ""
var kind := ""
## 怪物的挠痒音高、回嘴用的来源键。
var reaction_key := ""
var tickle_pitch := 1.0
var sprite: Sprite2D
var animator: SpriteSheetAnimator
var visual := "helpless_1"
var dir := "down"
var facing_left := false
## 怪物的动作风格：idle 轻微上下浮动 / wiggle 挠痒时左右扭 / bounce 一蹦一蹦
var style := "idle"
var _t := 0.0
var _base_scale := Vector2.ONE
var _base_offset := Vector2.ZERO
var _shake := 0.0
var _hframes := 1


## 公主演员。
static func make_princess(actor_id: String) -> CGActor:
	var a := CGActor.new()
	a.id = actor_id
	a.kind = "princess"
	a.sprite = Sprite2D.new()
	a.sprite.name = "Sprite"
	a.sprite.texture = PRINCESS_TEX
	a.sprite.hframes = 16
	a.sprite.vframes = GameState.EMOTIONS.size()
	a.sprite.offset = Vector2(0, -16)
	a.add_child(a.sprite)
	var cfg: SpriteSheetConfig = PRINCESS_CONFIG.duplicate(true)
	cfg.row_names.assign(GameState.VISUALS)
	a.animator = SpriteSheetAnimator.new()
	a.animator.name = "Animator"
	a.animator.config = cfg
	a.add_child(a.animator)
	a.animator.play("helpless")
	return a


## 怪物演员：info = cgs.json 的 actors[key]（scene 场景路径，sprite 可覆盖 hframes / region / scale / frame）。
static func make_monster(actor_id: String, key: String, info: Dictionary) -> CGActor:
	var a := CGActor.new()
	a.id = actor_id
	a.kind = "monster"
	a.reaction_key = key
	var scene: PackedScene = load(str(info.get("scene", "res://scenes/actors/monsters/slime.tscn")))
	var inst := scene.instantiate()
	var src := inst.get_node_or_null("Sprite") as Sprite2D
	a.sprite = src.duplicate() as Sprite2D if src else Sprite2D.new()
	a.sprite.name = "Sprite"
	var stats: MonsterStats = inst.get("stats")
	if stats:
		a.tickle_pitch = stats.tickle_pitch
	inst.free()
	var over: Dictionary = info.get("sprite", {})
	if over.has("hframes"):
		a.sprite.hframes = int(over["hframes"])
	if over.has("region"):
		var r: Array = over["region"]
		a.sprite.region_enabled = true
		a.sprite.region_rect = Rect2(r[0], r[1], r[2], r[3])
	if over.has("scale"):
		a.sprite.scale = Vector2.ONE * float(over["scale"])
	if over.has("offset"):
		a.sprite.offset = Vector2(over["offset"][0], over["offset"][1])
	a.sprite.frame = int(over.get("frame", 0))
	a.add_child(a.sprite)
	return a


func _ready() -> void:
	_base_scale = sprite.scale
	_base_offset = sprite.offset
	_hframes = sprite.hframes


## 公主：换视觉状态 / 动画 / 朝向。
func set_pose(new_visual: String, anim := "", new_dir := "") -> void:
	if new_visual != "":
		visual = new_visual
	if new_dir != "":
		set_dir(new_dir)
	if animator and anim != "":
		animator.play(anim)


func set_dir(d: String) -> void:
	dir = d
	if d in ["left", "right"]:
		facing_left = d == "left"
		if kind == "monster":
			sprite.flip_h = facing_left


func shake(time := 0.3) -> void:
	_shake = maxf(_shake, time)


## 头顶表情气泡。
func bubble(kind_name: String, time := 1.4) -> void:
	if not BUBBLE_INDEX.has(kind_name):
		return
	var b := Sprite2D.new()
	b.texture = EMOTES
	b.hframes = 8
	b.frame = BUBBLE_INDEX[kind_name]
	b.position = Vector2(8, -34 * _base_scale.y)
	b.z_index = 10
	add_child(b)
	b.scale = Vector2(0.3, 0.3)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(time)
	tw.tween_property(b, "modulate:a", 0.0, 0.25)
	tw.tween_callback(b.queue_free)


func top_height() -> float:
	return 30.0 * _base_scale.y


func _process(delta: float) -> void:
	_t += delta
	if animator:
		animator.update(delta, "side" if dir in ["left", "right"] else dir, facing_left, maxi(GameState.VISUALS.find(visual), 0))
	else:
		match style:
			"wiggle":
				sprite.rotation = sin(_t * 30.0) * 0.18
				sprite.offset = _base_offset
			"bounce":
				sprite.rotation = 0.0
				sprite.offset = _base_offset + Vector2(0, -absf(roundf(sin(_t * 9.0) * 4.0)))
			_:
				sprite.rotation = 0.0
				sprite.offset = _base_offset + Vector2(0, roundf(sin(_t * 3.0)))
		if _hframes > 1:
			sprite.frame = int(_t * 6.0) % _hframes
	if _shake > 0.0:
		_shake -= delta
		sprite.position.x = [-1.0, 1.0][int(_t * 40.0) % 2]
	elif not animator:
		sprite.position.x = 0.0
