extends "res://tests/run.gd".Test

const Review = preload("res://ui/review.gd")
const Game = preload("res://core/game.gd")
const MainScene = preload("res://ui/main.tscn")
const History = preload("res://core/history.gd")
const Clock = preload("res://core/clock.gd")
const Pgn = preload("res://core/pgn.gd")
const SETTINGS := {"colour": "w", "level": "maia-1500", "control": "3+2", "opening": "Free"}


class FakeTime:
	var now := 0

	func ms() -> int:
		return now


class HeldEngine extends "res://engine/uci.gd":
	func start(_dirs := PackedStringArray()) -> bool:
		return true

	func set_level(_net_path: String) -> void:
		pass

	func request_policy(_fen: String, _moves: PackedStringArray) -> void:
		pass


func _session(time: FakeTime):
	var main = MainScene.instantiate()
	var folder := "user://test_review_%d" % Time.get_ticks_usec()
	main.history = History.new(folder)
	main.tree_exiting.connect(func():
		for subdir in [folder.path_join("games"), folder]:
			if DirAccess.dir_exists_absolute(subdir):
				for file in DirAccess.get_files_at(subdir):
					DirAccess.remove_absolute(subdir.path_join(file))
				DirAccess.remove_absolute(subdir))
	main.uci.free()
	main.uci = HeldEngine.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new("res://tests/fixtures/no_review_settings.cfg")
	Engine.get_main_loop().root.add_child(main)
	main.board_view.slide_seconds = 0
	main.sound_player.select_theme("__review_silent__")
	main._start(SETTINGS.duplicate())
	main.clock = Clock.new(SETTINGS.control, time.ms)
	main.clock.flagged.connect(main._on_flagged)
	main.maia.clock = main.clock
	main.white_clock.clock = main.clock
	main.black_clock.clock = main.clock
	return main


func _key(main, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	main._unhandled_key_input(event)


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


func test_checkmate_opens_review_with_result_reason_and_both_sides_times():
	var time := FakeTime.new()
	var main = _session(time)
	var review = main.get_node_or_null("Review")
	assert_true(review != null, "Main includes the review screen")
	if review == null:
		main.free()
		return
	assert_true(not review.visible, "hidden during play")
	_key(main, KEY_F11)
	main.board_view.play("f2f3")
	main._on_maia_move("e7e5")
	time.now = 250
	main.board_view.play("g2g4")
	time.now = 1250
	main._on_maia_move("d8h4")
	assert_true(review.visible, "also opens in focus mode")
	var result: String = review.get_node("Margin/Content/Result").text
	assert_true(result.contains("0-1") and result.contains("checkmate") and result.contains("Black wins"))
	var rows = review.get_node("Margin/Content/Moves").get_root().get_children()
	assert_eq(rows.size(), 2)
	if rows.size() == 2:
		assert_eq(rows[0].get_text(0), "1.")
		assert_eq(rows[0].get_text(1), "f3 (0.000 s)")
		assert_eq(rows[0].get_text(2), "e5 (0.000 s)")
		assert_eq(rows[1].get_text(1), "g4 (0.250 s)")
		assert_eq(rows[1].get_text(2), "Qh4# (1.000 s)")
	main.free()


func test_review_opens_for_no_move_resignation_flag_and_claimed_draw():
	for ending in ["resignation", "time", "repetition"]:
		var time := FakeTime.new()
		var main = _session(time)
		if ending == "resignation":
			_key(main, KEY_ESCAPE)
			_key(main, KEY_ESCAPE)
		elif ending == "time":
			main.board_view.play("e2e4")
			main._on_maia_move("e7e5")
			time.now = 180000
			main._process(0)
		else:
			main.board_view.game.auto_claim = false
			for move in ["g1f3", "g8f6", "f3g1", "f6g8", "g1f3", "g8f6", "f3g1", "f6g8"]:
				main.board_view.play(move)
			main.claim_draw.pressed.emit()
		var review = main.get_node_or_null("Review")
		assert_true(review != null, "review for " + ending)
		if review != null:
			assert_true(review.visible, ending)
			assert_true(review.get_node("Margin/Content/Result").text.contains(ending))
			if ending == "resignation":
				assert_eq(review.get_node("Margin/Content/Moves").get_root().get_child_count(), 0)
		main.free()


func test_export_buttons_send_finished_pgn_and_lichess_url():
	var time := FakeTime.new()
	var main = _session(time)
	main.board_view.play("f2f3")
	main._on_maia_move("e7e5")
	time.now = 250
	main.board_view.play("g2g4")
	time.now = 1250
	main._on_maia_move("d8h4")
	var review = main.get_node("Review")
	var copy = review.get_node_or_null("Margin/Content/Actions/CopyPgn")
	var lichess = review.get_node_or_null("Margin/Content/Actions/Lichess")
	assert_true(copy != null and lichess != null, "review provides both export actions")
	if copy == null or lichess == null:
		main.free()
		return
	var sent := {"pgn": "", "url": ""}
	review.copy_text = func(text: String): sent.pgn = text
	review.open_browser = func(url: String): sent.url = url
	copy.pressed.emit()
	lichess.pressed.emit()
	var parsed := Pgn.parse(sent.pgn)
	assert_eq(parsed.error, "")
	assert_eq(parsed.games.size(), 1)
	if parsed.games.size() == 1:
		assert_eq(parsed.games[0].headers, {"White": "You", "Black": "Maia 1500", "TimeControl": "180+2",
				"Result": "0-1", "Termination": "Normal"})
		assert_eq(parsed.games[0].moves.map(func(move): return move.uci), ["f2f3", "e7e5", "g2g4", "d8h4"])
		assert_eq(parsed.games[0].moves.map(func(move): return move.clock_ms), [180000, 180000, 181750, 181000])
		assert_eq(parsed.games[0].result, "0-1")
	assert_eq(sent.url, "https://lichess.org/analysis/pgn/1.%20f3%20e5%202.%20g4%20Qh4%23%200-1")
	main.free()
