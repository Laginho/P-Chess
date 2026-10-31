extends Control

signal ply_selected(ply: int)

const Board = preload("res://core/board.gd")
const Tunables = preload("res://core/tunables.gd")

const COLOURS := {"Inaccuracy": Color("f4bf44"), "Mistake": Color("e28c28"), "Miss": Color("ff7769"), "Blunder": Color("c93230")}

var positions: Array = []
var classes: Array = []
var current_ply := 0
var flipped := false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not positions.is_empty():
		ply_selected.emit(roundi(clampf(event.position.x / maxf(size.x, 1.0), 0.0, 1.0) * (positions.size() - 1)))


func _draw() -> void:
	var card := StyleBoxFlat.new()
	card.bg_color = Color("403d39")
	card.set_corner_radius_all(6)
	draw_style_box(card, Rect2(Vector2.ZERO, size))
	var dots := []
	var previous := Vector2.ZERO
	var have_previous := false
	for i in positions.size():
		var position: Dictionary = positions[i]
		if not position.has("pv"):
			have_previous = false
			continue
		var line: Dictionary = position.pv[0] if not position.pv.is_empty() else {"cp": position.terminal_score}
		var score: int = int(line.cp) if line.has("cp") else (Tunables.CLASSIFICATION_CP_LIMIT if line.mate > 0 else -Tunables.CLASSIFICATION_CP_LIMIT)
		if Board.from_fen(position.fen).side_to_move == "b":
			score = -score
		if flipped:
			score = -score
		var fraction := 1.0 / (1.0 + exp(-Tunables.CLASSIFICATION_EP_FACTOR * clampi(score, -Tunables.CLASSIFICATION_CP_LIMIT, Tunables.CLASSIFICATION_CP_LIMIT)))
		var point := Vector2(size.x * i / maxi(positions.size() - 1, 1), size.y * (1.0 - fraction))
		if have_previous:
			draw_colored_polygon(PackedVector2Array([previous, point, Vector2(point.x, size.y), Vector2(previous.x, size.y)]), Color("ece9e4"))
		if i > 0 and i <= classes.size() and classes[i - 1] != null and COLOURS.has(classes[i - 1].class):
			dots.append([point, COLOURS[classes[i - 1].class]])
		previous = point
		have_previous = true
	draw_dashed_line(Vector2(0, size.y / 2), Vector2(size.x, size.y / 2), Color("8c887f"), 1.0, 3.0)
	if not positions.is_empty():
		var x := size.x * current_ply / maxi(positions.size() - 1, 1)
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color("7fa650"), 2.0)
	# Dots go on top of the area, the midline and the current-move marker, as drawn.
	for dot in dots:
		draw_circle(dot[0], 4.5, Color("141412"))
		draw_circle(dot[0], 3.5, dot[1])
