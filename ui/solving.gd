extends Control

signal back_requested
signal line_committed(position: Dictionary, uci: PackedStringArray, san: PackedStringArray)

var course
var unit: Dictionary
var position_data: Dictionary
var positions: Array

@onready var board = $Margin/Content/BoardView
@onready var side = $Margin/Content/Side


func _ready() -> void:
	side.get_node("Header/Back").pressed.connect(func(): back_requested.emit())
	side.get_node("Actions/Undo").pressed.connect(func(): board.undo_entry())
	side.get_node("Actions/Clear").pressed.connect(func(): board.clear_entry())
	side.get_node("Commit").pressed.connect(_commit_line)
	board.entry_changed.connect(_refresh_line)


func present(store, selected: Dictionary, settings = null) -> void:
	course = store
	unit = selected
	positions = course.practice_positions(unit)
	position_data = course.next_practice_position(unit)
	if position_data.is_empty():
		return
	board.game = preload("res://core/game.gd").new(position_data.fen)
	board.flipped = position_data.get("side", board.game.board.side_to_move) == "b"
	if settings != null:
		board.set_board_theme(settings.get_value("board_theme"))
		board.set_piece_theme(settings.get_value("piece_theme"))
		board.auto_queen = settings.get_value("auto_queen")
	board.start_entry(int(position_data.get("line_length", 1)))
	var index := positions.find(position_data)
	side.get_node("Header/Heading/UnitName").text = "%s · Solving" % unit.get("title", "")
	side.get_node("Header/Heading/Position").text = "Position %d of %d" % [index + 1, positions.size()]
	var mover := "White" if board.game.board.side_to_move == "w" else "Black"
	var opponent := "Black" if mover == "White" else "White"
	var goal := "draw" if position_data.get("goal") in ["hold", "draw"] else "win"
	side.get_node("GoalCard/Goal/Title").text = "%s to play and %s" % [mover, goal]
	side.get_node("GoalCard/Goal/Instruction").text = "Enter %d of your moves, with %s's replies in between." % [int(position_data.get("line_length", 1)), opponent]
	side.get_node("GoalCard/Goal/FromGame").visible = position_data.get("from_your_game", false)
	var strip = side.get_node("Progress")
	for child in strip.get_children():
		strip.remove_child(child)
		child.queue_free()
	for i in positions.size():
		var segment := Panel.new()
		segment.name = "Segment%d" % i
		segment.custom_minimum_size = Vector2(0, 8)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var result: Dictionary = course.practice_result(unit, positions[i])
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#7fa650") if result.get("first_try", false) and result.get("solved", false) else (Color("#4f6a33") if result.get("solved", false) else Color("#45423d"))
		style.set_corner_radius_all(4)
		if i == index:
			style.border_color = Color("#ece9e4")
			style.set_border_width_all(2)
		segment.set_meta("current", i == index)
		segment.add_theme_stylebox_override("panel", style)
		strip.add_child(segment)
	_refresh_line()
	show()


func _refresh_line() -> void:
	var length := int(position_data.get("line_length", 1))
	side.get_node("LineCard/Line/Count").text = "%d of %d moves" % [(board.entry_moves.size() + 1) / 2, length]
	var rows := PackedStringArray()
	for i in range(0, board.entry_san.size(), 2):
		var reply: String = board.entry_san[i + 1] if i + 1 < board.entry_san.size() else ""
		rows.append("%d.  %s  %s" % [i / 2 + 1, board.entry_san[i], reply])
	side.get_node("LineCard/Line/Moves").text = "\n".join(rows)
	side.get_node("Commit").disabled = board.entry_limit == 0 or board.entry_moves.size() != board.entry_limit


func _commit_line() -> void:
	if board.entry_limit > 0 and board.entry_moves.size() == board.entry_limit:
		line_committed.emit(position_data.duplicate(true), board.entry_moves.duplicate(), board.entry_san.duplicate())


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_BACKSPACE:
		board.undo_entry()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_commit_line()
		get_viewport().set_input_as_handled()
