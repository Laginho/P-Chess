extends Control

signal back_requested
signal part_requested(unit: Dictionary, part: String)

const BoardView = preload("res://ui/board_view.tscn")
const Game = preload("res://core/game.gd")

var course
var unit := {}


func _ready() -> void:
	$Margin/Content/Header/Back.pressed.connect(func(): back_requested.emit())
	$Margin/Content/Body/Side/Clock/ClockOn.pressed.connect(func(): _choose_clock("5+5"))
	$Margin/Content/Body/Side/Clock/NoClock.pressed.connect(func(): _choose_clock("none"))


func present(store, selected: Dictionary) -> void:
	course = store
	unit = selected
	var progress: Dictionary = course.unit_progress(unit)
	$Margin/Content/Header/Title.text = "%s  ·  %s" % [unit.get("title", ""), progress.status.capitalize()]
	$Margin/Content/Body/Side/FirstTry.text = progress.first_try
	var preview := $Margin/Content/Body/Side/Preview
	for child in preview.get_children():
		preview.remove_child(child)
		child.queue_free()
	var positions = unit.get("positions", [])
	if positions is Array and not positions.is_empty() and positions[0] is Dictionary and positions[0].has("fen"):
		var board = BoardView.instantiate()
		board.custom_minimum_size = Vector2(260, 260)
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(board)
		board.game = Game.new(positions[0].fen)
	$Margin/Content/Body/Side/ClockError.hide()
	_update_clock()
	var parts := $Margin/Content/Body/Parts
	for child in parts.get_children():
		parts.remove_child(child)
		child.queue_free()
	var rows := [
		["theory", "Theory pointer", "Done" if progress.theory_done else "Not opened", progress.theory_done],
		["solving", "Solving", "%d/%d solved" % [progress.solved, progress.total], progress.total > 0 and progress.solved >= progress.total],
		["playouts", "Play-outs", "%d/4 passed" % progress.playouts_passed, progress.playouts_passed >= 4],
		["test", "Pass test", progress.test.capitalize(), progress.test == "passed"]
	]
	var continuing := false
	for entry in rows:
		var row := PanelContainer.new()
		row.name = entry[0].capitalize().replace(" ", "")
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.theme_type_variation = "CardPanel"
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 20)
		row.add_child(content)
		var labels := VBoxContainer.new()
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(labels)
		var title := Label.new()
		title.text = entry[1]
		title.theme_type_variation = "ExtraBoldText"
		title.add_theme_font_size_override("font_size", 19)
		labels.add_child(title)
		var description := Label.new()
		description.text = {"theory": "Search terms and book chapters", "solving": "Calculate complete lines", "playouts": "Play the positions against Maia", "test": "Solve and play against a perfect opponent"}[entry[0]]
		description.theme_type_variation = "MutedText"
		labels.add_child(description)
		var status := Label.new()
		status.text = entry[2]
		status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(status)
		var button := Button.new()
		button.name = "Open"
		button.custom_minimum_size = Vector2(120, 44)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.text = "Continue" if not entry[3] and not continuing else "Open"
		if button.text == "Continue":
			continuing = true
			button.theme_type_variation = "PrimaryButton"
		button.pressed.connect(func(): part_requested.emit(unit, entry[0]))
		content.add_child(button)
		parts.add_child(row)
	show()


func _choose_clock(choice: String) -> void:
	$Margin/Content/Body/Side/ClockError.visible = not course.save_clock_choice(choice)
	_update_clock()


func _update_clock() -> void:
	$Margin/Content/Body/Side/Clock/ClockOn.button_pressed = course.clock_choice() == "5+5"
	$Margin/Content/Body/Side/Clock/NoClock.button_pressed = course.clock_choice() == "none"
