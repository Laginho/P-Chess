extends "res://tests/run.gd".Test

# Fails on purpose: `run.gd -- tests/fixtures/failing` must exit non-zero.


func test_fails_on_purpose():
	assert_eq(2 + 2, 5)
