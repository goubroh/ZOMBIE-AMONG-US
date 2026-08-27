extends Node
## GameState (autoload)
## Holds all server-authoritative game data: player registry, roles, settings,
## and the current game phase. Clients only ever see a filtered view of this
## (they never learn who the Zombie is unless they ARE the Zombie, or the
## round has ended and "reveal role" is on).

signal phase_changed(new_phase: String)
signal player_list_changed
signal role_assigned(role: String) # fired locally on the client who owns the role
signal task_progress_changed(percent: float)
signal meeting_started(reason: String, reporter_name: String)
signal vote_results(results: Dictionary, eliminated_id: int)
signal game_over(winner: String)
signal kill_cooldown_updated(seconds_left: float)
signal infected_notice

enum Phase { LOBBY, INTRO, PLAYING, MEETING, ENDED }

var phase: String = "LOBBY"

# --- Lobby / settings (host-configurable, replicated to all peers) ---
var settings := {
	"max_players": 7,
	"multiple_zombies": false, # allow 2 zombies at 8-10 players
	"infection_mode": true,    # true = infect then convert, false = instant kill
	"kill_cooldown": 20.0,
	"infection_time": 60.0,
	"tasks_per_player": 4,
	"discussion_time": 45.0,
	"voting_time": 30.0,
	"meeting_cooldown": 60.0,
	"reveal_role": true,
	"win_on_tasks": true,
	"win_on_vote": true,
	"map": "research_facility",
}

# player_id (int, = multiplayer unique id) -> data dict
# { name, color, role ("survivor"/"zombie"), alive, infected, infection_timer, is_host }
var players: Dictionary = {}

var local_role: String = "survivor" # only meaningful for the local peer once assigned
var local_infected: bool = false

var task_progress: float = 0.0 # 0..1, team-wide, only counts real survivor tasks
var required_task_points: int = 0
var completed_task_points: int = 0

var meetings_used: Dictionary = {} # player_id -> int count, for "1 per player per round" limit

func reset_for_new_game() -> void:
	phase = "LOBBY"
	task_progress = 0.0
	completed_task_points = 0
	meetings_used.clear()
	for id in players.keys():
		players[id]["role"] = "survivor"
		players[id]["alive"] = true
		players[id]["infected"] = false
		players[id]["infection_timer"] = 0.0

func set_phase(p: String) -> void:
	phase = p
	phase_changed.emit(p)

func add_player(id: int, player_name: String) -> void:
	if players.has(id):
		return
	players[id] = {
		"name": player_name,
		"color": Color.from_hsv(randf(), 0.65, 0.9),
		"role": "survivor",
		"alive": true,
		"infected": false,
		"infection_timer": 0.0,
		"is_host": id == 1, # peer id 1 is always the host with Godot's high-level API
	}
	player_list_changed.emit()

func remove_player(id: int) -> void:
	if players.has(id):
		players.erase(id)
		player_list_changed.emit()

func alive_players() -> Array:
	var out := []
	for id in players.keys():
		if players[id]["alive"]:
			out.append(id)
	return out

func zombie_count() -> int:
	var c := 0
	for id in players.keys():
		if players[id]["role"] == "zombie" and players[id]["alive"]:
			c += 1
	return c

func survivor_count() -> int:
	var c := 0
	for id in players.keys():
		if players[id]["role"] == "survivor" and players[id]["alive"]:
			c += 1
	return c
