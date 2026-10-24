extends Control

# Two humans, one window (UI-001): the board, the move list and the result.

const Game = preload("res://core/game.gd")

# Lichess order and values (§8.4).
const VALUES := {"q": 9, "r": 5, "b": 3, "n": 3, "p": 1}
# Role -> glyph of a captured piece of each colour.
const WHITE_GLYPHS := {"q": "♕", "r": "♖", "b": "♗", "n": "♘", "p": "♙"}
const BLACK_GLYPHS := {"q": "♛", "r": "♜", "b": "♝", "n": "♞", "p": "♟"}

@onready var board_view = $Layout/BoardView
@onready var move_list = $Layout/Side/MoveList
@onready var result_label: Label = $Layout/Side/Result
@onready var white_material: Label = $Layout/Side/WhiteMaterial
@onready var black_material: Label = $Layout/Side/BlackMaterial


# Per role, the side with more of it shows the surplus as captured: "w" and "b" hold those roles,
# queen first. "diff" is white's points minus black's, so a promotion counts the new piece, not the pawn.
static func material_balance(board) -> Dictionary:
	var balance := {"diff": 0, "w": "", "b": ""}
	for role in VALUES:
		var surplus: int = board.squares.count(role.to_upper()) - board.squares.count(role)
		balance.diff += surplus * VALUES[role]
		balance["w" if surplus > 0 else "b"] += role.repeat(absi(surplus))
	return balance


func _ready() -> void:
	get_window().min_size = Vector2i(800, 600)
	board_view.game = Game.new()
	board_view.move_played.connect(_on_move_played)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event.keycode == KEY_F:
		board_view.flipped = not board_view.flipped
		# Each side's material sits on that side's edge of the board.
		white_material.get_parent().move_child(white_material, 0 if board_view.flipped else -1)
		black_material.get_parent().move_child(black_material, -1 if board_view.flipped else 0)


func _on_move_played(san: String) -> void:
	move_list.add(san)
	if board_view.game.is_over():
		result_label.text = "%s, %s" % [board_view.game.result, board_view.game.reason]
	var balance := material_balance(board_view.game.board)
	white_material.text = _captured(balance.w, BLACK_GLYPHS) + _lead(balance.diff)
	black_material.text = _captured(balance.b, WHITE_GLYPHS) + _lead(-balance.diff)


static func _captured(roles: String, glyphs: Dictionary) -> String:
	var text := ""
	for role in roles:
		text += glyphs[role]
	return text


static func _lead(points: int) -> String:
	return " +%d" % points if points > 0 else ""
