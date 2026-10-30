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
