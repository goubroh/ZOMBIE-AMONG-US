extends Control

@onready var name_input: LineEdit = $Center/VBox/NameInput
@onready var ip_input: LineEdit = $Center/VBox/JoinRow/IPInput
@onready var status_label: Label = $Center/VBox/StatusLabel
@onready var how_to_play: Control = $HowToPlay

func _ready() -> void:
	Net.connected_to_host.connect(_on_connected)
	Net.connection_failed.connect(_on_connect_failed)
	how_to_play.visible = false
	name_input.text = "Player%d" % (randi() % 999)

func _player_name() -> String:
	var n := name_input.text.strip_edges()
	if n == "":
		n = "Player%d" % (randi() % 999)
	return n

func _on_host_pressed() -> void:
	if Net.host_game(_player_name()):
		get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
	else:
		status_label.text = "Could not host (port may be in use)."

func _on_join_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip == "":
		status_label.text = "Enter the host's IP address."
		return
	status_label.text = "Connecting..."
	Net.join_game(ip, _player_name())

func _on_connected() -> void:
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_connect_failed() -> void:
	status_label.text = "Could not connect. Check the IP and try again."

func _on_how_to_play_pressed() -> void:
	how_to_play.visible = true

func _on_close_how_to_play_pressed() -> void:
	how_to_play.visible = false

func _on_exit_pressed() -> void:
	get_tree().quit()
