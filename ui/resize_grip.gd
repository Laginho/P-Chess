extends Control

signal size_requested(side: int)

var _dragging := false
var _requested := 0.0


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	get_parent().resized.connect(_place)
	_place()


func _place() -> void:
	var board: Control = get_parent()
	var side := minf(board.size.x, board.size.y)
	position = Vector2((board.size.x + side) / 2.0, (board.size.y + side) / 2.0) - size


func _draw() -> void:
	for offset in [4, 9, 14]:
		# The dark edge keeps the white strokes visible on light squares.
		draw_line(Vector2(size.x - offset, size.y - 2), Vector2(size.x - 2, size.y - offset), Color(0, 0, 0, 0.6), 4.0)
		draw_line(Vector2(size.x - offset, size.y - 2), Vector2(size.x - 2, size.y - offset), Color.WHITE, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.double_click:
			_dragging = false
			size_requested.emit(0)
		elif event.pressed:
			_dragging = true
			_requested = minf(get_parent().size.x, get_parent().size.y)
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_requested += event.relative.x
		size_requested.emit(maxi(1, roundi(_requested)))
		_requested = get_parent().custom_minimum_size.x
