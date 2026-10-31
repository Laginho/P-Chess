extends Control

signal ply_selected(ply: int)

const Board = preload("res://core/board.gd")
const Tunables = preload("res://core/tunables.gd")

var positions: Array = []
var current_ply := 0
var flipped := false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not positions.is_empty():
		ply_selected.emit(roundi(clampf(event.position.x / maxf(size.x, 1.0), 0.0, 1.0) * (positions.size() - 1)))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.17, 0.18, 0.2))
	draw_line(Vector2(0, size.y / 2), Vector2(size.x, size.y / 2), Color.GRAY)
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
			draw_line(previous, point, Color.WHITE, 2.0)
		draw_circle(point, 2.5, Color.WHITE)
		previous = point
		have_previous = true
	if not positions.is_empty():
		var x := size.x * current_ply / maxi(positions.size() - 1, 1)
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.9, 0.7, 0.25), 2.0)
