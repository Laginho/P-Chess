extends Control

# Promotion (§8.4): queen, rook, bishop and knight in a column from the promotion square towards
# the board's centre. A click anywhere else, or Escape, cancels.

signal picked(piece: String)
signal cancelled

const CHOICES := "qrbn"


# Shared with premove input: Alt always requests an explicit promotion choice.
static func should_auto_queen(mode: String, premove: bool, alt: bool) -> bool:
	return not alt and (mode == "on" or (mode == "only on premoves" and premove))


# textures: FEN letter -> texture. The board places the buttons with layout().
func open(textures: Dictionary, white: bool) -> void:
	for i in CHOICES.length():
		var button := Button.new()
		var piece: String = CHOICES[i].to_upper() if white else CHOICES[i]
		button.icon = textures[piece]
		button.expand_icon = true
		button.focus_mode = FOCUS_NONE
		button.pressed.connect(_close.bind(CHOICES[i]))
		add_child(button)
	show()


# at: the promotion square's top-left; down: the column's direction. Called again on flip or resize.
func layout(at: Vector2, cell: float, down: bool) -> void:
	var i := 0
	# Buttons of a picker closed this frame are still children until freed.
	for button in get_children():
		if not button.is_queued_for_deletion():
			button.position = at + Vector2(0, i * cell * (1 if down else -1))
			button.size = Vector2.ONE * cell
			i += 1


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.3))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close("")


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close("")


func _close(piece: String) -> void:
	hide()
	for button in get_children():
		button.queue_free()
	if piece:
		picked.emit(piece)
	else:
		cancelled.emit()
