extends Control

# The board (§8.1): draws the position of `game` and turns drags into moves on it.
# Always square and centred in the control, so it scales with the window.

signal move_played(san: String)

const LIGHT := Color("#f0d9b5")
const DARK := Color("#b58863")
# shortcut: read as raw SVG, so the Windows export (CI-002) must ship *.svg as non-resource files.
const PIECES := "res://themes/pieces/cburnett/"
const SNAP_BACK_SECONDS := 0.15

var game:
	set(value):
		game = value
		queue_redraw()
# Black at the bottom.
var flipped := false:
	set(value):
		flipped = value
		queue_redraw()

# FEN letter -> texture.
var _textures := {}
# The held piece's square; "" when nothing is held.
var _drag_from := ""
# The held piece's centre, in control coordinates.
var _drag_pos := Vector2.ZERO:
	set(value):
		_drag_pos = value
		queue_redraw()
var _snapping := false


# The square under a point measured from the board's top-left corner; "" off the board.
static func square_at(point: Vector2, side: float, flipped: bool) -> String:
	var column := floori(point.x * 8 / side)
	var row := floori(point.y * 8 / side)
	if column < 0 or column > 7 or row < 0 or row > 7:
		return ""
	if flipped:
		return "abcdefgh"[7 - column] + str(row + 1)
	return "abcdefgh"[column] + str(8 - row)


# A square's top-left corner, measured from the board's top-left corner.
static func square_position(square: String, side: float, flipped: bool) -> Vector2:
	var file := square.unicode_at(0) - 97
	var rank := square.unicode_at(1) - 49
	var cell := Vector2(7 - file, rank) if flipped else Vector2(file, 7 - rank)
	return cell * side / 8


func _ready() -> void:
	for piece in "KQRBNPkqrbnp":
		var image := Image.new()
		# Rasterised once above any square size, then scaled down through mipmaps.
		image.load_svg_from_string(FileAccess.get_file_as_string(
				PIECES + ("w" if piece == piece.to_upper() else "b") + piece.to_upper() + ".svg"), 4.0)
		image.generate_mipmaps()
		_textures[piece] = ImageTexture.create_from_image(image)
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)


func _draw() -> void:
	var side := _side()
	var cell := Vector2.ONE * side / 8
	for i in 64:
		var square: String = "abcdefgh"[i % 8] + str(i / 8 + 1)
		var at := _corner() + square_position(square, side, flipped)
		draw_rect(Rect2(at, cell), LIGHT if _is_light(square) else DARK)
		if game and square != _drag_from:
			_draw_piece(game.board.piece_at(square), at, cell)
	_draw_coordinates(cell.x)
	if _drag_from:
		_draw_piece(game.board.piece_at(_drag_from), _drag_pos - cell / 2, cell)


# Files along the bottom edge, ranks along the left edge, in the other square colour.
func _draw_coordinates(cell: float) -> void:
	var font := get_theme_default_font()
	var font_size := int(cell / 5)
	var pad := cell / 20
	for i in 8:
		var bottom := _corner() + Vector2(i, 7) * cell
		var file := square_at(Vector2(i + 0.5, 7.5) * cell, _side(), flipped)
		draw_string(font, bottom + Vector2(0, cell - pad), file[0], HORIZONTAL_ALIGNMENT_RIGHT,
				cell - pad, font_size, DARK if _is_light(file) else LIGHT)
		var left := _corner() + Vector2(0, i) * cell
		var rank := square_at(Vector2(0.5, i + 0.5) * cell, _side(), flipped)
		draw_string(font, left + Vector2(pad, pad + font.get_ascent(font_size)), rank[1],
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DARK if _is_light(rank) else LIGHT)


func _draw_piece(piece: String, at: Vector2, cell: Vector2) -> void:
	if piece:
		draw_texture_rect(_textures[piece], Rect2(at, cell), false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pick_up(event.position)
		elif _drag_from and not _snapping:
			_drop(event.position)
	elif event is InputEventMouseMotion and _drag_from and not _snapping:
		_drag_pos = event.position


# Only a piece of the side to move, and never once the game is over.
func _pick_up(point: Vector2) -> void:
	if _drag_from or game == null or game.is_over():
		return
	var square := square_at(point - _corner(), _side(), flipped)
	var piece: String = game.board.piece_at(square) if square else ""
	if piece and (piece == piece.to_upper()) == (game.board.side_to_move == "w"):
		_drag_from = square
		_drag_pos = point


func _drop(point: Vector2) -> void:
	var to := square_at(point - _corner(), _side(), flipped)
	var move := _legal_move(_drag_from + to) if to else ""
	if move:
		var san: String = game.board.san(move)
		game.play(move)
		_drag_from = ""
		queue_redraw()
		move_played.emit(san)
		return
	_snapping = true
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_drag_pos", _centre(_drag_from), SNAP_BACK_SECONDS)
	tween.tween_callback(_end_snap_back)


func _end_snap_back() -> void:
	_snapping = false
	_drag_from = ""
	queue_redraw()


# shortcut: a promotion always becomes a queen; UI-002 brings the promotion picker.
func _legal_move(from_to: String) -> String:
	for move in game.board.legal_moves():
		if move.begins_with(from_to) and (move.length() == 4 or move[4] == "q"):
			return move
	return ""


func _side() -> float:
	return minf(size.x, size.y)


func _corner() -> Vector2:
	return (size - Vector2.ONE * _side()) / 2


func _centre(square: String) -> Vector2:
	return _corner() + square_position(square, _side(), flipped) + Vector2.ONE * _side() / 16


static func _is_light(square: String) -> bool:
	return (square.unicode_at(0) + square.unicode_at(1)) % 2 == 1
