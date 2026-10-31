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
	# As in Game.png, the icon hangs off the board's corner onto the dark background: grey on a light square is unreadable.
	position = Vector2((board.size.x + side) / 2.0, (board.size.y + side) / 2.0) - Vector2(4, 4)


func _draw() -> void:
	var colour := Color("#a8a49c")
	draw_line(Vector2(5, 5), Vector2(15, 15), colour, 1.5, true)
	draw_line(Vector2(5, 5), Vector2(5, 10), colour, 1.5, true)
	draw_line(Vector2(5, 5), Vector2(10, 5), colour, 1.5, true)
	draw_line(Vector2(15, 15), Vector2(10, 15), colour, 1.5, true)
	draw_line(Vector2(15, 15), Vector2(15, 10), colour, 1.5, true)


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
