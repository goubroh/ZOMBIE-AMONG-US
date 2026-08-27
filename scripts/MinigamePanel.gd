extends Control

signal finished(success: bool)

@onready var title_label: Label = $Panel/VBox/Title
@onready var button_row: HBoxContainer = $Panel/VBox/ButtonRow
@onready var status_label: Label = $Panel/VBox/Status

var _sequence: Array[int] = []
var _progress: int = 0
var _buttons: Array[Button] = []

func start(task_name: String) -> void:
	title_label.text = task_name
	status_label.text = "Repeat the sequence!"
	_progress = 0
	_sequence.clear()
	for c in button_row.get_children():
		c.queue_free()
	_buttons.clear()

	var colors := [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]
	for i in 4:
		var b := Button.new()
		b.text = str(i + 1)
		b.custom_minimum_size = Vector2(64, 64)
		b.modulate = colors[i]
		b.pressed.connect(_on_button_pressed.bind(i))
		button_row.add_child(b)
		_buttons.append(b)

	var length := 4
	for i in length:
		_sequence.append(randi() % 4)

	_flash_sequence()

func _flash_sequence() -> void:
	status_label.text = "Watch closely..."
	for i in _buttons.size():
		_buttons[i].disabled = true
	var t := 0.0
	for step in _sequence:
		get_tree().create_timer(t).timeout.connect(func(): _highlight(step))
		t += 0.5
	get_tree().create_timer(t).timeout.connect(func():
		status_label.text = "Now repeat it!"
		for b in _buttons:
			b.disabled = false
	)

func _highlight(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		return
	var b := _buttons[index]
	var original := b.modulate
	b.modulate = Color.WHITE
	get_tree().create_timer(0.25).timeout.connect(func(): b.modulate = original)

func _on_button_pressed(index: int) -> void:
	if index == _sequence[_progress]:
		_progress += 1
		if _progress >= _sequence.size():
			status_label.text = "Success!"
			finished.emit(true)
	else:
		status_label.text = "Wrong! Try again."
		finished.emit(false)

func _on_cancel_pressed() -> void:
	finished.emit(false)
