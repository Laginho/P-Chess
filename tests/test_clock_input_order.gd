extends "res://tests/run.gd".Test

# CLOCK-002: real Main input, with time and the engine held at their external boundaries.
const MainScene = preload("res://ui/main.tscn")
const Clock = preload("res://core/clock.gd")
const SETTINGS := {"colour": "b", "level": "maia-1700", "control": "3+2", "opening": "Free"}


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
	var folder := "user://test_clock_input_order_%d" % Time.get_ticks_usec()
	main.history = main.History.new(folder)
	main.tree_exiting.connect(func():
		for subdir in [folder.path_join("games"), folder]:
			if DirAccess.dir_exists_absolute(subdir):
				for file in DirAccess.get_files_at(subdir):
					DirAccess.remove_absolute(subdir.path_join(file))
				DirAccess.remove_absolute(subdir))
	main.uci.free()
	main.uci = HeldEngine.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new("res://tests/fixtures/no_session_settings.cfg")
	# The runner is already deferred: add_child readies Main synchronously, as in test_session.
	Engine.get_main_loop().root.add_child(main)
	main.board_view.slide_seconds = 0
	main.sound_player.select_theme("__clock002_silent__")
	main._start(SETTINGS.duplicate())
	main.clock = Clock.new(SETTINGS.control, time.ms)
	main.clock.flagged.connect(main._on_flagged)
	main.clock.low_time.connect(func(side: String):
		if side == main.human:
			main.sound_player.play("low_time"))
	main.maia.clock = main.clock
	main.white_clock.clock = main.clock
	main.black_clock.clock = main.clock
	main.board_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	main.board_view.size = Vector2(800, 800)
	for move in ["f2f3", "e7e5", "g2g4"]:
		assert_true(main.board_view.play(move))
	return main


func _mouse(main, pressed: bool, square: String) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	# Dispatch the global input phase through Godot, off the controls to avoid a second GUI
	# delivery. Then deliver board-local GUI input, as test_session does. No frame ticks here.
	event.position = Vector2(-100, -100)
	main.get_viewport().push_input(event, true)
	event.position = main.board_view.square_position(square, 800, main.board_view.flipped) + Vector2(50, 50)
	main.board_view._gui_input(event)


func test_a_mating_drop_at_zero_loses_on_time_before_the_move_is_played():
	var time := FakeTime.new()
	var main = _session(time)
	var board = main.board_view
	var before: String = main.move_list.get_parsed_text()
	var played := []
	var sounds := []
	board.move_played.connect(func(san): played.append(san))
	board.sound_requested.connect(func(event): sounds.append(event))
	_mouse(main, true, "d8")
	assert_eq(board._drag_from, "d8", "the human is holding the queen")
	time.now = 180000
	_mouse(main, false, "h4")
	assert_eq([board.game.result, board.game.reason], ["1-0", "time"], "late Qh4# cannot rescue Black")
	assert_eq(board.game.moves, PackedStringArray(["f2f3", "e7e5", "g2g4"]))
	assert_eq(board.game.board.piece_at("d8"), "q", "the queen stays on its source square")
	assert_eq(board.game.board.piece_at("h4"), "")
	assert_eq(board._drag_from, "", "nothing remains held after the flag")
	assert_eq(played, [], "no move_played")
	assert_eq(sounds, [], "no move sound")
	assert_eq(main.move_list.get_parsed_text(), before, "no phantom SAN")
	main.free()
