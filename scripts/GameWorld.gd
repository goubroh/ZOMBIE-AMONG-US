extends Node2D

const PLAYER_SCENE := preload("res://scenes/Player.tscn")

@onready var players_root: Node2D = $Players
@onready var tasks_root: Node2D = $Tasks
@onready var hud: CanvasLayer = $HUD

var spawn_points: Array[Vector2] = [
	Vector2(120, 120), Vector2(220, 120), Vector2(320, 120), Vector2(420, 120),
	Vector2(120, 220), Vector2(220, 220), Vector2(320, 220), Vector2(420, 220),
	Vector2(120, 320), Vector2(220, 320),
]

var _player_nodes: Dictionary = {} # id -> Player node

func _ready() -> void:
	add_to_group("game_world")
	GameState.player_list_changed.connect(_sync_players)
	GameState.game_over.connect(_on_game_over)
	_sync_players()

func _process(delta: float) -> void:
	if Net.is_host:
		Net.server_tick_infections(delta)
		_process_solo_bots(delta)

func _process_solo_bots(delta: float) -> void:
	if GameState.phase != "PLAYING" or not GameState.players.has(-1):
		return
	var local := get_local_player()
	if not local or not GameState.players.get(multiplayer.get_unique_id(), {}).get("alive", false):
		return
	for id in GameState.players.keys():
		if id >= 0 or not GameState.players[id]["alive"]:
			continue
		var bot: Node = _player_nodes.get(id)
		if not bot:
			continue
		var direction := local.global_position - bot.global_position
		if GameState.players[id]["role"] == "zombie":
			if direction.length() > 48.0:
				bot.global_position += direction.normalized() * 110.0 * delta
			elif direction.length() < 60.0:
				Net.bot_attack(id, multiplayer.get_unique_id())
		else:
			bot.global_position += Vector2(sin(Time.get_ticks_msec() * 0.001 + abs(id)), cos(Time.get_ticks_msec() * 0.001 + abs(id))) * 18.0 * delta

func _sync_players() -> void:
	var i := 0
	for id in GameState.players.keys():
		if not _player_nodes.has(id):
			var p := PLAYER_SCENE.instantiate()
			p.player_id = id
			p.is_local = (id == multiplayer.get_unique_id())
			p.global_position = spawn_points[i % spawn_points.size()]
			players_root.add_child(p)
			_player_nodes[id] = p
		i += 1
		if not GameState.players[id]["alive"] and _player_nodes[id].visible:
			_player_nodes[id].spawn_body_marker()
			if _player_nodes[id].is_local:
				hud.show_dead_overlay()

## Called by Net._relay_position for remote peers.
func remote_move(id: int, pos: Vector2, vel: Vector2, facing: float) -> void:
	if _player_nodes.has(id):
		_player_nodes[id].remote_update(pos, vel, facing)

func get_local_player() -> Node:
	return _player_nodes.get(multiplayer.get_unique_id())

func _unhandled_input(event: InputEvent) -> void:
	if GameState.phase != "PLAYING":
		return
	var local: Node = get_local_player()
	if not local or not GameState.players.get(multiplayer.get_unique_id(), {}).get("alive", false):
		return

	if event.is_action_pressed("interact"):
		if local.nearby_task:
			local.nearby_task.begin_task(local)
		elif local.nearby_body_marker:
			Net.request_report_body.rpc_id(1, local.nearby_body_marker.victim_id)

	elif event.is_action_pressed("report"):
		if local.nearby_body_marker:
			Net.request_report_body.rpc_id(1, local.nearby_body_marker.victim_id)

	elif event.is_action_pressed("ability"):
		if GameState.local_role == "zombie":
			var target := _find_nearby_victim(local)
			if target != -1:
				Net.request_attack.rpc_id(1, target)

	elif event.is_action_pressed("emergency"):
		Net.request_emergency_meeting.rpc_id(1)

func _find_nearby_victim(local: Node) -> int:
	var best_id := -1
	var best_dist := 60.0
	for id in _player_nodes.keys():
		if id == multiplayer.get_unique_id():
			continue
		var node = _player_nodes[id]
		if not node.visible:
			continue
		var d: float = local.global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best_id = id
	return best_id

func _on_game_over(winner: String) -> void:
	hud.show_game_over(winner)
