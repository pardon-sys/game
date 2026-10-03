class_name WanderSpot
extends Marker2D
## AI 溜达的目的地（WanderController 在同一关卡的这些点之间走）。图例：X = spot

func _ready() -> void:
	add_to_group("wander_spot")
