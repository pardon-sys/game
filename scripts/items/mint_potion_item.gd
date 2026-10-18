class_name MintPotionItem
extends ItemData
## 薄荷止痒药（七日赎罪：药剂师奶奶配对药方后做的）：喝下去 seconds 秒内闷笑不涨（借冰晶守护的状态 frost_guard），先降一点闷笑。

@export var seconds := 10.0
@export_range(0.0, 1.0) var ratio := 0.15


func can_use(user: Node) -> bool:
	return user is Actor and (user as Actor).laugh != null


func use(user: Node) -> bool:
	if not can_use(user):
		return false
	var a := user as Actor
	a.laugh.reduce_ratio(ratio)
	a.add_buff("frost_guard", seconds)
	Audio.play("chime", -4.0, 0.0, 1.3)
	GameState.notify("喝了%s——凉丝丝的，%d 秒内怎么挠都不会涨闷笑！" % [display_name, int(seconds)])
	return true
