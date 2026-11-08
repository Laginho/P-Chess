extends Control

# A game against Maia (BOT-004): Home, Custom game, the board, the clocks (CLOCK-001), the move list
# and the post-game review (HIST-002), then the hotkeys (UI-004, §9.2): Space rematch,
# Esc Esc resign, F11 focus.
# The settings screen (UI-005, §10) sits on top, and each setting applies the moment it changes.

const Game = preload("res://core/game.gd")
const Clock = preload("res://core/clock.gd")
const Tunables = preload("res://core/tunables.gd")
const SoundPlayer = preload("res://ui/sound_player.gd")
const UCI = preload("res://engine/uci.gd")
const Tablebase = preload("res://engine/tablebase.gd")
const MaiaPlayer = preload("res://bot/maia_player.gd")
const Settings = preload("res://core/settings.gd")
const SettingsScreen = preload("res://ui/settings.tscn")
const History = preload("res://core/history.gd")
const AnalysisQueue = preload("res://core/analysis_queue.gd")
const ReviewScreen = preload("res://ui/review.tscn")
const HistoryScreen = preload("res://ui/history_screen.tscn")
const Course = preload("res://core/course.gd")
const RatingDialog = preload("res://ui/rating_dialog.tscn")
const NameDialog = preload("res://ui/name_dialog.tscn")
const CourseMap = preload("res://ui/course_map.tscn")
const UnitPage = preload("res://ui/unit_page.tscn")
const TheoryPointer = preload("res://ui/theory_pointer.tscn")
const Solving = preload("res://ui/solving.tscn")
const Playout = preload("res://ui/playout.tscn")
const PassTest = preload("res://ui/pass_test.tscn")
const PlayoutJudge = preload("res://core/playout_judge.gd")

const WINNERS := {"1-0": "White wins", "0-1": "Black wins", "1/2-1/2": "Draw"}
const MIN_BOARD_SIZE := 320

var sound_player := SoundPlayer.new()
var uci := UCI.new()
var tablebase = Tablebase.new()
var maia := MaiaPlayer.new(uci)
# "w" or "b".
var human := "w"
# The game's core/clock.gd; null until a game starts.
var clock
# The current game's settings from the setup screen, colour as actually played.
var settings := {}
# The player's settings (§10), applied as they change.
var preferences := Settings.new()
# Their screen, over everything else; hidden during focused play.
var settings_screen := SettingsScreen.instantiate()
var review := ReviewScreen.instantiate()
var history_screen := HistoryScreen.instantiate()
var name_dialog := NameDialog.instantiate()
var rating_dialog := RatingDialog.instantiate()
var course = Course.new()
var course_map = CourseMap.instantiate()
var unit_page = UnitPage.instantiate()
var theory_pointer = TheoryPointer.instantiate()
var solving = Solving.instantiate()
var playout = Playout.instantiate()
var pass_test = PassTest.instantiate()
var _test_active := false
var _test_unit := {}
var _test_positions := []
var _test_results := []
var _test_playouts := []
var _review_active := false
var _review_unit := {}
var _review_positions := []
var _review_results := []
var _review_day := 0
var _playout_unit := {}
var _playout_index := 0
var _playout_active := false
var _playout_previous_fen := ""
var _playout_moves := 0
var _playout_flagged := ""
var _playout_generation := 0
var analysis_queue
var review_analysis_path := ""
var resign_key := ResignKey.new(Time.get_ticks_msec)
# Focus keeps the board, clocks and game actions visible.
var focus := false
var _playing_premove := false
var _draw_offered := false
var _draw_moves_left := 0
# Created at ready time so scene tests can supply isolated storage before any file is read.
var history
var _move_clocks := []
var _history_saved := false
var _recording_move := false
var _starting := false
var _review_repertoire: Array = []
var _review_repertoire_colour := ""
# Scores are half-points, attached to the players rather than board colours.
var _human_score := 0
var _maia_score := 0
var _match_games := 0
var _show_match_score := false
var _resign_style := StyleBoxFlat.new()
# Callables keep the real window transition observable on headless DisplayServers too.
var window_mode_get: Callable = DisplayServer.window_get_mode
var window_mode_set: Callable = DisplayServer.window_set_mode
var _window_mode_before_focus := DisplayServer.WINDOW_MODE_WINDOWED
var _notice_rect_before_focus := Rect2()


# Esc resigns on a second press within 2 s of the first (§7). The time source returns milliseconds.
class ResignKey:
	const WINDOW_MS := 2000

	var _now: Callable
	var _armed_at := -1

	func _init(time_source: Callable) -> void:
		_now = time_source

	# True when this press resigns; otherwise it arms the key, and the hint shows.
	func press() -> bool:
		if armed():
			_armed_at = -1
			return true
		_armed_at = _now.call()
		return false

	func armed() -> bool:
		return _armed_at >= 0 and _now.call() - _armed_at <= WINDOW_MS

@onready var board_view = $Layout/BoardView
@onready var move_list = $Layout/Side/MoveList
@onready var result_label: Label = $Layout/Side/Result
@onready var white_clock = $Layout/Side/WhiteClockRow/WhiteClock
@onready var black_clock = $Layout/Side/BlackClockRow/BlackClock
@onready var white_score: Label = $Layout/Side/WhiteClockRow/Score
@onready var black_score: Label = $Layout/Side/BlackClockRow/Score
@onready var setup = $Setup
@onready var resign_button: Button = $Layout/Side/Actions/ResignButton
@onready var draw_button: Button = $Layout/Side/Actions/DrawButton
@onready var draw_notice: Label = $Layout/Side/DrawNotice
@onready var draw_notice_timer: Timer = $Layout/Side/DrawNoticeTimer
@onready var claim_draw: Button = $Layout/Side/ClaimBox/ClaimDraw
@onready var searching = $Searching


# The same settings with the colours swapped.
static func rematch(played: Dictionary) -> Dictionary:
	var next := played.duplicate()
	next.colour = "b" if played.colour == "w" else "w"
	return next


func _ready() -> void:
	_resign_style.bg_color = Color("#c93230")
	_resign_style.set_corner_radius_all(8)
	_resign_style.set_content_margin_all(8)
	var side: Control = $Layout/Side
	var card := StyleBoxFlat.new()
	card.bg_color = Color("#2b2a27")
	card.border_color = Color("#45423d")
	card.set_border_width_all(1)
	card.set_corner_radius_all(10)
	side.draw.connect(func():
		side.draw_style_box(card, Rect2(Vector2.ZERO, side.size))
		# The canvas's rules under Maia's row, above the player's row and above Claim draw.
		var rules := [side.get_child(0).get_rect().end.y]
		for row in [side.get_child(-2), side.get_child(-1)]:
			if row.visible:
				rules.append(row.position.y)
		for y in rules:
			side.draw_line(Vector2(1, y), Vector2(side.size.x - 1, y), card.border_color))
	side.sort_children.connect(side.queue_redraw)
	# The canvas's ½ badge in front of the notice.
	draw_notice.draw.connect(func():
		draw_notice.draw_circle(Vector2(37, 20), 11, Color("#45423d"))
		draw_notice.draw_string(get_theme_font("font", "ExtraBoldText"), Vector2(26, 25), String.chr(189),
				HORIZONTAL_ALIGNMENT_CENTER, 22, 13))
	if history == null:
		history = History.new()
	get_window().min_size = Vector2i(800, 600)
	sound_player.name = "Sounds"
	add_child(sound_player)
	# In the tree, so its _process reads Lc0 every frame without blocking the UI.
	uci.name = "Engine"
	add_child(uci)
	tablebase.name = "Tablebase"
	add_child(tablebase)
	solving.probe = tablebase
	uci.stopped.connect(_on_engine_stopped)
	board_view.game = Game.new()
	board_view.move_played.connect(_on_move_played)
	board_view.sound_requested.connect(sound_player.play)
	maia.move_ready.connect(_on_maia_move)
	claim_draw.pressed.connect(func() -> void:
		if _playout_active:
			return
		board_view.game.claim_draw()
		_show_result())
	resign_button.pressed.connect(_resign)
	draw_button.pressed.connect(_offer_draw)
	$Layout/Side/Actions/NewGameButton.pressed.connect(func():
		if _test_active:
			_show_unit(_test_unit)
		else:
			_show_home())
	$Layout/Side/Actions/RematchButton.pressed.connect(func(): _start(rematch(settings)))
	draw_notice_timer.timeout.connect(func():
		draw_notice.hide())
	setup.started.connect(func(choice):
		var saved: Dictionary = choice.duplicate()
		saved.colour_choice = ["w", "b", "random"][setup.get_node("Center/Form/Colour").selected]
		_start(saved))
	$Home.configure(preferences, course)
	rating_dialog.name = "RatingDialog"
	add_child(rating_dialog)
	$Home.course_requested.connect(func():
		if course.rating().is_empty():
			rating_dialog.present(course)
		else:
			_show_course_map())
	$Home.continue_requested.connect(_continue_course)
	rating_dialog.saved.connect(_show_course_map)
	$Home.started.connect(_start)
	$Home.custom_requested.connect(_show_setup)
	$Home.history_requested.connect(_show_history)
	$Home.settings_requested.connect(func(): settings_screen.get_node("Panel").show())
	setup.get_node("Center/Form/Back").pressed.connect(_show_home)
	setup.get_node("OpeningPicker").catalog_ready.connect(func(_error):
		if history_screen.visible:
			history.book = setup.book
			history_screen._refresh())
	# The catalog takes seconds to parse: start it now so the first game does not wait for it.
	setup.get_node("OpeningPicker").ensure_catalog()
	$Layout.resized.connect(_fit_board)
	resized.connect(_fit_board)
	$Layout.sort_children.connect(func(): _place_focus_clocks.call_deferred())
	board_view.resized.connect(_place_focus_clocks)
	$FocusClocks.resized.connect(_place_focus_clocks)
	$FocusActions.resized.connect(_place_focus_clocks)
	$Layout/BoardView/ResizeGrip.size_requested.connect(_resize_board)
	_fit_board()
	if analysis_queue == null:
		analysis_queue = AnalysisQueue.new(null, history.queue_file())
	analysis_queue.maximum = preferences.get_value("analysis_threads") == "Max"
	add_child(analysis_queue)
	review.analysis_queue = analysis_queue
	review.own_game_probe = tablebase
	review.own_game_course = course
	var rook_unit = course._read_data("res://data/course/rook-endgames.json")
	if rook_unit is Dictionary:
		review.own_game_unit = rook_unit
	history_screen.analysis_queue = analysis_queue
	settings_screen.store = preferences
	review.settings_panel = settings_screen.get_node("Panel")
	add_child(review)
	add_child(settings_screen)
	review.visibility_changed.connect(func(): settings_screen.visible = not focus or review.visible)
	review.get_node("Margin/Content/ReviewBody/BoardView").sound_requested.connect(sound_player.play)
	add_child(history_screen)
	add_child(course_map)
	add_child(unit_page)
	add_child(theory_pointer)
	add_child(solving)
	add_child(playout)
	add_child(pass_test)
	pass_test.back_requested.connect(func(): _show_unit(_test_unit))
	pass_test.start_requested.connect(_begin_test)
	pass_test.retry_requested.connect(func():
		if _test_active:
			pass_test.hide()
			_start_test_playout()
		else:
			_begin_test())
	solving.test_graded.connect(_test_position_graded)
	playout.back_requested.connect(func(): _show_unit(_playout_unit))
	playout.start_requested.connect(_start_playout)
	playout.retry_requested.connect(func(): _show_playout(_playout_index))
	playout.next_requested.connect(func(): _show_playout(_playout_index + 1))
	course_map.back_requested.connect(_show_home)
	course_map.unit_requested.connect(_show_unit)
	course_map.edit_requested.connect(_edit_course_rating)
	unit_page.back_requested.connect(_show_course_map)
	unit_page.part_requested.connect(_show_course_part)
	theory_pointer.back_requested.connect(func(): _show_unit(theory_pointer.unit))
	solving.back_requested.connect(func(): _show_unit(solving.unit))
	theory_pointer.solving_requested.connect(func(selected):
		_show_unit(selected)
		unit_page.part_requested.emit(selected, "solving"))
	add_child(name_dialog)
	history_screen.back_requested.connect(_show_home)
	history_screen.review_requested.connect(_review_history_game)
	review.back_history_requested.connect(_show_history)
	review.unit_requested.connect(func(unit: Dictionary):
		review.hide()
		history_screen.hide()
		$Home.hide()
		setup.hide()
		_show_unit(unit))
	review.rematch_requested.connect(func(): _start(rematch(settings)))
	review.setup_requested.connect(_show_home)
	preferences.changed.connect(_apply)
	for key in Settings.DEFAULTS:
		_apply(key, preferences.get_value(key))
	if not uci.start():
		setup.show_missing(uci.error)
		$Home.show_missing(uci.error)
	elif not FileAccess.file_exists(MaiaPlayer.net_path(setup.LEVELS[0])):
		setup.show_missing("The Maia nets are missing from engine/weights. Run scripts/fetch-engine.ps1 to download them.")
		$Home.show_missing("The Maia nets are missing from engine/weights.")
	name_dialog.present(preferences)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#1f1e1c"))


func _process(_delta: float) -> void:
	if clock:
		clock.tick()
	_update_resign_button()


func _update_resign_button() -> void:
	var confirming: bool = clock != null and not board_view.game.is_over() and resign_key.armed()
	var bar: ProgressBar = resign_button.get_node("Bar")
	bar.visible = confirming
	if confirming:
		bar.value = maxf(0, 2000 - (resign_key._now.call() - resign_key._armed_at))
	# Restyled only when the state flips, not every frame.
	var resign_text := "Click again to resign" if confirming else ("" if focus else "Resign")
	if resign_button.text != resign_text:
		resign_button.text = resign_text
		# Focus mode: the square widens to one line rather than wrapping inside 44 px.
		resign_button.clip_text = confirming and not focus
		resign_button.add_theme_font_override("font", get_theme_font("font", "BoldText" if confirming else "SemiboldText"))
		if focus:
			# Godot's minimum size leaves out an expanded icon, which this button still draws beside the label.
			var label := resign_button.get_theme_font("font").get_string_size(resign_text, HORIZONTAL_ALIGNMENT_LEFT, -1, resign_button.get_theme_font_size("font_size")).x
			resign_button.custom_minimum_size.x = label + 18 + 8 + 32 if confirming else 44.0
		for state in ["normal", "hover"]:
			if confirming:
				resign_button.add_theme_stylebox_override(state, _resign_style)
			else:
				resign_button.remove_theme_stylebox_override(state)


# Global input runs before GUI input: a flag or low-time warning must precede the drop
# and its increment, even when the threshold was crossed since the last frame tick.
func _input(_event: InputEvent) -> void:
	if clock:
		clock.tick()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if _playout_active or playout.visible:
		return
	if event.keycode == KEY_COMMA and event.ctrl_pressed:
		if settings_screen.visible and not _covers_settings():
			settings_screen.get_node("Panel").show()
		return
	if clock == null or _starting:
		return
	# Home and Custom game have no clock; game hotkeys apply only after a game starts.
	var in_game: bool = clock != null and not board_view.game.is_over()
	match event.keycode:
		KEY_F:
			_set_flipped(not board_view.flipped)
		KEY_SPACE:
			if clock and not in_game:
				_start(rematch(settings))
		KEY_ESCAPE:
			_resign()
		KEY_F11:
			_set_focus(not focus)


# Ctrl+, must not open the panel behind a screen drawn above Settings.
func _covers_settings() -> bool:
	# Focus reparents the non-modal draw notice here; it must not block Settings.
	return get_children().slice(settings_screen.get_index() + 1).any(
			func(screen): return screen != draw_notice and (screen is Control or screen is Window) and screen.visible)


func _resign() -> void:
	if _playout_active or playout.visible:
		return
	if not settings_screen.get_node("Panel").visible and clock != null and not board_view.game.is_over() and resign_key.press():
		board_view.game.resign(human)
		_show_result()


func _offer_draw() -> void:
	if _playout_active or playout.visible:
		return
	if settings_screen.get_node("Panel").visible or clock == null or board_view.game.is_over() or draw_button.disabled:
		return
	_draw_offered = true
	_draw_moves_left = Tunables.DRAW_COOLDOWN_MOVES
	draw_button.disabled = true


func _start(new_settings: Dictionary) -> void:
	if _starting or not uci.error.is_empty():
		return
	_starting = true
	var started_at := Time.get_ticks_msec()
	searching.present(new_settings)
	searching.move_to_front()
	searching.grab_focus()
	if clock:
		clock.stop()
	$Home.hide()
	if not analysis_queue.current().is_empty():
		searching.status("Pausing analysis…")
		await get_tree().process_frame
	analysis_queue.pause()
	setup.hide()
	setup.get_node("OpeningPicker").hide()
	setup.get_node("RepertoireScreen/RepertoireImport").hide()
	review.hide()
	history_screen.hide()
	board_view.mouse_filter = MOUSE_FILTER_IGNORE
	while not analysis_queue.current().is_empty() and uci.error.is_empty():
		await get_tree().process_frame
	if not uci.error.is_empty():
		_starting = false
		searching.hide()
		analysis_queue.resume()
		if _playout_active:
			_playout_start_failed(uci.error)
		return
	searching.status("Loading Maia %s…" % new_settings.level.trim_prefix("maia-"))
	var ready := [false]
	var on_ready := func(): ready[0] = true
	uci.level_ready.connect(on_ready, CONNECT_ONE_SHOT)
	uci.set_level(MaiaPlayer.net_path(new_settings.level))
	while not ready[0] and uci.error.is_empty():
		await get_tree().process_frame
	if uci.level_ready.is_connected(on_ready):
		uci.level_ready.disconnect(on_ready)
	if not uci.error.is_empty():
		_starting = false
		searching.hide()
		analysis_queue.resume()
		if _playout_active:
			_playout_start_failed(uci.error)
		return
	searching.status("Preparing game…")
	var error := ""
	var practice_book = setup.book
	var review_repertoire: Array = []
	var review_repertoire_colour := ""
	var repertoire_name: String = new_settings.get("repertoire", "")
	var repertoire_mode: bool = new_settings.opening == "My repertoire"
	var repertoire_error := ""
	if repertoire_mode or not repertoire_name.is_empty():
		repertoire_error = setup.repertoire.load_saved(repertoire_name)
		if repertoire_mode or preferences.get_value("check_repertoire"):
			error = repertoire_error
		if repertoire_error.is_empty():
			# Snapshot even with checking off, so enabling it during play uses this PGN.
			review_repertoire = setup.repertoire.lines.duplicate(true)
			review_repertoire_colour = setup.repertoire.colour
		if repertoire_mode and error.is_empty():
			practice_book = setup.Book.new()
			practice_book.load_repertoire(setup.repertoire.lines, "b" if new_settings.colour == "w" else "w")
	if error.is_empty():
		error = await setup.get_node("OpeningPicker").ensure_catalog()
	# Settings stay live while the catalog loads; checking may now require the saved PGN.
	if error.is_empty() and (repertoire_mode or preferences.get_value("check_repertoire")):
		error = repertoire_error
	if error.is_empty() and new_settings.opening == "Catalog":
		error = setup.book.load_selection(new_settings.get("selection", ""))
	while error.is_empty() and uci.error.is_empty() and Time.get_ticks_msec() - started_at < 500:
		await get_tree().process_frame
	_starting = false
	searching.hide()
	if not uci.error.is_empty():
		analysis_queue.resume()
		if _playout_active:
			_playout_start_failed(uci.error)
		return
	if not error.is_empty():
		analysis_queue.resume()
		if _playout_active:
			_playout_start_failed(error)
			return
		setup.show()
		var status: Label = setup.get_node("Center/Form/Missing")
		status.text = error
		status.show()
		return
	setup.get_node("Center/Form/Missing").hide()
	if new_settings.has("colour_choice"):
		preferences.save_last_game(new_settings)
		new_settings = new_settings.duplicate()
		new_settings.erase("colour_choice")
	_move_clocks.clear()
	_history_saved = false
	if settings.is_empty() or new_settings != rematch(settings) or not board_view.game.is_over():
		_reset_match()
	settings = new_settings.duplicate()
	_review_repertoire = review_repertoire
	_review_repertoire_colour = review_repertoire_colour
	human = settings.colour
	_show_match_score = _match_games > 0
	white_score.visible = _show_match_score and not focus
	black_score.visible = _show_match_score and not focus
	_update_score_text()
	var game = Game.new(new_settings.get("start_fen", Game.START))
	maia.book = practice_book
	history.book = setup.book
	maia.begin_game(game, settings.opening, history.practice_counts(), "b" if human == "w" else "w")
	board_view.game = game
	board_view.human_side = human
	board_view.game.auto_claim = preferences.get_value("auto_claim")
	resign_key = ResignKey.new(Time.get_ticks_msec)
	move_list.reset()
	result_label.text = ""
	result_label.hide()
	claim_draw.disabled = true
	clock = Clock.new(settings.control, Time.get_ticks_msec)
	resign_button.disabled = false
	resign_button.visible = not _playout_active
	draw_button.visible = not _playout_active
	$Layout/Side/Actions/NewGameButton.hide()
	$Layout/Side/Actions/NewGameButton.text = "New game"
	$Layout/Side/Actions/RematchButton.hide()
	_draw_offered = false
	_draw_moves_left = 0
	draw_button.disabled = _playout_active
	draw_notice.hide()
	draw_notice_timer.stop()
	maia.clock = null if _playout_active else clock
	maia.control = settings.control
	maia.level = settings.level
	clock.flagged.connect(_on_flagged)
	clock.low_time.connect(func(side: String) -> void:
		if side == human:
			sound_player.play("low_time"))
	white_clock.clock = clock
	black_clock.clock = clock
	_set_flipped(human == "b")
	sound_player.play("game_start")
	_next_turn()


func _show_setup() -> void:
	$Home.hide()
	analysis_queue.resume()
	_reset_match()
	draw_button.disabled = true
	_draw_offered = false
	draw_notice.hide()
	draw_notice_timer.stop()
	resign_button.disabled = true
	review.hide()
	history_screen.hide()
	clock = null
	white_clock.clock = null
	black_clock.clock = null
	setup.show()


func _show_home() -> void:
	_test_active = false
	_review_active = false
	pass_test.hide()
	_cancel_playout()
	playout.hide()
	solving.hide()
	course_map.hide()
	unit_page.hide()
	_show_setup()
	_set_focus(false)
	setup.hide()
	$Home.sync_level()
	$Home.refresh_continue()
	$Home.show()


func _continue_course(target: Dictionary) -> void:
	var kind: String = target.get("kind", "rating")
	if kind == "rating":
		rating_dialog.present(course)
	elif kind == "done":
		_show_setup()
	elif kind == "review":
		if target.get("positions", []).size() != 3:
			return
		$Home.hide()
		_review_active = true
		_review_unit = target.unit
		_review_positions = target.positions
		_review_day = target.day
		_review_results = []
		solving.present_review(course, _review_unit, _review_positions, 0, preferences)
	else:
		$Home.hide()
		_show_course_part(target.unit, "solving" if kind == "from_game" else kind)


func _show_course_map() -> void:
	_test_active = false
	_review_active = false
	pass_test.hide()
	_cancel_playout()
	playout.hide()
	solving.hide()
	$Home.hide()
	setup.hide()
	unit_page.hide()
	course_map.present(course)


func _show_unit(unit: Dictionary) -> void:
	_test_active = false
	_review_active = false
	pass_test.hide()
	_cancel_playout()
	playout.hide()
	solving.hide()
	theory_pointer.hide()
	course_map.hide()
	unit_page.present(course, unit)


func _show_course_part(unit: Dictionary, part: String) -> void:
	if part == "theory":
		unit_page.hide()
		theory_pointer.present(course, unit)
	elif part == "solving" and not str(course.next_practice_position(unit).get("fen", "")).is_empty():
		unit_page.hide()
		solving.present(course, unit, preferences)
	elif part == "playouts" and not unit.get("playouts", []).is_empty():
		_playout_unit = unit
		var index := 0
		for i in unit.playouts.size():
			if not course.playout_passed(unit, unit.playouts[i]):
				index = i
				break
		_show_playout(index)
	elif part == "test":
		_test_unit = unit
		unit_page.hide()
		pass_test.present_start(course, unit)


func _begin_test() -> void:
	_test_positions = course.draw_test_positions(_test_unit)
	if _test_positions.size() != preload("res://core/tunables.gd").COURSE_TEST_POSITIONS or _test_unit.get("test_playouts", []).size() != 2:
		pass_test.details.text = "This unit does not have enough test positions."
		return
	_test_results = []
	_test_playouts = []
	_test_active = true
	pass_test.hide()
	solving.present_test(course, _test_unit, _test_positions, 0, preferences)


func _test_position_graded(position: Dictionary, grade: Dictionary) -> void:
	if _review_active:
		if not grade.solved and not course.record_review_check(_review_unit, _review_day, false, false):
			solving._show_error("Could not save your review check. Try Commit again.")
			return
		_review_results.append(bool(grade.solved))
		if _review_results.size() < _review_positions.size():
			solving.present_review(course, _review_unit, _review_positions, _review_results.size(), preferences)
		elif not course.record_review_check(_review_unit, _review_day, not _review_results.has(false)):
			_review_results.pop_back()
			solving._show_error("Could not save your review check. Try Commit again.")
		else:
			_show_unit(_review_unit)
		return
	if not _test_active:
		return
	var result := {"position": position, "solved": grade.solved}
	if not grade.solved:
		result.your_move = grade.plies[grade.failed_ply].san
		result.best_move = grade.correct[0].san if not grade.correct.is_empty() else "unavailable"
	_test_results.append(result)
	if _test_results.size() < _test_positions.size():
		solving.present_test(course, _test_unit, _test_positions, _test_results.size(), preferences)
	else:
		solving.hide()
		_start_test_playout()


func _start_test_playout() -> void:
	var position: Dictionary = _test_unit.test_playouts[_test_playouts.size()]
	_playout_unit = {"playouts": _test_unit.test_playouts}
	_playout_index = _test_playouts.size()
	_playout_active = true
	_playout_generation += 1
	_playout_previous_fen = position.fen
	_playout_moves = 0
	_playout_flagged = ""
	human = position.side
	settings = {"colour": human, "level": course.maia_level(), "control": "none", "opening": "Free", "start_fen": position.fen}
	board_view.game = Game.new(position.fen)
	board_view.human_side = human
	move_list.reset()
	result_label.text = "Pass test · %s · %s" % ["Convert" if position.goal == "convert" else "Hold", "No clock"]
	result_label.show()
	claim_draw.disabled = true
	resign_button.hide()
	draw_button.hide()
	$Layout/Side/Actions/NewGameButton.text = "Back to the unit"
	$Layout/Side/Actions/NewGameButton.show()
	$Layout/Side/Actions/RematchButton.hide()
	clock = Clock.new("none", Time.get_ticks_msec)
	clock.flagged.connect(_on_flagged)
	white_clock.clock = clock
	black_clock.clock = clock
	_set_flipped(human == "b")
	_next_turn()


func _finish_test_playout(passed: bool) -> void:
	_teardown_test_playout()
	_test_playouts.append(passed)
	if _test_playouts.size() < 2:
		_start_test_playout()
		return
	var date := Time.get_date_string_from_system()
	if not course.record_test_attempt(_test_unit, _test_results, _test_playouts, date):
		pass_test.present_start(course, _test_unit)
		pass_test.details.text = "Could not save your attempt. Please try again."
	else:
		pass_test.present_result(course.test_attempts(_test_unit).back())
	_test_active = false


func _test_playout_error(message: String) -> void:
	_teardown_test_playout()
	pass_test.present_error(message)


func _teardown_test_playout() -> void:
	_playout_generation += 1
	_playout_active = false
	clock.stop()
	clock = null
	white_clock.clock = null
	black_clock.clock = null
	board_view.cancel_premoves()
	board_view.mouse_filter = MOUSE_FILTER_IGNORE


func _cancel_playout() -> void:
	var leaving_game: bool = _playout_active or playout.visible
	_playout_generation += 1
	_playout_active = false
	if clock != null:
		clock.stop()
	if leaving_game:
		clock = null
		white_clock.clock = null
		black_clock.clock = null


func _show_playout(index: int) -> void:
	_cancel_playout()
	_playout_index = index
	unit_page.hide()
	playout.present_start(course, _playout_unit, index)


func _start_playout() -> void:
	if not uci.error.is_empty():
		_playout_start_failed(uci.error)
		return
	var position: Dictionary = _playout_unit.playouts[_playout_index]
	_playout_active = true
	_playout_generation += 1
	_playout_previous_fen = position.fen
	_playout_moves = 0
	_playout_flagged = ""
	playout.hide()
	_start({"colour": position.side, "level": course.maia_level(), "control": course.clock_choice(), "opening": "Free", "start_fen": position.fen})


func _playout_start_failed(message: String) -> void:
	_cancel_playout()
	playout.present_start(course, _playout_unit, _playout_index)
	playout.reason.text = message


func _finish_playout(title: String, message: String, failed_move := "") -> void:
	if _test_active:
		_finish_test_playout(title in ["Converted", "Held"])
		return
	_playout_generation += 1
	_playout_active = false
	clock.stop()
	board_view.cancel_premoves()
	board_view.mouse_filter = MOUSE_FILTER_IGNORE
	analysis_queue.resume()
	var position: Dictionary = _playout_unit.playouts[_playout_index]
	if title in ["Converted", "Held"] and not course.record_playout_pass(_playout_unit, position):
		title = "Play-out failed"
		message = "Could not save your pass. Please retry."
	playout.present_end(position, board_view.game, title, message, failed_move, _playout_index + 1 < _playout_unit.playouts.size())


func _edit_course_rating() -> void:
	course_map.hide()
	$Home.show()
	$Home._show_profile()
	var profile = $Home.get_node("Profile")
	profile.back_requested.connect(func(): _show_course_map())


func _show_history() -> void:
	review.hide()
	setup.hide()
	$Home.hide()
	history.book = setup.book if setup.get_node("OpeningPicker")._worker == null else null
	history_screen.present(history, preferences)


func _review_history_game(path: String, saved: Dictionary) -> void:
	var headers: Dictionary = saved.headers
	var colour: String = History.human_colour(headers)
	var game = Game.new()
	var clocks := []
	for move in saved.moves:
		game.play(move.uci)
		clocks.append(move.clock_ms)
	game.result = saved.result
	game.reason = history.reason(saved)
	var other: String = headers.get("Black" if colour == "w" else "White", "Maia 1500")
	var review_settings := {"colour": colour, "level": "maia-" + other.trim_prefix("Maia "), "control": "1+0"}
	var player_name: String = headers.get("White" if colour == "w" else "Black", "You")
	review_settings.player_name = preferences.get_value("player_name") if not headers.has("HumanColor") and player_name == "You" else player_name
	var snapshot: Dictionary = history.read_repertoire(path)
	review.present(game, clocks, review_settings, history_screen._result_text(saved, colour),
			setup.book.entries, snapshot.lines, not snapshot.lines.is_empty())
	history_screen.hide()
	var analysis_path: String = history.analysis_folder().path_join(path.get_file() + ".json")
	review.present_history(path, analysis_path, saved.result == "1/2-1/2")


# Abort without recording a chess result, and invalidate Maia's already scheduled moves.
func _on_engine_stopped() -> void:
	searching.hide()
	if clock:
		clock.stop()
	maia.clock = null
	maia.begin_game(null)
	board_view.cancel_premoves()
	board_view.mouse_filter = MOUSE_FILTER_IGNORE
	claim_draw.disabled = true
	resign_key = ResignKey.new(Time.get_ticks_msec)
	_show_home()
	setup.show_missing(uci.error)
	$Home.show_missing(uci.error)


# One setting to whatever reads it; the next move, sound or game picks it up.
func _apply(key: String, value) -> void:
	var review_board = review.get_node("Margin/Content/ReviewBody/BoardView")
	match key:
		"analysis_threads":
			analysis_queue.maximum = value == "Max"
		"premove_style":
			board_view.premove_style = value
		"click_click":
			board_view.click_click = value
			review_board.click_click = value
		"auto_queen":
			board_view.auto_queen = value
			review_board.auto_queen = value
		"legal_dots":
			board_view.show_targets = value
			review_board.show_targets = value
		"best_move_arrow":
			review.best_move_arrow_enabled = value
		"animation_ms":
			board_view.slide_seconds = value / 1000.0
			review_board.slide_seconds = value / 1000.0
		"board_theme":
			board_view.set_board_theme(value)
			review_board.set_board_theme(value)
		"piece_theme":
			board_view.set_piece_theme(value)
			review_board.set_piece_theme(value)
		"sound_theme":
			sound_player.select_theme(value)
		"volume":
			AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))
		"tau":
			maia.tau = value
		"temperature":
			maia.temperature = value
		"panic":
			maia.panic = value
		"book_intensity":
			maia.book_intensity = value
		"auto_claim":
			board_view.game.auto_claim = value
		"board_size":
			_fit_board()


# The board stays square and the side panel sits right next to it.
func _fit_board() -> void:
	var fit := _board_fit_size()
	var chosen: int = preferences.get_value("board_size")
	board_view.custom_minimum_size.x = fit if chosen == 0 else clampf(chosen, minf(MIN_BOARD_SIZE, fit), fit)
	var board_width: float = board_view.custom_minimum_size.x
	var width := minf($Layout.size.x, size.x - 80)
	$Layout/BoardOffset.custom_minimum_size.x = maxf(0, minf((width - board_width) / 2,
			width - board_width - 40 - $Layout/Side.get_combined_minimum_size().x))


func _board_fit_size() -> float:
	return maxf(0, minf(minf($Layout.size.y, size.y - 80),
			minf($Layout.size.x, size.x - 80) - $Layout/Side.get_combined_minimum_size().x - 40))


func _resize_board(side: int) -> void:
	var fit := _board_fit_size()
	preferences.set_value("board_size", 0 if side == 0 else roundi(clampf(side, minf(MIN_BOARD_SIZE, fit), fit)))


func _set_flipped(flipped: bool) -> void:
	board_view.flipped = flipped
	var bot = white_clock.get_parent() if human == "b" else black_clock.get_parent()
	var player = black_clock.get_parent() if human == "b" else white_clock.get_parent()
	bot.get_parent().move_child(bot, 0)
	player.get_parent().move_child(player, -1)
	$Layout/Side.move_child(claim_draw.get_parent(), -1)
	bot.get_node("Name").text = "Perfect opponent" if _test_active else "Maia"
	bot.get_node("Name/Colour").hide()
	# The player's name and colour centre as a pair; Maia's name alone.
	bot.get_node("Name").vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player.get_node("Name").vertical_alignment = VERTICAL_ALIGNMENT_TOP
	bot.get_node("Avatar").show()
	bot.get_node("Initial").hide()
	player.get_node("Name").text = preferences.get_value("player_name")
	player.get_node("Name/Colour").text = "White" if human == "w" else "Black"
	player.get_node("Name/Colour").show()
	player.get_node("Avatar").hide()
	player.get_node("Initial").show()
	player.get_node("Initial").text = preferences.get_value("player_name").left(1).to_upper()
	if focus:
		_set_focus(true)


func _set_focus(on: bool) -> void:
	if on != focus:
		if on:
			_notice_rect_before_focus = draw_notice.get_rect()
			_window_mode_before_focus = window_mode_get.call()
			window_mode_set.call(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			window_mode_set.call(_window_mode_before_focus)
		# Move the existing controls: cooldown, confirmation and notice timers keep running.
		for button in [draw_button, resign_button]:
			button.reparent($FocusActions if on else $Layout/Side/Actions, false)
			# Small icon squares beside the board; the resign confirmation widens only its own button.
			button.custom_minimum_size = Vector2(44, 44) if on else Vector2(0, 44)
			button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if on else Control.SIZE_EXPAND_FILL
		if not on:
			$Layout/Side/Actions.move_child(draw_button, 1)
			$Layout/Side/Actions.move_child(resign_button, 2)
		draw_notice.reparent(self if on else $Layout/Side, false)
		if not on:
			draw_notice.position = _notice_rect_before_focus.position
			draw_notice.size = _notice_rect_before_focus.size
		var destination: Node = $FocusClocks if on else $Layout/Side
		for row in [white_clock.get_parent(), black_clock.get_parent()]:
			row.reparent(destination, false)
		var bot = white_clock.get_parent() if human == "b" else black_clock.get_parent()
		var player = black_clock.get_parent() if human == "b" else white_clock.get_parent()
		destination.move_child(bot, 0)
		destination.move_child(player, -1)
		if not on:
			$Layout/Side.move_child(claim_draw.get_parent(), -1)
			$Layout/Side.move_child(draw_notice, 3)
	focus = on
	$Layout/Side.visible = not on
	$Layout/BoardOffset.visible = not on
	$Layout/BoardGap.visible = not on
	$Layout/BoardView/ResizeGrip.visible = not on
	$FocusClocks.visible = on
	$FocusActions.visible = on
	draw_button.text = String.chr(189) if on else String.chr(189) + "  Offer draw"
	_update_resign_button()
	_fit_board()
	_place_focus_clocks.call_deferred()
	for node in [move_list, claim_draw.get_parent(), $Layout/Side/Actions]:
		node.visible = not on
	settings_screen.visible = not on or review.visible
	# The game-over card shows the result; the side panel keeps only a history failure.
	result_label.visible = not on and result_label.text.contains("History: ")
	for row in [white_clock.get_parent(), black_clock.get_parent()]:
		row.get_node("Lead").visible = not on
		row.get_node("Name").visible = not on
		row.get_node("Avatar").visible = not on and row == (white_clock.get_parent() if human == "b" else black_clock.get_parent())
		row.get_node("Initial").visible = not on and row == (black_clock.get_parent() if human == "b" else white_clock.get_parent())
	white_score.visible = _show_match_score and not on
	black_score.visible = _show_match_score and not on


func _place_focus_clocks() -> void:
	if focus:
		var board: Rect2 = board_view.get_global_rect()
		$FocusClocks.size = $FocusClocks.get_combined_minimum_size()
		$FocusClocks.position = Vector2(board.position.x - $FocusClocks.size.x - 40,
				board.get_center().y - $FocusClocks.size.y / 2) - global_position
		$FocusActions.size = $FocusActions.get_combined_minimum_size()
		$FocusActions.position = Vector2(board.end.x + 40,
				board.get_center().y - $FocusActions.size.y / 2) - global_position
		draw_notice.size = Vector2(draw_notice.get_combined_minimum_size().x, 50)
		draw_notice.position = $FocusActions.position + Vector2(0, $FocusActions.size.y + 12)


# Like _input: Maia's think-time timer can fire after its clock hit zero but before the next
# frame tick, and the flag must precede the move.
func _on_maia_move(move: String) -> void:
	if clock:
		clock.tick()
	if clock == null or board_view.game.is_over():
		return
	if _draw_offered:
		_draw_offered = false
		var accepted := MaiaPlayer.accepts_draw(maia.evaluation, board_view.game.board,
				clock.left(board_view.game.board.side_to_move), Clock.CONTROLS[settings.control][0])
		draw_notice.text = "Draw agreed" if accepted else "Maia declined"
		draw_notice.show()
		draw_notice_timer.start()
		if accepted:
			board_view.game.agree_draw()
			_show_result()
			return
	board_view.play(move)


func _on_move_played(san: String) -> void:
	move_list.add(san)
	var game = board_view.game
	claim_draw.disabled = _playout_active or not game.can_claim_draw()
	var mover: String = "b" if game.board.side_to_move == "w" else "w"
	if mover == human and _draw_moves_left > 0:
		_draw_moves_left -= 1
		draw_button.disabled = _draw_moves_left > 0
	_recording_move = true
	if not _playing_premove:
		# May flag, when the time ran out before the move landed.
		# A terminal move keeps its existing result even if clock.moved emits a flag.
		clock.moved(mover)
	_move_clocks.append(clock.left(mover))
	_recording_move = false
	if _playout_active:
		if not _playout_flagged.is_empty():
			_finish_playout("Out of time" if _playout_flagged == human else "Play-out failed", "Your time ran out." if _playout_flagged == human else "Maia ran out of time.")
			return
		if mover == human:
			_playout_moves += 1
			var move: String = game.moves[-1]
			var previous := _playout_previous_fen
			var generation := _playout_generation
			board_view.mouse_filter = MOUSE_FILTER_IGNORE
			if tablebase.has_method("start"):
				tablebase.start()
			PlayoutJudge.new(tablebase).check(previous, move, _playout_unit.playouts[_playout_index].goal, _playout_moves, func(result: Dictionary):
				if not _playout_active or generation != _playout_generation:
					return
				if not result.get("ok", false):
					if _test_active:
						_test_playout_error(result.get("error", "Tablebase probe failed."))
					else:
						_finish_playout("Play-out failed", result.get("error", "Tablebase probe failed."))
				elif result.state == "failed":
					var before = preload("res://core/board.gd").from_fen(previous)
					var best: String = result.get("best", "")
					var correct: String = before.san(best) if not best.is_empty() else "unavailable"
					_finish_playout("Play-out failed", "✗ %s changed the result. %s kept it." % [san, correct], move)
				elif result.state == "passed":
					var converted: bool = _playout_unit.playouts[_playout_index].goal == "convert"
					_finish_playout("Converted" if converted else "Held", result.get("reason", "You kept the result."))
				elif game.is_over():
					_finish_ended_playout()
				else:
					_playout_previous_fen = game.board.to_fen()
					_next_turn())
			return
		_playout_previous_fen = game.board.to_fen()
		if game.is_over():
			_finish_ended_playout()
			return
	if game.is_over():
		_show_result()
	_next_turn()


# The judge kept the draw on every move of yours, so a drawn end holds it (spec L8).
func _finish_ended_playout() -> void:
	var game = board_view.game
	if game.result == "1/2-1/2" and _playout_unit.playouts[_playout_index].goal == "hold":
		_finish_playout("Held", "The game ended in a draw (%s)." % game.reason)
	else:
		_finish_playout("Play-out failed", "The game ended before the task was complete.")


# The clock has already stopped. Maia may still be thinking: its move then finds the game over.
func _on_flagged(side: String) -> void:
	board_view.game.flag(side)
	if _playout_active:
		_playout_flagged = side
		if not _recording_move:
			_finish_playout("Out of time" if side == human else "Play-out failed", "Your time ran out." if side == human else "Maia ran out of time.")
		return
	# A flag during move accounting must wait for that move's clock snapshot.
	if not _recording_move:
		_show_result()


# Every way a sandbox game ends lands here, after the game has its result.
func _show_result() -> void:
	if _playout_active or playout.visible:
		return
	analysis_queue.resume()
	draw_button.disabled = true
	draw_button.hide()
	_draw_offered = false
	resign_button.disabled = true
	resign_button.hide()
	$Layout/Side/Actions/NewGameButton.show()
	$Layout/Side/Actions/RematchButton.show()
	var game = board_view.game
	var named_settings := settings.duplicate()
	named_settings.player_name = preferences.get_value("player_name")
	board_view.cancel_premoves()
	clock.stop()
	claim_draw.disabled = true
	result_label.text = "%s by %s (%s)\nSpace for a rematch" % [WINNERS[game.result], game.reason, game.result]
	if not _history_saved:
		_match_games += 1
		if game.result == "1/2-1/2":
			_human_score += 1
			_maia_score += 1
		elif (game.result == "1-0") == (human == "w"):
			_human_score += 2
		else:
			_maia_score += 2
		_update_score_text()
		_history_saved = true
		var game_path: String = history.save(game, _move_clocks, named_settings, "", maia.target_id, _review_repertoire, _review_repertoire_colour)
		var name := game_path.get_file() if not game_path.is_empty() else "unsaved-%d.pgn" % Time.get_ticks_usec()
		review_analysis_path = history.analysis_folder().path_join(name + ".json")
	if history.error:
		result_label.text += "\nHistory: " + history.error
	result_label.visible = not focus and not history.error.is_empty()
	review.present(game, _move_clocks, named_settings, result_label.text,
			setup.book.entries, _review_repertoire, preferences.get_value("check_repertoire"))
	review.hide()
	var old_panel = board_view.get_node_or_null("GameOver")
	if old_panel:
		old_panel.free()
	var panel = load("res://ui/game_over.tscn").instantiate()
	board_view.add_child(panel)
	panel.present(self, game)
	sound_player.play("game_end")
	print("Maia: median %.1f ms from your move to Lc0's answer, over %d moves"
			% [maia.median_ms(), maia.latencies_ms.size()])


# Input stays available for human premoves while Maia thinks.
func _next_turn() -> void:
	var game = board_view.game
	var maia_to_move: bool = not game.is_over() and game.board.side_to_move != human
	board_view.mouse_filter = MOUSE_FILTER_STOP
	if maia_to_move:
		if _test_active and _playout_active:
			board_view.mouse_filter = MOUSE_FILTER_IGNORE
			var generation := _playout_generation
			if tablebase.has_method("start"):
				tablebase.start()
			tablebase.probe(game.board.to_fen(), func(answer: Dictionary):
				if not _playout_active or not _test_active or generation != _playout_generation:
					return
				var move: String = answer.get("best", "")
				if not answer.get("ok", false) or move not in game.board.legal_moves():
					_test_playout_error(answer.get("error", "Tablebase probe failed."))
				else:
					board_view.play(move))
			return
		var start_time: int = Clock.CONTROLS[settings.control][0] if Clock.CONTROLS.has(settings.control) else Clock.PLAY_OUT_CONTROLS[settings.control][0]
		maia.think(game, clock.left(game.board.side_to_move), start_time)
	elif not game.is_over():
		var move: String = board_view.premoves.take(game.board)
		if move:
			# Charge before playing: the increment or a mating move cannot rescue a flag.
			clock.moved(human, true)
			if not game.is_over():
				_playing_premove = true
				board_view.play(move, true)
				_playing_premove = false


func _update_score_text() -> void:
	white_score.text = _format_score(_human_score if human == "w" else _maia_score)
	black_score.text = _format_score(_human_score if human == "b" else _maia_score)


func _reset_match() -> void:
	_human_score = 0
	_maia_score = 0
	_match_games = 0


static func _format_score(half_points: int) -> String:
	var whole := half_points / 2
	return (str(whole) if whole > 0 or half_points == 0 else "") + (String.chr(0x00bd) if half_points % 2 else "")


func match_score_text() -> String:
	return "%s %s %s %s Maia %s" % [preferences.get_value("player_name"), _format_score(_human_score), String.chr(0x2013), _format_score(_maia_score), settings.level.trim_prefix("maia-")]
