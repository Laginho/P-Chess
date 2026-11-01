extends "res://tests/run.gd".Test

const Review = preload("res://ui/review.gd")
const Game = preload("res://core/game.gd")
const MainScene = preload("res://ui/main.tscn")
const History = preload("res://core/history.gd")
const HistoryStorage = preload("res://tests/history_storage.gd")
const Clock = preload("res://core/clock.gd")
const Pgn = preload("res://core/pgn.gd")
const Tunables = preload("res://core/tunables.gd")
const SETTINGS := {"colour": "w", "level": "maia-1500", "control": "3+2", "opening": "Free"}


func test_unanalysed_history_explains_state_and_hides_analysis_summary():
	var main = await _session(FakeTime.new())
	var review = main.get_node("Review")
	var game = Game.new()
	game.play("e2e4")
	review.present(game, [180000], SETTINGS, "")
	review.present_history("user://ui026-missing-game.pgn", "user://ui026-missing-analysis.json", false)
	var side = review.get_node("Margin/Content/ReviewBody/Side")
	var notice = side.get_node_or_null("UnanalysedNotice")
	assert_true(notice != null and notice.visible and notice.text.contains("hasn’t been analysed yet"), "unanalysed explanation is visible")
	assert_true(side.get_node("Analyze").visible, "analysis can be started")
	var description = notice.get_node_or_null("AnalysisDescription") if notice != null else null
	assert_true(description != null and description.text.contains("Stockfish"), "the card explains what analysis adds")
	assert_true(not side.get_node("Counts").visible and not side.get_node("EvalGraph").visible, "empty analysis summary is hidden")
	main.free()


func test_eval_bar_shows_white_perspective_score_for_current_position():
	var main = await _session(FakeTime.new())
	var review = main.get_node("Review")
	var game = Game.new()
	game.play("e2e4")
	review.present(game, [180000], SETTINGS, "")
	var bar = review.get_node("Margin/Content/ReviewBody/EvalBar")
	var score = bar.get_node_or_null("Score")
	assert_true(score != null, "evaluation score is visible on the bar")
	if score != null:
		assert_eq(score.text, "", "unknown position has no score")
		review.receive_position(1, {"pv": [{"cp": -120, "moves": ["e7e5"]}]})
		assert_eq(score.text, "+1.2", "black-to-move evaluation is converted to white's perspective")
		review.get_node("Margin/Content/ReviewBody/Side/Navigation/First").pressed.emit()
		assert_eq(score.text, "", "navigating to an unknown position clears the score")
	main.free()


func test_summary_waits_for_analysis_and_shows_accuracy_and_counts():
	var main = await _session(FakeTime.new())
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
		var white_card = summary.get_node_or_null("AccuracyCards/WhiteScore/Value")
		assert_true(white_card != null and white_card.text == "100.0%", "white accuracy appears in its card")
		assert_true(summary.text.contains("–"), "black has no moves")
	var counts = review.get_node_or_null("Margin/Content/ReviewBody/Side/Counts")
	assert_true(counts != null, "class table exists")
	if counts != null:
		assert_eq(counts.get_node("BestWhite").text, "1")
		assert_true(counts.get_node("BestIcon").texture != null, "class icon is shown between the counts")
	main.free()


func test_graph_click_navigates_and_tracks_orientation():
	var main = await _session(FakeTime.new())
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


func test_review_help_explains_accuracy_and_class_thresholds():
	var main = await _session(FakeTime.new())
	var review = main.get_node("Review")
	var accuracy_help = review.get_node_or_null("Margin/Content/ReviewBody/Side/AccuracyHelp")
	var class_help = review.get_node_or_null("Margin/Content/ReviewBody/Side/ClassHelp")
	assert_true(accuracy_help != null and class_help != null, "both help controls exist")
	if accuracy_help != null and class_help != null:
		assert_true(accuracy_help.tooltip_text.contains("win"))
		class_help.pressed.emit()
		var legend = review.get_node_or_null("ClassLegend")
		assert_true(legend != null and legend.get_node("Content/LegendRows").get_child(3).get_child(1).get_child(1).text.contains("2%") and legend.get_node("Content/LegendRows").get_child(10).get_child(1).get_child(1).text.contains("20%"), "legend gives class thresholds")
		if legend != null:
			var rows = legend.get_node_or_null("Content/LegendRows")
			assert_true(rows != null and rows.get_child_count() == 12, "legend has an icon and description for each class")
	main.free()


func test_fixture_updates_counts_before_final_accuracy():
	var main = await _session(FakeTime.new())
	var review = main.get_node("Review")
	var game = Game.new()
	game.play("e2e4")
	game.play("e7e5")
	review.present(game, [180000, 180000], SETTINGS, "")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/analysis/rev003-opening.json"))
	var side = review.get_node("Margin/Content/ReviewBody/Side")
	review.receive_position(2, fixture.positions[2])
	review.receive_position(1, fixture.positions[1])
	assert_true(not side.get_node("Summary").visible, "accuracy waits for complete analysis")
	assert_eq(side.get_node("Counts/BestWhite").text, "0")
	assert_eq(side.get_node("Counts/BestBlack").text, "1", "black's final class appears while analysis runs")
	review.receive_position(0, fixture.positions[0])
	assert_true(side.get_node("Summary").visible)
	assert_true(side.get_node("Summary").text.contains("100.0%"))
	assert_eq(side.get_node("Counts/BestWhite").text, "1")
	assert_eq(side.get_node("Counts/BestBlack").text, "1")
	main.free()


class FakeTime:
	var now := 0

	func ms() -> int:
		return now


class HeldEngine extends "res://engine/uci.gd":
	func start(_dirs := PackedStringArray()) -> bool:
		return true

	func set_level(_net_path: String) -> void:
		level_ready.emit()

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
	main.preferences = main.Settings.new(folder.path_join("settings.cfg"))
	DirAccess.make_dir_recursive_absolute(folder)
	main.preferences.set_value("player_name", "You")
	Engine.get_main_loop().root.add_child(main)
	main.board_view.slide_seconds = 0
	main.sound_player.select_theme("__review_silent__")
	await main._start(SETTINGS.duplicate())
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
	var main = await _session(time)
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
	assert_eq(panel.get_node("Panel/Content/Headline").text, "You lost")
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
		var main = await _session(time)
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
			assert_eq(panel.get_node("Panel/Content/Headline").text, "Draw" if ending == "repetition" else "You lost")
			assert_eq(panel.get_node("Panel/Content/Reason").text, "on time" if ending == "time" else "by " + ending)
			main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
			assert_true(review.visible, ending)
			assert_true(review.get_node("Margin/Content/Result").text.contains(ending))
			if ending == "resignation":
				assert_eq(review.get_node("Margin/Content/ReviewBody/Side/Moves").get_root().get_child_count(), 0)
		main.free()


func test_export_buttons_send_finished_pgn_and_lichess_url():
	var time := FakeTime.new()
	var main = await _session(time)
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
				"Result": "0-1", "Termination": "Normal", "Reason": "checkmate", "HumanColor": "w"})
		assert_eq(parsed.games[0].moves.map(func(move): return move.uci), ["f2f3", "e7e5", "g2g4", "d8h4"])
		assert_eq(parsed.games[0].moves.map(func(move): return move.clock_ms), [180000, 180000, 181750, 181000])
		assert_eq(parsed.games[0].result, "0-1")
	assert_eq(sent.url, "https://lichess.org/analysis/pgn/1.%20f3%20e5%202.%20g4%20Qh4%23%200-1")
	main.free()


func test_space_with_review_focused_rematches_and_replaces_the_previous_game():
	var time := FakeTime.new()
	var main = await _session(time)
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
	await _wait_start(main)
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
	var main = await _session(time)
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
	assert_true(main.get_node("Home").visible)
	assert_true(not review.visible)
	assert_true(main.clock == null, "setup has no active game")
	_key(main, KEY_SPACE)
	await _wait_start(main)
	assert_true(main.get_node("Home").visible, "Space on Home does not silently start a rematch")
	var next := SETTINGS.duplicate()
	next.control = "1+0"
	main.setup.started.emit(next)
	await _wait_start(main)
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
	var main = await _session(time)
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
	var main = await _session(time)
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
	var main = await _session(FakeTime.new())
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
	var main = await _session(FakeTime.new())
	main.board_view.play("e2e4")
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
	var review = main.review
	var list: Tree = review.get_node("Margin/Content/ReviewBody/Side/Moves")
	var row: TreeItem = list.get_root().get_first_child()
	assert_true(row.get_icon(1) == null, "unanalysed move has no class")
	review.receive_position(1, {"pv": [{"cp": -20, "moves": ["e7e5"]}], "best_move": "e7e5"})
	assert_true(row.get_icon(1) != null, "unsettled move has a placeholder")
	var pending_icon = row.get_icon(1)
	review.receive_position(0, {"pv": [{"cp": 20, "moves": ["e2e4"]}], "best_move": "e2e4"})
	assert_true(row.get_icon(1) != null and row.get_icon(1) != pending_icon, "settled move replaces its placeholder with a class icon")
	var board = review.get_node("Margin/Content/ReviewBody/BoardView")
	assert_eq(board.review_square, "e4")
	assert_eq(board.review_arrow, "e2e4")
	assert_true(board.review_icon != null)
	main.free()


class FakeAnalysisBridge extends Node:
	signal stopped
	var engine_id := "Stockfish 19"
	var error := ""
	var starts := true
	func start() -> bool:
		return starts


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
	var main = await _session(FakeTime.new())
	main.review.analysis_queue = null # Exercise the direct analyser without the history queue.
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
	var main = await _session(FakeTime.new())
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
		var main = await _session(FakeTime.new())
		var fake = FakeReviewAnalyser.new()
		# A current cache must show even when the engine cannot start.
		main.review.analysis_bridge_factory = func():
			var bridge := FakeAnalysisBridge.new()
			bridge.starts = version != "Stockfish 19"
			return bridge
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
				await _wait_start(main)
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
	var main = await _session(FakeTime.new())
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


func test_review_help_popups_fit_minimum_window():
	var tree = Engine.get_main_loop()
	var root = tree.root
	var old_size: Vector2i = root.size
	root.size = Vector2i(800, 600)
	var main = await _session(FakeTime.new())
	var game = Game.new()
	game.play("e2e4")
	main.review.present(game, [180000, 180000], SETTINGS, "")
	main.review.receive_position(1, {"pv": [{"cp": 0, "moves": ["e7e5"]}]})
	main.review.receive_position(0, {"pv": [{"cp": 0, "moves": ["e2e4"]}], "best_move": "e2e4"})
	await tree.process_frame
	await tree.process_frame
	for help_name in ["AccuracyHelp"]:
		var help = main.review.get_node("Margin/Content/ReviewBody/Side/" + help_name)
		var event := InputEventMouseMotion.new()
		event.position = help.get_global_rect().get_center()
		root.push_input(event)
		await tree.create_timer(1.0).timeout
		var popup = _visible_tooltip(root)
		assert_true(popup != null, help_name + " opens a tooltip")
		if popup != null:
			assert_true(popup.position.x >= 0 and popup.position.y >= 0 and popup.position.x + popup.size.x <= 800 and popup.position.y + popup.size.y <= 600, help_name + " tooltip fits")
			var label = popup.get_child(0)
			assert_true(label is Label and label.text == help.tooltip_text, help_name + " displays the full explanation")
		# Keyboard users reach the same text: focus the "?" and press Enter.
		var dialog: AcceptDialog = main.review.get_node("HelpDialog")
		assert_eq(help.focus_mode, Control.FOCUS_ALL, help_name + " takes keyboard focus")
		help.grab_focus()
		for pressed in [true, false]:
			var enter := InputEventKey.new()
			enter.keycode = KEY_ENTER
			enter.pressed = pressed
			root.push_input(enter)
		await tree.process_frame
		assert_true(dialog.visible and dialog.dialog_text == help.tooltip_text, help_name + " opens its explanation with Enter")
		var rect := Rect2(dialog.position, dialog.size)
		assert_true(Rect2(0, 0, 800, 600).encloses(rect), help_name + " dialog fits")
		dialog.hide()
	main.free()
	root.size = old_size


func _visible_tooltip(node: Node):
	if node is PopupPanel and node.visible:
		return node
	for child in node.get_children(true):
		var found = _visible_tooltip(child)
		if found != null:
			return found
	return null


# Starts now cross a real asynchronous searching screen.
func _wait_start(main) -> void:
	while main._starting:
		await Engine.get_main_loop().process_frame

func test_unsettled_move_has_placeholder_while_analysis_arrives():
	var main = await _session(FakeTime.new())
	var game = Game.new()
	game.play("e2e4")
	main.review.present(game, [180000, 180000], SETTINGS, "")
	main.review.receive_position(0, {"pv": [{"cp": 0, "moves": ["e2e4"]}], "best_move": "e2e4"})
	var moves: Tree = main.review.get_node("Margin/Content/ReviewBody/Side/Moves")
	assert_true(moves.get_root().get_first_child().get_icon(1) != null, "unsettled move has a placeholder")
	main.free()

func test_move_classes_help_opens_ordered_legend():
	var main = await _session(FakeTime.new())
	var review = main.review
	review.present(Game.new(), [180000, 180000], SETTINGS, "")
	review.get_node("Margin/Content/ReviewBody/Side/ClassHelp").pressed.emit()
	var legend = review.get_node_or_null("ClassLegend")
	assert_true(legend != null and legend.visible, "move classes opens the legend")
	if legend != null:
		var rows = legend.get_node("Content/LegendRows").get_children()
		var names = ["Brilliant", "Great", "Best", "Excellent", "Good", "Book", "Repertoire", "Inaccuracy", "Mistake", "Miss", "Blunder", "Forced"]
		assert_eq(rows.size(), names.size())
		for i in mini(rows.size(), names.size()):
			assert_eq(rows[i].get_child(1).get_child(0).text, names[i])
	main.free()

func test_move_classes_collapse_in_small_review():
	var root = Engine.get_main_loop().root
	var old_size: Vector2i = root.size
	root.size = Vector2i(800, 600)
	var main = await _session(FakeTime.new())
	main.review.present(Game.new(), [180000, 180000], SETTINGS, "")
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var side = main.review.get_node("Margin/Content/ReviewBody/Side")
	var toggle = side.get_node_or_null("ClassToggle")
	assert_true(toggle != null and toggle.visible, "small review offers a move classes toggle")
	assert_true(not side.get_node("Counts").visible, "class table starts collapsed")
	assert_eq(side.get_node("Summary/AccuracyCards").columns, 2, "accuracy cards stack at the minimum width")
	if toggle != null:
		toggle.pressed.emit()
		assert_true(side.get_node("Counts").visible, "toggle opens class table")
		await Engine.get_main_loop().process_frame
		var actions: Control = main.review.get_node("Margin/Content/Actions")
		assert_true(actions.global_position.y + actions.size.y <= 600, "expanded classes leave actions inside the window")
		toggle.pressed.emit()
		assert_true(side.get_node("Moves").visible, "collapsing returns to the moves")
	main.free()
	root.size = old_size

func test_review_navigation_buttons_visit_first_and_last_move():
	var main = await _session(FakeTime.new())
	var game = Game.new()
	game.play("e2e4")
	game.play("e7e5")
	main.review.present(game, [180000, 180000], SETTINGS, "")
	var nav = main.review.get_node_or_null("Margin/Content/ReviewBody/Side/Navigation")
	assert_true(nav != null, "review has navigation buttons")
	if nav != null:
		nav.get_node("First").pressed.emit()
		assert_eq(main.review.get_node("Margin/Content/ReviewBody/BoardView").game.moves.size(), 0)
		nav.get_node("Last").pressed.emit()
		assert_eq(main.review.get_node("Margin/Content/ReviewBody/BoardView").game.moves.size(), 2)
	main.free()

func test_unanalysed_history_keeps_book_icon():
	var main = await _session(FakeTime.new())
	var game = Game.new()
	game.play("h2h3")
	var path := "user://ui026-unanalysed.pgn"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("1. h3 *")
	file.close()
	main.review.present(game, [180000, 180000], SETTINGS, "", main.get_node("Setup").book.entries)
	main.review.present_history(path, "user://ui026-missing-analysis.json", false)
	var moves: Tree = main.review.get_node("Margin/Content/ReviewBody/Side/Moves")
	assert_true(moves.get_root().get_first_child().get_icon(1) != null, "book move retains its icon without analysis")
	DirAccess.remove_absolute(path)
	main.free()


func test_review_player_labels_follow_board_orientation():
	var main = await _session(FakeTime.new())
	var review = main.get_node("Review")
	var settings := SETTINGS.duplicate()
	settings["player_name"] = "Bruno"
	review.present(Game.new(), [180000, 180000], settings, "")
	var body = review.get_node("Margin/Content/ReviewBody")
	var top = body.find_child("TopPlayer", true, false)
	var bottom = body.find_child("BottomPlayer", true, false)
	assert_true(top != null and bottom != null, "both players are labelled by the board")
	if top != null and bottom != null:
		assert_true(top.text.contains("Maia 1500") and bottom.text.contains("Bruno"))
		var flip := InputEventKey.new()
		flip.keycode = KEY_F
		flip.pressed = true
		review._input(flip)
		assert_true(top.text.contains("Bruno") and bottom.text.contains("Maia 1500"), "labels follow the flipped board")
	main.free()


func test_review_header_and_actions_are_in_the_side_card():
	var main = await _session(FakeTime.new())
	var review = main.get_node("Review")
	review.present(Game.new(), [180000, 180000], SETTINGS, "")
	await Engine.get_main_loop().process_frame
	var side: Control = review.get_node("Margin/Content/ReviewBody/Side")
	var title: Control = review.get_node("Margin/Content/Title")
	var actions: Control = review.get_node("Margin/Content/Actions")
	assert_true(title.global_position.x >= side.global_position.x, "review header belongs above the side card")
	assert_true(actions.global_position.x >= side.global_position.x, "actions belong below the side card")
	main.free()


func test_navigation_marks_current_move_in_list():
	var main = await _session(FakeTime.new())
	var game = Game.new()
	game.play("e2e4")
	game.play("e7e5")
	var review = main.get_node("Review")
	review.present(game, [180000, 180000], SETTINGS, "")
	var list: Tree = review.get_node("Margin/Content/ReviewBody/Side/Moves")
	review.get_node("Margin/Content/ReviewBody/Side/Navigation/Previous").pressed.emit()
	assert_eq(list.get_selected_column(), 1, "the selected cell follows navigation")
	assert_eq(list.get_selected().get_text(1), "e4")
	main.free()


func test_graph_receives_classifications_as_analysis_arrives():
	var main = await _session(FakeTime.new())
	var game = Game.new()
	game.play("e2e4")
	game.play("e7e5")
	var review = main.get_node("Review")
	review.present(game, [180000, 180000], SETTINGS, "")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/analysis/rev003-opening.json"))
	for i in 3:
		review.receive_position(i, fixture.positions[i])
	var graph = review.get_node("Margin/Content/ReviewBody/Side/EvalGraph")
	assert_eq(graph.classes.size(), 2)
	assert_eq(graph.classes[0].class, "Best")
	assert_eq(graph.classes[1].class, "Best")
	main.free()


func test_analysis_progress_counts_settled_moves():
	var main = await _session(FakeTime.new())
	var game = Game.new()
	game.play("e2e4")
	game.play("e7e5")
	var review = main.get_node("Review")
	review.present(game, [180000, 180000], SETTINGS, "")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/analysis/rev003-opening.json"))
	review.receive_position(0, fixture.positions[0])
	review.receive_position(1, fixture.positions[1])
	var summary = review.get_node("Margin/Content/ReviewBody/Side/Summary")
	assert_true(not summary.visible, "partial analysis must not be presented as final accuracy")
	var progress = review.get_node_or_null("Margin/Content/ProgressText")
	assert_true(progress != null, "analysis progress includes a move count")
	if progress != null:
		assert_eq(progress.text, "1 of 2 moves")
	main.free()


func test_review_result_header_includes_time_control_and_move_count():
	var main = await _session(FakeTime.new())
	var game = Game.new()
	game.play("e2e4")
	game.play("e7e5")
	var review = main.get_node("Review")
	review.present(game, [180000, 180000], SETTINGS, "White wins by resignation")
	var result: Label = review.get_node("Margin/Content/Result")
	assert_true(result.text.contains("3+2") and result.text.contains("resignation") and result.text.contains("1 move"))
	main.free()


func test_repertoire_exit_is_a_move_list_row():
	var main = await _session(FakeTime.new())
	var repertoire = preload("res://bot/repertoire.gd").new()
	assert_eq(repertoire.parse("1. e4 e5 2. Nf3 Nc6 *", "w"), "")
	var game = Game.new()
	for move in ["e2e4", "e7e5", "d2d4"]:
		game.play(move)
	var review = main.get_node("Review")
	review.present(game, [180000, 180000, 180000], SETTINGS, "", [], repertoire.lines, true)
	var rows = review.get_node("Margin/Content/ReviewBody/Side/Moves").get_root().get_children()
	var found := false
	for row in rows:
		if row.get_text(1).contains("Left repertoire") and row.get_text(1).contains("Nf3"):
			found = true
			assert_true(row.get_expand_right(1), "expected moves can use both move columns")
	assert_true(found, "the exit and expected move appear inside the move list")
	main.free()


func test_legend_keyboard_does_not_activate_review_shortcuts():
	var main = await _session(FakeTime.new())
	var review = main.get_node("Review")
	review.present(Game.new(), [180000, 180000], SETTINGS, "")
	var triggered := [false]
	review.rematch_requested.connect(func(): triggered[0] = true)
	review.get_node("Margin/Content/ReviewBody/Side/ClassHelp").pressed.emit()
	await Engine.get_main_loop().process_frame
	assert_true(review.get_node("ClassLegend").visible, "legend is open before keyboard input")
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	Engine.get_main_loop().root.push_input(event)
	await Engine.get_main_loop().process_frame
	assert_true(not triggered[0], "Space in the legend must not start a rematch")
	main.free()


func test_compact_analysis_progress_does_not_cover_game_result():
	var root = Engine.get_main_loop().root
	var old_size: Vector2i = root.size
	root.size = Vector2i(800, 600)
	var main = await _session(FakeTime.new())
	var review = main.get_node("Review")
	review.present(Game.new(), [180000, 180000], SETTINGS, "White won by resignation")
	var result: Control = review.get_node("Margin/Content/Result")
	var progress: Control = review.get_node("Margin/Content/Progress")
	progress.show()
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	assert_true(result.global_position.y + result.size.y <= progress.global_position.y, "progress starts below the result")
	main.free()
	root.size = old_size

func test_history_review_uses_saved_time_control_and_legacy_fallback():
	var main = await _session(FakeTime.new())
	var game = Game.new()
	game.play("e2e4")
	game.resign("b")
	var saved = Pgn.finished_game(game, [180000], SETTINGS)
	var path: String = main.history.save(game, [180000], SETTINGS)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(Pgn.write(saved))
	file.close()
	main.history_screen.present(main.history, main.preferences)
	main._review_history_game(path, Pgn.parse(FileAccess.get_file_as_string(path)).games[0])
	assert_true(main.review.get_node("Margin/Content/Result").text.begins_with("3+2 ·"), "saved 180+2 displays as 3+2")
	saved.headers.erase("TimeControl")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(Pgn.write(saved))
	file.close()
	main.history_screen.present(main.history, main.preferences)
	main._review_history_game(path, Pgn.parse(FileAccess.get_file_as_string(path)).games[0])
	assert_true(main.review.get_node("Margin/Content/Result").text.begins_with("1+0 ·"), "legacy game keeps its fallback")
	main.free()

func test_postgame_analysis_progress_follows_real_result():
	var root = Engine.get_main_loop().root
	var old_size: Vector2i = root.size
	root.size = Vector2i(1280, 800)
	var main = await _session(FakeTime.new())
	main.board_view.play("e2e4")
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
	var result: Control = main.review.get_node("Margin/Content/Result")
	var progress: Control = main.review.get_node("Margin/Content/Progress")
	progress.show()
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	assert_true(not result.text.contains("Space for a rematch"), "review summary omits game-over shortcuts")
	assert_true(result.global_position.y + result.size.y <= progress.global_position.y, "progress stays below post-game result")
	main.free()
	root.size = old_size

func test_long_review_keeps_selected_move_visible():
	var root = Engine.get_main_loop().root
	var old_size: Vector2i = root.size
	root.size = Vector2i(1280, 800)
	var main = await _session(FakeTime.new())
	var game = Game.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 260026
	for i in 80:
		if game.is_over():
			break
		var legal = game.board.legal_moves()
		game.play(legal[rng.randi_range(0, legal.size() - 1)])
	assert_true(game.moves.size() >= 40, "fixture must exceed the visible move list")
	var clocks := []
	clocks.resize(game.moves.size())
	clocks.fill(180000)
	main.review.present(game, clocks, SETTINGS, "Fixture")
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	var list: Tree = main.review.get_node("Margin/Content/ReviewBody/Side/Moves")
	var rect := list.get_item_area_rect(list.get_selected(), list.get_selected_column())
	assert_true(rect.position.y >= 0 and rect.end.y <= list.size.y, "initial final move is visible")
	main.review.get_node("Margin/Content/ReviewBody/Side/Navigation/First").pressed.emit()
	main.review.get_node("Margin/Content/ReviewBody/Side/Navigation/Next").pressed.emit()
	await root.get_tree().process_frame
	rect = list.get_item_area_rect(list.get_selected(), list.get_selected_column())
	assert_true(rect.position.y >= 0 and rect.end.y <= list.size.y, "first move is visible after navigation")
	main.review.get_node("Margin/Content/ReviewBody/Side/EvalGraph").ply_selected.emit(game.moves.size())
	await root.get_tree().process_frame
	rect = list.get_item_area_rect(list.get_selected(), list.get_selected_column())
	assert_true(rect.position.y >= 0 and rect.end.y <= list.size.y, "graph jump scrolls to last move")
	main.free()
	root.size = old_size

func test_cached_history_keeps_final_move_visible_after_layout():
	var root = Engine.get_main_loop().root
	var old_size: Vector2i = root.size
	for window_size in [Vector2i(1280, 800), Vector2i(800, 600)]:
		root.size = window_size
		var main = await _session(FakeTime.new())
		var game = Game.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 260026
		for i in 80:
			if game.is_over():
				break
			var legal = game.board.legal_moves()
			game.play(legal[rng.randi_range(0, legal.size() - 1)])
		assert_eq(game.moves.size(), 80, "fixture has 80 plies")
		game.resign(game.board.side_to_move)
		var clocks := []
		clocks.resize(game.moves.size())
		clocks.fill(180000)
		var path: String = main.history.save(game, clocks, SETTINGS)
		var positions := []
		for i in game.moves.size() + 1:
			var best: String = game.moves[i] if i < game.moves.size() else ""
			positions.append({"best_move": best, "pv": [{"cp": 0, "moves": [best] if not best.is_empty() else []}]})
		DirAccess.make_dir_recursive_absolute(main.history.analysis_folder())
		var cache := FileAccess.open(main.history.analysis_folder().path_join(path.get_file() + ".json"), FileAccess.WRITE)
		cache.store_string(JSON.stringify({"engine_version": "Stockfish 19", "node_budget": Tunables.ANALYSIS_NODES, "positions": positions}))
		cache.close()
		main._show_history()
		main._review_history_game(path, Pgn.parse(FileAccess.get_file_as_string(path)).games[0])
		for i in 10:
			await root.get_tree().process_frame
		var list: Tree = main.review.get_node("Margin/Content/ReviewBody/Side/Moves")
		assert_true(main.review.get_node("Margin/Content/ReviewBody/Side/Summary").visible, "cached analysis is complete")
		assert_eq(main.review._ply, 80, "last move is selected")
		var rect := list.get_item_area_rect(list.get_selected(), list.get_selected_column())
		assert_true(rect.position.y >= 0 and rect.end.y <= list.size.y, "cached final move visible at %s: %s in %s" % [window_size, rect, list.size])
		main.free()
	root.size = old_size


func test_move_class_legend_is_anchored_and_contained():
	var root = Engine.get_main_loop().root
	var old_size: Vector2i = root.size
	var old_embed: bool = root.gui_embed_subwindows
	root.gui_embed_subwindows = true
	for window_size in [Vector2i(1280, 800), Vector2i(800, 600)]:
		root.size = window_size
		var main = await _session(FakeTime.new())
		var review = main.review
		review.present(Game.new(), [180000, 180000], SETTINGS, "")
		await root.get_tree().process_frame
		await root.get_tree().process_frame
		var help: Button = review.get_node("Margin/Content/ReviewBody/Side/ClassHelp")
		help.pressed.emit()
		await root.get_tree().process_frame
		await root.get_tree().process_frame
		var legend = review.get_node("ClassLegend")
		var rect := Rect2i(legend.position, legend.size)
		assert_true(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= window_size.x and rect.end.y <= window_size.y, "legend fits inside window")
		assert_true(absf(rect.end.x - help.global_position.x) <= 24, "legend sits beside the Moves help")
		assert_true(legend.get_node("Content/Header/Close").text == "×", "legend offers a close action")
		legend.get_node("Content/Header/Close").pressed.emit()
		assert_true(not legend.visible, "close dismisses legend")
		main.free()
	root.gui_embed_subwindows = old_embed
	root.size = old_size

func test_legend_opens_and_dismisses_with_keyboard_without_review_shortcuts():
	var root = Engine.get_main_loop().root
	var old_embed: bool = root.gui_embed_subwindows
	root.gui_embed_subwindows = true
	var main = await _session(FakeTime.new())
	var review = main.review
	review.present(Game.new(), [180000, 180000], SETTINGS, "")
	await root.get_tree().process_frame
	var triggered := [false]
	review.rematch_requested.connect(func(): triggered[0] = true)
	var help: Button = review.get_node("Margin/Content/ReviewBody/Side/ClassHelp")
	help.grab_focus()
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event)
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	var legend = review.get_node("ClassLegend")
	assert_true(legend.visible, "Enter opens the legend")
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		root.push_input(event)
	await root.get_tree().process_frame
	assert_true(not legend.visible, "Escape closes the legend")
	assert_true(not triggered[0], "legend keyboard input does not trigger rematch")
	main.free()
	root.gui_embed_subwindows = old_embed

func test_review_keeps_history_error_clear_of_analysis_progress():
	var root = Engine.get_main_loop().root
	var old_size: Vector2i = root.size
	root.size = Vector2i(1280, 800)
	var main = await _session(FakeTime.new())
	var review = main.review
	review.present(Game.new(), [], SETTINGS, "White wins by resignation (1-0)\nSpace for a rematch\nHistory: Could not save game")
	var result: Control = review.get_node("Margin/Content/Result")
	var progress: Control = review.get_node("Margin/Content/Progress")
	progress.show()
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	assert_true(result.text.contains("History: Could not save game"), "save failures remain visible")
	assert_true(not result.text.contains("Space for a rematch"), "shortcut is not part of review summary")
	assert_true(result.global_position.y + result.size.y <= progress.global_position.y, "progress stays below the whole warning")
	main.free()
	root.size = old_size


# CLEAN-013: the review's palettes live in the shared theme, not in per-node overrides.
func test_review_cards_use_theme_variations():
	var main = await _session(FakeTime.new())
	var review = main.get_node("Review")
	var cards = review.get_node("Margin/Content/ReviewBody/Side/Summary/AccuracyCards")
	for side in ["White", "Black"]:
		var card: PanelContainer = cards.get_node(side + "Score")
		var tone := "Light" if side == "White" else "Dark"
		assert_eq(card.theme_type_variation, StringName("AccuracyCard" + tone), side + " card style")
		assert_true(not card.has_theme_stylebox_override("panel"), side + " card has no inline style")
		var value: Label = card.get_node("Value")
		assert_eq(value.theme_type_variation, StringName("AccuracyValue" + tone), side + " value style")
		assert_true(not value.has_theme_color_override("font_color") and not value.has_theme_font_size_override("font_size"), side + " value has no inline palette")
	var empty: Panel = review.get_node("Margin/Content/ReviewBody/Side/UnanalysedNotice/NoticeCard")
	assert_eq(empty.theme_type_variation, &"EmptyAnalysisCard")
	assert_true(not empty.has_theme_stylebox_override("panel"), "empty-analysis card has no inline style")
	main.free()


func test_eval_score_stays_readable_on_either_colour():
	var main = await _session(FakeTime.new())
	var review = main.get_node("Review")
	var game = Game.new()
	game.play("e2e4")
	var black := SETTINGS.duplicate()
	black.colour = "b"
	review.present(game, [180000], black, "")
	var bar: Control = review.get_node("Margin/Content/ReviewBody/EvalBar")
	bar.size = Vector2(28, 680)
	var score: Label = bar.get_node("Score")
	# Black to move: +820 for black is -8.2 for white; the score sits on black's part at black's end.
	review.receive_position(1, {"pv": [{"cp": 0, "moves": ["e7e5"]}]})
	assert_eq(score.get_theme_color("font_color"), Color("141412"), "flipped, even: the score is at white's end, on white, so it is dark")
	review.receive_position(1, {"pv": [{"cp": 820, "moves": ["e7e5"]}]})
	assert_eq(score.get_theme_color("font_color"), Color("ece9e4"), "flipped, black far ahead: the score is on black's part, so it is light")
	review._board_view.flipped = false
	review._update_eval_bar()
	assert_eq(score.get_theme_color("font_color"), Color("ece9e4"), "unflipped, black far ahead: still on black's part, so it is light")
	main.free()


func test_eval_score_sits_at_the_end_of_the_side_ahead():
	var main = await _session(FakeTime.new())
	var review = main.get_node("Review")
	var game = Game.new()
	game.play("e2e4")
	review.present(game, [180000], SETTINGS, "")
	var bar: Control = review.get_node("Margin/Content/ReviewBody/EvalBar")
	bar.size = Vector2(28, 680)
	var score: Label = bar.get_node("Score")
	# Black to move, so the engine's cp is black's view: -360 is +3.6 for white.
	for case in [[-360, false, true, "white ahead"], [-360, true, false, "white ahead, flipped"],
			[360, false, false, "black ahead"], [360, true, true, "black ahead, flipped"],
			[0, false, true, "level"], [0, true, false, "level, flipped"]]:
		review._board_view.flipped = case[1]
		review.receive_position(1, {"pv": [{"cp": case[0], "moves": ["e7e5"]}]})
		var middle := score.position.y + score.size.y / 2
		assert_eq(middle > bar.size.y / 2, case[2], "%s: score at the %s end" % [case[3], "bottom" if case[2] else "top"])
		var white_ahead: bool = case[0] <= 0
		assert_eq(score.get_theme_color("font_color"), Color("141412") if white_ahead else Color("ece9e4"), case[3] + ": readable on its part")
	review._board_view.flipped = false
	review.receive_position(1, {"pv": [{"mate": -2, "moves": ["e7e5"]}]})
	assert_true(score.text == "+M2" and score.position.y > bar.size.y / 2, "mate for white sits at white's end")
	main.free()


func test_compact_review_keeps_unanalysed_card_and_exit_readable():
	var root = Engine.get_main_loop().root
	var old_size: Vector2i = root.size
	root.size = Vector2i(800, 600)
	var main = await _session(FakeTime.new())
	var repertoire = preload("res://bot/repertoire.gd").new()
	assert_eq(repertoire.parse("1. e4 e5 2. Nf3 Nc6 *", "w"), "")
	var game = Game.new()
	for move in ["e2e4", "e7e5", "d2d4"]:
		game.play(move)
	main.review.present(game, [180000, 180000, 180000], SETTINGS, "", [], repertoire.lines, true)
	main.review.present_history("user://pr35-missing-game.pgn", "user://pr35-missing-analysis.json", false)
	for i in 3:
		await Engine.get_main_loop().process_frame
	var side = main.review.get_node("Margin/Content/ReviewBody/Side")
	var notice: Label = side.get_node("UnanalysedNotice")
	var description: Label = notice.get_node("AnalysisDescription")
	var title_bottom: float = notice.global_position.y + notice.get_theme_stylebox("normal").content_margin_top + notice.get_line_count() * notice.get_line_height()
	assert_true(description.global_position.y >= title_bottom, "the description starts below the wrapped title")
	assert_true(description.get_global_rect().end.y <= side.get_node("Analyze").global_position.y, "the description ends above Analyze")
	var tree: Tree = side.get_node("Moves")
	var rows: Array = tree.get_root().get_children()
	var exit_row: TreeItem = rows[2]
	assert_true(exit_row.get_text(1).begins_with("Left repertoire"), "fixture has an exit row")
	assert_true(tree.get_item_area_rect(exit_row, 1).size.y > tree.get_item_area_rect(rows[0], 1).size.y, "the exit callout wraps instead of eliding the expected move")
	main.free()
	root.size = old_size


func test_compact_analysis_progress_keeps_title_and_count_apart():
	var root = Engine.get_main_loop().root
	var old_size: Vector2i = root.size
	root.size = Vector2i(800, 600)
	var main = await _session(FakeTime.new())
	var game = Game.new()
	for move in ["e2e4", "e7e5", "g1f3", "b8c6"]:
		game.play(move)
	main.review.present(game, [180000, 180000, 180000, 180000], SETTINGS, "")
	main.review.get_node("Margin/Content/Progress").show()
	for i in 3:
		await Engine.get_main_loop().process_frame
	var title: Label = main.review.get_node("Margin/Content/ProgressTitle")
	var count: Label = main.review.get_node("Margin/Content/ProgressText")
	var title_end: float = title.global_position.x + title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x
	var count_start: float = count.global_position.x + count.size.x - count.get_theme_font("font").get_string_size(count.text, HORIZONTAL_ALIGNMENT_LEFT, -1, count.get_theme_font_size("font_size")).x
	assert_true(count.global_position.y >= title.global_position.y + title.size.y or count_start >= title_end + 8, "the move count does not run into the title")
	main.free()
	root.size = old_size


func test_late_analysis_error_is_laid_out_in_the_card():
	var root = Engine.get_main_loop().root
	var old_size: Vector2i = root.size
	for window_size in [Vector2i(1280, 800), Vector2i(800, 600)]:
		root.size = window_size
		var main = await _session(FakeTime.new())
		var game = Game.new()
		game.play("e2e4")
		main.review.present(game, [180000], SETTINGS, "")
		main.review.get_node("Margin/Content/Progress").show()
		for i in 3:
			await Engine.get_main_loop().process_frame
		main.review._analysis_error("Stockfish stopped")
		await Engine.get_main_loop().process_frame
		var error: Label = main.review.get_node("Margin/Content/AnalysisError")
		var side: Control = main.review.get_node("Margin/Content/ReviewBody/Side")
		assert_true(error.visible and absf(error.size.x - side.size.x) < 1, "the error spans the side column at %s" % window_size)
		assert_true(absf(error.global_position.x - side.global_position.x) < 1, "the error starts at the column's edge at %s" % window_size)
		main.free()
	root.size = old_size
