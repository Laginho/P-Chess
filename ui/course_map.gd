extends Control

signal back_requested
signal edit_requested
signal unit_requested(unit: Dictionary)

const BoardView = preload("res://ui/board_view.tscn")
const Game = preload("res://core/game.gd")


func _ready() -> void:
	$Margin/Content/Header/Back.pressed.connect(func(): back_requested.emit())
	$Margin/Content/Header/Edit.pressed.connect(func(): edit_requested.emit())


func present(course) -> void:
	var rating: Dictionary = course.rating()
	$Margin/Content/Header/Rating.text = "Rated %d in rapid on chess.com" % course.chess_com_rating() if not rating.is_empty() else ""
	var stage: Dictionary = course.stage()
	$Margin/Content/Stage.text = "%s · around %d" % [stage.get("name", ""), course.chess_com_rating()]
	var list := $Margin/Content/Scroll/Units
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for unit in course.units():
		var progress: Dictionary = course.unit_progress(unit)
		var card := Button.new()
		card.custom_minimum_size.y = 240
		card.theme_type_variation = "RaisedButton"
		card.pressed.connect(func(): unit_requested.emit(unit))
		list.add_child(card)
		var inset := MarginContainer.new()
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]:
			inset.add_theme_constant_override("margin_" + side, 20)
		card.add_child(inset)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 24)
		inset.add_child(row)
		var positions = unit.get("positions", [])
		if positions is Array and not positions.is_empty() and positions[0] is Dictionary and positions[0].has("fen"):
			var board = BoardView.instantiate()
			board.custom_minimum_size = Vector2(200, 200)
			board.size_flags_horizontal = 0
			board.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(board)
			board.game = Game.new(positions[0].fen)
		var details := VBoxContainer.new()
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_theme_constant_override("separation", 8)
		row.add_child(details)
		_add_label(details, "Unit %d    ·    %s" % [list.get_child_count(), progress.status.capitalize()], "MutedText", 14)
		_add_label(details, unit.get("title", ""), "ExtraBoldText", 28)
		_add_label(details, unit.get("subtitle", ""), "MutedText", 16)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.add_child(spacer)
		var summaries := HBoxContainer.new()
		summaries.mouse_filter = Control.MOUSE_FILTER_IGNORE
		summaries.add_theme_constant_override("separation", 16)
		details.add_child(summaries)
		for summary in [["Theory", "Done" if progress.theory_done else "Not opened"], ["Solving", "%d/%d solved" % [progress.solved, progress.total]], ["Play-outs", "%d/4 passed" % progress.playouts_passed], ["Pass test", progress.test.capitalize()]]:
			var column := VBoxContainer.new()
			column.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			summaries.add_child(column)
			_add_label(column, summary[0], "SemiboldText", 14)
			_add_label(column, summary[1], "MutedText", 13)

	show()


func _add_label(parent: Control, text: String, variation: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
