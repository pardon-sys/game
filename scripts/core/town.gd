class_name Town
extends RefCounted
## 第六层地下小镇的设施入口（道具交互、人物对话的 call 效果都走这里）：
##   rest(公主)          篝火：恢复满生命、闷笑清零、魔力疲倦清零
##   open_shop(商店 id)  集贸市场：data/shop/<id>.json，用金币买东西（await 到关掉商店）
##   open_training()     保卫队训练：TrainingDB（小游戏以后接，现在提示还没开放）


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


static func open_training() -> void:
	var r := TrainingDB.start("")
	GameState.notify(str(r.get("message", "")))
