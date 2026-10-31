extends "res://tests/run.gd".Test

# The settings store (UI-005, §10): user://settings.cfg through ConfigFile. Each test uses its own
# file under user://, removed first, so a real settings.cfg is never touched. The last test checks
# that Maia reads the bot settings it is given.

const Settings = preload("res://core/settings.gd")
const Game = preload("res://core/game.gd")
const MaiaPlayer = preload("res://bot/maia_player.gd")
const ThemeLoader = preload("res://ui/theme_loader.gd")
const PATH := "user://test_settings.cfg"


func _fresh() -> String:
	DirAccess.remove_absolute(PATH)
	return PATH


func test_board_size_defaults_round_trips_and_rejects_invalid_values():
	var store = Settings.new(_fresh())
	assert_eq(store.get_value("board_size"), 0, "zero means fit to window")
	assert_true(store.set_value("board_size", 480))
	assert_eq(Settings.new(PATH).get_value("board_size"), 480)
	assert_true(not store.set_value("board_size", -1))
	var file := ConfigFile.new()
	file.set_value("settings", "board_size", -1)
	file.save(PATH)
	assert_eq(Settings.new(PATH).get_value("board_size"), 0)


func test_a_missing_file_gives_the_spec_defaults():
	var settings = Settings.new(_fresh())
	assert_eq(settings.get_value("legal_dots"), true)
	assert_eq(settings.get_value("animation_ms"), 120)
	assert_eq(settings.get_value("board_theme"), "brown")
	assert_eq(settings.get_value("piece_theme"), "cburnett")
	assert_eq(settings.get_value("sound_theme"), "sfx")
	assert_eq(settings.get_value("volume"), 20)
	assert_eq(settings.get_value("tau"), 0.02)
	assert_eq(settings.get_value("temperature"), 1.0)
	assert_eq(settings.get_value("panic"), "medium")
	assert_eq(settings.get_value("auto_claim"), true)


func test_a_change_is_saved_and_read_back_by_a_new_store():
	var settings = Settings.new(_fresh())
	var changes := []
	settings.changed.connect(func(key, value): changes.append([key, value]))
	assert_true(settings.set_value("animation_ms", 0), "0 ms is allowed")
	assert_true(settings.set_value("legal_dots", false))
	assert_true(settings.set_value("panic", "high"))
	assert_true(settings.set_value("tau", 0.05))
	assert_eq(changes, [["animation_ms", 0], ["legal_dots", false], ["panic", "high"], ["tau", 0.05]],
			"each change is announced, so it applies without a restart")
	var reloaded = Settings.new(PATH)
	assert_eq(reloaded.get_value("animation_ms"), 0)
	assert_eq(reloaded.get_value("legal_dots"), false)
	assert_eq(reloaded.get_value("panic"), "high")
	assert_eq(reloaded.get_value("tau"), 0.05)
	assert_eq(reloaded.get_value("volume"), 20, "untouched settings keep their default")


func test_saved_volume_is_kept_across_its_range():
	var settings = Settings.new(_fresh())
	for volume in [0, 50, 100]:
		assert_true(settings.set_value("volume", volume))
		assert_eq(Settings.new(PATH).get_value("volume"), volume)


func test_an_out_of_range_change_is_refused():
	var settings = Settings.new(_fresh())
	assert_true(not settings.set_value("volume", 150))
	assert_true(not settings.set_value("animation_ms", -1))
	assert_true(not settings.set_value("panic", "extreme"))
	assert_true(not settings.set_value("legal_dots", "yes"))
	assert_eq(settings.get_value("volume"), 20)
	assert_eq(settings.get_value("animation_ms"), 120)
	assert_eq(settings.get_value("panic"), "medium")
	assert_eq(settings.get_value("legal_dots"), true)


func test_a_bad_value_in_the_file_falls_back_to_its_default_and_keeps_the_rest():
	var file := ConfigFile.new()
	file.set_value("settings", "volume", 400)
	file.set_value("settings", "temperature", "hot")
	file.set_value("settings", "panic", "extreme")
	file.set_value("settings", "animation_ms", -50)
	file.set_value("settings", "board_theme", 7)
	file.set_value("settings", "tau", 0.05)
	file.save(_fresh())
	var settings = Settings.new(PATH)
	assert_eq(settings.get_value("volume"), 20)
	assert_eq(settings.get_value("temperature"), 1.0)
	assert_eq(settings.get_value("panic"), "medium")
	assert_eq(settings.get_value("animation_ms"), 120)
	assert_eq(settings.get_value("board_theme"), "brown")
	assert_eq(settings.get_value("tau"), 0.05, "the good value stays")


# The bundled themes are tracked, so this does not hang on what a checkout happens to hold: a
# nonsense name can never exist, and `piano` always does.
func test_a_saved_theme_that_no_longer_exists_falls_back_to_its_default():
	var file := ConfigFile.new()
	file.set_value("settings", "sound_theme", "deleted-or-misspelled")
	file.set_value("settings", "board_theme", "deleted-or-misspelled")
	file.set_value("settings", "piece_theme", "deleted-or-misspelled")
	file.save(_fresh())
	var settings = Settings.new(PATH)
	assert_eq(settings.get_value("sound_theme"), "sfx")
	assert_eq(settings.get_value("board_theme"), "brown")
	assert_eq(settings.get_value("piece_theme"), "cburnett")
	assert_eq(ThemeLoader.new().load_sounds(settings.get_value("sound_theme")).size(),
			ThemeLoader.SOUND_EVENTS.size(), "the default sounds load, so nothing goes silent")
	assert_true(not settings.set_value("sound_theme", "deleted-or-misspelled"))
	file.set_value("settings", "sound_theme", "piano")
	file.save(PATH)
	assert_eq(Settings.new(PATH).get_value("sound_theme"), "piano", "a theme that exists is kept")


func test_a_corrupt_file_gives_the_defaults():
	var file := FileAccess.open(_fresh(), FileAccess.WRITE)
	file.store_string("[settings\nvolume = = ][ not a config file")
	file.close()
	# ConfigFile logs its own parse error, which the runner would count as a failure.
	Engine.print_error_messages = false
	var settings = Settings.new(PATH)
	Engine.print_error_messages = true
	assert_eq(settings.get_value("volume"), 20)
	assert_eq(settings.get_value("panic"), "medium")
	assert_true(settings.set_value("volume", 50), "and still saves over it")
	assert_eq(Settings.new(PATH).get_value("volume"), 50)


# Answers every request at once with the same policy, as uci.gd would.
class FakeBridge:
	signal policy_ready(policy: Dictionary)
	var policy := {}

	func request_policy(_start_fen: String, _moves: PackedStringArray) -> void:
		policy_ready.emit(policy)


# The moves Maia plays over 200 seeds, sorted; time_left and start_time in ms (0, 0: no clock).
func _played(maia, time_left := 0, start_time := 0) -> Array:
	var seen := {}
	maia.move_ready.connect(func(move): seen[move] = true)
	for seed_value in 200:
		maia.rng.seed = seed_value
		maia.think(Game.new(), time_left, start_time)
	var moves := seen.keys()
	moves.sort()
	return moves


func test_maia_reads_tau_temperature_and_panic():
	var bridge := FakeBridge.new()
	bridge.policy = {"e2e4": 0.9, "g1f3": 0.1}
	var maia = MaiaPlayer.new(bridge)
	assert_eq(_played(maia), ["e2e4", "g1f3"], "the defaults keep a 10% move")
	maia = MaiaPlayer.new(bridge)
	maia.tau = 0.2
	maia.panic = "off"
	assert_eq(_played(maia, 0, 60000), ["e2e4"], "tau 20% cuts it, and panic off leaves tau alone")
	maia = MaiaPlayer.new(bridge)
	maia.tau = 0.2
	maia.panic = "high"
	assert_eq(_played(maia, 60000, 60000), ["e2e4"], "no panic with the full clock")
	assert_eq(_played(maia, 0, 60000), ["e2e4", "g1f3"], "panic at 0 s drops tau to 0.2%")
	maia = MaiaPlayer.new(bridge)
	maia.tau = 0.0
	maia.temperature = 0.01
	assert_eq(_played(maia), ["e2e4"], "a cold temperature always plays the top move")

func test_history_tab_defaults_and_accepts_only_supported_tabs():
	var settings = Settings.new(_fresh())
	assert_eq(settings.get_value("history_tab"), "All")
	for tab in ["All", "1+0", "3+2", "5+0"]:
		assert_true(settings.set_value("history_tab", tab))
		assert_eq(Settings.new(PATH).get_value("history_tab"), tab)
	assert_true(not settings.set_value("history_tab", "other"))

func test_analysis_threads_defaults_and_choices():
	var settings = Settings.new(_fresh())
	assert_eq(settings.get_value("analysis_threads"), "Background")
	assert_true(settings.set_value("analysis_threads", "Max"))
	assert_eq(Settings.new(PATH).get_value("analysis_threads"), "Max")
	assert_true(not settings.set_value("analysis_threads", "other"))
