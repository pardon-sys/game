class_name TrainingDB
extends RefCounted
## 保卫队训练（接口）：训练项目在 data/training/trainings.json，每种训练以后各自是一个小游戏，
## 场景放在 scenes/training/<训练 id>.tscn（根节点实现 start() 并在结束时发 finished(过关: bool)）。
##   list()        训练项目列表 [{id, name, desc, status}]
##   start(id)     开始训练：现在都还没开放，返回 {ok: false, message}；以后找到对应场景就加载小游戏
## 训练成功后的奖励（升级被动等）写在训练项目的 reward 里，由小游戏系统调用 grant(id)。

const PATH := "res://data/training/trainings.json"
const SCENE_DIR := "res://scenes/training/"


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


static func scene_of(id: String) -> String:
	return SCENE_DIR + id + ".tscn"


## 开始训练（id 为空 = 打开训练菜单）。小游戏场景还没有时返回「还没开放」。
static func start(id: String) -> Dictionary:
	if id != "" and ResourceLoader.exists(scene_of(id)):
		return {"ok": true, "scene": scene_of(id)}
	return {"ok": false, "message": str(data().get("closed_message", "训练场还在准备中……"))}


## 训练过关的奖励（小游戏系统调用）：reward = {passive: id} / {upgrade: id} / {max_hp: n}
static func grant(id: String) -> void:
	var r: Dictionary = info(id).get("reward", {})
	if r.has("passive"):
		GameState.grant_passive(str(r["passive"]))
	if r.has("upgrade"):
		GameState.upgrade_passive(str(r["upgrade"]))
