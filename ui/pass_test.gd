extends Control

signal start_requested
signal back_requested
signal retry_requested

var heading: Label
var details: Label
var results: Label
var boards: GridContainer
var start_steps: VBoxContainer
var column: VBoxContainer
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
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	column = VBoxContainer.new()
	column.custom_minimum_size.x = 900
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	heading = Label.new()
	heading.name = "Heading"
	heading.theme_type_variation = "ExtraBoldText"
	heading.add_theme_font_size_override("font_size", 30)
	column.add_child(heading)
	details = Label.new()
	details.name = "Details"
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(details)
	start_steps = VBoxContainer.new()
	start_steps.add_theme_constant_override("separation", 16)
	column.add_child(start_steps)
	_step_card("1    6 positions", "Solve at least 5 on the first commit. Each position allows one attempt.")
	_step_card("2    2 play-outs against a perfect opponent", "Convert and hold the position. Both play-outs must pass; there is no clock.")
	boards = GridContainer.new()
	boards.name = "Boards"
	boards.columns = 6
	boards.add_theme_constant_override("h_separation", 12)
	boards.add_theme_constant_override("v_separation", 12)
	column.add_child(boards)
	results = Label.new()
	results.name = "Results"
	results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(results)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	var back := _button(actions, "Back", "Back to the unit")
	start_button = _button(actions, "Start", "Start test")
	retry_button = _button(actions, "Retry", "Retry with new positions")
	start_button.theme_type_variation = "PrimaryButton"
	retry_button.theme_type_variation = "PrimaryButton"
	start_button.pressed.connect(func(): start_requested.emit())
	retry_button.pressed.connect(func(): retry_requested.emit())
	back.pressed.connect(func(): back_requested.emit())
	resized.connect(_fit_content)
	_fit_content()

func _fit_content() -> void:
	column.custom_minimum_size.x = minf(900, maxf(320, size.x - 80))
	boards.columns = 3 if size.x < 860 else 6

func _step_card(title: String, description: String) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "CardPanel"
	start_steps.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var label := Label.new()
	label.theme_type_variation = "ExtraBoldText"
	label.add_theme_font_size_override("font_size", 20)
	label.text = title
	content.add_child(label)
	var note := Label.new()
	note.text = description
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)

func _button(parent: Node, node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = 44
	button.custom_minimum_size.x = 180
	parent.add_child(button)
	return button

func present_start(course, unit: Dictionary) -> void:
	heading.text = "Pass test · " + str(unit.get("title", ""))
	details.text = "Pass both parts to master the unit."
	var attempts: Array = course.test_attempts(unit)
	if not attempts.is_empty():
		var last: Dictionary = attempts.back()
		details.text += "\n\nLast attempt: %d of 6 · %s" % [last.get("score", 0), last.get("date", "")]
	_clear_boards()
	start_steps.show()
	results.text = ""
	start_button.show()
	retry_button.hide()
	show()

func present_result(attempt: Dictionary) -> void:
	start_steps.hide()
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
		label.add_theme_color_override("font_color", Color("#98bc49") if result.solved else Color("#ee7a72"))
		card.add_child(label)
		if not result.solved:
			lines.append("Position %d: your move %s · best %s" % [i + 1, result.get("your_move", ""), result.get("best_move", "")])
	lines.append("Convert: %s" % ("Passed" if attempt.playouts[0] else "Failed"))
	lines.append("Hold: %s" % ("Passed" if attempt.playouts[1] else "Failed"))
	results.text = "\n".join(lines)
	start_button.hide()
	retry_button.text = "Retry with new positions"
	retry_button.visible = not attempt.passed
	show()

func present_error(message: String) -> void:
	start_steps.hide()
	heading.text = "Could not continue the test"
	details.text = message
	results.text = ""
	_clear_boards()
	start_button.hide()
	retry_button.text = "Retry play-out"
	retry_button.show()
	show()

func _clear_boards() -> void:
	for child in boards.get_children():
		boards.remove_child(child)
		child.queue_free()
