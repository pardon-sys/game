class_name Town
extends RefCounted
## 第六层地下小镇的设施入口（道具交互、人物对话的 call 效果都走这里）：
##   rest(公主)          篝火：恢复满生命、闷笑清零、魔力疲倦清零
##   open_shop(商店 id)  集贸市场：data/shop/<id>.json，用金币买东西（await 到关掉商店）
##   open_training()     保卫队训练：训练菜单（TrainingMenu）→ TrainingDB.run（训练小游戏）
##   choose_training() / start_training_later(选择)  人物对话里用：对话里只选项目，等对话结束再开训练
##                       （不然整轮训练期间对话 runner 都算在跑，训练里的对话结束后 in_dialogue 不会复位，地图就卡住了）


static func rest(player: Node) -> void:
	var p := player as PlayableCharacter
	if p == null:
		return
	if p.health:
		p.health.fill()
	if p.laugh:
		p.laugh.clear()
	if p.get("fatigue"):
		p.fatigue.clear()
	Audio.play("chime", -4.0, 0.05, 0.9)
	Fx.burst(p.get_parent(), p.global_position + Vector2(0, -10), "heart", 8, 30.0, 0.8, Vector2(0, -30), Color(1, 0.7, 0.5))
	GameState.notify("在篝火旁暖和了一会儿——生命值恢复了，笑意也平复了")


static func open_shop(id := "market") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var ui := ShopUI.new()
	tree.root.add_child(ui)
	await ui.open(id)
	ui.queue_free()


## 训练台：训练菜单 → 选好的训练（扣金币、过场、小游戏，await 到这一轮结束）。
static func open_training() -> void:
	var r := await choose_training()
	if not r.is_empty():
		await TrainingDB.run(str(r["id"]), str(r.get("zone", "")))


## 只打开训练菜单选项目：返回 {id, zone}（取消返回 {}）。
static func choose_training() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var menu := TrainingMenu.new()
	tree.root.add_child(menu)
	var r: Dictionary = await menu.choose()
	menu.queue_free()
	return r


## 等人物对话 / 过场都结束了再开始训练（调用方不要 await）。
static func start_training_later(r: Dictionary) -> void:
	if r.is_empty():
		return
	await TrainingDB.wait_dialogue_free()
	await TrainingDB.run(str(r["id"]), str(r.get("zone", "")))
