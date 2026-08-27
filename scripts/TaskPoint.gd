extends Area2D
## A task location in the world. Real completion is only ever credited by
## the host (see Net.request_complete_task). The Zombie can still "play" the
## animation locally to blend in, but it never sends a completion RPC that
## the host would honor for a zombie-role peer.

@export var task_id: String = "task_1"
@export var task_name: String = "Generator Repair"
@export var points: int = 1
@export var minigame_scene: PackedScene

@onready var icon: ColorRect = $Icon

var completed_by_local: bool = false

func _ready() -> void:
	add_to_group("task_point")

func begin_task(local_player: Node) -> void:
	if GameState.local_role == "zombie":
		_play_fake_animation()
		return
	if completed_by_local:
		return
	var ui := get_tree().get_first_node_in_group("hud")
	if ui and ui.has_method("open_task_minigame"):
		ui.open_task_minigame(self)

func on_minigame_success() -> void:
	completed_by_local = true
	icon.color = Color(0.3, 0.9, 0.3)
	Net.request_complete_task.rpc_id(1, task_id, points)

func _play_fake_animation() -> void:
	var tw := create_tween()
	tw.tween_property(icon, "modulate:a", 0.3, 0.3)
	tw.tween_property(icon, "modulate:a", 1.0, 0.3)
