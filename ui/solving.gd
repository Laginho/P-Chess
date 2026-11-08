extends Control

signal back_requested
signal line_committed(position: Dictionary, uci: PackedStringArray, san: PackedStringArray)

var course
var unit: Dictionary
var position_data: Dictionary
var positions: Array
var probe
var _settings
var _mode := "entry"
var _generation := 0
var _grade := {}
var _playback_ply := 0

@onready var board = $Margin/Content/BoardView
@onready var side = $Margin/Content/Side


func _ready() -> void:
	side.get_node("Header/Back").pressed.connect(func(): back_requested.emit())
	side.get_node("Actions/Undo").pressed.connect(func():
		if _mode == "entry": board.undo_entry())
	side.get_node("Actions/Clear").pressed.connect(func():
		if _mode == "entry": board.clear_entry())
	side.get_node("Commit").pressed.connect(_commit_line)
	board.entry_changed.connect(_refresh_line)
	side.get_node("Feedback/Buttons/Retry").pressed.connect(func(): _open_position(position_data))
	side.get_node("Feedback/Buttons/Next").pressed.connect(func(): present(course, unit, _settings))
	$Playback.timeout.connect(_advance_feedback)
	visibility_changed.connect(func():
		if not visible:
			_generation += 1
			$Playback.stop())


func present(store, selected: Dictionary, settings = null) -> void:
	course = store
	unit = selected
	positions = course.practice_positions(unit)
	_settings = settings
	_open_position(course.next_practice_position(unit))


func _open_position(selected: Dictionary) -> void:
	_generation += 1
	$Playback.stop()
	_mode = "entry"
	_grade = {}
	position_data = selected
	_set_entry_visible(true)
	side.get_node("ProbeError").hide()
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.best_move_arrow = ""
	if position_data.is_empty():
		return
	board.game = preload("res://core/game.gd").new(position_data.fen)
	board.flipped = position_data.get("side", board.game.board.side_to_move) == "b"
	if _settings != null:
		board.set_board_theme(_settings.get_value("board_theme"))
		board.set_piece_theme(_settings.get_value("piece_theme"))
		board.auto_queen = _settings.get_value("auto_queen")
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
	var black_first: bool = board.game.board.side_to_move == "b"
	var start := 0
	if black_first and not board.entry_san.is_empty():
		rows.append("1...  %s" % board.entry_san[0])
		start = 1
	for i in range(start, board.entry_san.size(), 2):
		var row := "%d.  %s" % [(i - start) / 2 + 1 + int(black_first), board.entry_san[i]]
		if i + 1 < board.entry_san.size():
			row += "  " + board.entry_san[i + 1]
		rows.append(row)
	side.get_node("LineCard/Line/Moves").text = "\n".join(rows)
	side.get_node("Commit").disabled = board.entry_limit == 0 or board.entry_moves.size() != board.entry_limit


func _commit_line() -> void:
	if _mode != "entry" or board.entry_limit == 0 or board.entry_moves.size() != board.entry_limit:
		return
	var line: PackedStringArray = board.entry_moves.duplicate()
	line_committed.emit(position_data.duplicate(true), line, board.entry_san.duplicate())
	if probe == null:
		return
	_mode = "grading"
	side.get_node("ProbeError").hide()
	side.get_node("Commit").disabled = true
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for name in ["Undo", "Clear"]:
		side.get_node("Actions/" + name).disabled = true
	if probe.has_method("start"):
		probe.start()
	var generation := _generation
	var first: bool = course.practice_result(unit, position_data).is_empty()
	var grader = preload("res://core/grader.gd").new(probe)
	grader.grade(position_data, line, func(result: Dictionary):
		if generation != _generation or not visible:
			return
		if not result.ok:
			_show_error(result.get("error", "Tablebase probe failed."))
		elif not course.record_commit(unit, position_data, result.solved):
			_show_error("Could not save course progress. Try Commit again.")
		else:
			_show_feedback(result, first and result.solved))


func _input(event: InputEvent) -> void:
	if not visible or _mode != "entry" or not event is InputEventKey or event.keycode not in [KEY_ENTER, KEY_KP_ENTER]:
		return
	# Consume both phases before a focused button can activate on key release.
	if event.pressed and not event.echo:
		_commit_line()
	get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _mode != "entry" or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_BACKSPACE:
		board.undo_entry()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_commit_line()
		get_viewport().set_input_as_handled()


func _set_entry_visible(value: bool) -> void:
	for name in ["GoalCard", "LineCard", "Actions", "Commit"]:
		side.get_node(name).visible = value
	side.get_node("Feedback").visible = not value
	for name in ["Undo", "Clear"]:
		side.get_node("Actions/" + name).disabled = false


func _show_error(message: String) -> void:
	_mode = "entry"
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	side.get_node("ProbeError").text = message
	side.get_node("ProbeError").show()
	for name in ["Undo", "Clear"]:
		side.get_node("Actions/" + name).disabled = false
	_refresh_line()


func _show_feedback(result: Dictionary, first: bool) -> void:
	_mode = "feedback"
	_grade = result
	_playback_ply = 0
	_set_entry_visible(false)
	board.entry_mode = false
	board.entry_moves.clear()
	board.entry_san.clear()
	board.game = preload("res://core/game.gd").new(position_data.fen)
	board.queue_redraw()
	var feedback = side.get_node("Feedback")
	feedback.get_node("Banner/BannerText/BannerTitle").text = ("Solved, first try" if first else "Solved") if result.solved else "Not solved"
	var progress: Dictionary = course.unit_progress(unit)
	feedback.get_node("Banner/BannerText/BannerReason").text = "%d of %d solved · %s first try" % [progress.solved, progress.total, progress.first_try] if result.solved else result.plies[result.failed_ply].san + ": " + result.reason
	var banner := StyleBoxFlat.new()
	banner.bg_color = Color("#2c3a21") if result.solved else Color("#3a2423")
	banner.set_corner_radius_all(10)
	banner.set_content_margin_all(18)
	feedback.get_node("Banner").add_theme_stylebox_override("panel", banner)
	feedback.get_node("Banner").modulate = Color.WHITE
	feedback.get_node("Banner/BannerText").modulate = Color("#b9d68f") if result.solved else Color("#f0a3a1")
	feedback.get_node("Note").text = "" if result.solved else "A retry counts as solved, not as first try."
	feedback.get_node("CorrectCard").hide()
	feedback.get_node("Buttons/Retry").theme_type_variation = "" if result.solved else "PrimaryButton"
	feedback.get_node("Buttons/Next").theme_type_variation = "PrimaryButton" if result.solved else ""
	_render_feedback()
	$Playback.start()


func _render_feedback() -> void:
	var rows = side.get_node("Feedback/YourLine/LineContent/Scroll/FeedbackMoves")
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var initial = preload("res://core/board.gd").from_fen(position_data.fen)
	var black := int(initial.side_to_move == "b")
	for i in _grade.plies.size():
		var ply: Dictionary = _grade.plies[i]
		var revealed: bool = i < _playback_ply
		var label := Label.new()
		var number: int = initial.fullmove_number + (i + black) / 2
		label.text = "%d%s  %s" % [number, "." if (i + black) % 2 == 0 else "...", ply.san]
		if revealed and not ply.mark.is_empty():
			label.text += "  " + ply.mark
		if revealed and not ply.better_defence.is_empty():
			label.text += "\n    Better defence: " + ply.better_defence
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color("#8a857c") if not revealed or ply.grey else (Color("#e0605e") if ply.mark == "✗" else Color("#ece9e4")))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(label)


func _advance_feedback() -> void:
	if _mode != "feedback" or _playback_ply >= _grade.plies.size() or (_grade.failed_ply >= 0 and _playback_ply > _grade.failed_ply):
		return
	var ply: Dictionary = _grade.plies[_playback_ply]
	_playback_ply += 1
	if ply.mark == "✗":
		$Playback.stop()
		board.best_move_arrow = _grade.correct[0].uci
		board.queue_redraw()
		var card = side.get_node("Feedback/CorrectCard")
		card.show()
		card.get_node("Correct/CorrectMove").text = _grade.correct[0].san
		var correct := PackedStringArray()
		for move in _grade.correct:
			correct.append(move.san)
		card.get_node("Correct/CorrectLine").text = " ".join(correct)
	else:
		board.game.play(ply.uci)
		board.queue_redraw()
		if _playback_ply == _grade.plies.size():
			$Playback.stop()
	_render_feedback()
