extends Control

signal start_requested
signal back_requested
signal retry_requested

var heading: Label
var details: Label
var results: Label
var boards: GridContainer
var start_button: Button
var retry_button: Button

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("#1f1e1c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	heading = Label.new()
	heading.name = "Heading"
	heading.theme_type_variation = "ExtraBoldText"
	heading.add_theme_font_size_override("font_size", 30)
	column.add_child(heading)
	details = Label.new()
	details.name = "Details"
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(details)
	boards = GridContainer.new()
	boards.name = "Boards"
	boards.columns = 3
	column.add_child(boards)
	results = Label.new()
	results.name = "Results"
	results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(results)
	start_button = _button(column, "Start", "Start test")
	retry_button = _button(column, "Retry", "Retry with new positions")
	var back := _button(column, "Back", "Back to the unit")
	start_button.pressed.connect(func(): start_requested.emit())
	retry_button.pressed.connect(func(): retry_requested.emit())
	back.pressed.connect(func(): back_requested.emit())

func _button(parent: Node, node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = 44
	parent.add_child(button)
	return button

func present_start(course, unit: Dictionary) -> void:
	heading.text = "Pass test · " + str(unit.get("title", ""))
	details.text = "1. Solve 6 positions, one attempt each.\n2. Convert and hold against the perfect opponent, with no clock.\nPass with 5 positions right and both play-outs passed."
	var attempts: Array = course.test_attempts(unit)
	if not attempts.is_empty():
		var last: Dictionary = attempts.back()
		details.text += "\n\nLast attempt: %d of 6 · %s" % [last.get("score", 0), last.get("date", "")]
	_clear_boards()
	results.text = ""
	start_button.show()
	retry_button.hide()
	show()

func present_result(attempt: Dictionary) -> void:
	heading.text = "Unit mastered" if attempt.passed else "Not passed yet"
	details.text = "%d of 6 positions right" % attempt.score
	if attempt.passed:
		details.text += " · Review checks come 7 and 30 days after mastery."
	_clear_boards()
	var lines := PackedStringArray()
	for i in attempt.positions.size():
		var result: Dictionary = attempt.positions[i]
		var position: Dictionary = result.position
		var card := VBoxContainer.new()
		boards.add_child(card)
		var board = preload("res://ui/board_view.tscn").instantiate()
		board.custom_minimum_size = Vector2(120, 120)
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(board)
		board.game = preload("res://core/game.gd").new(position.fen)
		board.flipped = position.get("side", "w") == "b"
		var label := Label.new()
		label.text = "%d  %s" % [i + 1, "✓" if result.solved else "✗"]
		card.add_child(label)
		if not result.solved:
			lines.append("Position %d: your move %s · best %s" % [i + 1, result.get("your_move", ""), result.get("best_move", "")])
	lines.append("Convert: %s" % ("Passed" if attempt.playouts[0] else "Failed"))
	lines.append("Hold: %s" % ("Passed" if attempt.playouts[1] else "Failed"))
	results.text = "\n".join(lines)
	start_button.hide()
	retry_button.visible = not attempt.passed
	show()

func _clear_boards() -> void:
	for child in boards.get_children():
		boards.remove_child(child)
		child.queue_free()
