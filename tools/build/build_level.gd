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
	"arena": "res://scenes/objects/arena_zone.tscn",
}
## 按 type 参数选择场景的类型：新增怪物/友军/陷阱时在这里注册。
const TYPED_SCENES := {
	"monster": {
		"slime": "res://scenes/actors/monsters/slime.tscn",
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
	},
	"ally": {"knight": "res://scenes/actors/allies/knight.tscn"},
	"trap": {
		"spike": "res://scenes/traps/spike_trap.tscn",
		"feather": "res://scenes/traps/feather_trap.tscn",
		"vent": "res://scenes/traps/powder_vent.tscn",
		"brush": "res://scenes/traps/feather_brush.tscn",
		"vine": "res://scenes/traps/tickle_vine.tscn",
		"fan": "res://scenes/traps/feather_fan.tscn",
		"conveyor": "res://scenes/traps/tickle_conveyor.tscn",
	},
	## 装在墙面格上的陷阱
	"walltrap": {"hand": "res://scenes/traps/grab_hand.tscn"},
}
## 挂在墙上的类型：所在格仍是墙。
const WALL_MOUNTED := ["torch", "face", "walltrap", "secret"]
## 看起来是墙、之后可能打开的格子：照常放墙块，下面再铺一层地面。
const HIDDEN_PASSAGE := ["secret"]
## 放在地面层（总在角色下方）的类型。
const FLOOR_LEVEL := ["trap", "checkpoint", "trigger", "plate", "exit", "arena"]
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
## [level] 段：intro（开场对话 id）、ambient（环境光 r,g,b）
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
	var ts := make_tileset()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/tilesets"))
	ResourceSaver.save(ts, TILESET_PATH)
	ts = ResourceLoader.load(TILESET_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)

	var root := Node2D.new()
	root.name = floor_id.to_pascal_case()
	root.set_script(load("res://scripts/level.gd"))
	root.set("floor_id", floor_id)
	root.set("intro_dialogue", level_meta.get("intro", "intro"))

	var cm := CanvasModulate.new()
	cm.name = "Darkness"
	cm.color = Color(0.2, 0.17, 0.28)
	if level_meta.has("ambient"):
		var c: PackedStringArray = str(level_meta["ambient"]).split(",")
		cm.color = Color(float(c[0]), float(c[1]), float(c[2]))
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
				var inst := _spawn(kind, info, x, y)
				var parent: Node = triggers if kind in ["checkpoint", "trigger", "exit", "arena"] else (floor_objs if kind in FLOOR_LEVEL else ents)
				parent.add_child(inst)
				inst.owner = root
				if kind == "letter":
					decor.set_cell(Vector2i(x, y), SRC_KENNEY, _kcoord(72))
				counts[kind] = counts.get(kind, 0) + 1

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
			# 形如 "X = kind k=v ..."；其它行（空行、说明）忽略
			if line.length() >= 5 and line.substr(1, 3) == " = ":
				var parts := line.substr(4).split(" ", false)
				var info := {"kind": parts[0]}
				for p in parts.slice(1):
					var kv := p.split("=", true, 1)
					if kv.size() == 2:
						info[kv[0]] = _value(kv[1])
				legend[line[0]] = info
		elif section == "[map]" and line != "":
			rows.append(line)
	height = rows.size()
	for r in rows:
		width = maxi(width, r.length())
	return height > 0


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
	var label: String = info.get("type", kind)
	inst.name = "%s_%d_%d" % [label.to_pascal_case(), x, y]
	var base := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE)
	match kind:
		"player", "monster", "ally", "item":
			inst.position = base - Vector2(0, 4)
		"trap", "checkpoint", "trigger", "plate", "exit", "arena":
			inst.position = base - Vector2(0, TILE / 2.0)
		"letter":
			inst.position = base + Vector2(0, 0.5)
		_:
			inst.position = base
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
			["trap", "len"]: prop = "length"
			["trap", "lever"], ["walltrap", "lever"]:
				# 受哪个拉杆组控制：加入该组
				inst.add_to_group(str(value), true)
				continue
			["walltrap", "group"]: prop = "group_name"
			["exit", "target"]:
				prop = "target_level"
				# next = 下一层（运行时按 data/floors.json 解析）；也可以直接写楼层 id
				value = "next" if value == "next" else Floors.scene(value)
			["exit", "w"]:
				inst.set("size", Vector2(float(info["w"]) * TILE, float(info.get("h", 1)) * TILE))
				continue
			["exit", "h"]:
				continue
			["arena", "group"]: prop = "group_name"
			["arena", "w"]:
				inst.set("size", Vector2(float(info["w"]) * TILE, float(info.get("h", 1)) * TILE))
				continue
			["arena", "h"]:
				continue
			["trigger", "w"]:
				inst.set("size", Vector2(float(info["w"]) * TILE, float(info.get("h", 1)) * TILE))
				continue
			["trigger", "h"]:
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


func make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_occlusion_layer()
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	var low := PackedVector2Array([Vector2(-7, -1), Vector2(7, -1), Vector2(7, 8), Vector2(-7, 8)])

	var ken := _atlas(ts, KENNEY, SRC_KENNEY, Vector2i(12, 11))
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
		var atlas := _atlas(ts, src[0], src[1], src[2])
		for y in src[2].y:
			for x in src[2].x:
				var td := atlas.get_tile_data(Vector2i(x, y), 0)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, full)
				if src[1] == SRC_WALLS:
					td.add_occluder_polygon(0)
					td.set_occluder_polygon(0, 0, occ)
	for id in VOID_ROCKS:
		var td := ken.get_tile_data(_kcoord(id), 0)
		td.add_occluder_polygon(0)
		td.set_occluder_polygon(0, 0, occ)
	return ts


func _atlas(ts: TileSet, path: String, id: int, grid: Vector2i) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = load(path)
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, id)
	for y in grid.y:
		for x in grid.x:
			src.create_tile(Vector2i(x, y))
	return src
