extends "res://tests/run.gd".Test

# The board's pixel <-> square mapping, both orientations, at two board sizes (UI-001).
# Points are measured from the board's top-left corner; `flipped` puts black at the bottom.

const BoardView = preload("res://ui/board_view.gd")


func test_point_to_square_with_white_at_the_bottom():
	assert_eq(BoardView.square_at(Vector2(0, 0), 800, false), "a8")
	assert_eq(BoardView.square_at(Vector2(799, 799), 800, false), "h1")
	assert_eq(BoardView.square_at(Vector2(350, 450), 800, false), "d4")
	assert_eq(BoardView.square_at(Vector2(130, 70), 480, false), "c7")
	assert_eq(BoardView.square_at(Vector2(479.5, 0), 480, false), "h8")


func test_point_to_square_with_black_at_the_bottom():
	assert_eq(BoardView.square_at(Vector2(0, 0), 800, true), "h1")
	assert_eq(BoardView.square_at(Vector2(799, 799), 800, true), "a8")
	assert_eq(BoardView.square_at(Vector2(350, 450), 800, true), "e5")
	assert_eq(BoardView.square_at(Vector2(130, 70), 480, true), "f2")


func test_points_off_the_board_name_no_square():
	for flipped in [false, true]:
		assert_eq(BoardView.square_at(Vector2(800, 10), 800, flipped), "", "right edge")
		assert_eq(BoardView.square_at(Vector2(10, 800), 800, flipped), "", "bottom edge")
		assert_eq(BoardView.square_at(Vector2(-1, 10), 800, flipped), "", "left of the board")
		assert_eq(BoardView.square_at(Vector2(10, -0.5), 800, flipped), "", "above the board")


func test_square_to_top_left_corner():
	assert_eq(BoardView.square_position("a1", 800, false), Vector2(0, 700))
	assert_eq(BoardView.square_position("h8", 800, false), Vector2(700, 0))
	assert_eq(BoardView.square_position("e2", 480, false), Vector2(240, 360))
	assert_eq(BoardView.square_position("a1", 800, true), Vector2(700, 0))
	assert_eq(BoardView.square_position("h8", 800, true), Vector2(0, 700))
	assert_eq(BoardView.square_position("e2", 480, true), Vector2(180, 60))


func test_every_square_centre_maps_back_to_its_square():
	for side in [800.0, 480.0]:
		for flipped in [false, true]:
			for i in 64:
				var square: String = "abcdefgh"[i % 8] + str(i / 8 + 1)
				var centre: Vector2 = BoardView.square_position(square, side, flipped) + Vector2.ONE * side / 16
				assert_eq(BoardView.square_at(centre, side, flipped), square, "%s %d %s" % [square, side, flipped])
