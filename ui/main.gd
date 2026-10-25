extends Control

# A game against Maia (BOT-004): the setup screen, the board, the clocks (CLOCK-001), the move list
# and the post-game review (HIST-002), then the hotkeys (UI-004, §9.2): Space rematch,
# Esc Esc resign, F11 focus.
# The settings screen (UI-005, §10) sits on top, and each setting applies the moment it changes.

const Game = preload("res://core/game.gd")
const Clock = preload("res://core/clock.gd")
const SoundPlayer = preload("res://ui/sound_player.gd")
const UCI = preload("res://engine/uci.gd")
const MaiaPlayer = preload("res://bot/maia_player.gd")
const Settings = preload("res://core/settings.gd")
const SettingsScreen = preload("res://ui/settings.tscn")
const History = preload("res://core/history.gd")
const ReviewScreen = preload("res://ui/review.tscn")

const WINNERS := {"1-0": "White wins", "0-1": "Black wins", "1/2-1/2": "Draw"}

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
var resign_key := ResignKey.new(Time.get_ticks_msec)
# Only the board and the clocks show (§8.7).
var focus := false
var _playing_premove := false
# Created at ready time so scene tests can supply isolated storage before any file is read.
var history
var _move_clocks := []
var _history_saved := false
var _recording_move := false


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
@onready var white_clock = $Layout/Side/WhiteClock
@onready var black_clock = $Layout/Side/BlackClock
@onready var setup = $Setup
@onready var resign_hint: Label = $Layout/Side/ResignHint
@onready var claim_draw: Button = $Layout/Side/ClaimDraw


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
	board_view.game = Game.new()
	board_view.move_played.connect(_on_move_played)
	board_view.sound_requested.connect(sound_player.play)
	maia.move_ready.connect(_on_maia_move)
	claim_draw.pressed.connect(func() -> void:
		board_view.game.claim_draw()
		_show_result())
	setup.started.connect(_start)
	settings_screen.store = preferences
	add_child(settings_screen)
	add_child(review)
	review.rematch_requested.connect(func(): _start(rematch(settings)))
	review.setup_requested.connect(_show_setup)
	preferences.changed.connect(_apply)
	for key in Settings.DEFAULTS:
		_apply(key, preferences.get_value(key))
	if not uci.start():
		setup.show_missing(uci.error)
	elif not FileAccess.file_exists(MaiaPlayer.net_path(setup.LEVELS[0])):
		setup.show_missing("The Maia nets are missing from engine/weights. Run scripts/fetch-engine.ps1 to download them.")


func _process(_delta: float) -> void:
	if clock:
		clock.tick()
	resign_hint.visible = resign_key.armed()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	# No clock means no game has started: the setup screen is up.
	var in_game: bool = clock != null and not board_view.game.is_over()
	match event.keycode:
		KEY_F:
			_set_flipped(not board_view.flipped)
		KEY_SPACE:
			if clock and not in_game:
				_start(rematch(settings))
		KEY_ESCAPE:
			if in_game and resign_key.press():
				board_view.game.resign(human)
				_show_result()
		KEY_F11:
			_set_focus(not focus)


func _start(new_settings: Dictionary) -> void:
	setup.hide()
	review.hide()
	_move_clocks.clear()
	_history_saved = false
	settings = new_settings
	human = settings.colour
	uci.set_level(MaiaPlayer.net_path(settings.level))
	var game = Game.new()
	maia.begin_game(game)
	board_view.game = game
	board_view.human_side = human
	board_view.game.auto_claim = preferences.get_value("auto_claim")
	resign_key = ResignKey.new(Time.get_ticks_msec)
	move_list.reset()
	for label in [result_label, white_material, black_material]:
		label.text = ""
	claim_draw.disabled = true
	clock = Clock.new(settings.control, Time.get_ticks_msec)
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
	review.hide()
	clock = null
	white_clock.clock = null
	black_clock.clock = null
	setup.show()


# One setting to whatever reads it; the next move, sound or game picks it up.
func _apply(key: String, value) -> void:
	match key:
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
		"auto_claim":
			board_view.game.auto_claim = value


func _set_flipped(flipped: bool) -> void:
	board_view.flipped = flipped
	# Each side's clock and material sit on that side's edge of the board, the clock outermost.
	var top := [white_clock, white_material] if flipped else [black_clock, black_material]
	var bottom := [black_material, black_clock] if flipped else [white_material, white_clock]
	var side_panel := white_material.get_parent()
	for i in top.size():
		side_panel.move_child(top[i], i)
	for node in bottom:
		side_panel.move_child(node, -1)


func _set_focus(on: bool) -> void:
	focus = on
	# The Esc hint and the result stay out of this list: criteria 4 and 2 show them when they apply,
	# and the result is empty during play.
	for node in [move_list, white_material, black_material, claim_draw, settings_screen]:
		node.visible = not on


func _on_maia_move(move: String) -> void:
	board_view.play(move)


func _on_move_played(san: String) -> void:
	move_list.add(san)
	var game = board_view.game
	claim_draw.disabled = not game.can_claim_draw()
	var mover: String = "b" if game.board.side_to_move == "w" else "w"
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
	var game = board_view.game
	board_view.cancel_premoves()
	clock.stop()
	claim_draw.disabled = true
	result_label.text = "%s by %s (%s)\nSpace for a rematch" % [WINNERS[game.result], game.reason, game.result]
	if not _history_saved:
		_history_saved = true
		history.save(game, _move_clocks, settings)
	if history.error:
		result_label.text += "\nHistory: " + history.error
	review.present(game, _move_clocks, settings, result_label.text)
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
