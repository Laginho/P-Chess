extends "res://tests/run.gd".Test


func test_convergence_requires_three_stable_completed_depths_at_depth_twelve():
	var script = load("res://engine/analyser.gd")
	if script == null:
		assert_true(false, "analyser is missing")
		return
	var stable := [
		{"depth": 10, "move": "e2e4", "cp": 30},
		{"depth": 11, "move": "e2e4", "cp": 31},
		{"depth": 12, "move": "e2e4", "cp": 32},
	]
	assert_true(script.converged(stable), "stable depths 10-12")
	assert_true(not script.converged(stable.slice(0, 2)), "only two depths")
	var early := stable.duplicate(true)
	early[2].depth = 11
	assert_true(not script.converged(early), "depth below 12")
	var changed := stable.duplicate(true)
	changed[1].move = "d2d4"
	assert_true(not script.converged(changed), "different best move")
	changed = stable.duplicate(true)
	changed[2].cp = 200
	assert_true(not script.converged(changed), "expected points changed")
