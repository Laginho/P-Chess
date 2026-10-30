extends "res://tests/run.gd".Test


func test_move_accuracy_for_win_percentage_drops():
	var accuracy = load("res://core/accuracy.gd")
	assert_true(accuracy != null, "accuracy module exists")
	if accuracy == null:
		return
	assert_eq(accuracy.move_accuracy(50.0, 50.0), 100.0)
	assert_eq(accuracy.move_accuracy(50.0, 60.0), 100.0)
	assert_true(absf(accuracy.move_accuracy(60.0, 50.0) - 64.5826) < 0.001)
	assert_true(absf(accuracy.move_accuracy(80.0, 30.0) - 9.5303) < 0.001)


func test_game_accuracy_matches_two_lichess_games():
	var accuracy = load("res://core/accuracy.gd")
	for id: String in ["uqCv060v", "T1QrzasJ"]:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/analysis/rev004-" + id + ".json"))
		var result: Dictionary = accuracy.evaluate(data)
		for colour: String in ["white", "black"]:
			assert_true(absf(result[colour] - data.lichess_accuracy[colour]) < 0.1, id + " " + colour)


func test_empty_and_black_start_games():
	var accuracy = load("res://core/accuracy.gd")
	var start := {"fen": "8/8/8/8/8/8/8/8 b - - 0 1", "pv": [{"cp": 0}]}
	var empty: Dictionary = accuracy.evaluate({"positions": [start]})
	assert_eq(empty.white, null)
	assert_eq(empty.black, null)
	var single: Dictionary = accuracy.evaluate({"positions": [start, {"pv": [{"cp": 0}]}]})
	assert_eq(single.white, null)
	assert_eq(single.black, 100.0)


func test_game_windows_at_15_40_and_200_plies():
	var accuracy = load("res://core/accuracy.gd")
	for sample in [[15, 43.61833, 64.67922], [40, 52.29550, 68.16831], [200, 51.56424, 68.66874]]:
		var positions := []
		for i in int(sample[0]) + 1:
			var white_cp: int = (i * 137) % 1201 - 600
			positions.append({"pv": [{"cp": white_cp if i % 2 == 0 else -white_cp}]})
		positions[0].fen = "8/8/8/8/8/8/8/8 w - - 0 1"
		var result: Dictionary = accuracy.evaluate({"positions": positions})
		assert_true(absf(result.white - sample[1]) < 0.001, "white at %d plies" % sample[0])
		assert_true(absf(result.black - sample[2]) < 0.001, "black at %d plies" % sample[0])


func test_mate_and_terminal_scores_are_clamped_from_side_to_move():
	var accuracy = load("res://core/accuracy.gd")
	var start := {"fen": "8/8/8/8/8/8/8/8 w - - 0 1", "pv": [{"cp": 0}]}
	var mate: Dictionary = accuracy.evaluate({"positions": [start, {"pv": [{"mate": -3}]}]})
	var terminal: Dictionary = accuracy.evaluate({"positions": [start, {"pv": [], "terminal_score": -1000}]})
	assert_eq(mate.white, 100.0)
	assert_eq(terminal.white, 100.0)
	var losing: Dictionary = accuracy.evaluate({"positions": [start, {"pv": [{"mate": 2}]}]})
	assert_true(losing.white < 12.0, "positive mate for black lowers white win percentage")
