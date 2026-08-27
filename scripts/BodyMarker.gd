extends Area2D

var victim_name: String = ""
@export var victim_id: int = -1

func _ready() -> void:
	add_to_group("body_marker")
	$Label.text = victim_name
