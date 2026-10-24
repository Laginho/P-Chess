extends Control

# A game against Maia (BOT-004): the setup screen, the board, the clocks (CLOCK-001), the move list
# and the result.

const Game = preload("res://core/game.gd")
const Clock = preload("res://core/clock.gd")
const SoundPlayer = preload("res://ui/sound_player.gd")
const UCI = preload("res://engine/uci.gd")
const MaiaPlayer = preload("res://bot/maia_player.gd")

var sound_player := SoundPlayer.new()
var uci := UCI.new()
var maia := MaiaPlayer.new(uci)
# "w" or "b".
var human := "w"
# The game's core/clock.gd; null until a game starts.
var clock

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
	get_window().min_size = Vector2i(800, 600)
	sound_player.name = "Sounds"
	add_child(sound_player)
	# In the tree, so its _process reads Lc0 every frame without blocking the UI.
	uci.name = "Engine"
	add_child(uci)
	board_view.game = Game.new()
	board_view.move_played.connect(_on_move_played)
	board_view.sound_requested.connect(sound_player.play)
	maia.move_ready.connect(board_view.play)
	setup.started.connect(_start)
	if not uci.start():
		setup.show_missing(uci.error)
	elif not FileAccess.file_exists(MaiaPlayer.net_path(setup.LEVELS[0])):
		setup.show_missing("The Maia nets are missing from engine/weights. Run scripts/fetch-engine.ps1 to download them.")


func _process(_delta: float) -> void:
	if clock:
		clock.tick()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event.keycode == KEY_F:
		_set_flipped(not board_view.flipped)


func _start(colour: String, level: String, control: String) -> void:
	setup.hide()
	human = colour
	uci.set_level(MaiaPlayer.net_path(level))
	board_view.game = Game.new()
	clock = Clock.new(control, Time.get_ticks_msec)
	clock.flagged.connect(_on_flagged)
	clock.low_time.connect(func(side: String) -> void:
		if side == human:
			sound_player.play("low_time"))
	white_clock.clock = clock
	black_clock.clock = clock
	_set_flipped(human == "b")
	sound_player.play("game_start")
	_next_turn()


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


func _on_move_played(san: String) -> void:
	move_list.add(san)
	var game = board_view.game
	if game.is_over():
		clock.stop()
		_show_result()
	else:
		# May flag, when the time ran out before the move landed.
		clock.moved("b" if game.board.side_to_move == "w" else "w")
	var balance := material_balance(board_view.game.board)
	white_material.text = _captured(balance.w, BLACK_GLYPHS) + _lead(balance.diff)
	black_material.text = _captured(balance.b, WHITE_GLYPHS) + _lead(-balance.diff)
	_next_turn()


# The clock has already stopped. Maia may still be thinking: its move then finds the game over.
func _on_flagged(side: String) -> void:
	board_view.game.flag(side)
	_show_result()


func _show_result() -> void:
	var game = board_view.game
	result_label.text = "%s, %s" % [game.result, game.reason]
	sound_player.play("game_end")
	print("Maia: median %.1f ms from your move to its move, over %d moves"
			% [maia.median_ms(), maia.latencies_ms.size()])


# While Maia is to move the board takes no input, so the human cannot hold one of its pieces when
# its move lands (BoardView.play does not drop a held piece).
func _next_turn() -> void:
	var game = board_view.game
	var maia_to_move: bool = not game.is_over() and game.board.side_to_move != human
	board_view.mouse_filter = MOUSE_FILTER_IGNORE if maia_to_move else MOUSE_FILTER_STOP
	if maia_to_move:
		maia.think(game)


static func _captured(roles: String, glyphs: Dictionary) -> String:
	var text := ""
	for role in roles:
		text += glyphs[role]
	return text


static func _lead(points: int) -> String:
	return " +%d" % points if points > 0 else ""
