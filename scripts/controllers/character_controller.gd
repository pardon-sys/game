class_name CharacterController
extends Node
## 可操作角色的输入来源（Controllable 接口）。挂在 PlayableCharacter 下，节点名 "Controller"。
## 继承并重写这几个方法即可接入键盘、脚本（测试/过场）、AI、回放或第二玩家。
## 动作名：attack / dash / interact / use_item


func get_move_vector() -> Vector2:
	return Vector2.ZERO


func is_action_just_pressed(_action: StringName) -> bool:
	return false


## 角色每帧处理完输入后调用（用于清理一次性输入）。
func end_frame() -> void:
	pass
