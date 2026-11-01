extends Control

# The board (§8.1, §8.3): draws the position, handles moves and square annotations.
# Always square and centred in the control, so it scales with the window.

signal move_played(san: String)
signal sound_requested(event: String)

const ThemeLoader = preload("res://ui/theme_loader.gd")
const PromotionPicker = preload("res://ui/promotion_picker.gd")
const PremoveQueue = preload("res://ui/premove_queue.gd")
const SNAP_BACK_SECONDS := 0.15
const LAST_MOVE_LIGHT := Color("#cdd26a")
const LAST_MOVE_DARK := Color("#aaa23a")
const PREMOVE_LIGHT := Color("#e28b80")
const PREMOVE_DARK := Color("#b75e56")
const CHECK := Color(1, 0, 0, 0.6)
const TARGET := Color(0.08, 0.33, 0.12, 0.5)
const DRAWING := Color(0.12, 0.65, 0.22, 0.75)

# How long a move that was not dragged (the bot's, a premove) slides; 0 is instant.
@export var slide_seconds := 0.12
# Dots on the held piece's empty targets, rings on its captures.
@export var show_targets := true
@export var board_theme := "brown"
@export var piece_theme := "cburnett"
@export var click_click := false:
	set(value):
		click_click = value
		if not value and _selected:
			_end_snap_back()
@export_enum("off", "on", "only on premoves") var auto_queen := "off"

var premoves := PremoveQueue.new("w")
@export_enum("off", "Lichess", "Chess.com") var premove_style := "Chess.com":
	set(value):
		premove_style = value
		premoves.style = value
		if _is_premove_input():
			_cancel_interaction()
		queue_redraw()
# Empty preserves the standalone board's two-human input.
var human_side := "":
	set(value):
		human_side = value
		premoves.human = value
		premoves.clear()

var _board_style := {"light": ThemeLoader.BROWN_LIGHT, "dark": ThemeLoader.BROWN_DARK, "texture": null}

var game:
	set(value):
		game = value
		premoves.clear()
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
		_layout_picker()
		queue_redraw()

# FEN letter -> texture.
var _textures := {}
# The held piece's square; "" when nothing is held.
var _drag_from := ""
# A piece selected by a completed click stays on its square until the next click.
var _selected := ""
var _reselected := false
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
var _held_piece := ""
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
var review_square := ""
var review_arrow := ""
var review_icon: Texture2D
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
	resized.connect(func() -> void:
		_layout_picker()
		queue_redraw())
	_picker.picked.connect(func(piece: String) -> void: _submit(_promoting + piece, false))
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
func play(move: String, premove := false) -> bool:
	if game.is_over() or not move in game.board.legal_moves():
		return false
	_commit(move, true, premove)
	return true


func premove_highlighted_squares() -> PackedStringArray:
	var squares := PackedStringArray()
	for move in premoves.moves:
		for square in [move.substr(0, 2), move.substr(2, 2)]:
			if square not in squares:
				squares.append(square)
	return squares


func _draw() -> void:
	var side := _side()
	if side < 40:
		return
	var cell := Vector2.ONE * side / 8
	var last: String = game.moves[-1] if game and game.moves else ""
	var premove_squares := premove_highlighted_squares()
	var checked := ""
	var position = game.board if game else null
	if game and not premoves.moves.is_empty():
		var ghost = premoves.position(game.board)
		if ghost != null:
			position = ghost
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
			draw_rect(Rect2(at, cell), LAST_MOVE_LIGHT if _is_light(square) else LAST_MOVE_DARK)
		if square in premove_squares:
			draw_rect(Rect2(at, cell), PREMOVE_LIGHT if _is_light(square) else PREMOVE_DARK)
		var piece: String = position.piece_at(square) if position else ""
		# A Lichess replacement is picked from the live position, so keep its source visible.
		if game and premoves.style == "Lichess" and piece == "":
			piece = game.board.piece_at(square)
		if checked and piece == checked:
			draw_circle(at + cell / 2, cell.x / 2, CHECK)
		if square != _drag_from and square != _slide_to:
			_draw_piece(piece, at, cell, 0.5 if game and piece != game.board.piece_at(square) else 1.0)
	_draw_coordinates(cell.x)
	if show_targets:
		for move in _held_moves:
			# A promotion is four moves to one square: mark it once.
			if move.length() == 5 and move[4] != "q":
				continue
			var to := move.substr(2, 2)
			if position.piece_at(to):
				draw_arc(_centre(to), cell.x * 0.45, 0, TAU, 48, TARGET, cell.x * 0.08)
			else:
				draw_circle(_centre(to), cell.x * 0.15, TARGET)
	if _slide_to:
		_draw_piece(game.board.piece_at(_slide_to), _slide_pos - cell / 2, cell)
	if _drag_from:
		_draw_piece(_held_piece, _drag_pos - cell / 2, cell)
	if review_arrow.length() >= 4:
		_draw_annotation(review_arrow.substr(0, 2), review_arrow.substr(2, 2), cell.x)
	if review_icon and review_square.length() == 2:
		var icon_size := cell.x * 0.45
		var at := _corner() + square_position(review_square, _side(), flipped) + Vector2(cell.x - icon_size, 0)
		draw_texture_rect(review_icon, Rect2(at, Vector2.ONE * icon_size), false)
	for drawing in drawings:
		_draw_annotation(drawing[0], drawing[1], cell.x)
	# Redrawing an existing one erases it on release, so don't stack a copy on it meanwhile.
	if _drawing_from and _drawing_to and not PackedStringArray([_drawing_from, _drawing_to]) in drawings:
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
	var font := get_theme_font("font", "BoldText")
	var font_size := maxi(9, roundi(cell * 0.18))
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


func _draw_piece(piece: String, at: Vector2, cell: Vector2, opacity := 1.0) -> void:
	if piece and _textures.get(piece):
		draw_texture_rect(_textures[piece], Rect2(at, cell), false, Color(1, 1, 1, opacity))


# The promotion overlay consumes GUI events, so catch its right click before GUI dispatch.
func _input(event: InputEvent) -> void:
	if _picker.visible and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT and get_global_rect().has_point(event.position):
		cancel_premoves()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		var square := square_at(event.position - _corner(), _side(), flipped)
		if event.pressed:
			# A right click that cancels a queue, a drag or a selection draws nothing.
			var interrupts: bool = not premoves.moves.is_empty() or (_drag_from and not _snapping) \
					or _selected != ""
			if not premoves.moves.is_empty() or _is_premove_input():
				cancel_premoves()
			elif _drag_from or _selected:
				_cancel_interaction()
			_drawing_from = "" if interrupts else square
			_drawing_to = _drawing_from
		else:
			if _drawing_from and square:
				# Drawing the same arrow or circle again erases it.
				var drawing := PackedStringArray([_drawing_from, square])
				if drawing in drawings:
					drawings.erase(drawing)
				else:
					drawings.append(drawing)
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
				if square_at(event.position - _corner(), _side(), flipped) == _drag_from:
					# A second click deselects on release, but can still become a drag.
					_reselected = true
					_press_pos = event.position
					_drag_pos = event.position
					_dragged = false
				else:
					_drop(event.position, true, event.alt_pressed)
			else:
				_pick_up(event.position)
		elif _drag_from and not _snapping:
			var to := square_at(event.position - _corner(), _side(), flipped)
			if click_click and not _dragged and to == _drag_from:
				if _reselected:
					_end_snap_back()
				else:
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


# During Maia's turn only human pieces can be held, on the queued position.
func _pick_up(point: Vector2) -> void:
	if _drag_from or game == null or game.is_over():
		return
	var square := square_at(point - _corner(), _side(), flipped)
	var position = _input_position()
	if position == null:
		return
	var piece: String = position.piece_at(square) if square else ""
	if piece and (piece == piece.to_upper()) == (position.side_to_move == "w"):
		_end_slide()
		_drag_from = square
		_held_piece = piece
		_drag_pos = point
		_press_pos = point
		_dragged = false
		_reselected = false
		for move in (premoves.targets(position, square) if _is_premove_input() else position.legal_moves()):
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
		if PromotionPicker.should_auto_queen(auto_queen, _is_premove_input(), alt):
			_submit(_drag_from + to + "q", clicked)
		else:
			_open_picker(to)
	elif moves:
		_submit(moves[0], clicked)
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
	_picker.open(_textures, _held_piece == "P")
	_layout_picker()


# The pawn and the picker's column sit on the promotion square, also after a flip or resize.
func _layout_picker() -> void:
	if not _promoting:
		return
	var to := _promoting.substr(2, 2)
	_drag_pos = _centre(to)
	var at := square_position(to, _side(), flipped)
	_picker.layout(_corner() + at, _side() / 8, at.y < _side() / 2)


# shortcut: only the moving piece slides, a castling rook jumps; slide it too if it looks wrong.
func _commit(move: String, slide: bool, premove := false) -> void:
	var san: String = game.board.san(move)
	# The game ended (a flag) while the piece was held or the promotion picker was open.
	if not game.play(move):
		_end_snap_back()
		return
	if _promoting or _snapping:
		_cancel_interaction()
	if slide and slide_seconds > 0:
		_end_slide()
		_slide_to = move.substr(2, 2)
		_slide_pos = _centre(move.substr(0, 2))
		_slide = create_tween()
		_slide.tween_property(self, "_slide_pos", _centre(_slide_to), slide_seconds)
		_slide.tween_callback(_end_slide)
	queue_redraw()
	sound_requested.emit("premove" if premove else "castle" if san.begins_with("O-O") else "capture" if "x" in san else "move")
	if "=" in san:
		sound_requested.emit("promote")
	if game.board.in_check():
		sound_requested.emit("check")
	move_played.emit(san)
	# A reply's listeners may also play the due premove before input resumes.
	var held := _drag_from if _drag_from else _selected
	if held:
		var position = _input_position()
		if game.is_over() or position == null or position.piece_at(held) != _held_piece:
			_cancel_interaction()
		else:
			if _drag_from == _slide_to:
				_end_slide()
			_held_moves.clear()
			for target in (premoves.targets(position, held) if _is_premove_input() else position.legal_moves()):
				if target.begins_with(held):
					_held_moves.append(target)


func _end_slide() -> void:
	if _slide:
		_slide.kill()
	_slide_to = ""
	queue_redraw()


func _end_snap_back() -> void:
	_snapping = false
	_reselected = false
	_drag_from = ""
	_selected = ""
	_held_moves.clear()
	_held_piece = ""
	_promoting = ""
	queue_redraw()


func _is_premove_input() -> bool:
	return game != null and human_side != "" and game.board.side_to_move != human_side


func _input_position():
	if _is_premove_input():
		return null if premoves.style == "off" else premoves.input_position(game.board)
	return game.board


func _submit(move: String, slide: bool) -> void:
	if game.is_over():
		_cancel_interaction()
		return
	if _is_premove_input():
		premoves.enqueue(game.board, move)
		_end_snap_back()
	else:
		_commit(move, slide)


func cancel_premoves() -> void:
	premoves.clear()
	_cancel_interaction()


func _cancel_interaction() -> void:
	if _snap:
		_snap.kill()
	if _picker and _picker.visible:
		_picker._close("")
	_end_snap_back()


func _side() -> float:
	return minf(size.x, size.y)


func _corner() -> Vector2:
	return (size - Vector2.ONE * _side()) / 2


func _centre(square: String) -> Vector2:
	return _corner() + square_position(square, _side(), flipped) + Vector2.ONE * _side() / 16


static func _is_light(square: String) -> bool:
	return (square.unicode_at(0) + square.unicode_at(1)) % 2 == 1
