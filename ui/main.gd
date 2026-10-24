extends Control

# Two humans, one window (UI-001): the board, the move list and the result.

const Game = preload("res://core/game.gd")

@onready var board_view = $Layout/BoardView
@onready var move_list = $Layout/Side/MoveList
@onready var result_label: Label = $Layout/Side/Result


func _ready() -> void:
	get_window().min_size = Vector2i(800, 600)
	board_view.game = Game.new()
	board_view.move_played.connect(_on_move_played)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event.keycode == KEY_F:
		board_view.flipped = not board_view.flipped


func _on_move_played(san: String) -> void:
	move_list.add(san)
	if board_view.game.is_over():
		result_label.text = "%s, %s" % [board_view.game.result, board_view.game.reason]
