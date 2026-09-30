extends Node2D
## 可阅读物体（石碑、信件）：按 E 播放对话。

@export var dialogue := ""


func on_interact(_player: Node) -> void:
	Audio.play("book", -4.0)
	Dialogue.start(dialogue)
