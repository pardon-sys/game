class_name TrainingDB
extends RefCounted
## 保卫队训练：训练表 data/training/trainings.json（阶段、上限、每次成功加多少、部位类训练的刑具候选）。
##   list() / info(id)        训练项目
##   run(id, 部位)            开始一轮训练（await 到结束）：扣金币 → 训练小游戏（scripts/training/<kind>.gd，
##                            它负责走到训练位置的过场、小游戏本身、结束后回到训练台）→ TrainingStats.apply → 提示本轮收获
##   devices_for(部位)        训练三、四这个部位可以用的刑具
## 训练成果的数值和上限见 TrainingStats。

const PATH := "res://data/training/trainings.json"
const SCRIPT_DIR := "res://scripts/training/"

## 正在进行的训练（小游戏节点），测试用。
static var current: Node


static func data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else {}
	return parsed if parsed is Dictionary else {}


static func list() -> Array:
	return data().get("trainings", [])


static func info(id: String) -> Dictionary:
	for t in list():
		if t.get("id", "") == id:
			return t
	return {}


static func devices_for(zone: String) -> Array:
	return data().get("zone_devices", {}).get(zone, [])


static func script_of(t: Dictionary) -> String:
	return SCRIPT_DIR + str(t.get("kind", "")) + ".gd"


## 兼容旧接口：能不能开始（不扣钱）。
static func start(id: String) -> Dictionary:
	var t := info(id)
	if t.is_empty():
		return {"ok": false, "message": str(data().get("closed_message", "训练场还在准备中……"))}
	var why := TrainingMenu.blocked_reason(t)
	return {"ok": why == "", "message": why}


static func run(id: String, zone := "") -> Dictionary:
	var t := info(id)
	var why := TrainingMenu.blocked_reason(t, zone) if not t.is_empty() else "没有这项训练"
	if why != "":
		GameState.notify(why)
		return {}
	if not ResourceLoader.exists(script_of(t)):
		GameState.notify(str(data().get("closed_message", "训练场还在准备中……")))
		return {}
	GameState.inventory.remove("coin", TrainingMenu.cost())
	var tree := Engine.get_main_loop() as SceneTree
	var runner: Node = load(script_of(t)).new()
	runner.name = "Training"
	tree.root.add_child(runner)
	current = runner
	var result: Dictionary = await runner.run(t, zone)
	current = null
	if is_instance_valid(runner):
		runner.queue_free()
	TrainingStats.apply(GameState.player)
	GameState.notify(summary_text(t, result))
	return result


static func summary_text(t: Dictionary, result: Dictionary) -> String:
	var gained: Dictionary = result.get("gained", {})
	var parts: Array = []
	for k in gained:
		if float(gained[k]) > 0.0:
			parts.append("%s +%s" % [k, ("%.3f" % gained[k]) if float(gained[k]) < 1.0 else str(snappedf(float(gained[k]), 0.1))])
	return "%s结束：成功 %d 次。%s" % [t.get("name", "训练"), int(result.get("successes", 0)), "　".join(parts)]
