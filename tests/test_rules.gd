extends "res://tests/run.gd".Test

# Every way a game ends under Lichess behaviour, §7, with its PGN result and reason (CORE-004).

const Game = preload("res://core/game.gd")

# Knights out and back: the start position again every four plies.
const SHUFFLE := "g1f3 g8f6 f3g1 f6g8"


# Space-separated UCI moves; fails the test on the first one the game refuses.
func _play(game, moves: String) -> void:
	for move in moves.split(" "):
		assert_true(game.play(move), "refused " + move)


func _assert_end(game, result: String, reason: String, message := "") -> void:
	assert_eq([game.result, game.reason], [result, reason], message)


func test_checkmate_wins_and_stalemate_draws():
	var fools = Game.new()
	_play(fools, "f2f3 e7e5 g2g4 d8h4")
	_assert_end(fools, "0-1", "checkmate", "fool's mate")
	var scholars = Game.new()
	_play(scholars, "e2e4 e7e5 f1c4 b8c6 d1h5 g8f6 h5f7")
	_assert_end(scholars, "1-0", "checkmate", "scholar's mate")
	var stalemate = Game.new("7k/8/6K1/8/8/8/5Q2/8 w - - 0 1")
	assert_eq(stalemate.is_over(), false, "before Qf7")
	_play(stalemate, "f2f7")
	_assert_end(stalemate, "1/2-1/2", "stalemate")


func test_fifty_move_rule_draws_at_100_plies_unless_the_move_mates():
	var game = Game.new("4k3/8/8/8/8/8/R7/4K3 w - - 99 80")
	assert_eq(game.is_over(), false, "at 99 plies")
	_play(game, "a2a3")
	_assert_end(game, "1/2-1/2", "50-move")
	var mate = Game.new("k7/8/1K6/8/8/8/8/7R w - - 99 80")
	_play(mate, "h1h8")
	_assert_end(mate, "1-0", "checkmate", "mate on the 100th ply")


func test_fivefold_repetition_draws_automatically():
	var game = Game.new()
	game.auto_claim = false
	for i in 3:
		_play(game, SHUFFLE)
	_play(game, "g1f3 g8f6 f3g1")
	assert_eq(game.is_over(), false, "start position seen four times")
	_play(game, "f6g8")
	_assert_end(game, "1/2-1/2", "repetition")


func test_threefold_repetition_is_a_claim_unless_auto_claim_is_on():
	var game = Game.new()
	game.auto_claim = false
	_play(game, SHUFFLE)
	game.claim_draw()
	assert_eq(game.is_over(), false, "claimed with the start position seen twice")
	_play(game, "g1f3 g8f6 f3g1")
	assert_eq(game.can_claim_draw(), false, "position seen twice")
	_play(game, "f6g8")
	assert_eq(game.can_claim_draw(), true, "start position seen three times")
	assert_eq(game.is_over(), false, "a claim is not automatic")
	game.claim_draw()
	_assert_end(game, "1/2-1/2", "repetition")

	var auto = Game.new()
	auto.auto_claim = true
	_play(auto, SHUFFLE + " g1f3 g8f6 f3g1")
	assert_eq(auto.is_over(), false, "auto-claim, position seen twice")
	_play(auto, "f6g8")
	_assert_end(auto, "1/2-1/2", "repetition", "auto-claim")


func test_insufficient_material_draws_automatically():
	var drawn := {
		"4k3/8/8/8/8/8/8/4K3 w - - 0 1": "K vs K",
		"4k3/8/8/8/8/8/8/2B1K3 w - - 0 1": "K+B vs K",
		"4k3/8/8/8/8/8/8/1N2K3 w - - 0 1": "K+N vs K",
		"4kb2/8/8/8/8/8/8/2B1K3 w - - 0 1": "K+B vs K+B, both on dark squares",
		"4k3/8/8/8/8/4B3/8/2B1K3 w - - 0 1": "K+2B vs K, both on dark squares",
	}
	for fen in drawn:
		_assert_end(Game.new(fen), "1/2-1/2", "insufficient material", drawn[fen])
	var playable := {
		"2b1k3/8/8/8/8/8/8/2B1K3 w - - 0 1": "K+B vs K+B on opposite colours",
		"1n2k3/8/8/8/8/8/8/1N2K3 w - - 0 1": "K+N vs K+N",
		"4k3/8/8/8/8/8/8/1N2KN2 w - - 0 1": "K+2N vs K",
	}
	for fen in playable:
		assert_eq(Game.new(fen).is_over(), false, playable[fen])
	var capture = Game.new("4k3/8/8/8/8/8/4q3/4K3 w - - 0 1")
	_play(capture, "e1e2")
	_assert_end(capture, "1/2-1/2", "insufficient material", "Kxe2 leaves K vs K")


func test_flag_loses_unless_the_opponent_cannot_mate():
	var start = Game.new()
	start.flag("w")
	_assert_end(start, "0-1", "time", "white flags at the start")
	# [FEN, side that flags]: result
	var cases := {
		["r3k3/8/8/8/8/8/8/4K1N1 w - - 0 1", "b"]: "1-0",  # K+N vs K+R, the rook side flags: the knight side wins
		["4k3/8/8/8/8/8/8/R3K3 w - - 0 1", "w"]: "1/2-1/2",  # the other side has a lone king
		["3qk3/8/8/8/8/8/8/4K1N1 w - - 0 1", "b"]: "1/2-1/2",  # K+N vs K+Q, the queen side flags
	}
	for fen_and_side in cases:
		var game = Game.new(fen_and_side[0])
		game.flag(fen_and_side[1])
		_assert_end(game, cases[fen_and_side], "time", fen_and_side[0])


func test_resignation_ends_the_game_for_the_other_side():
	var white_resigns = Game.new()
	white_resigns.resign("w")
	_assert_end(white_resigns, "0-1", "resignation")
	var black_resigns = Game.new()
	_play(black_resigns, "e2e4")
	black_resigns.resign("b")
	_assert_end(black_resigns, "1-0", "resignation")
	assert_eq(Game.new().has_method("abort"), false, "there is no abort")


# play() is where outside input (the UI, an engine) meets the board, which does not check legality.
func test_play_records_legal_moves_and_refuses_the_rest():
	var game = Game.new()
	_play(game, "e2e4 e7e5")
	assert_eq(game.play("e4e5"), false, "blocked pawn")
	assert_eq(game.moves, PackedStringArray(["e2e4", "e7e5"]))
	game.resign("w")
	assert_eq(game.play("g1f3"), false, "after the game ended")
	game.flag("b")
	_assert_end(game, "0-1", "resignation", "a flag after the end changes nothing")
	assert_eq(game.moves, PackedStringArray(["e2e4", "e7e5"]))


func test_draw_by_agreement_ends_only_a_running_game():
	var game = Game.new()
	game.agree_draw()
	_assert_end(game, "1/2-1/2", "agreement")
	var finished = Game.new()
	finished.resign("w")
	finished.agree_draw()
	_assert_end(finished, "0-1", "resignation", "agreement cannot replace a result")
