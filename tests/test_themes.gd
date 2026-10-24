extends "res://tests/run.gd".Test

const ThemeLoader = preload("res://ui/theme_loader.gd")

class Warnings extends Logger:
	var messages: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			messages.append(rationale if rationale else code)


func test_lists_both_roots_and_only_complete_piece_sets():
	var loader = ThemeLoader.new("res://tests/fixtures/themes/builtin", "res://tests/fixtures/themes/user")
	var boards: Dictionary = loader.list_themes("boards")
	assert_eq(boards.blue, "res://tests/fixtures/themes/user/boards/blue")
	assert_eq(boards.custom, "res://tests/fixtures/themes/user/boards/custom")
	assert_eq(loader.list_themes("pieces"), {"complete": "res://tests/fixtures/themes/builtin/pieces/complete"})
	assert_eq(loader.list_themes("sounds"), {"quiet": "res://tests/fixtures/themes/builtin/sounds/quiet"})
	assert_eq(ThemeLoader.new("res://missing", "user://missing").list_themes("boards"), {})


func test_board_colours_or_texture_and_malformed_fallback_with_warning():
	var loader = ThemeLoader.new("res://tests/fixtures/themes/builtin", "res://tests/fixtures/themes/user")
	var blue: Dictionary = loader.load_board("blue")
	assert_eq(blue.light, Color("#123456"))
	assert_eq(blue.dark, Color("#654321"))
	assert_eq(blue.texture, null)
	var textured: Dictionary = loader.load_board("textured")
	assert_true(textured.texture is Texture2D)
	assert_eq(textured.texture.get_size(), Vector2(80, 80))
	var warnings := Warnings.new()
	OS.add_logger(warnings)
	for name in ["malformed", "bad_colour", "missing_texture", "unknown"]:
		var board: Dictionary = loader.load_board(name)
		assert_eq(board.light, Color("#f0d9b5"), name)
		assert_eq(board.dark, Color("#b58863"), name)
		assert_eq(board.texture, null, name)
	assert_eq(warnings.messages.size(), 4)
	OS.remove_logger(warnings)


func test_missing_sound_event_is_silent_and_other_events_still_load():
	var loader = ThemeLoader.new("res://tests/fixtures/themes/builtin", "res://tests/fixtures/themes/user")
	var sounds: Dictionary = loader.load_sounds("quiet")
	assert_eq(sounds.size(), 8)
	assert_true(not sounds.has("capture"))
	for event in ["move", "castle", "check", "promote", "premove", "low_time", "game_start", "game_end"]:
		assert_true(sounds.get(event) is AudioStreamOggVorbis, event)
		assert_true(sounds[event].get_length() > 0, event)
	assert_eq(loader.load_sounds("unknown"), {})
