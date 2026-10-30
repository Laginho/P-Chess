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
