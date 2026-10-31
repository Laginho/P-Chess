extends RefCounted

# The player's settings (§10), in the settings section beside the last game's choices. A bad preference
# reads as its default, so a bad file never stops the app. Every accepted change is saved at once
# and announced through `changed`, which is how it takes effect without a restart.

signal changed(key: String, value)

const ThemeLoader = preload("res://ui/theme_loader.gd")

const SECTION := "settings"
# The settings whose features exist; later tickets add their own rows.
const DEFAULTS := {
	"player_name": "You",
	"premove_style": "Chess.com",
	"click_click": false,
	"auto_queen": "off",
	"legal_dots": true,
	"animation_ms": 120,
	"board_theme": "brown",
	"piece_theme": "cburnett",
	# UI-003's default until Bruno picks one by ear.
	"sound_theme": "sfx",
	"volume": 20,
	"tau": 0.02,
	"temperature": 1.0,
	"panic": "medium",
	"book_intensity": "medium",
	"auto_claim": true,
	"check_repertoire": false,
	"board_size": 0, # 0 follows the window; positive values are pixels.
	"history_tab": "All",
	"analysis_threads": "Background",
}
# Inclusive bounds of the numeric settings.
const RANGES := {"animation_ms": [0, 1000], "volume": [0, 100], "tau": [0.0, 0.2], "temperature": [0.1, 3.0], "board_size": [0, 2147483647]}
const CHOICES := {
	"premove_style": ["off", "Lichess", "Chess.com"],
	"panic": ["off", "low", "medium", "high"],
	"book_intensity": ["weak", "medium", "strong"],
	"auto_queen": ["off", "on", "only on premoves"],
	"history_tab": ["All", "1+0", "3+2", "5+0"],
	"analysis_threads": ["Background", "Max"],
}
# Theme settings and the folder kind each names.
const THEMES := {"board_theme": "boards", "piece_theme": "pieces", "sound_theme": "sounds"}

var path: String
var _values := DEFAULTS.duplicate()
var _config := ConfigFile.new()


func _init(file := "user://settings.cfg") -> void:
	path = file
	if _config.load(path) != OK:
		_config = ConfigFile.new()
		return
	for key in DEFAULTS:
		var value = _config.get_value(SECTION, key) if _config.has_section_key(SECTION, key) else null
		if valid(key, value):
			_values[key] = type_convert(value, typeof(DEFAULTS[key]))


func get_value(key: String):
	return _values[key]


func has_player_name() -> bool:
	return _config.has_section_key(SECTION, "player_name") \
			and valid("player_name", _config.get_value(SECTION, "player_name"))


# False, with nothing changed, for an unknown key or a value out of range.
func set_value(key: String, value) -> bool:
	if not valid(key, value):
		return false
	_values[key] = type_convert(value, typeof(DEFAULTS[key]))
	for k in _values:
		if k == "player_name" and key != "player_name" and not has_player_name():
			continue
		_config.set_value(SECTION, k, _values[k])
	_config.save(path)
	changed.emit(key, _values[key])
	return true


func last_game() -> Dictionary:
	var value = _config.get_value("game", "last", {})
	return value.duplicate(true) if value is Dictionary else {}


func save_last_game(value: Dictionary) -> void:
	_config.set_value("game", "last", value.duplicate(true))
	_config.save(path)


# Numbers may be int or float; NaN fails both bounds. A theme must exist now, bundled or user's,
# or a deleted folder would leave the board unstyled or every sound silent.
static func valid(key: String, value) -> bool:
	if not DEFAULTS.has(key):
		return false
	var numbers := [TYPE_INT, TYPE_FLOAT]
	if typeof(DEFAULTS[key]) in numbers:
		return typeof(value) in numbers and value >= RANGES[key][0] and value <= RANGES[key][1]
	if typeof(value) != typeof(DEFAULTS[key]):
		return false
	if key == "player_name":
		return not value.strip_edges().is_empty()
	if CHOICES.has(key):
		return value in CHOICES[key]
	if THEMES.has(key):
		return ThemeLoader.new().list_themes(THEMES[key]).has(value)
	return true
