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
const MaiaPlayer = preload("res://bot/maia_player.gd")
const Settings = preload("res://core/settings.gd")
const SettingsScreen = preload("res://ui/settings.tscn")
const History = preload("res://core/history.gd")
const AnalysisQueue = preload("res://core/analysis_queue.gd")
const ReviewScreen = preload("res://ui/review.tscn")
const HistoryScreen = preload("res://ui/history_screen.tscn")

const WINNERS := {"1-0": "White wins", "0-1": "Black wins", "1/2-1/2": "Draw"}
const MIN_BOARD_SIZE := 320

var sound_player := SoundPlayer.new()
var uci := UCI.new()
var maia := MaiaPlayer.new(uci)
# "w" or "b".
var human := "w"
# The game's core/clock.gd; null until a game starts.
var clock
# The current game's settings from the setup screen, colour as actually played.
var settings := {}
# The player's settings (§10), applied as they change.
var preferences := Settings.new()
# Their screen, over everything else; hidden in focus mode.
var settings_screen := SettingsScreen.instantiate()
var review := ReviewScreen.instantiate()
var history_screen := HistoryScreen.instantiate()
var analysis_queue
var review_analysis_path := ""
var resign_key := ResignKey.new(Time.get_ticks_msec)
# Only the board and the clocks show (§8.7).
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

# Lichess order and values (§8.4).
const VALUES := {"q": 9, "r": 5, "b": 3, "n": 3, "p": 1}
# Role -> glyph of a captured piece of each colour.
const WHITE_GLYPHS := {"q": "♕", "r": "♖", "b": "♗", "n": "♘", "p": "♙"}
const BLACK_GLYPHS := {"q": "♛", "r": "♜", "b": "♝", "n": "♞", "p": "♟"}

@onready var board_view = $Layout/BoardView
@onready var move_list = $Layout/Side/MoveList
@onready var result_label: Label = $Layout/Side/Result
@onready var white_material: Label = $Layout/Side/WhiteMaterial
@onready var black_material: Label = $Layout/Side/BlackMaterial
@onready var white_clock = $Layout/Side/WhiteClockRow/WhiteClock
@onready var black_clock = $Layout/Side/BlackClockRow/BlackClock
@onready var white_score: Label = $Layout/Side/WhiteClockRow/Score
@onready var black_score: Label = $Layout/Side/BlackClockRow/Score
@onready var setup = $Setup
@onready var resign_hint: Label = $Layout/Side/ResignHint
@onready var resign_button: Button = $Layout/Side/Actions/ResignButton
@onready var draw_button: Button = $Layout/Side/Actions/DrawButton
@onready var draw_notice: Label = $Layout/Side/DrawNotice
@onready var draw_notice_timer: Timer = $Layout/Side/DrawNoticeTimer
@onready var claim_draw: Button = $Layout/Side/ClaimDraw
@onready var searching = $Searching


# The same settings with the colours swapped.
static func rematch(played: Dictionary) -> Dictionary:
	var next := played.duplicate()
	next.colour = "b" if played.colour == "w" else "w"
	return next


# Per role, the side with more of it shows the surplus as captured: "w" and "b" hold those roles,
# queen first. "diff" is white's points minus black's, so a promotion counts the new piece, not the pawn.
static func material_balance(board) -> Dictionary:
	var balance := {"diff": 0, "w": "", "b": ""}
	for role in VALUES:
		var surplus: int = board.squares.count(role.to_upper()) - board.squares.count(role)
		balance.diff += surplus * VALUES[role]
		balance["w" if surplus > 0 else "b"] += role.repeat(absi(surplus))
	return balance


func _ready() -> void:
	if history == null:
		history = History.new()
	get_window().min_size = Vector2i(800, 600)
	sound_player.name = "Sounds"
	add_child(sound_player)
	# In the tree, so its _process reads Lc0 every frame without blocking the UI.
	uci.name = "Engine"
	add_child(uci)
	uci.stopped.connect(_on_engine_stopped)
	board_view.game = Game.new()
	board_view.move_played.connect(_on_move_played)
	board_view.sound_requested.connect(sound_player.play)
	maia.move_ready.connect(_on_maia_move)
	claim_draw.pressed.connect(func() -> void:
		board_view.game.claim_draw()
		_show_result())
	resign_button.pressed.connect(_resign)
	draw_button.pressed.connect(_offer_draw)
	draw_notice_timer.timeout.connect(draw_notice.hide)
	setup.started.connect(func(choice):
		var saved: Dictionary = choice.duplicate()
		saved.colour_choice = ["w", "b", "random"][setup.get_node("Center/Form/Colour").selected]
		_start(saved))
	$Home.configure(preferences)
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
	$Layout/BoardView/ResizeGrip.size_requested.connect(_resize_board)
	_fit_board()
	if analysis_queue == null:
		analysis_queue = AnalysisQueue.new()
	analysis_queue.maximum = preferences.get_value("analysis_threads") == "Max"
	add_child(analysis_queue)
	review.analysis_queue = analysis_queue
	history_screen.analysis_queue = analysis_queue
	settings_screen.store = preferences
	add_child(settings_screen)
	add_child(review)
	add_child(history_screen)
	history_screen.back_requested.connect(_show_home)
	history_screen.review_requested.connect(_review_history_game)
	review.back_history_requested.connect(_show_history)
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


func _process(_delta: float) -> void:
	if clock:
		clock.tick()
	resign_hint.visible = clock != null and not board_view.game.is_over() and resign_key.armed()


# Global input runs before GUI input: a flag or low-time warning must precede the drop
# and its increment, even when the threshold was crossed since the last frame tick.
func _input(_event: InputEvent) -> void:
	if clock:
		clock.tick()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or clock == null or _starting:
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


func _resign() -> void:
	if not settings_screen.get_node("Panel").visible and clock != null and not board_view.game.is_over() and resign_key.press():
		board_view.game.resign(human)
		_show_result()


func _offer_draw() -> void:
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
		return
	if not error.is_empty():
		analysis_queue.resume()
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
	var game = Game.new()
	maia.book = practice_book
	history.book = setup.book
	maia.begin_game(game, settings.opening, history.practice_counts(), "b" if human == "w" else "w")
	board_view.game = game
	board_view.human_side = human
	board_view.game.auto_claim = preferences.get_value("auto_claim")
	resign_key = ResignKey.new(Time.get_ticks_msec)
	move_list.reset()
	for label in [result_label, white_material, black_material]:
		label.text = ""
	claim_draw.disabled = true
	clock = Clock.new(settings.control, Time.get_ticks_msec)
	resign_button.disabled = false
	_draw_offered = false
	_draw_moves_left = 0
	draw_button.disabled = false
	draw_notice.hide()
	draw_notice_timer.stop()
	maia.clock = clock
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
	resign_hint.hide()
	review.hide()
	history_screen.hide()
	clock = null
	white_clock.clock = null
	black_clock.clock = null
	setup.show()


func _show_home() -> void:
	_show_setup()
	_set_focus(false)
	setup.hide()
	$Home.sync_level()
	$Home.show()


func _show_history() -> void:
	review.hide()
	setup.hide()
	$Home.hide()
	history.book = setup.book if setup.get_node("OpeningPicker")._worker == null else null
	history_screen.present(history, preferences)


func _review_history_game(path: String, saved: Dictionary) -> void:
	var headers: Dictionary = saved.headers
	var colour := "w" if headers.get("White", "") == "You" else "b"
	var game = Game.new()
	var clocks := []
	for move in saved.moves:
		game.play(move.uci)
		clocks.append(move.clock_ms)
	game.result = saved.result
	game.reason = history.reason(saved)
	var other: String = headers.get("Black" if colour == "w" else "White", "Maia 1500")
	var review_settings := {"colour": colour, "level": "maia-" + other.trim_prefix("Maia "), "control": "1+0"}
	var snapshot: Dictionary = history.read_repertoire(path)
	review.present(game, clocks, review_settings, history_screen._result_text(saved, colour),
			setup.book.entries, snapshot.lines, not snapshot.lines.is_empty())
	history_screen.hide()
	var analysis_path := "user://analysis".path_join(path.get_file() + ".json")
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
	match key:
		"analysis_threads":
			analysis_queue.maximum = value == "Max"
		"premove_style":
			board_view.premove_style = value
		"click_click":
			board_view.click_click = value
		"auto_queen":
			board_view.auto_queen = value
		"legal_dots":
			board_view.show_targets = value
		"animation_ms":
			board_view.slide_seconds = value / 1000.0
		"board_theme":
			board_view.set_board_theme(value)
		"piece_theme":
			board_view.set_piece_theme(value)
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


func _board_fit_size() -> float:
	return maxf(0, minf($Layout.size.y,
			$Layout.size.x - $Layout/Side.get_combined_minimum_size().x - 16))


func _resize_board(side: int) -> void:
	var fit := _board_fit_size()
	preferences.set_value("board_size", 0 if side == 0 else roundi(clampf(side, minf(MIN_BOARD_SIZE, fit), fit)))


func _set_flipped(flipped: bool) -> void:
	board_view.flipped = flipped
	# Each side's clock and material sit on that side's edge of the board, the clock outermost.
	var top := [white_clock.get_parent(), white_material] if flipped else [black_clock.get_parent(), black_material]
	var bottom := [black_material, black_clock.get_parent()] if flipped else [white_material, white_clock.get_parent()]
	var side_panel := white_material.get_parent()
	for i in top.size():
		side_panel.move_child(top[i], i)
	for node in bottom:
		side_panel.move_child(node, -1)


func _set_focus(on: bool) -> void:
	focus = on
	# The Esc hint and the result stay out of this list: criteria 4 and 2 show them when they apply,
	# and the result is empty during play.
	for node in [move_list, white_material, black_material, claim_draw, $Layout/Side/Actions, settings_screen]:
		node.visible = not on
	white_score.visible = _show_match_score and not on
	black_score.visible = _show_match_score and not on


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
	claim_draw.disabled = not game.can_claim_draw()
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
	if game.is_over():
		_show_result()
	var balance := material_balance(board_view.game.board)
	white_material.text = _captured(balance.w, BLACK_GLYPHS) + _lead(balance.diff)
	black_material.text = _captured(balance.b, WHITE_GLYPHS) + _lead(-balance.diff)
	_next_turn()


# The clock has already stopped. Maia may still be thinking: its move then finds the game over.
func _on_flagged(side: String) -> void:
	board_view.game.flag(side)
	# A flag during move accounting must wait for that move's clock snapshot.
	if not _recording_move:
		_show_result()


# Every way a game ends lands here, after the game has its result.
func _show_result() -> void:
	analysis_queue.resume()
	draw_button.disabled = true
	_draw_offered = false
	resign_button.disabled = true
	resign_hint.hide()
	var game = board_view.game
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
		var game_path: String = history.save(game, _move_clocks, settings, "", maia.target_id, _review_repertoire, _review_repertoire_colour)
		var name := game_path.get_file() if not game_path.is_empty() else "unsaved-%d.pgn" % Time.get_ticks_usec()
		review_analysis_path = "user://analysis".path_join(name + ".json")
	if history.error:
		result_label.text += "\nHistory: " + history.error
	review.present(game, _move_clocks, settings, result_label.text,
			setup.book.entries, _review_repertoire, preferences.get_value("check_repertoire"))
	review.hide()
	var old_panel = board_view.get_node_or_null("GameOver")
	if old_panel:
		old_panel.free()
	var panel = load("res://ui/game_over.tscn").instantiate()
	board_view.add_child(panel)
	panel.present(self, game, $Layout/Side/ReviewButton)
	sound_player.play("game_end")
	print("Maia: median %.1f ms from your move to Lc0's answer, over %d moves"
			% [maia.median_ms(), maia.latencies_ms.size()])


# Input stays available for human premoves while Maia thinks.
func _next_turn() -> void:
	var game = board_view.game
	var maia_to_move: bool = not game.is_over() and game.board.side_to_move != human
	board_view.mouse_filter = MOUSE_FILTER_STOP
	if maia_to_move:
		maia.think(game, clock.left(game.board.side_to_move), Clock.CONTROLS[settings.control][0])
	elif not game.is_over():
		var move: String = board_view.premoves.take(game.board)
		if move:
			# Charge before playing: the increment or a mating move cannot rescue a flag.
			clock.moved(human, true)
			if not game.is_over():
				_playing_premove = true
				board_view.play(move, true)
				_playing_premove = false


static func _captured(roles: String, glyphs: Dictionary) -> String:
	var text := ""
	for role in roles:
		text += glyphs[role]
	return text


static func _lead(points: int) -> String:
	return " +%d" % points if points > 0 else ""


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
	return "You %s %s %s Maia %s" % [_format_score(_human_score), String.chr(0x2013), _format_score(_maia_score), settings.level.trim_prefix("maia-")]
