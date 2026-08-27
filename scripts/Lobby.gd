extends Control

@onready var room_code_label: Label = $VBox/RoomCodeLabel
@onready var player_list: VBoxContainer = $VBox/HBox/PlayerList
@onready var count_label: Label = $VBox/HBox/PlayerList/CountLabel
@onready var settings_panel: VBoxContainer = $VBox/HBox/SettingsPanel
@onready var max_players_slider: HSlider = $VBox/HBox/SettingsPanel/MaxPlayersRow/Slider
@onready var max_players_value: Label = $VBox/HBox/SettingsPanel/MaxPlayersRow/Value
@onready var multi_zombie_check: CheckBox = $VBox/HBox/SettingsPanel/MultiZombieCheck
@onready var infection_check: CheckBox = $VBox/HBox/SettingsPanel/InfectionCheck
@onready var reveal_check: CheckBox = $VBox/HBox/SettingsPanel/RevealCheck
@onready var start_button: Button = $VBox/StartButton
@onready var status_label: Label = $VBox/StatusLabel

func _ready() -> void:
	GameState.player_list_changed.connect(_refresh)
	Net.kicked.connect(_on_kicked)
	room_code_label.text = "Room Code: %s   (share your IP with friends to join)" % (Net.room_code if Net.is_host else "-")
	settings_panel.visible = Net.is_host
	start_button.visible = Net.is_host
	if Net.is_host:
		max_players_slider.value = GameState.settings["max_players"]
		multi_zombie_check.button_pressed = GameState.settings["multiple_zombies"]
		infection_check.button_pressed = GameState.settings["infection_mode"]
		reveal_check.button_pressed = GameState.settings["reveal_role"]
	GameState.phase_changed.connect(_on_phase_changed)
	_refresh()

func _refresh() -> void:
	for c in player_list.get_children():
		if c != count_label:
			c.queue_free()
	for id in GameState.players.keys():
		var p: Dictionary = GameState.players[id]
		var l := Label.new()
		l.text = "%s%s" % [p["name"], "  (Host)" if p.get("is_host", false) else ""]
		l.modulate = p.get("color", Color.WHITE)
		player_list.add_child(l)
	count_label.text = "Players: %d / %d" % [GameState.players.size(), GameState.settings["max_players"]]
	max_players_value.text = str(int(max_players_slider.value))

func _on_phase_changed(phase: String) -> void:
	if phase == "PLAYING":
		get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")

func _on_kicked() -> void:
	status_label.text = "Disconnected from host."
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_max_players_changed(value: float) -> void:
	max_players_value.text = str(int(value))
	if Net.is_host:
		Net.request_setting_change("max_players", int(value))
	else:
		Net.request_setting_change.rpc_id(1, "max_players", int(value))

func _on_multi_zombie_toggled(pressed: bool) -> void:
	if Net.is_host:
		Net.request_setting_change("multiple_zombies", pressed)
	else:
		Net.request_setting_change.rpc_id(1, "multiple_zombies", pressed)

func _on_infection_toggled(pressed: bool) -> void:
	if Net.is_host:
		Net.request_setting_change("infection_mode", pressed)
	else:
		Net.request_setting_change.rpc_id(1, "infection_mode", pressed)

func _on_reveal_toggled(pressed: bool) -> void:
	if Net.is_host:
		Net.request_setting_change("reveal_role", pressed)
	else:
		Net.request_setting_change.rpc_id(1, "reveal_role", pressed)

func _on_start_pressed() -> void:
	if GameState.players.size() < 1:
		status_label.text = "Need at least 1 player to start."
		return
	if Net.is_host:
		Net.request_start_game()
	else:
		Net.request_start_game.rpc_id(1)

func _on_leave_pressed() -> void:
	Net.leave_game()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
