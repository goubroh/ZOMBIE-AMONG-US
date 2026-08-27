extends Node
## Net (autoload)
## Wraps Godot's high-level ENet multiplayer API. The HOST (peer id 1) is the
## authority for every rule in the game: roles, kills, tasks, votes, sabotage,
## win conditions. Clients only ever send *requests*; the host validates and
## broadcasts the resulting state. Never trust the client.

const PORT := 47321
const MAX_CLIENTS := 10

signal connected_to_host
signal connection_failed
signal player_spawned(id: int)
signal kicked

var is_host: bool = false
var local_name: String = "Player"
var room_code: String = ""

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ---------------------------------------------------------------------------
# Hosting / joining
# ---------------------------------------------------------------------------

func host_game(player_name: String) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	local_name = player_name
	room_code = _make_room_code()
	GameState.reset_for_new_game()
	GameState.add_player(1, local_name)
	return true

func join_game(ip_address: String, player_name: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip_address, PORT)
	if err != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	is_host = false
	local_name = player_name

func leave_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	GameState.players.clear()
	is_host = false

func _make_room_code() -> String:
	var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in 6:
		code += chars[randi() % chars.length()]
	return code

# ---------------------------------------------------------------------------
# Connection lifecycle
# ---------------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if is_host:
		# Ask the new client for their chosen name; they'll call register_player.
		pass

func _on_peer_disconnected(id: int) -> void:
	if is_host:
		GameState.remove_player(id)
		_broadcast_player_list()
		_check_win_conditions()

func _on_connected_ok() -> void:
	connected_to_host.emit()
	register_player.rpc_id(1, local_name)

func _on_connected_fail() -> void:
	connection_failed.emit()

func _on_server_disconnected() -> void:
	kicked.emit()
	leave_game()

# ---------------------------------------------------------------------------
# Lobby: registration, settings, starting the game
# ---------------------------------------------------------------------------

@rpc("any_peer", "reliable")
func register_player(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if GameState.players.size() >= GameState.settings["max_players"]:
		disconnect_peer.rpc_id(id, "Room is full.")
		return
	if GameState.phase != "LOBBY":
		disconnect_peer.rpc_id(id, "Game already in progress.")
		return
	GameState.add_player(id, player_name)
	_broadcast_player_list()
	_sync_settings_to.rpc_id(id, GameState.settings)

@rpc("authority", "reliable")
func disconnect_peer(_reason: String) -> void:
	leave_game()

func _broadcast_player_list() -> void:
	var payload := {}
	for id in GameState.players.keys():
		var p: Dictionary = GameState.players[id]
		payload[id] = {"name": p["name"], "color": p["color"], "is_host": p["is_host"], "alive": p["alive"]}
	_receive_player_list.rpc(payload)

@rpc("authority", "reliable", "call_local")
func _receive_player_list(payload: Dictionary) -> void:
	for id in payload.keys():
		if not GameState.players.has(id):
			GameState.players[id] = {"role": "survivor", "infected": false, "infection_timer": 0.0}
		GameState.players[id]["name"] = payload[id]["name"]
		GameState.players[id]["color"] = payload[id]["color"]
		GameState.players[id]["is_host"] = payload[id]["is_host"]
		GameState.players[id]["alive"] = payload[id]["alive"]
	for id in GameState.players.keys():
		if not payload.has(id):
			GameState.players.erase(id)
	GameState.player_list_changed.emit()

@rpc("any_peer", "reliable")
func request_setting_change(key: String, value) -> void:
	if not multiplayer.is_server():
		return
	if not GameState.settings.has(key):
		return
	GameState.settings[key] = value
	_sync_settings_to.rpc(GameState.settings)

@rpc("authority", "reliable", "call_local")
func _sync_settings_to(new_settings: Dictionary) -> void:
	GameState.settings = new_settings

@rpc("any_peer", "reliable")
func request_start_game() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != 0:
		return # only host may start
	if GameState.players.size() < 1:
		return
	if GameState.players.size() == 1:
		_add_solo_bots()
	_assign_roles()
	_assign_tasks()
	_start_game.rpc()

func _assign_roles() -> void:
	var ids: Array = GameState.players.keys()
	ids.shuffle()
	var zombie_count := 1
	if ids.size() == 1:
		zombie_count = 0
	elif GameState.settings["multiple_zombies"] and ids.size() >= 8:
		zombie_count = 2
	for i in ids.size():
		GameState.players[ids[i]]["role"] = "survivor"
	for i in zombie_count:
		GameState.players[ids[i]]["role"] = "zombie"
	if GameState.players.has(1) and GameState.players.has(-1):
		GameState.players[1]["role"] = "survivor"
		GameState.players[-1]["role"] = "zombie"
	# Privately tell each player their own role (never broadcast the zombie's identity).
	for id in ids:
		if id > 0:
			if id == multiplayer.get_unique_id():
				GameState.local_role = GameState.players[id]["role"]
				GameState.role_assigned.emit(GameState.local_role)
			else:
				_assign_role_to.rpc_id(id, GameState.players[id]["role"])

func _add_solo_bots() -> void:
	for i in 4:
		var bot_id := -(i + 1)
		GameState.add_player(bot_id, "Bot %d" % (i + 1))

@rpc("authority", "reliable")
func _assign_role_to(role: String) -> void:
	GameState.local_role = role
	GameState.role_assigned.emit(role)

func _assign_tasks() -> void:
	GameState.required_task_points = GameState.settings["tasks_per_player"] * GameState.survivor_count()
	GameState.completed_task_points = 0

@rpc("authority", "reliable", "call_local")
func _start_game() -> void:
	GameState.set_phase("PLAYING")
	player_spawned.emit(multiplayer.get_unique_id())

# ---------------------------------------------------------------------------
# Movement sync (lightweight, unreliable, host relays to everyone)
# ---------------------------------------------------------------------------

@rpc("any_peer", "unreliable_ordered")
func send_position(pos: Vector2, vel: Vector2, facing: float) -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server():
		_relay_position.rpc(id, pos, vel, facing)

@rpc("authority", "unreliable_ordered", "call_local")
func _relay_position(id: int, pos: Vector2, vel: Vector2, facing: float) -> void:
	var world := get_tree().get_first_node_in_group("game_world")
	if world:
		world.remote_move(id, pos, vel, facing)

# ---------------------------------------------------------------------------
# Tasks
# ---------------------------------------------------------------------------

@rpc("any_peer", "reliable")
func request_complete_task(task_id: String, points: int) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not GameState.players.has(id):
		return
	if GameState.players[id]["role"] != "survivor" or not GameState.players[id]["alive"]:
		return # zombies can only FAKE tasks locally; the server never credits them
	GameState.completed_task_points += points
	var pct: float = 0.0
	if GameState.required_task_points > 0:
		pct = float(GameState.completed_task_points) / float(GameState.required_task_points)
	_update_task_progress.rpc(min(pct, 1.0))
	if pct >= 1.0 and GameState.settings["win_on_tasks"]:
		_end_game.rpc("survivors", "All tasks completed.")

@rpc("authority", "reliable", "call_local")
func _update_task_progress(pct: float) -> void:
	GameState.task_progress = pct
	GameState.task_progress_changed.emit(pct)

# ---------------------------------------------------------------------------
# Zombie attack / infection / kill
# ---------------------------------------------------------------------------

var _kill_ready := {} # id -> bool

@rpc("any_peer", "reliable")
func request_attack(target_id: int) -> void:
	if not multiplayer.is_server():
		return
	var attacker_id := multiplayer.get_remote_sender_id()
	_resolve_attack(attacker_id, target_id)

func bot_attack(attacker_id: int, target_id: int) -> void:
	if not multiplayer.is_server():
		return
	_resolve_attack(attacker_id, target_id)

func _resolve_attack(attacker_id: int, target_id: int) -> void:
	if not GameState.players.has(attacker_id) or not GameState.players.has(target_id):
		return
	if GameState.players[attacker_id]["role"] != "zombie":
		return
	if not GameState.players[attacker_id]["alive"] or not GameState.players[target_id]["alive"]:
		return
	if _kill_ready.get(attacker_id, true) == false:
		return # still on cooldown, server enforces this regardless of client claim

	if GameState.settings["infection_mode"] and GameState.players[target_id]["role"] == "survivor":
		GameState.players[target_id]["infected"] = true
		GameState.players[target_id]["infection_timer"] = GameState.settings["infection_time"]
		if target_id > 0:
			_notify_infected.rpc_id(target_id)
	else:
		GameState.players[target_id]["alive"] = false
		_player_died.rpc(target_id, false)

	_kill_ready[attacker_id] = false
	_kill_cooldown_tick(attacker_id, GameState.settings["kill_cooldown"])
	_broadcast_player_list()
	_check_win_conditions()

func _kill_cooldown_tick(attacker_id: int, seconds_left: float) -> void:
	if seconds_left <= 0.0:
		_kill_ready[attacker_id] = true
		_cooldown_update.rpc_id(attacker_id, 0.0)
		return
	_cooldown_update.rpc_id(attacker_id, seconds_left)
	get_tree().create_timer(1.0).timeout.connect(func(): _kill_cooldown_tick(attacker_id, seconds_left - 1.0))

@rpc("authority", "reliable")
func _cooldown_update(seconds_left: float) -> void:
	GameState.kill_cooldown_updated.emit(seconds_left)

@rpc("authority", "reliable")
func _notify_infected() -> void:
	GameState.local_infected = true
	GameState.infected_notice.emit()

@rpc("authority", "reliable", "call_local")
func _player_died(id: int, was_infection_expiry: bool) -> void:
	if GameState.players.has(id):
		GameState.players[id]["alive"] = false
	GameState.player_list_changed.emit()

# Host-side per-second tick for infection timers (called from GameWorld._process on host only)
func server_tick_infections(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for id in GameState.players.keys():
		var p: Dictionary = GameState.players[id]
		if p["alive"] and p["infected"] and p["role"] == "survivor":
			p["infection_timer"] -= delta
			if p["infection_timer"] <= 0.0:
				p["role"] = "zombie"
				p["infected"] = false
				if id == multiplayer.get_unique_id():
					GameState.local_role = "zombie"
					GameState.role_assigned.emit("zombie")
				else:
					_assign_role_to.rpc_id(id, "zombie")
				_broadcast_player_list()
				_check_win_conditions()

# ---------------------------------------------------------------------------
# Body report / emergency meeting / voting
# ---------------------------------------------------------------------------

@rpc("any_peer", "reliable")
func request_report_body(dead_id: int) -> void:
	if not multiplayer.is_server():
		return
	var reporter_id := multiplayer.get_remote_sender_id()
	if not GameState.players.has(reporter_id) or not GameState.players[reporter_id]["alive"]:
		return
	_open_meeting("body", GameState.players[reporter_id]["name"])

@rpc("any_peer", "reliable")
func request_emergency_meeting() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not GameState.players.has(id) or not GameState.players[id]["alive"]:
		return
	var used: int = GameState.meetings_used.get(id, 0)
	if used >= 1:
		return # 1 emergency meeting per player per round
	GameState.meetings_used[id] = used + 1
	_open_meeting("emergency", GameState.players[id]["name"])

func _open_meeting(reason: String, reporter_name: String) -> void:
	GameState.set_phase("MEETING")
	_votes.clear()
	_meeting_open.rpc(reason, reporter_name, GameState.settings["discussion_time"], GameState.settings["voting_time"])

@rpc("authority", "reliable", "call_local")
func _meeting_open(reason: String, reporter_name: String, _discussion_time: float, _voting_time: float) -> void:
	GameState.set_phase("MEETING")
	GameState.meeting_started.emit(reason, reporter_name)

var _votes: Dictionary = {} # voter_id -> target_id (-1 == skip)

@rpc("any_peer", "reliable")
func cast_vote(target_id: int) -> void:
	if not multiplayer.is_server():
		return
	var voter := multiplayer.get_remote_sender_id()
	if not GameState.players.has(voter) or not GameState.players[voter]["alive"]:
		return
	_votes[voter] = target_id

@rpc("any_peer", "reliable")
func request_tally_votes() -> void:
	if not multiplayer.is_server():
		return
	var tally := {} # target_id -> count, -1 = skip
	for voter in GameState.alive_players():
		var target: int = _votes.get(voter, -1)
		tally[target] = tally.get(target, 0) + 1

	# Find the highest-voted candidate (excluding "skip").
	var eliminated_id := -1
	var top_count := -1
	var tie := false
	for target in tally.keys():
		if target == -1:
			continue
		if tally[target] > top_count:
			top_count = tally[target]
			eliminated_id = target
			tie = false
		elif tally[target] == top_count:
			tie = true

	var skip_count: int = tally.get(-1, 0)
	if tie or eliminated_id == -1 or skip_count >= top_count:
		eliminated_id = -1

	var revealed_role := ""
	if eliminated_id != -1:
		GameState.players[eliminated_id]["alive"] = false
		revealed_role = GameState.players[eliminated_id]["role"]

	_vote_results.rpc(tally, eliminated_id, revealed_role)
	_broadcast_player_list()

	await get_tree().create_timer(4.0).timeout
	if not _check_win_conditions():
		GameState.meetings_used.clear()
		_resume_game.rpc()

@rpc("authority", "reliable", "call_local")
func _vote_results(tally: Dictionary, eliminated_id: int, revealed_role: String) -> void:
	GameState.vote_results.emit(tally, eliminated_id)
	if eliminated_id != -1 and GameState.players.has(eliminated_id):
		var reveal_text := "%s was eliminated." % GameState.players[eliminated_id]["name"]
		if GameState.settings["reveal_role"] and revealed_role != "":
			reveal_text = "%s was the %s." % [GameState.players[eliminated_id]["name"], revealed_role.to_upper()]
		print(reveal_text)

@rpc("authority", "reliable", "call_local")
func _resume_game() -> void:
	GameState.set_phase("PLAYING")

# ---------------------------------------------------------------------------
# Win conditions (host-only check, called after every state change)
# ---------------------------------------------------------------------------

func _check_win_conditions() -> bool:
	if not multiplayer.is_server():
		return false
	var zc := GameState.zombie_count()
	var sc := GameState.survivor_count()
	if zc == 0:
		return false # shouldn't happen once game started, but guard anyway
	if zc >= sc:
		_end_game.rpc("zombies", "Zombies equal or outnumber survivors.")
		return true
	if sc == 0:
		_end_game.rpc("zombies", "All survivors eliminated.")
		return true
	return false

@rpc("authority", "reliable", "call_local")
func _end_game(winner: String, _reason: String) -> void:
	GameState.set_phase("ENDED")
	GameState.game_over.emit(winner)
