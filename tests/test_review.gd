extends "res://tests/run.gd".Test

const Review = preload("res://ui/review.gd")
const Game = preload("res://core/game.gd")


func test_move_times_reconstruct_both_sides_with_increment():
	# White spent 2.466 s, Black 0.999 s, then White 0.100 s.
	var clocks := [180000, 180000, 179534, 181001, 181434]
	assert_eq(Review.move_times(clocks, "3+2"), [0, 0, 2466, 999, 100])
	assert_eq(clocks, [180000, 180000, 179534, 181001, 181434], "input is unchanged")


func test_move_times_preserve_first_premove_cost_and_missing_flag_increment():
	assert_eq(Review.move_times([180000, 179900, 182000, 181800], "3+2"), [0, 100, 0, 100])
	# The clock awards no increment at zero, including a mating move that retains its result.
	assert_eq(Review.move_times([180000, 180000, 0], "3+2"), [0, 0, 180000])
	assert_eq(Review.move_times([180000, 180000, 181750, 0], "3+2"), [0, 0, 250, 180000])


func test_move_times_handle_empty_and_zero_increment_games():
	assert_eq(Review.move_times([], "3+2"), [])
	assert_eq(Review.move_times([60000, 60000, 58750, 55000], "1+0"), [0, 0, 1250, 5000])
	assert_eq(Review.move_times([300000], "5+0"), [0])


func test_lichess_url_encodes_san_moves_and_mate():
	var game = Game.new()
	for move in ["f2f3", "e7e5", "g2g4", "d8h4"]:
		assert_true(game.play(move))
	assert_eq(Review.lichess_url(game),
			"https://lichess.org/analysis/pgn/1.%20f3%20e5%202.%20g4%20Qh4%23%200-1")
	var empty = Game.new()
	empty.resign("w")
	assert_eq(Review.lichess_url(empty), "https://lichess.org/analysis/pgn/0-1")
