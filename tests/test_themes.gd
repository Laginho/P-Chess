extends "res://tests/run.gd".Test

const ThemeLoader = preload("res://ui/theme_loader.gd")


func test_lists_both_roots_and_only_complete_piece_sets():
	var loader = ThemeLoader.new("res://tests/fixtures/themes/builtin", "res://tests/fixtures/themes/user")
	assert_eq(loader.list_themes("boards"), {
		"blue": "res://tests/fixtures/themes/builtin/boards/blue",
		"custom": "res://tests/fixtures/themes/user/boards/custom"})
	assert_eq(loader.list_themes("pieces"), {"complete": "res://tests/fixtures/themes/builtin/pieces/complete"})
	assert_eq(loader.list_themes("sounds"), {"quiet": "res://tests/fixtures/themes/builtin/sounds/quiet"})
	assert_eq(ThemeLoader.new("res://missing", "user://missing").list_themes("boards"), {})
