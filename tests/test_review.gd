extends "res://tests/run.gd".Test

const Review = preload("res://ui/review.gd")
const Game = preload("res://core/game.gd")
const MainScene = preload("res://ui/main.tscn")
const History = preload("res://core/history.gd")
const HistoryStorage = preload("res://tests/history_storage.gd")
const Clock = preload("res://core/clock.gd")
const Pgn = preload("res://core/pgn.gd")
const SETTINGS := {"colour": "w", "level": "maia-1500", "control": "3+2", "opening": "Free"}


func test_summary_waits_for_analysis_and_shows_accuracy_and_counts():
	var main = _session(FakeTime.new())
	var review = main.get_node("Review")
	var game = Game.new()
	game.play("e2e4")
	review.present(game, [180000, 180000, 180000], SETTINGS, "")
	var summary = review.get_node_or_null("Margin/Content/ReviewBody/Side/Summary")
	assert_true(summary != null, "summary exists")
	if summary != null:
		assert_true(not summary.visible, "accuracy waits for complete analysis")
		review.receive_position(1, {"pv": [{"cp": 0, "moves": ["e7e5"]}]})
		review.receive_position(0, {"pv": [{"cp": 0, "moves": ["e2e4"]}], "best_move": "e2e4"})
		assert_true(summary.visible)
		assert_true(summary.text.contains("100.0%"), "white accuracy")
		assert_true(summary.text.contains("–"), "black has no moves")
	var counts = review.get_node_or_null("Margin/Content/ReviewBody/Side/Counts")
	assert_true(counts != null, "class table exists")
	if counts != null:
		assert_true(counts.text.contains("Best") and counts.text.contains("1"))
	main.free()


func test_graph_click_navigates_and_tracks_orientation():
	var main = _session(FakeTime.new())
	var review = main.get_node("Review")
	var game = Game.new()
	game.play("e2e4")
	game.play("e7e5")
	review.present(game, [180000, 180000], SETTINGS, "")
	var graph = review.get_node_or_null("Margin/Content/ReviewBody/Side/EvalGraph")
	assert_true(graph != null, "eval graph exists")
	if graph != null:
		graph.size = Vector2(200, 100)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = Vector2(100, 50)
		graph._gui_input(click)
		assert_eq(review.get_node("Margin/Content/ReviewBody/BoardView").game.moves.size(), 1)
		assert_eq(graph.current_ply, 1)
		var flip := InputEventKey.new()
		flip.keycode = KEY_F
		flip.pressed = true
		review._input(flip)
		assert_true(graph.flipped)
	main.free()


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
	main.get_node("Setup").book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	var folder := "user://test_review_%d" % Time.get_ticks_usec()
	main.history = History.new(folder)
	main.tree_exiting.connect(func(): HistoryStorage.clean(folder))
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


func test_checkmate_opens_review_with_result_and_both_sides_moves():
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
	assert_true(not review.visible, "review waits for a request")
	var panel = main.board_view.get_node("GameOver")
	assert_true(panel.visible)
	assert_eq(panel.get_node("Panel/Content/Headline").text, "Black won")
	assert_eq(panel.get_node("Panel/Content/Reason").text, "by checkmate")
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
	assert_true(review.visible, "also opens in focus mode")
	var result: String = review.get_node("Margin/Content/Result").text
	assert_true(result.contains("0-1") and result.contains("checkmate") and result.contains("Black wins"))
	var rows = review.get_node("Margin/Content/ReviewBody/Side/Moves").get_root().get_children()
	assert_eq(rows.size(), 2)
	if rows.size() == 2:
		assert_eq(rows[0].get_text(0), "1.")
		assert_eq(rows[0].get_text(1), "f3")
		assert_eq(rows[0].get_text(2), "e5")
		assert_eq(rows[1].get_text(1), "g4")
		assert_eq(rows[1].get_text(2), "Qh4#")
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
			assert_true(not review.visible, "review waits for a request")
			var panel = main.board_view.get_node("GameOver")
			assert_true(panel.visible)
			assert_eq(panel.get_node("Panel/Content/Headline").text, "Draw" if ending == "repetition" else "Black won")
			assert_eq(panel.get_node("Panel/Content/Reason").text, "by " + ending)
			main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
			assert_true(review.visible, ending)
			assert_true(review.get_node("Margin/Content/Result").text.contains(ending))
			if ending == "resignation":
				assert_eq(review.get_node("Margin/Content/ReviewBody/Side/Moves").get_root().get_child_count(), 0)
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
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
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
				"Result": "0-1", "Termination": "Normal", "Reason": "checkmate"})
		assert_eq(parsed.games[0].moves.map(func(move): return move.uci), ["f2f3", "e7e5", "g2g4", "d8h4"])
		assert_eq(parsed.games[0].moves.map(func(move): return move.clock_ms), [180000, 180000, 181750, 181000])
		assert_eq(parsed.games[0].result, "0-1")
	assert_eq(sent.url, "https://lichess.org/analysis/pgn/1.%20f3%20e5%202.%20g4%20Qh4%23%200-1")
	main.free()


func test_space_with_review_focused_rematches_and_replaces_the_previous_game():
	var time := FakeTime.new()
	var main = _session(time)
	main.board_view.play("e2e4")
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
	var review = main.get_node("Review")
	review.get_node("Margin/Content/ReviewBody/Side/Moves").grab_focus()
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	Engine.get_main_loop().root.push_input(event)
	assert_true(not review.visible, "Space works with the move list focused")
	assert_true(not main.setup.visible)
	assert_eq(main.settings, {"colour": "b", "level": "maia-1500", "control": "3+2", "opening": "Free"})
	assert_eq(main.board_view.game.moves, PackedStringArray())
	main._on_maia_move("d2d4")
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
	assert_true(review.visible)
	var rows = review.get_node("Margin/Content/ReviewBody/Side/Moves").get_root().get_children()
	assert_eq(rows.size(), 1)
	if rows.size() == 1:
		assert_eq(rows[0].get_text(1), "d4", "no moves or times from the previous game")
		assert_eq(rows[0].get_text(2), "")
	var sent := {"pgn": ""}
	review.copy_text = func(text: String): sent.pgn = text
	review.get_node("Margin/Content/Actions/CopyPgn").pressed.emit()
	var parsed := Pgn.parse(sent.pgn)
	assert_eq(parsed.error, "")
	if parsed.games.size() == 1:
		assert_eq(parsed.games[0].headers.White, "Maia 1500")
		assert_eq(parsed.games[0].result, "1-0")
		assert_eq(parsed.games[0].moves.map(func(move): return move.uci), ["d2d4"])
	else:
		assert_eq(parsed.games.size(), 1)
	main.free()


func test_review_returns_to_setup_and_starts_a_fresh_game():
	var time := FakeTime.new()
	var main = _session(time)
	_key(main, KEY_F11)
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
	var review = main.get_node("Review")
	var back = review.get_node_or_null("Margin/Content/Actions/Setup")
	assert_true(back != null, "review provides a return to setup")
	if back == null:
		main.free()
		return
	back.pressed.emit()
	assert_true(main.setup.visible)
	assert_true(not review.visible)
	assert_true(main.clock == null, "setup has no active game")
	_key(main, KEY_SPACE)
	assert_true(main.setup.visible, "Space on setup does not silently start a rematch")
	var next := SETTINGS.duplicate()
	next.control = "1+0"
	main.setup.started.emit(next)
	assert_true(not main.setup.visible and not review.visible)
	assert_eq(main.clock.left("w"), 60000)
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
	assert_true(review.visible)
	assert_eq(review.get_node("Margin/Content/ReviewBody/Side/Moves").get_root().get_child_count(), 0)
	main.free()

func test_review_steps_through_game_with_arrow_keys():
	var time := FakeTime.new()
	var main = _session(time)
	main.board_view.play("e2e4")
	main._on_maia_move("e7e5")
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
	var review = main.get_node("Review")
	var board = review.get_node_or_null("Margin/Content/ReviewBody/BoardView")
	assert_true(board != null, "review has its own board")
	if board != null:
		var event := InputEventKey.new()
		event.pressed = true
		event.keycode = KEY_LEFT
		review._input(event)
		assert_eq(board.game.moves, PackedStringArray(["e2e4"]))
		event.keycode = KEY_RIGHT
		review._input(event)
		assert_eq(board.game.moves, PackedStringArray(["e2e4", "e7e5"]))
	main.free()

func test_clicking_a_move_shows_its_position():
	var time := FakeTime.new()
	var main = _session(time)
	main.board_view.play("e2e4")
	main._on_maia_move("e7e5")
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
	var review = main.get_node("Review")
	var list: Tree = review.get_node("Margin/Content/ReviewBody/Side/Moves")
	var row: TreeItem = list.get_root().get_first_child()
	row.select(1)
	list.item_selected.emit()
	var board = review.get_node("Margin/Content/ReviewBody/BoardView")
	assert_eq(board.game.moves, PackedStringArray(["e2e4"]))
	main.free()


func test_eval_bar_tracks_current_position_and_board_orientation():
	var main = _session(FakeTime.new())
	main.board_view.play("e2e4")
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
	var review = main.review
	var bar = review.get_node_or_null("Margin/Content/ReviewBody/EvalBar")
	assert_true(bar != null, "evaluation bar sits beside board")
	if bar != null:
		review.receive_position(1, {"pv": [{"cp": -200, "moves": ["e7e5"]}]})
		assert_true(bar.white_fraction > 0.5, "black-to-move negative score favours white")
		assert_true(not bar.flipped)
		review.get_node("Margin/Content/ReviewBody/BoardView").flipped = true
		review.receive_position(1, {"pv": [{"cp": -200, "moves": ["e7e5"]}]})
		assert_true(bar.flipped, "bar follows the board orientation")
	main.free()


func test_analysis_landing_shows_class_icon_and_best_move_on_board():
	var main = _session(FakeTime.new())
	main.board_view.play("e2e4")
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
	var review = main.review
	var list: Tree = review.get_node("Margin/Content/ReviewBody/Side/Moves")
	var row: TreeItem = list.get_root().get_first_child()
	assert_true(row.get_icon(1) == null, "unanalysed move has no class")
	review.receive_position(1, {"pv": [{"cp": -20, "moves": ["e7e5"]}], "best_move": "e7e5"})
	assert_true(row.get_icon(1) == null, "both positions must land")
	review.receive_position(0, {"pv": [{"cp": 20, "moves": ["e2e4"]}], "best_move": "e2e4"})
	assert_true(row.get_icon(1) != null, "settled move has its class icon")
	var board = review.get_node("Margin/Content/ReviewBody/BoardView")
	assert_eq(board.review_square, "e4")
	assert_eq(board.review_arrow, "e2e4")
	assert_true(board.review_icon != null)
	main.free()


class FakeAnalysisBridge extends Node:
	signal stopped
	var engine_id := "Stockfish 19"
	var error := ""
	func start() -> bool:
		return true


class FakeReviewAnalyser extends Node:
	signal position_ready(index: int, position: Dictionary)
	signal progress(done: int, total: int)
	signal finished(success: bool, error: String)
	var called := false
	var maximum := false
	var fens := []
	func analyse(positions: Array, _path: String, max_threads: bool, _draw: bool) -> bool:
		called = true
		maximum = max_threads
		fens = positions
		return true
	func cancel() -> void:
		pass


func test_open_review_starts_max_analysis_and_tracks_progress():
	var main = _session(FakeTime.new())
	var fake = FakeReviewAnalyser.new()
	main.review.analysis_bridge_factory = func(): return FakeAnalysisBridge.new()
	main.review.analyser_factory = func(_bridge): return fake
	main.board_view.play("e2e4")
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
	assert_true(fake.called and fake.maximum, "review requests Max analysis")
	assert_eq(fake.fens.size(), 2)
	var progress = main.review.get_node_or_null("Margin/Content/Progress")
	assert_true(progress != null and progress.visible)
	if progress != null:
		fake.progress.emit(1, 2)
		assert_eq(progress.value, 50.0)
		fake.finished.emit(true, "")
		assert_true(not progress.visible)
	main.free()


func test_review_places_move_list_beside_board():
	var main = _session(FakeTime.new())
	main.board_view.play("e2e4")
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
	var body = main.review.get_node("Margin/Content/ReviewBody")
	assert_true(body.has_node("BoardView") and body.has_node("Side/Moves"), "board and list share the review body")
	if body.has_node("Side/Moves"):
		assert_eq(body.get_node("Side/Moves").columns, 3)
	main.free()


func test_review_reuses_current_analysis_and_reanalyses_stale_file():
	for version in ["Stockfish 19", "Stockfish 18"]:
		var main = _session(FakeTime.new())
		var fake = FakeReviewAnalyser.new()
		main.review.analysis_bridge_factory = func(): return FakeAnalysisBridge.new()
		main.review.analyser_factory = func(_bridge): return fake
		main.board_view.play("e2e4")
		_key(main, KEY_ESCAPE)
		_key(main, KEY_ESCAPE)
		var path := "user://rev005-cache-%d.json" % Time.get_ticks_usec()
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"engine_version": version, "node_budget": 3000000, "positions": [
			{"fen": Pgn.START, "pv": [{"cp": 20, "moves": ["e2e4"]}], "best_move": "e2e4"},
			{"fen": main.board_view.game.board.to_fen(), "pv": [{"cp": -20, "moves": ["e7e5"]}], "best_move": "e7e5"}]}))
		file.close()
		main.review_analysis_path = path
		main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
		assert_eq(fake.called, version != "Stockfish 19", "only stale analysis is rerun")
		if version == "Stockfish 19":
			var list: Tree = main.review.get_node("Margin/Content/ReviewBody/Side/Moves")
			assert_true(list.get_root().get_first_child().get_icon(1) != null, "cached class is shown")
			var board = main.review.get_node("Margin/Content/ReviewBody/BoardView")
			var bar = main.review.get_node("Margin/Content/ReviewBody/EvalBar")
			list.grab_focus()
			for flipped in [true, false]:
				var event := InputEventKey.new()
				event.keycode = KEY_F
				event.pressed = true
				Engine.get_main_loop().root.push_input(event)
				assert_eq(board.flipped, flipped, "F flips the visible review board")
				assert_eq(bar.flipped, flipped, "evaluation bar follows immediately")
				assert_true(not main.board_view.flipped, "hidden game board is unchanged")
			fake.free()
		main.free()
		DirAccess.remove_absolute(path)


func test_review_fits_an_800_by_600_window():
	var root = Engine.get_main_loop().root
	var old_size: Vector2i = root.size
	root.size = Vector2i(800, 600)
	var main = _session(FakeTime.new())
	main.board_view.play("e2e4")
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	for path in ["Margin/Content/ReviewBody/BoardView", "Margin/Content/ReviewBody/Side/Moves", "Margin/Content/Actions/Setup"]:
		var rect: Rect2 = main.review.get_node(path).get_global_rect()
		assert_true(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= 800 and rect.end.y <= 600, path + " fits the window")
		assert_true(rect.size.x > 0 and rect.size.y > 0, path + " is visible")
	main.free()
	root.size = old_size
