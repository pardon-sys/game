class_name DevConfig
extends RefCounted
## 测试模式：项目根目录的 dev_config.json（dev_mode 一键开关）。
##   enabled()              测试模式是否打开（测试脚本可以用 override 强制开关）
##   skip_points()          跳关点列表（暂停菜单「测试：跳关」）
##   rewards_for(跳关点)     跳到这里要补上的流程奖励（前面各层的；rewards_through 连这一层也给）
##   skip_to(跳关点)         补奖励 → 解除暂停 → 换楼层 → 放到指定格
## 打开后背包不需要先拿到也能打开，背包「CG 图鉴」里所有 CG 都能播放。
##   data_root()            玩家数据（存档等）的根目录：调试运行（编辑器里运行 / 测试模式）用 user://<dev_data_dir>/，
##                          导出的正式游戏用 user://——Godot 的 user:// 在编辑器和导出游戏里是同一个文件夹，不隔离的话调试存档会混进正式游戏。
##                          以后要存别的数据（设置、图鉴进度……）也放在 data_root() 下。

const PATH := "res://dev_config.json"

static var _data := {}
## 不为 null 时覆盖配置文件里的 dev_mode（测试用）。
static var override: Variant = null


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


## 调试运行：在编辑器里运行（包括 headless 测试），或者打开了测试模式。
static func is_dev_run() -> bool:
	return OS.has_feature("editor") or enabled()


## 玩家数据的根目录（以 / 结尾）。
static func data_root() -> String:
	return root_for(is_dev_run())


static func root_for(dev_run: bool) -> String:
	var sub := str(data().get("dev_data_dir", "")).strip_edges().trim_prefix("/").trim_suffix("/")
	if not dev_run or sub == "":
		return "user://"
	return "user://%s/" % sub


static func enabled() -> bool:
	if override != null:
		return bool(override)
	return bool(data().get("dev_mode", false))


static func skip_points() -> Array:
	return data().get("skip_points", [])


## 跳到这个点要补的奖励：楼层表里排在目标楼层前面的各层（rewards_through 的那一层也算）。
static func rewards_for(point: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var target := str(point.get("floor", ""))
	var through := str(point.get("rewards_through", ""))
	var all: Dictionary = data().get("floor_rewards", {})
	for id in Floors.ids():
		if id == target and through != target:
			break
		if all.has(id):
			out.append(all[id])
		if id == target:
			break
	return out


static func grant(rewards: Array[Dictionary]) -> void:
	for r in rewards:
		for f in r.get("flags", []):
			GameState.set_flag(str(f))
		var items: Dictionary = r.get("items", {})
		for id in items:
			var have := GameState.inventory.count(str(id))
			if have < int(items[id]):
				GameState.give_item(ItemDB.get_item(str(id)), int(items[id]) - have)
		for p in r.get("passives", []):
			GameState.grant_passive(str(p), true)


## 跳关：补奖励 → 解除暂停 → 换楼层 → 有 cell 时放到那一格并设为检查点。
static func skip_to(point: Dictionary) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var main := tree.get_first_node_in_group("main")
	if main == null:
		return
	grant(rewards_for(point))
	tree.paused = false
	await main.change_level(Floors.scene(str(point["floor"])))
	if point.has("cell"):
		var c: Array = point["cell"]
		var p := GameState.player
		if is_instance_valid(p):
			p.global_position = Vector2(float(c[0]) * 16.0 + 8.0, float(c[1]) * 16.0 + 12.0)
			GameState.set_checkpoint(p.global_position)
			if p.camera:
				p.camera.reset_smoothing()
