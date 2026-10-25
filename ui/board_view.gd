extends Control

# The board (§8.1, §8.3): draws the position, handles moves and square annotations.
# Always square and centred in the control, so it scales with the window.

signal move_played(san: String)
signal sound_requested(event: String)

const ThemeLoader = preload("res://ui/theme_loader.gd")
const PromotionPicker = preload("res://ui/promotion_picker.gd")
const SNAP_BACK_SECONDS := 0.15
const LAST_MOVE := Color(0.61, 0.78, 0, 0.41)
const CHECK := Color(1, 0, 0, 0.6)
const TARGET := Color(0.08, 0.33, 0.12, 0.5)
const DRAWING := Color(0.12, 0.65, 0.22, 0.75)

# How long a move that was not dragged (the bot's, a premove) slides; 0 is instant.
@export var slide_seconds := 0.12
# Dots on the held piece's empty targets, rings on its captures.
@export var show_targets := true
@export var board_theme := "brown"
@export var piece_theme := "cburnett"
@export var click_click := false
@export_enum("off", "on", "only on premoves") var auto_queen := "off"

var _board_style := {"light": ThemeLoader.BROWN_LIGHT, "dark": ThemeLoader.BROWN_DARK, "texture": null}

var game:
	set(value):
		game = value
		# A new game (a rematch) keeps nothing held, sliding or promoting from the old one.
		_end_slide()
		if _snap:
			_snap.kill()
		_held_moves.clear()
		drawings.clear()
		_drawing_from = ""
		_drawing_to = ""
		_promoting = ""
		# Null on a board built outside a scene.
		if _picker and _picker.visible:
			_picker._close("")
		_end_snap_back()
# Black at the bottom.
var flipped := false:
	set(value):
		flipped = value
		queue_redraw()

# FEN letter -> texture.
var _textures := {}
# The held piece's square; "" when nothing is held.
var _drag_from := ""
# A piece selected by a completed click stays on its square until the next click.
var _selected := ""
var _press_pos := Vector2.ZERO
var _dragged := false
# The held piece's centre, in control coordinates.
var _drag_pos := Vector2.ZERO:
	set(value):
		_drag_pos = value
		queue_redraw()
var _snapping := false
var _snap: Tween
# The held piece's legal moves, UCI.
var _held_moves := PackedStringArray()
# The sliding piece's destination; "" when nothing slides.
var _slide_to := ""
var _slide_pos := Vector2.ZERO:
	set(value):
		_slide_pos = value
		queue_redraw()
var _slide: Tween
# From and to of the promotion waiting on the picker.
var _promoting := ""
# Square pairs, independent of board orientation/size. Equal endpoints represent a circle.
var drawings: Array[PackedStringArray] = []
var _drawing_from := ""
var _drawing_to := ""

@onready var _picker = $PromotionPicker


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
	set_board_theme(board_theme)
	set_piece_theme(piece_theme)
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)
	_picker.picked.connect(func(piece: String) -> void: _commit(_promoting + piece, false))
	_picker.cancelled.connect(_end_snap_back)


func set_board_theme(name: String) -> void:
	board_theme = name
	_board_style = ThemeLoader.new().load_board(name)
	queue_redraw()


func set_piece_theme(name: String) -> void:
	piece_theme = name
	_textures = ThemeLoader.new().load_pieces(name)
	queue_redraw()


# A move not dragged on the board (the bot's, a premove); false when it is illegal.
func play(move: String) -> bool:
	if game.is_over() or not move in game.board.legal_moves():
		return false
	_commit(move, true)
	return true


func _draw() -> void:
	var side := _side()
	var cell := Vector2.ONE * side / 8
	var last: String = game.moves[-1] if game and game.moves else ""
	var checked := ""
	if game and game.board.in_check():
		checked = "K" if game.board.side_to_move == "w" else "k"
	if _board_style.texture:
		draw_texture_rect(_board_style.texture, Rect2(_corner(), Vector2.ONE * side), false)
	for i in 64:
		var square: String = "abcdefgh"[i % 8] + str(i / 8 + 1)
		var at := _corner() + square_position(square, side, flipped)
		if not _board_style.texture:
			draw_rect(Rect2(at, cell), _board_style.light if _is_light(square) else _board_style.dark)
		if last and square in [last.substr(0, 2), last.substr(2, 2)]:
			draw_rect(Rect2(at, cell), LAST_MOVE)
		var piece: String = game.board.piece_at(square) if game else ""
		if checked and piece == checked:
			draw_circle(at + cell / 2, cell.x / 2, CHECK)
		if square != _drag_from and square != _slide_to:
			_draw_piece(piece, at, cell)
	_draw_coordinates(cell.x)
	if show_targets:
		for move in _held_moves:
			# A promotion is four moves to one square: mark it once.
			if move.length() == 5 and move[4] != "q":
				continue
			var to := move.substr(2, 2)
			if game.board.piece_at(to):
				draw_arc(_centre(to), cell.x * 0.45, 0, TAU, 48, TARGET, cell.x * 0.08)
			else:
				draw_circle(_centre(to), cell.x * 0.15, TARGET)
	if _slide_to:
		_draw_piece(game.board.piece_at(_slide_to), _slide_pos - cell / 2, cell)
	if _drag_from:
		_draw_piece(game.board.piece_at(_drag_from), _drag_pos - cell / 2, cell)
	for drawing in drawings:
		_draw_annotation(drawing[0], drawing[1], cell.x)
	if _drawing_from and _drawing_to:
		_draw_annotation(_drawing_from, _drawing_to, cell.x)


func _draw_annotation(from: String, to: String, cell: float) -> void:
	var start := _centre(from)
	var end := _centre(to)
	if from == to:
		draw_arc(start, cell * 0.43, 0, TAU, 64, DRAWING, cell * 0.07, true)
	else:
		var direction := (end - start).normalized()
		var base := end - direction * cell * 0.3
		var wing := direction.orthogonal() * cell * 0.2
		draw_line(start, base, DRAWING, cell * 0.12, true)
		draw_colored_polygon(PackedVector2Array([end, base + wing, base - wing]), DRAWING)


# Files along the bottom edge, ranks along the left edge, in the other square colour.
func _draw_coordinates(cell: float) -> void:
	var font := get_theme_default_font()
	var font_size := int(cell / 5)
	var pad := cell / 20
	for i in 8:
		var bottom := _corner() + Vector2(i, 7) * cell
		var file := square_at(Vector2(i + 0.5, 7.5) * cell, _side(), flipped)
		draw_string(font, bottom + Vector2(0, cell - pad), file[0], HORIZONTAL_ALIGNMENT_RIGHT,
				cell - pad, font_size, _board_style.dark if _is_light(file) else _board_style.light)
		var left := _corner() + Vector2(0, i) * cell
		var rank := square_at(Vector2(0.5, i + 0.5) * cell, _side(), flipped)
		draw_string(font, left + Vector2(pad, pad + font.get_ascent(font_size)), rank[1],
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _board_style.dark if _is_light(rank) else _board_style.light)


func _draw_piece(piece: String, at: Vector2, cell: Vector2) -> void:
	if piece and _textures.get(piece):
		draw_texture_rect(_textures[piece], Rect2(at, cell), false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		var square := square_at(event.position - _corner(), _side(), flipped)
		if event.pressed:
			_drawing_from = square
			_drawing_to = square
		else:
			if _drawing_from and square:
				drawings.append(PackedStringArray([_drawing_from, square]))
			_drawing_from = ""
			_drawing_to = ""
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drawings.clear()
			_drawing_from = ""
			_drawing_to = ""
			queue_redraw()
		if _snapping or _promoting:
			return
		if event.pressed:
			if _selected:
				_drag_from = _selected
				_selected = ""
				_drop(event.position, true, event.alt_pressed)
			else:
				_pick_up(event.position)
		elif _drag_from and not _snapping:
			var to := square_at(event.position - _corner(), _side(), flipped)
			if click_click and not _dragged and to == _drag_from:
				_selected = _drag_from
				_drag_from = ""
				queue_redraw()
			else:
				_drop(event.position, false, event.alt_pressed)
	elif event is InputEventMouseMotion:
		if _drawing_from:
			_drawing_to = square_at(event.position - _corner(), _side(), flipped)
			queue_redraw()
		elif _drag_from and not _snapping and not _promoting:
			_dragged = _dragged or event.position.distance_to(_press_pos) >= 8
			_drag_pos = event.position


# Only a piece of the side to move, and never once the game is over.
func _pick_up(point: Vector2) -> void:
	if _drag_from or game == null or game.is_over():
		return
	var square := square_at(point - _corner(), _side(), flipped)
	var piece: String = game.board.piece_at(square) if square else ""
	if piece and (piece == piece.to_upper()) == (game.board.side_to_move == "w"):
		_end_slide()
		_drag_from = square
		_drag_pos = point
		_press_pos = point
		_dragged = false
		for move in game.board.legal_moves():
			if move.begins_with(square):
				_held_moves.append(move)


func _drop(point: Vector2, clicked := false, alt := false) -> void:
	var to := square_at(point - _corner(), _side(), flipped)
	var moves := PackedStringArray()
	for move in _held_moves:
		if to and move.substr(2, 2) == to:
			moves.append(move)
	_held_moves.clear()
	if moves.size() > 1:
		if PromotionPicker.should_auto_queen(auto_queen, false, alt):
			_commit(_drag_from + to + "q", clicked)
		else:
			_open_picker(to)
	elif moves:
		_commit(moves[0], clicked)
	elif clicked:
		_end_snap_back()
	else:
		_snapping = true
		_snap = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_snap.tween_property(self, "_drag_pos", _centre(_drag_from), SNAP_BACK_SECONDS)
		_snap.tween_callback(_end_snap_back)


# The pawn waits on the promotion square; the picker covers the board until it is answered.
func _open_picker(to: String) -> void:
	_promoting = _drag_from + to
	_drag_pos = _centre(to)
	var at := square_position(to, _side(), flipped)
	_picker.open(_textures, game.board.side_to_move == "w", _corner() + at, _side() / 8, at.y < _side() / 2)


# shortcut: only the moving piece slides, a castling rook jumps; slide it too if it looks wrong.
func _commit(move: String, slide: bool) -> void:
	var san: String = game.board.san(move)
	# The game ended (a flag) while the piece was held or the promotion picker was open.
	if not game.play(move):
		_end_snap_back()
		return
	_drag_from = ""
	_selected = ""
	_held_moves.clear()
	_promoting = ""
	if slide and slide_seconds > 0:
		_end_slide()
		_slide_to = move.substr(2, 2)
		_slide_pos = _centre(move.substr(0, 2))
		_slide = create_tween()
		_slide.tween_property(self, "_slide_pos", _centre(_slide_to), slide_seconds)
		_slide.tween_callback(_end_slide)
	queue_redraw()
	sound_requested.emit("castle" if san.begins_with("O-O") else "capture" if "x" in san else "move")
	if "=" in san:
		sound_requested.emit("promote")
	if game.board.in_check():
		sound_requested.emit("check")
	move_played.emit(san)


func _end_slide() -> void:
	if _slide:
		_slide.kill()
	_slide_to = ""
	queue_redraw()


func _end_snap_back() -> void:
	_snapping = false
	_drag_from = ""
	_selected = ""
	_held_moves.clear()
	_promoting = ""
	queue_redraw()


func _side() -> float:
	return minf(size.x, size.y)


func _corner() -> Vector2:
	return (size - Vector2.ONE * _side()) / 2


func _centre(square: String) -> Vector2:
	return _corner() + square_position(square, _side(), flipped) + Vector2.ONE * _side() / 16


static func _is_light(square: String) -> bool:
	return (square.unicode_at(0) + square.unicode_at(1)) % 2 == 1
