class_name QuestHerbs
extends QuestRunner
## 支线「手印样本」第五段「旧药方」（矿道深处的草药洞 floor_06_after_herbcave）：光着脚采三味药（HerbPatch），每种 NEED 株。
##   药草：笑铃草（踩上去 / 摘的时候挠脚心）、软须苔（缠住脚趾、定身）、哈欠花（喷粉打哈欠，动不了）。每种摆 PATCHES 丛。
##   站在药草上按住 E 摘 PICK_TIME 秒（摘的时候药草一直在痒）。
##   洞里爬着几只诅咒手印（CurseHand，HANDS）：平时乱爬，她一打哈欠就扑上来贴着挠；冰晶结界 / 千手解放能冻住。
##   闷笑满（SPILL_AT）：笑得一屁股坐在地上，怀里的药草撒一株（那一种的数 −1，那一丛长回来），闷笑回到 SPILL_RESET，贴着的手印被抖下去。
##   三种都够了 → 这一段做完（光着脚的状态收走）。
## 测试：patches、hands、got、held（这一帧当成按住了 E）、progress、pick_at(丛)、spill()。

const NEED := 4
const PICK_TIME := 1.4
const SPILL_AT := 0.97
const SPILL_RESET := 0.4
const PATCHES := {"bell": [Vector2i(7, 4), Vector2i(12, 6), Vector2i(9, 11), Vector2i(15, 9)],
	"moss": [Vector2i(17, 4), Vector2i(20, 8), Vector2i(13, 12), Vector2i(24, 4)],
	"yawn": [Vector2i(22, 11), Vector2i(26, 8), Vector2i(18, 12), Vector2i(11, 3)]}
const HANDS := [Vector2i(14, 7), Vector2i(21, 5), Vector2i(19, 11), Vector2i(9, 8), Vector2i(24, 10)]
const SEEK_R := 80.0

var patches: Array = []
var hands: Array = []
var got := {"bell": 0, "moss": 0, "yawn": 0}
var held := false
var progress := 0.0
var _picking: HerbPatch


func hb() -> Dictionary:
	return q.get("herbs", {})


func setup() -> void:
	patches.clear()
	hands.clear()
	got = {"bell": 0, "moss": 0, "yawn": 0}
	if is_instance_valid(pink):
		pink.set_meta(&"barefoot", true)
		pink.add_buff("barefoot", -1.0)
	for k in PATCHES:
		for c in PATCHES[k]:
			var p := put(HerbPatch.new(), Cutscene.cell_to_world(c)) as HerbPatch
			p.kind = str(k)
			p.yawned.connect(_on_yawn)
			patches.append(p)
	for c in HANDS:
		var h := put(CurseHand.new(), Cutscene.cell_to_world(c)) as CurseHand
		h.ticked.connect(_on_hand_tick)
		hands.append(h)


func _on_hand_tick(_who: Node2D) -> void:
	if randf() < 0.3:
		say(hb().get("react", []), 1.2)


func cleanup() -> void:
	QuestShoes.reset_items()


func done() -> bool:
	return got.values().all(func(n): return int(n) >= NEED)


func status() -> String:
	return str(hb().get("status", "%d %d %d")) % [got["bell"], got["moss"], got["yawn"]]


func _process(delta: float) -> void:
	if not live() or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink) or GameState.player != pink:
		return
	tick(delta, held or Input.is_action_pressed("interact"))


func tick(delta: float, holding: bool) -> void:
	for p in patches:
		if is_instance_valid(p):
			var k := (p as HerbPatch).step(pink, delta)
			if k != "":
				say(hb().get(k, []), 1.6)
	var here: HerbPatch = null
	for p in patches:
		if is_instance_valid(p) and not p.picked and got[p.kind] < NEED and p.inside(pink):
			here = p
			break
	if here and holding:
		if here != _picking:
			_picking = here
			progress = 0.0
		here.pick_tick(pink, delta)
		progress += delta
		if progress >= PICK_TIME:
			pick_at(here)
	else:
		_picking = null
		progress = maxf(0.0, progress - delta)
	if pink.laugh and pink.laugh.ratio() >= SPILL_AT:
		spill()


## 摘下一丛
func pick_at(p: HerbPatch) -> void:
	p.take()
	got[p.kind] = int(got[p.kind]) + 1
	progress = 0.0
	_picking = null
	GameState.notify("%s %d / %d" % [str(hb().get("names", {}).get(p.kind, p.kind)), got[p.kind], NEED], 1.2)
	if done():
		say(hb().get("done", ""), 3.0)
		QuestShoes.reset_items()
		advance()


## 打哈欠：附近的手印扑上来
func _on_yawn(_who: PlayableCharacter) -> void:
	for h in hands:
		if is_instance_valid(h) and h.state in ["wander", "flee"] and h.global_position.distance_to(pink.global_position) <= SEEK_R:
			h.seek(pink)


## 笑得坐在地上：撒一株（随便哪一种有的），那一丛长回来；贴着的手印被抖下去
func spill() -> void:
	var have: Array = got.keys().filter(func(k): return int(got[k]) > 0)
	if not have.is_empty():
		var k: String = have.pick_random()
		got[k] = int(got[k]) - 1
		for p in patches:
			if is_instance_valid(p) and p.kind == k and p.picked:
				p.picked = false
				break
	say(hb().get("spill", ""), 2.4)
	if pink.laugh:
		pink.laugh.set_value(pink.laugh.max_value * SPILL_RESET)
	for h in hands:
		if is_instance_valid(h):
			h.release()
			h.flee(pink.global_position)
