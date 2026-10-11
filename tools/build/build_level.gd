extends SceneTree
## 把楼层 ASCII 地图（levels/<floor>/map.txt）构建成 levels/<floor>/floor.tscn。
##
## 用法：
##   Godot --headless --path . --script res://tools/build/build_level.gd -- floor=floor_01
##   Godot --headless --path . --script res://tools/build/build_level.gd -- all      # data/floors.json 里的全部楼层
##
## 墙体自动拼接：
##   墙格下方是地面 → 墙面（wall_faces.png，砖墙）；否则 → 墙顶（walls.png，按 8 邻域掩码选图块）。
## 实体：地图字符在 [legend] 里定义类型与参数，实例化对应场景并设置导出属性。

const TILE := 16
const KENNEY := "res://assets/third_party/kenney_tiny_dungeon/tilemap_packed.png"
const WALLS := "res://assets/generated/walls.png"
const FACES := "res://assets/generated/wall_faces.png"
const TILESET_PATH := "res://assets/tilesets/dungeon.tres"
## 2.5D 楼层（[level] style = 2.5d）：同样的图块，但贴图是带法线 / 高光的 CanvasTexture（tools/art/gen_normal_maps.py）
const TILESET_25D_PATH := "res://assets/tilesets/dungeon_25d.tres"
const NORMAL_DIR := "res://assets/generated/normal/"
## 2.5D 楼层的高墙：墙顶往上画多少像素（墙的高度）；墙顶用 walls 图集的第 CAP_ALT 个替代图块（只是往上画，没有碰撞）
const WALL_HEIGHT := 16
const CAP_ALT := 1

const SRC_KENNEY := 0
const SRC_WALLS := 1
const SRC_FACES := 2

const SCENES := {
	"plate": "res://scenes/objects/pressure_plate.tscn",
	"exit": "res://scenes/objects/level_exit.tscn",
	"player": "res://scenes/actors/playable/princess.tscn",
	"chest": "res://scenes/objects/chest.tscn",
	"barrel": "res://scenes/objects/barrel.tscn",
	"rack": "res://scenes/objects/weapon_rack.tscn",
	"secret": "res://scenes/objects/secret_wall.tscn",
	"torch": "res://scenes/objects/torch.tscn",
	"lever": "res://scenes/objects/lever.tscn",
	"gate": "res://scenes/objects/gate.tscn",
	"door": "res://scenes/objects/door.tscn",
	"sign": "res://scenes/objects/sign.tscn",
	"letter": "res://scenes/objects/letter.tscn",
	"item": "res://scenes/items/world_item.tscn",
	"checkpoint": "res://scenes/objects/checkpoint.tscn",
	"trigger": "res://scenes/objects/dialogue_trigger.tscn",
	"banter": "res://scenes/objects/banter_zone.tscn",
	"arena": "res://scenes/objects/arena_zone.tscn",
	"traproom": "res://scenes/objects/trap_room_zone.tscn",
	# 第六层地下小镇
	"npc": "res://scenes/actors/allies/resident.tscn",
	"prop": "res://scenes/objects/prop.tscn",
	"stairs": "res://scenes/objects/stairs.tscn",
	"spawn": "res://scenes/objects/spawn_point.tscn",
	"savepoint": "res://scenes/objects/save_point.tscn",
	"blue_princess": "res://scenes/actors/playable/blue_princess.tscn",
	"spot": "res://scenes/objects/wander_spot.tscn",
	# 潜入模式（scripts/stealth/）
	"stealth": "res://scenes/stealth/stealth_director.tscn",
	"f8director": "res://levels/floor_08/scenes/floor8_director.tscn",
	"f8chase": "res://levels/floor_08/scenes/chase_run.tscn",
	"f8maze": "res://levels/floor_08/scenes/maze_director.tscn",
	"moonlamp": "res://levels/floor_08/scenes/moon_lamp.tscn",
	"memshard": "res://levels/floor_08/scenes/memory_shard.tscn",
	"moonmirror": "res://levels/floor_08/scenes/moon_mirror.tscn",
	"beamswitch": "res://levels/floor_08/scenes/beam_switch.tscn",
	"handgate": "res://levels/floor_08/scenes/hand_gate.tscn",
	"cradle": "res://levels/floor_08/scenes/cradle_bench.tscn",
	"handshadow": "res://levels/floor_08/scenes/hand_shadow.tscn",
	"nightstalker": "res://levels/floor_08/scenes/night_stalker.tscn",
	"stalkerzone": "res://levels/floor_08/scenes/stalker_zone.tscn",
	"f8shelter": "res://levels/floor_08/scenes/shelter_return.tscn",
	"f6war": "res://levels/floor_06/scenes/war_town.tscn",
	# 小镇攻防战（scripts/siege/）
	"siege": "res://scenes/siege/siege_director.tscn",
	"siegewall": "res://scenes/siege/siege_wall.tscn",
	"siegeladder": "res://scenes/siege/siege_ladder.tscn",
	"siegehorn": "res://scenes/siege/siege_horn.tscn",
	"guard_patrol": "res://scenes/stealth/patrol_guard.tscn",
}
## 按 type 参数选择场景的类型：新增怪物/友军/陷阱时在这里注册。
const TYPED_SCENES := {
	"monster": {
		"slime": "res://scenes/actors/monsters/slime.tscn",
		# 第八层夜迷宫
		"glow_moth": "res://levels/floor_08/scenes/glow_moth.tscn",
		"dream_fluff": "res://levels/floor_08/scenes/dream_fluff.tscn",
		"lamp_imp": "res://levels/floor_08/scenes/lamp_imp.tscn",
		"laugh_jar": "res://levels/floor_08/scenes/laugh_jar.tscn",
		"blind_bat": "res://levels/floor_08/scenes/blind_bat.tscn",
		"bat": "res://scenes/actors/monsters/feather_bat.tscn",
		"ghost": "res://scenes/actors/monsters/tickle_ghost.tscn",
		"spider": "res://scenes/actors/monsters/tickle_spider.tscn",
		"troll": "res://scenes/actors/monsters/tickle_troll.tscn",
		"rat": "res://scenes/actors/monsters/foot_rat.tscn",
		"crab": "res://scenes/actors/monsters/pincer_crab.tscn",
		"split_slime": "res://scenes/actors/monsters/split_slime.tscn",
		"mimic": "res://scenes/actors/monsters/mimic.tscn",
		"fairy": "res://scenes/actors/monsters/fairy_swarm.tscn",
		"tentacle": "res://scenes/actors/monsters/tentacle_boss.tscn",
		"mana_jelly": "res://scenes/actors/monsters/mana_jelly.tscn",
		"bubble_fish": "res://scenes/actors/monsters/bubble_fish.tscn",
		"glove": "res://scenes/actors/monsters/ghost_glove.tscn",
		"hedgehog": "res://scenes/actors/monsters/brush_hedgehog.tscn",
		"jelly_queen": "res://scenes/actors/monsters/jelly_queen.tscn",
		"imp": "res://scenes/actors/monsters/machine_imp.tscn",
		"mini_tentacle": "res://scenes/actors/monsters/mini_tentacle.tscn",
		"frog": "res://scenes/actors/monsters/tongue_frog.tscn",
		"squirrel": "res://scenes/actors/monsters/brush_squirrel.tscn",
		"octopus": "res://scenes/actors/monsters/suction_octopus.tscn",
		"caterpillar": "res://scenes/actors/monsters/caterpillar.tscn",
		"barnacle": "res://scenes/actors/monsters/barnacle.tscn",
	},
	"ally": {"knight": "res://scenes/actors/allies/knight.tscn"},
	"trap": {
		"spike": "res://scenes/traps/spike_trap.tscn",
		# 第八层夜迷宫
		"mirror_puddle": "res://levels/floor_08/scenes/mirror_puddle.tscn",
		"shadow_vine": "res://levels/floor_08/scenes/shadow_vine.tscn",
		"feather_curtain": "res://levels/floor_08/scenes/feather_curtain.tscn",
		"hanging_hands": "res://levels/floor_08/scenes/hanging_hands.tscn",
		"feather": "res://scenes/traps/feather_trap.tscn",
		"vent": "res://scenes/traps/powder_vent.tscn",
		"brush": "res://scenes/traps/feather_brush.tscn",
		"vine": "res://scenes/traps/tickle_vine.tscn",
		"fan": "res://scenes/traps/feather_fan.tscn",
		"conveyor": "res://scenes/traps/tickle_conveyor.tscn",
		"totem": "res://scenes/traps/frenzy_totem.tscn",
		"rune": "res://scenes/traps/hex_rune.tscn",
		"stocks": "res://scenes/traps/stocks.tscn",
		"carpet": "res://scenes/traps/sticky_carpet.tscn",
		"vortex": "res://scenes/traps/tickle_vortex.tscn",
		"bounce": "res://scenes/traps/bounce_pad.tscn",
		"soap": "res://scenes/traps/soap_floor.tscn",
		"snare": "res://scenes/traps/snare.tscn",
		"cuffs": "res://scenes/traps/cuffs.tscn",
		"clamp": "res://scenes/traps/clamp.tscn",
		"legloop": "res://scenes/traps/legloop.tscn",
		"mud": "res://scenes/traps/mud.tscn",
		"boots": "res://scenes/traps/boots.tscn",
		"binding": "res://scenes/traps/binding.tscn",
		"teaser": "res://scenes/traps/teaser.tscn",
		"wheel": "res://scenes/traps/wheel.tscn",
		"shower": "res://scenes/traps/shower.tscn",
		"cage": "res://scenes/traps/cage.tscn",
		"tripwire": "res://scenes/traps/tripwire.tscn",
		"supine": "res://scenes/traps/supine.tscn",
		"cushion": "res://scenes/traps/cushion.tscn",
		"prone": "res://scenes/traps/prone.tscn",
		"pit": "res://scenes/traps/pit.tscn",
		"spinwheel": "res://scenes/traps/spinwheel.tscn",
		"vest": "res://scenes/traps/vest.tscn",
		"chute": "res://scenes/traps/chute.tscn",
		# 训练营：脚 / 大腿 / 屁股陷阱
		"foot_thigh_rack": "res://scenes/traps/foot_thigh_rack.tscn",
		"feather_swing": "res://scenes/traps/feather_swing.tscn",
		"thigh_brush_ring": "res://scenes/traps/thigh_brush_ring.tscn",
		"foot_bath": "res://scenes/traps/foot_bath.tscn",
		"sitz_bath": "res://scenes/traps/sitz_bath.tscn",
		"spring_seat": "res://scenes/traps/spring_seat.tscn",
		"saddle_bench": "res://scenes/traps/saddle_bench.tscn",
		"scissor_stand": "res://scenes/traps/scissor_stand.tscn",
	},
	## 怪物巢穴（MonsterNest 的子类）
	"nest": {
		"rat": "res://scenes/objects/nests/rat_hole.tscn",
		"fairy": "res://scenes/objects/nests/fairy_flower.tscn",
		"slime": "res://scenes/objects/nests/slime_pool.tscn",
		"jelly": "res://scenes/objects/nests/jelly_egg.tscn",
		"chest": "res://scenes/objects/nests/chest_pile.tscn",
	},
	## 装在墙面格上的陷阱
	"walltrap": {
		"hand": "res://scenes/traps/grab_hand.tscn",
		"arm": "res://scenes/traps/feather_arm.tscn",
		"wardrobe": "res://scenes/traps/wardrobe.tscn",
		"duster": "res://scenes/traps/duster.tscn",
		"thigh_pincer": "res://scenes/traps/thigh_pincer.tscn",
		"wall_brush": "res://levels/floor_08/scenes/wall_brush.tscn",
	},
}
## 挂在墙上的类型：所在格仍是墙。
const WALL_MOUNTED := ["torch", "face", "walltrap", "secret"]
## 看起来是墙、之后可能打开的格子：照常放墙块，下面再铺一层地面。
const HIDDEN_PASSAGE := ["secret"]
## 放在地面层（总在角色下方）的类型。
const FLOOR_LEVEL := ["trap", "checkpoint", "trigger", "banter", "plate", "exit", "arena", "traproom", "stairs", "spawn", "spot"]
## Kenney 图块中带碰撞的装饰（下半格碰撞）。
const SOLID_DECOR := [63, 64, 65, 72, 73, 74, 75, 82]
## 当墙顶用的 Kenney 碎石图块（整格碰撞）。
const VOID_ROCKS := [12, 24]
const FLOOR_PLAIN := 48
const FLOOR_SHADOW := 50
const FLOOR_RANDOM := [[49, 0.07], [51, 0.04], [42, 0.03]]

var rng := RandomNumberGenerator.new()
var rows: PackedStringArray = []
var legend := {}
## 同一格叠放的其它实体：字符 -> [info, ...]（legend 里用 " + " 连接，例如 "K = trap type=stocks + trap type=vortex radius=3"）。
var stacked := {}
## [level] 段：intro（开场对话 id）、ambient（环境光 r,g,b）、night_ambient（夜晚的环境光，剧情标记 night 时用）、no_switch = true（不能切换操控角色）、
##   style = 2.5d（法线贴图图块集 dungeon_25d.tres + 很暗的环境光 + 墙上的幽光点；关卡进场时人物套实时光照、操控的角色带冷光）、
##   style = iso（同样的光照，画面是等距 45° + 方块墙 + 转镜头：scripts/iso/；iso_theme = 主题名、iso_rotate = false 关掉转镜头）、
##   light_drain = 秒（2.5D 楼层冷光从满到空的时间，0 = 不消耗）
var level_meta := {}
var width := 0
var height := 0


func _initialize() -> void:
	var targets: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("floor="):
			targets.append(a.substr(6))
		elif a == "all":
			targets = Floors.ids()
	if targets.is_empty():
		push_error("用法: -- floor=<id> 或 -- all")
		quit(1)
		return
	var err := OK
	for id in targets:
		err = maxi(err, build(id))
	quit(err)


func _reset() -> void:
	rng.seed = 20260928
	rows = []
	legend = {}
	level_meta = {}
	width = 0
	height = 0


func build(floor_id: String) -> int:
	_reset()
	if not parse(Floors.map_path(floor_id)):
		return 1
	var style := str(level_meta.get("style", ""))
	# 等距（style = iso）：逻辑图层和 2.5D 一样（带法线的图块集），画面由运行时的 IsoView / IsoTerrain 画，不加高墙图层
	var lit := style == "2.5d" or style == "iso"
	var ts_path := TILESET_25D_PATH if lit else TILESET_PATH
	var ts := make_tileset(lit)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/tilesets"))
	ResourceSaver.save(ts, ts_path)
	ts = ResourceLoader.load(ts_path, "", ResourceLoader.CACHE_MODE_REPLACE)

	var root := Node2D.new()
	root.name = floor_id.to_pascal_case()
	root.set_script(load("res://scripts/level.gd"))
	root.set("floor_id", floor_id)
	root.set("intro_dialogue", level_meta.get("intro", "intro"))
	root.set("intro_cutscene", level_meta.get("intro_cutscene", ""))
	root.set("no_switch", str(level_meta.get("no_switch", "")) == "true")
	root.set("style", style)
	root.set("iso_theme", str(level_meta.get("iso_theme", "")))
	root.set("iso_rotate", str(level_meta.get("iso_rotate", "true")) != "false")
	root.set("light_drain", float(level_meta.get("light_drain", 0.0)))

	var cm := CanvasModulate.new()
	cm.name = "Darkness"
	cm.color = Color(0.2, 0.17, 0.28) if not lit else Color(0.05, 0.055, 0.1)
	if level_meta.has("ambient"):
		var c: PackedStringArray = str(level_meta["ambient"]).split(",")
		cm.color = Color(float(c[0]), float(c[1]), float(c[2]))
	# 夜晚的环境光（剧情标记 night 时用）：[level] 段 night_ambient = r,g,b
	if level_meta.has("night_ambient"):
		var nc: PackedStringArray = str(level_meta["night_ambient"]).split(",")
		root.set("night_ambient", Color(float(nc[0]), float(nc[1]), float(nc[2])))
	var floor_layer := _layer("Floor", ts)
	var walls_layer := _layer("Walls", ts)
	var floor_objs := Node2D.new()
	floor_objs.name = "FloorObjects"
	var ents := Node2D.new()
	ents.name = "Entities"
	ents.y_sort_enabled = true
	var decor := _layer("Decor", ts)
	decor.y_sort_enabled = true
	var triggers := Node2D.new()
	triggers.name = "Triggers"
	for n in [cm, floor_layer, walls_layer, floor_objs, ents, triggers]:
		root.add_child(n)
		n.owner = root
	ents.add_child(decor)
	decor.owner = root

	var counts := {}
	for y in height:
		for x in width:
			var c := cell(x, y)
			var info: Dictionary = legend.get(c, {})
			var kind: String = kind_at(x, y)
			if is_wall(x, y):
				_place_wall(walls_layer, x, y, info)
				if kind in HIDDEN_PASSAGE:
					floor_layer.set_cell(Vector2i(x, y), SRC_KENNEY, _kcoord(FLOOR_PLAIN))
			else:
				var tile := FLOOR_PLAIN
				if kind == "floor" and info.has("tile"):
					tile = int(info["tile"])
				elif is_face(x, y - 1):
					tile = FLOOR_SHADOW
				else:
					for pair in FLOOR_RANDOM:
						if rng.randf() < pair[1]:
							tile = pair[0]
							break
				floor_layer.set_cell(Vector2i(x, y), SRC_KENNEY, _kcoord(tile))
			if kind == "decor":
				decor.set_cell(Vector2i(x, y), SRC_KENNEY, _kcoord(int(info["tile"])))
			elif SCENES.has(kind) or TYPED_SCENES.has(kind):
				for one in [info] + stacked.get(c, []):
					var k: String = one["kind"]
					if not (SCENES.has(k) or TYPED_SCENES.has(k)):
						continue
					var inst := _spawn(k, one, x, y)
					var parent: Node = triggers if k in ["checkpoint", "trigger", "banter", "exit", "arena", "traproom"] else (floor_objs if k in FLOOR_LEVEL else ents)
					parent.add_child(inst)
					inst.owner = root
					if k == "letter":
						decor.set_cell(Vector2i(x, y), SRC_KENNEY, _kcoord(72))
					counts[k] = counts.get(k, 0) + 1

	if style == "2.5d":
		_add_tall_walls(root, ents, walls_layer, ts)
	if lit:
		_add_wall_glows(root, walls_layer)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack 失败: %s" % err)
		return 1
	var out := Floors.scene(floor_id)
	err = ResourceSaver.save(ps, out)
	print("已生成 %s (%dx%d) 实体: %s" % [out, width, height, counts])
	root.free()
	return err


# ------------------------------------------------------------------ 解析
func parse(path: String) -> bool:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("读不到关卡文件: " + path)
		return false
	var section := ""
	for raw in text.split("\n"):
		var line := raw.strip_edges(false, true)
		if line == "[legend]" or line == "[map]" or line == "[level]":
			section = line
			continue
		if section == "[level]":
			var kv := line.split("=", true, 1)
			if kv.size() == 2 and not line.begins_with("#"):
				level_meta[kv[0].strip_edges()] = kv[1].strip_edges()
			continue
		if section == "[legend]":
			# 形如 "X = kind k=v ..."；同一格叠放多个实体用 " + " 连接；其它行（空行、说明）忽略
			if line.length() >= 5 and line.substr(1, 3) == " = ":
				var specs := line.substr(4).split(" + ", false)
				var infos: Array = []
				for spec in specs:
					var parts := spec.split(" ", false)
					var info := {"kind": parts[0]}
					for p in parts.slice(1):
						var kv := p.split("=", true, 1)
						if kv.size() == 2:
							info[kv[0]] = _value(kv[1])
					infos.append(info)
				legend[line[0]] = infos[0]
				if infos.size() > 1:
					stacked[line[0]] = infos.slice(1)
		elif section == "[map]" and line != "":
			rows.append(line)
	height = rows.size()
	for r in rows:
		width = maxi(width, r.length())
	return height > 0


## "sole:1.5,thigh:1.3" -> {"sole": 1.5, "thigh": 1.3}（图例里的部位倍率 / 部位权重）。
func _dict(v: Variant) -> Dictionary:
	var out := {}
	for part in str(v).split(",", false):
		var kv := part.split(":", true, 1)
		if kv.size() == 2:
			out[kv[0].strip_edges()] = kv[1].to_float()
	return out


func _value(s: String) -> Variant:
	if s == "true":
		return true
	if s == "false":
		return false
	if s.is_valid_int():
		return s.to_int()
	if s.is_valid_float():
		return s.to_float()
	return s


func cell(x: int, y: int) -> String:
	if y < 0 or y >= height or x < 0 or x >= rows[y].length():
		return "#"
	return rows[y][x]


func kind_at(x: int, y: int) -> String:
	var c := cell(x, y)
	if c == "#":
		return "wall"
	if c == ".":
		return "floor"
	return legend.get(c, {}).get("kind", "floor")


func is_wall(x: int, y: int) -> bool:
	var k := kind_at(x, y)
	return k == "wall" or k in WALL_MOUNTED


func is_face(x: int, y: int) -> bool:
	return is_wall(x, y) and not is_wall(x, y + 1)


func is_top(x: int, y: int) -> bool:
	return is_wall(x, y) and not is_face(x, y)


# ------------------------------------------------------------------ 2.5D 高墙
## Walls 图层只管碰撞 / 挡光 / 寻路（画面透明）；画面交给两个 y 排序的图层（放在 Entities 里，和人物一起排序）：
##   WallFaces3D：下面是地面的墙格画砖墙正面；WallCaps3D：每个墙格的墙顶往上画 WALL_HEIGHT 像素（排序点在墙脚）。
## 人物走到墙后（墙的上方）时被墙顶挡住，走在墙前时挡住墙。
func _add_tall_walls(root: Node, ents: Node, walls_layer: TileMapLayer, ts: TileSet) -> void:
	walls_layer.self_modulate = Color(1, 1, 1, 0)
	var faces := _layer("WallFaces3D", ts)
	var caps := _layer("WallCaps3D", ts)
	for l in [faces, caps]:
		l.y_sort_enabled = true
		l.collision_enabled = false
		l.occlusion_enabled = false
		ents.add_child(l)
		l.owner = root
	for c in walls_layer.get_used_cells():
		if is_face(c.x, c.y) and walls_layer.get_cell_source_id(c) == SRC_FACES:
			faces.set_cell(c, SRC_FACES, walls_layer.get_cell_atlas_coords(c))
		var mask := 0
		for n in NEIGHBORS:
			var p: Vector2i = c + n[1]
			if p.x >= 0 and p.y >= 0 and p.x < width and p.y < height and not is_wall(p.x, p.y):
				mask |= n[0]
		caps.set_cell(c, SRC_WALLS, Vector2i(mask % 16, mask / 16), CAP_ALT)


# ------------------------------------------------------------------ 墙体
const NEIGHBORS := [
	[1, Vector2i(0, -1)], [2, Vector2i(1, 0)], [4, Vector2i(0, 1)], [8, Vector2i(-1, 0)],
	[16, Vector2i(1, -1)], [32, Vector2i(1, 1)], [64, Vector2i(-1, 1)], [128, Vector2i(-1, -1)],
]


func _place_wall(layer: TileMapLayer, x: int, y: int, info: Dictionary) -> void:
	if is_face(x, y):
		var flags := 0
		if not is_wall(x, y - 1):
			flags |= 1
		if not is_wall(x - 1, y):
			flags |= 2
		if not is_wall(x + 1, y):
			flags |= 4
		var variant := 0
		if info.get("kind", "") == "face":
			variant = int(info.get("variant", 0))
		elif flags == 0 and kind_at(x, y) == "wall" and rng.randf() < 0.06:
			variant = [1, 3].pick_random()
		layer.set_cell(Vector2i(x, y), SRC_FACES, Vector2i(variant, flags))
		return
	var mask := 0
	for n in NEIGHBORS:
		var p: Vector2i = Vector2i(x, y) + n[1]
		if p.x >= 0 and p.y >= 0 and p.x < width and p.y < height and not is_top(p.x, p.y):
			mask |= n[0]
	if mask == 0 and rng.randf() < 0.05:
		layer.set_cell(Vector2i(x, y), SRC_KENNEY, _kcoord(VOID_ROCKS.pick_random()))
	else:
		layer.set_cell(Vector2i(x, y), SRC_WALLS, Vector2i(mask % 16, mask / 16))


# ------------------------------------------------------------------ 实体
func _spawn(kind: String, info: Dictionary, x: int, y: int) -> Node2D:
	var path: String = SCENES.get(kind, "")
	if TYPED_SCENES.has(kind):
		path = TYPED_SCENES[kind].get(info.get("type", ""), "")
	if path == "":
		push_error("(%d,%d) 未注册的类型: %s %s" % [x, y, kind, info])
		return Node2D.new()
	var inst: Node2D = load(path).instantiate()
	var label: String = info.get("type", info.get("id", kind)) if kind in ["prop", "npc"] else info.get("type", kind)
	inst.name = "%s_%d_%d" % [label.to_pascal_case(), x, y]
	var base := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE)
	match kind:
		"player", "monster", "ally", "item", "npc", "spawn", "blue_princess", "spot":
			inst.position = base - Vector2(0, 4)
		"stairs":
			inst.position = base - Vector2(0, TILE / 2.0)
		"trap", "checkpoint", "trigger", "banter", "plate", "exit", "arena", "traproom":
			inst.position = base - Vector2(0, TILE / 2.0)
		"letter":
			inst.position = base + Vector2(0, 0.5)
		_:
			inst.position = base
	if kind == "prop":
		inst.set("kind", info.get("type", "crate"))
	for key in info:
		if key in ["kind", "type"]:
			continue
		var value: Variant = info[key]
		var prop: String = key
		match [kind, key]:
			["gate", "group"], ["secret", "group"]: prop = "group_name"
			["trap", "offset"]: prop = "phase_offset"
			["chest", "item"], ["item", "id"]:
				prop = "item"
				value = ItemDB.get_item(value)
			["door", "key"]:
				prop = "required_key"
				value = ItemDB.get_item(value)
			["trap", "speed"]: prop = "spin_speed"
			["trap", "len"], ["walltrap", "len"]: prop = "length"
			# 多格陷阱（黏黏毛毯）：从所在格向右 w 格、向下 h 格
			["trap", "w"]: prop = "tiles_w"
			["trap", "h"]: prop = "tiles_h"
			["trap", "group"]: prop = "group_name"
			[_, "zones"]:
				prop = "tickle_zones"
				value = _dict(value)
			[_, "exposed"]:
				value = _dict(value)
			["trap", "lever"], ["walltrap", "lever"]:
				# 受哪个拉杆组控制：加入该组
				inst.add_to_group(str(value), true)
				continue
			["walltrap", "group"]: prop = "group_name"
			["npc", "id"]: prop = "npc_id"
			["stairs", "target"]:
				prop = "target_level"
				value = Floors.scene(value)
			["exit", "target"]:
				prop = "target_level"
				# next = 下一层（运行时按 data/floors.json 解析）；也可以直接写楼层 id
				value = "next" if value == "next" else Floors.scene(value)
			["exit", "w"]:
				inst.set("size", Vector2(float(info["w"]) * TILE, float(info.get("h", 1)) * TILE))
				continue
			["exit", "h"]:
				continue
			["arena", "group"], ["traproom", "group"]: prop = "group_name"
			["traproom", "w"]:
				inst.set("size", Vector2(float(info["w"]) * TILE, float(info.get("h", 1)) * TILE))
				continue
			["traproom", "h"]:
				continue
			["arena", "w"]:
				inst.set("size", Vector2(float(info["w"]) * TILE, float(info.get("h", 1)) * TILE))
				continue
			["arena", "h"]:
				continue
			["trigger", "w"], ["banter", "w"]:
				inst.set("size", Vector2(float(info["w"]) * TILE, float(info.get("h", 1)) * TILE))
				continue
			["trigger", "h"], ["banter", "h"]:
				continue
		if not prop in inst:
			push_warning("(%d,%d) %s 没有属性 %s" % [x, y, inst.name, prop])
		inst.set(prop, value)
	return inst


# ------------------------------------------------------------------ TileSet
func _layer(n: String, ts: TileSet) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = n
	l.tile_set = ts
	return l


func _kcoord(id: int) -> Vector2i:
	return Vector2i(id % 12, id / 12)


## 2.5D 楼层：墙面上零星的幽光点（冷蓝 / 淡紫，很暗），让墙和地面有微光。
func _add_wall_glows(root: Node2D, walls_layer: TileMapLayer) -> void:
	var glows := Node2D.new()
	glows.name = "WallGlows"
	root.add_child(glows)
	glows.owner = root
	var tex := load("res://assets/lights/light_soft.tres")
	var n := 0
	for y in height:
		for x in width:
			if not is_face(x, y) or rng.randf() > 0.035:
				continue
			var l := PointLight2D.new()
			l.name = "Glow_%d_%d" % [x, y]
			l.texture = tex
			l.texture_scale = rng.randf_range(0.28, 0.42)
			l.energy = rng.randf_range(0.18, 0.32)
			l.height = 20.0
			l.color = Color(0.45, 0.75, 1.0) if rng.randf() < 0.6 else Color(0.75, 0.5, 1.0)
			l.position = Vector2(x * TILE + TILE / 2.0, y * TILE + TILE + 2.0)
			glows.add_child(l)
			l.owner = root
			n += 1


func make_tileset(lit := false) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_occlusion_layer()
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	var low := PackedVector2Array([Vector2(-7, -1), Vector2(7, -1), Vector2(7, 8), Vector2(-7, 8)])

	var ken := _atlas(ts, KENNEY, SRC_KENNEY, Vector2i(12, 11), lit)
	for y in 11:
		for x in 12:
			var id := y * 12 + x
			var td := ken.get_tile_data(Vector2i(x, y), 0)
			td.y_sort_origin = 8
			if id in SOLID_DECOR:
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, low)
			elif id in VOID_ROCKS:
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, full)
	# 墙顶遮挡光线（墙面不遮挡，这样火把能照亮所在的墙面）
	var occ := OccluderPolygon2D.new()
	occ.polygon = full
	for src in [[WALLS, SRC_WALLS, Vector2i(16, 16)], [FACES, SRC_FACES, Vector2i(4, 8)]]:
		var atlas := _atlas(ts, src[0], src[1], src[2], lit)
		for y in src[2].y:
			for x in src[2].x:
				var td := atlas.get_tile_data(Vector2i(x, y), 0)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, full)
				if src[1] == SRC_WALLS:
					td.add_occluder_polygon(0)
					td.set_occluder_polygon(0, 0, occ)
				if lit:
					# 高墙（WallFaces3D / WallCaps3D 图层用）：墙面按墙脚排序；墙顶的替代图块往上画 WALL_HEIGHT 像素
					td.y_sort_origin = 8
					if src[1] == SRC_WALLS:
						var alt := atlas.create_alternative_tile(Vector2i(x, y), CAP_ALT)
						var cap := atlas.get_tile_data(Vector2i(x, y), alt)
						cap.texture_origin = Vector2i(0, WALL_HEIGHT)
						cap.y_sort_origin = 8
	for id in VOID_ROCKS:
		var td := ken.get_tile_data(_kcoord(id), 0)
		td.add_occluder_polygon(0)
		td.set_occluder_polygon(0, 0, occ)
	return ts


func _atlas(ts: TileSet, path: String, id: int, grid: Vector2i, lit := false) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = load(path)
	if lit:
		# 带法线 / 高光的贴图（2.5D 楼层）：tools/art/gen_normal_maps.py 生成 <图集名>_n.png / _s.png
		var base := path.get_file().get_basename()
		var ct := CanvasTexture.new()
		ct.diffuse_texture = load(path)
		if ResourceLoader.exists(NORMAL_DIR + base + "_n.png"):
			ct.normal_texture = load(NORMAL_DIR + base + "_n.png")
		if ResourceLoader.exists(NORMAL_DIR + base + "_s.png"):
			ct.specular_texture = load(NORMAL_DIR + base + "_s.png")
			ct.specular_shininess = 0.55
		src.texture = ct
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, id)
	for y in grid.y:
		for x in grid.x:
			src.create_tile(Vector2i(x, y))
	return src
