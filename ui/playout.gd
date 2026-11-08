extends Control

signal start_requested
signal back_requested
signal next_requested
signal retry_requested

const BoardView = preload("res://ui/board_view.tscn")
const Game = preload("res://core/game.gd")
var board
var heading: Label
var reason: Label
var details: Label
var states: Label
var start_button: Button
var next_button: Button
var retry_button: Button
var back_button: Button

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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	margin.add_child(row)
	board = BoardView.instantiate()
	board.name = "Board"
	board.custom_minimum_size = Vector2(320, 320)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(board)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "CardPanel"
	panel.custom_minimum_size.x = 340
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	heading = Label.new()
	heading.name = "Heading"
	heading.theme_type_variation = "ExtraBoldText"
	heading.add_theme_font_size_override("font_size", 28)
	content.add_child(heading)
	states = Label.new()
	states.name = "States"
	states.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(states)
	details = Label.new()
	details.name = "Details"
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(details)
	reason = Label.new()
	reason.name = "Reason"
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(reason)
	start_button = _button(content, "Start", "Start")
	next_button = _button(content, "Next", "Next play-out")
	retry_button = _button(content, "Retry", "Retry")
	back_button = _button(content, "Back", "Back to the unit")
	start_button.pressed.connect(func(): start_requested.emit())
	next_button.pressed.connect(func(): next_requested.emit())
	retry_button.pressed.connect(func(): retry_requested.emit())
	back_button.pressed.connect(func(): back_requested.emit())

func _button(parent: Node, node_name: String, label: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size.y = 44
	parent.add_child(button)
	return button

func present_start(course, unit: Dictionary, index: int) -> void:
	var position: Dictionary = unit.playouts[index]
	board.game = Game.new(position.fen)
	board.flipped = position.side == "b"
	board.review_square = ""
	board.review_icon = null
	board.best_move_arrow = ""
	heading.text = "Play-out %d of 4" % (index + 1)
	var labels := []
	for i in unit.playouts.size():
		labels.append("%d %s" % [i + 1, "Passed" if course.playout_passed(unit, unit.playouts[i]) else ("Current" if i == index else "To do")])
	states.text = "   ·   ".join(labels)
	var task := "win" if position.goal == "convert" else "draw"
	details.text = "%s to play and %s\nMaia %s  ·  %s" % ["White" if position.side == "w" else "Black", task, course.maia_level().trim_prefix("maia-"), "No clock" if course.clock_choice() == "none" else "5+5"]
	reason.text = "Pass: promote or mate.\nFail: change the result or run out of time." if task == "win" else "Pass: capture the pawn or hold the draw for 30 moves.\nFail: change the result or run out of time."
	start_button.show()
	next_button.hide()
	retry_button.hide()
	back_button.show()
	show()

func present_end(position: Dictionary, game, title: String, message: String, failed_move := "", next_exists := false) -> void:
	board.game = game
	board.flipped = position.side == "b"
	board.review_square = failed_move.substr(2, 2) if not failed_move.is_empty() else ""
	board.review_icon = preload("res://ui/icons/classes/blunder.svg") if not failed_move.is_empty() else null
	board.queue_redraw()
	heading.text = title
	states.text = ""
	details.text = ""
	reason.text = message
	start_button.hide()
	next_button.visible = title in ["Converted", "Held"] and next_exists
	retry_button.visible = title not in ["Converted", "Held"]
	back_button.show()
	show()
