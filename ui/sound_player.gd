extends Node

const ThemeLoader = preload("res://ui/theme_loader.gd")

@export var theme_name := "sfx"
var _players := {}


func _ready() -> void:
	select_theme(theme_name)


func select_theme(name: String) -> void:
	theme_name = name
	for player in _players.values():
		player.free()
	_players.clear()
	var streams := ThemeLoader.new().load_sounds(name)
	for event in streams:
		var player := AudioStreamPlayer.new()
		player.name = event
		player.stream = streams[event]
		player.max_polyphony = 4
		add_child(player)
		_players[event] = player


# Independent players let a move, promotion and check sound overlap.
# Unknown or missing events are silent, including a wholly missing theme.
func play(event: String) -> void:
	if _players.has(event):
		_players[event].play()
