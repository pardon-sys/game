extends Node
## 楼层扩充 / 第三层 / 魔法 / 组合技测试。
## 用法：Godot --headless --path . res://tests/floor3_test.tscn   （退出码 0 = 全部通过）

var main: Node
var level: Node
var player: PlayableCharacter
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish_dialogue()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	_refresh()
	_run_floors()
	await _run_floor1_rooms()
	await _goto("floor_02")
	await _run_floor2_rooms()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 楼层表
func _run_floors() -> void:
	print("-- 楼层表")
	var ids := Floors.ids()
	check("floors.json 顺序", ids.slice(0, 2) == ["floor_01", "floor_02"])
	check("下一层", Floors.next_of("floor_01") == "floor_02")
	for id in ids:
		check("%s 有地图、对话和场景" % id, FileAccess.file_exists(Floors.map_path(id))
			and FileAccess.file_exists(Floors.dialogues_path(id)) and ResourceLoader.exists(Floors.scene(id)))
	check("第一层根节点记录 floor_id", level.get("floor_id") == "floor_01")


# ------------------------------------------------------------------ 第一层扩充房间
func _run_floor1_rooms() -> void:
	print("-- 第一层扩充房间")
	check("所有地面都能从起点走到（暗墙视为可通行）", _unreachable_cells(true).is_empty())
	var secret_cell := Vector2i(19, 13)
	check("暗墙打开前秘密储物间走不到", _unreachable_cells(false).has(Vector2i(22, 12)))

	var secret: SecretWall = _find("Secret_19_13")
	check("暗墙初始看不出来", not secret.revealed and not secret.interactable.enabled)
	_find("Torch_17_7").on_interact(player)
	check("点亮书房火把后显出裂缝", secret.revealed and secret.interactable.enabled)
	secret.on_interact(player)
	await _wait(0.1)
	var walls: TileMapLayer = level.get_node("Walls")
	check("推倒暗墙后墙格消失", walls.get_cell_source_id(secret_cell) == -1)
	check("秘密储物间可以走到", not _unreachable_cells(false).has(Vector2i(22, 12)))
	check("彩蛋石碑对话存在", Dialogue.has_dialogue("sign_knight_note"))

	var gate_a: Node = _find("Gate_18_40")
	var gate_b: Node = _find("Gate_14_40")
	check("谜题初始：外门关、内门开", not gate_a.is_open and gate_b.is_open)
	_find("Lever_24_40").on_interact(player)
	check("外拉杆：外门开、内门合上", gate_a.is_open and not gate_b.is_open)
	_find("Lever_16_38").on_interact(player)
	check("内拉杆：内门打开，宝物可取", gate_a.is_open and gate_b.is_open)

	var rack: Node = _find("Rack_38_37")
	rack.receive_hit(HitData.make_attack(player, 1, 0.0))
	await _wait(0.5)
	check("武器架可以打碎", not is_instance_valid(rack) or rack.is_queued_for_deletion())
	check("兵器库宝箱放着心", _find("Chest_48_42").item.id == "heart")


# ------------------------------------------------------------------ 第二层扩充房间
func _run_floor2_rooms() -> void:
	print("-- 第二层扩充房间")
	check("第二层所有地面都能从起点走到", _unreachable_cells(true).is_empty())
	var a: Trap = _find("Vent_23_15")
	var b: Trap = _find("Vent_26_16")
	check("喷口回廊两排错开", absf(a.phase_offset - b.phase_offset) > 1.0 and a.idle_time >= 2.0)
	check("蛛丝幽灵房：蜘蛛和幽灵同屋", _find("Spider_40_16") != null and _find("Ghost_35_13") != null)
	check("休息室有检查点", _find("Checkpoint_36_27") != null)
	for id in ["sign2_vents", "sign2_webghost", "sign2_rest"]:
		check("第二层对话 " + id, Dialogue.has_dialogue(id))


## 从公主位置出发做 4 邻域洪泛：墙层有图块的格子不可走（暗墙可选视为可走），门、铁栅视为可走。
## 返回地面层上走不到的格子。
func _unreachable_cells(secret_open: bool) -> Array[Vector2i]:
	var walls: TileMapLayer = level.get_node("Walls")
	var floor_layer: TileMapLayer = level.get_node("Floor")
	var open := {}
	if secret_open:
		for s in level.find_children("*", "SecretWall", true, false):
			open[walls.local_to_map(walls.to_local(s.global_position + Vector2(0, -8)))] = true
	var start := walls.local_to_map(walls.to_local(player.global_position))
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if seen.has(n) or floor_layer.get_cell_source_id(n) == -1:
				continue
			if walls.get_cell_source_id(n) != -1 and not open.has(n):
				continue
			seen[n] = true
			queue.append(n)
	var missing: Array[Vector2i] = []
	for c in floor_layer.get_used_cells():
		if walls.get_cell_source_id(c) == -1 and not seen.has(c):
			missing.append(c)
	if not missing.is_empty():
		print("    走不到的格子（前 10 个）: ", missing.slice(0, 10))
	return missing


# ------------------------------------------------------------------ 工具
func _goto(floor_id: String) -> void:
	main.change_level(Floors.scene(floor_id))
	await _wait(1.2)
	_finish_dialogue()
	_refresh()


func _refresh() -> void:
	level = main.level
	player = get_tree().get_first_node_in_group("player") as PlayableCharacter


func check(label: String, ok: bool) -> void:
	print(("  [通过] " if ok else "  [失败] ") + label)
	if not ok:
		failures += 1


func _find(n: String) -> Node:
	var node := level.find_child(n, true, false)
	if node == null:
		print("    找不到节点 " + n)
	return node


func _finish_dialogue() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 200:
		Dialogue.advance()
		Dialogue.advance()
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
