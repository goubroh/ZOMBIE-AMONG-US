extends CanvasLayer

@onready var role_banner: Label = $RoleBanner
@onready var task_bar: ProgressBar = $TaskBar
@onready var task_label: Label = $TaskBar/Label
@onready var cooldown_label: Label = $CooldownLabel
@onready var infected_banner: Label = $InfectedBanner
@onready var dead_overlay: Control = $DeadOverlay
@onready var minigame_layer: Control = $MinigameLayer
@onready var meeting_ui: Control = $MeetingUI
@onready var game_over_screen: Control = $GameOverScreen
@onready var game_over_label: Label = $GameOverScreen/Label

var _current_task: Node = null

func _ready() -> void:
	add_to_group("hud")
	GameState.role_assigned.connect(_on_role_assigned)
	GameState.task_progress_changed.connect(_on_task_progress)
	GameState.kill_cooldown_updated.connect(_on_cooldown)
	GameState.infected_notice.connect(_on_infected)
	GameState.meeting_started.connect(_on_meeting_started)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.game_over.connect(_on_game_over)

	role_banner.text = "ROLE: %s" % GameState.local_role.to_upper()
	role_banner.modulate = Color(0.9, 0.2, 0.2) if GameState.local_role == "zombie" else Color(0.3, 0.9, 0.4)
	cooldown_label.visible = GameState.local_role == "zombie"
	infected_banner.visible = false
	dead_overlay.visible = false
	meeting_ui.visible = false
	game_over_screen.visible = false
	minigame_layer.visible = false

func _on_role_assigned(role: String) -> void:
	role_banner.text = "ROLE: %s" % role.to_upper()
	role_banner.modulate = Color(0.9, 0.2, 0.2) if role == "zombie" else Color(0.3, 0.9, 0.4)
	cooldown_label.visible = role == "zombie"

func _on_task_progress(pct: float) -> void:
	task_bar.value = pct * 100.0
	task_label.text = "Team Tasks: %d%%" % int(pct * 100.0)

func _on_cooldown(seconds_left: float) -> void:
	if seconds_left <= 0.0:
		cooldown_label.text = "ATTACK READY"
		cooldown_label.modulate = Color(0.9, 0.2, 0.2)
	else:
		cooldown_label.text = "KILL READY IN: %d" % int(ceil(seconds_left))
		cooldown_label.modulate = Color(1, 1, 1)

func _on_infected() -> void:
	infected_banner.visible = true
	infected_banner.text = "You have been infected. You will turn soon..."

func show_dead_overlay() -> void:
	dead_overlay.visible = true

func _on_phase_changed(phase: String) -> void:
	if phase == "PLAYING":
		meeting_ui.visible = false

func _on_meeting_started(reason: String, reporter_name: String) -> void:
	meeting_ui.visible = true
	meeting_ui.call("open", reason, reporter_name)

func _on_game_over(winner: String) -> void:
	show_game_over(winner)

func show_game_over(winner: String) -> void:
	game_over_screen.visible = true
	if winner == "zombies":
		game_over_label.text = "ZOMBIES WIN"
		game_over_label.modulate = Color(0.9, 0.2, 0.2)
	else:
		game_over_label.text = "SURVIVORS WIN"
		game_over_label.modulate = Color(0.3, 0.9, 0.4)

func open_task_minigame(task_point: Node) -> void:
	_current_task = task_point
	minigame_layer.visible = true
	minigame_layer.call("start", task_point.task_name)

func _on_minigame_finished(success: bool) -> void:
	minigame_layer.visible = false
	if success and _current_task:
		_current_task.on_minigame_success()
	_current_task = null

func _on_leave_pressed() -> void:
	Net.leave_game()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
