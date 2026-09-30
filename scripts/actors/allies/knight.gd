class_name Knight
extends Ally
## 示例友军：骑士。跟随公主、攻击怪物，公主笑得停不下来时拍拍她帮她平复。
## 目前用 Kenney 骑士图块占位。

var _t := 0.0


func _animate(delta: float) -> void:
	_t += delta
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
	sprite.offset.y = -8.0 - (absf(sin(_t * 10.0)) if velocity.length() > 1.0 else 0.0)


func _on_attack_performed(_target: Actor) -> void:
	Audio.play("swing", -6.0)


func _on_assist_performed(target: Actor) -> void:
	if target is PlayableCharacter and target.emotion:
		target.emotion.show_bubble("shy")
	if not GameState.has_flag("hint_knight_assist"):
		GameState.set_flag("hint_knight_assist")
		GameState.notify("骑士拍了拍公主的背，闷笑值下降了。")
