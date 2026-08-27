extends Control

@onready var reason_label: Label = $Panel/VBox/ReasonLabel
@onready var timer_label: Label = $Panel/VBox/TimerLabel
@onready var chat_log: RichTextLabel = $Panel/VBox/ChatLog
@onready var chat_input: LineEdit = $Panel/VBox/ChatInput
@onready var vote_list: VBoxContainer = $Panel/VBox/VoteList
@onready var results_label: Label = $Panel/VBox/ResultsLabel

var _discussion_time: float = 45.0
var _voting_time: float = 30.0
var _phase: String = "discussion" # discussion -> voting -> results
var _time_left: float = 0.0

func _ready() -> void:
	GameState.vote_results.connect(_on_vote_results)
	set_process(false)

func open(reason: String, reporter_name: String) -> void:
	results_label.text = ""
	if reason == "body":
		reason_label.text = "%s reported a body!" % reporter_name
	else:
		reason_label.text = "%s called an emergency meeting." % reporter_name
	_discussion_time = GameState.settings.get("discussion_time", 45.0)
	_voting_time = GameState.settings.get("voting_time", 30.0)
	_phase = "discussion"
	_time_left = _discussion_time
	chat_log.clear()
	vote_list.visible = false
	set_process(true)

func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		if _phase == "discussion":
			_phase = "voting"
			_time_left = _voting_time
			_build_vote_list()
		elif _phase == "voting":
			_phase = "results"
			set_process(false)
			if Net.is_host:
				Net.request_tally_votes.rpc_id(1)
	timer_label.text = "%s: %ds" % [_phase.to_upper(), max(0, ceil(_time_left))]

func _build_vote_list() -> void:
	vote_list.visible = true
	for c in vote_list.get_children():
		c.queue_free()
	for id in GameState.alive_players():
		var b := Button.new()
		b.text = "Vote %s" % GameState.players[id]["name"]
		b.pressed.connect(func(): _cast_vote(id))
		vote_list.add_child(b)
	var skip_btn := Button.new()
	skip_btn.text = "Skip Vote"
	skip_btn.pressed.connect(func(): _cast_vote(-1))
	vote_list.add_child(skip_btn)

func _cast_vote(target_id: int) -> void:
	Net.cast_vote.rpc_id(1, target_id)
	for c in vote_list.get_children():
		c.disabled = true

func _on_vote_results(tally: Dictionary, eliminated_id: int) -> void:
	var text := "Votes:\n"
	for target in tally.keys():
		var label := "Skip" if target == -1 else GameState.players.get(target, {}).get("name", "?")
		text += "%s: %d\n" % [label, tally[target]]
	if eliminated_id == -1:
		text += "\nNO ONE WAS ELIMINATED."
	else:
		var reveal := "%s was eliminated." % GameState.players.get(eliminated_id, {}).get("name", "?")
		text += "\n" + reveal
	results_label.text = text

func _on_send_pressed() -> void:
	var msg := chat_input.text.strip_edges()
	if msg == "":
		return
	chat_input.text = ""
	_broadcast_chat.rpc(str(multiplayer.get_unique_id()), msg)

@rpc("any_peer", "call_local", "reliable")
func _broadcast_chat(sender_id: String, msg: String) -> void:
	var sender_name := "Player"
	var id := int(sender_id)
	if GameState.players.has(id):
		sender_name = GameState.players[id]["name"]
	chat_log.append_text("[b]%s:[/b] %s\n" % [sender_name, msg])
