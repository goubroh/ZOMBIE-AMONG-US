extends CharacterBody2D
## Original character controller. Small top-down survivor with a colored
## suit and a visor, entirely custom shapes (no external art dependency),
## easy to later swap for real sprite sheets.

const SPEED := 220.0
const ZOMBIE_SPEED_BONUS := 1.1

@export var player_id: int = 0
@export var is_local: bool = false

@onready var body: ColorRect = $Body
@onready var visor: ColorRect = $Visor
@onready var name_label: Label = $NameLabel
@onready var interact_area: Area2D = $InteractArea
@onready var camera: Camera2D = $Camera2D

var _target_pos: Vector2
var _target_facing: float = 0.0
var nearby_task: Node = null
var nearby_body_marker: Node = null

func _ready() -> void:
	_target_pos = global_position
	camera.enabled = is_local
	interact_area.body_entered.connect(_on_area_entered)
	interact_area.body_exited.connect(_on_area_exited)
	interact_area.area_entered.connect(_on_area_entered)
	interact_area.area_exited.connect(_on_area_exited)
	if GameState.players.has(player_id):
		body.color = GameState.players[player_id]["color"]
		name_label.text = GameState.players[player_id]["name"]
	# Only the local zombie sees their own visor tint differently; other
	# players never get a visual tell.
	if is_local and GameState.local_role == "zombie":
		visor.color = Color(0.7, 0.05, 0.05)

func _physics_process(delta: float) -> void:
	if is_local:
		_local_movement(delta)
	else:
		global_position = global_position.lerp(_target_pos, 12.0 * delta)
		rotation = lerp_angle(rotation, _target_facing, 10.0 * delta)

func _local_movement(delta: float) -> void:
	if GameState.phase != "PLAYING":
		velocity = Vector2.ZERO
		return
	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	var speed := SPEED
	if GameState.local_role == "zombie":
		speed *= ZOMBIE_SPEED_BONUS

	velocity = input_vec * speed
	move_and_slide()

	if input_vec.length() > 0.1:
		rotation = input_vec.angle()

	Net.send_position.rpc_id(1, global_position, velocity, rotation)

## Called by Net._relay_position for every OTHER player's updates.
func remote_update(pos: Vector2, vel: Vector2, facing: float) -> void:
	_target_pos = pos
	velocity = vel
	_target_facing = facing

func _on_area_entered(other: Node) -> void:
	if other.is_in_group("task_point"):
		nearby_task = other
	elif other.is_in_group("body_marker"):
		nearby_body_marker = other

func _on_area_exited(other: Node) -> void:
	if other == nearby_task:
		nearby_task = null
	if other == nearby_body_marker:
		nearby_body_marker = null

## Called by GameWorld when this player dies, to drop a body marker.
func spawn_body_marker() -> void:
	var marker := preload("res://scenes/BodyMarker.tscn").instantiate()
	marker.global_position = global_position
	marker.victim_name = name_label.text
	marker.victim_id = player_id
	get_parent().add_child(marker)
	visible = false
	set_physics_process(false)
