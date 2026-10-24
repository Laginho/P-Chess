extends "res://tests/run.gd".Test

# The material counter (UI-002, §8.4): per-role surplus of each side and the +N difference,
# pawn 1, minor 3, rook 5, queen 9. `diff` is white minus black.

const Main = preload("res://ui/main.gd")
const Game = preload("res://core/game.gd")


func test_start_position_is_level():
	assert_eq(Main.material_balance(Game.new().board), {"diff": 0, "w": "", "b": ""})


func test_a_pawn_up_then_level_after_the_recapture():
	var game = Game.new()
	for move in ["e2e4", "d7d5", "e4d5"]:
		game.play(move)
	assert_eq(Main.material_balance(game.board), {"diff": 1, "w": "p", "b": ""}, "after exd5")
	game.play("d8d5")
	assert_eq(Main.material_balance(game.board), {"diff": 0, "w": "", "b": ""}, "after Qxd5")


func test_black_ahead_counts_negative():
	# Black has won a knight and a pawn; white has won a bishop.
	var game = Game.new("rn1qkbnr/pppppppp/8/8/8/8/PPPPPPP1/R1BQKBNR w KQkq - 0 1")
	assert_eq(Main.material_balance(game.board), {"diff": -1, "w": "b", "b": "np"})


func test_promotion_trades_the_pawn_for_the_new_piece():
	var game = Game.new("k7/4P3/8/8/8/8/8/K7 w - - 0 1")
	assert_eq(Main.material_balance(game.board), {"diff": 1, "w": "p", "b": ""}, "before")
	game.play("e7e8q")
	assert_eq(Main.material_balance(game.board), {"diff": 9, "w": "q", "b": ""}, "queen")
	var under = Game.new("k7/4P3/8/8/8/8/8/K7 w - - 0 1")
	under.play("e7e8n")
	assert_eq(Main.material_balance(under.board), {"diff": 3, "w": "n", "b": ""}, "knight")


func test_promotion_against_a_full_black_army():
	# White promoted its h-pawn: one queen up, one pawn down.
	var game = Game.new("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPP1/RNBQKBNQ w Qkq - 0 1")
	assert_eq(Main.material_balance(game.board), {"diff": 3, "w": "q", "b": "rp"})
