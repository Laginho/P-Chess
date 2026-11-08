extends Control

signal back_requested
signal edit_requested
signal unit_requested(unit: Dictionary)


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
		card.custom_minimum_size.y = 200
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.theme_type_variation = "RaisedButton"
		card.text = "%s    ·    %s\n\n%s\n\nTheory: %s     Solving: %d/%d     Play-outs: %d/4     Pass test: %s" % [unit.get("title", ""), progress.status.capitalize(), unit.get("subtitle", ""), "Done" if progress.theory_done else "Not opened", progress.solved, progress.total, progress.playouts_passed, progress.test]
		card.pressed.connect(func(): unit_requested.emit(unit))
		list.add_child(card)
	show()
