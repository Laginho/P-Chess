extends RefCounted

# The player's settings (§10), in one ConfigFile section. A missing, corrupt or out-of-range value
# reads as its default, so a bad file never stops the app. Every accepted change is saved at once
# and announced through `changed`, which is how it takes effect without a restart.

signal changed(key: String, value)

const ThemeLoader = preload("res://ui/theme_loader.gd")

const SECTION := "settings"
# The settings whose features exist; later tickets add their own rows.
const DEFAULTS := {
	"click_click": false,
	"auto_queen": "off",
	"legal_dots": true,
	"animation_ms": 120,
	"board_theme": "brown",
	"piece_theme": "cburnett",
	# UI-003's default until Bruno picks one by ear.
	"sound_theme": "sfx",
	"volume": 100,
	"tau": 0.02,
	"temperature": 1.0,
	"panic": "medium",
	"auto_claim": true,
}
# Inclusive bounds of the numeric settings.
const RANGES := {"animation_ms": [0, 1000], "volume": [0, 100], "tau": [0.0, 0.2], "temperature": [0.1, 3.0]}
const CHOICES := {
	"panic": ["off", "low", "medium", "high"],
	"auto_queen": ["off", "on", "only on premoves"],
}
# Theme settings and the folder kind each names.
const THEMES := {"board_theme": "boards", "piece_theme": "pieces", "sound_theme": "sounds"}

var path: String
var _values := DEFAULTS.duplicate()


func _init(file := "user://settings.cfg") -> void:
	path = file
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	for key in DEFAULTS:
		var value = config.get_value(SECTION, key) if config.has_section_key(SECTION, key) else null
		if valid(key, value):
			_values[key] = type_convert(value, typeof(DEFAULTS[key]))


func get_value(key: String):
	return _values[key]


# False, with nothing changed, for an unknown key or a value out of range.
func set_value(key: String, value) -> bool:
	if not valid(key, value):
		return false
	_values[key] = type_convert(value, typeof(DEFAULTS[key]))
	var config := ConfigFile.new()
	for k in _values:
		config.set_value(SECTION, k, _values[k])
	config.save(path)
	changed.emit(key, _values[key])
	return true


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
	if CHOICES.has(key):
		return value in CHOICES[key]
	if THEMES.has(key):
		return ThemeLoader.new().list_themes(THEMES[key]).has(value)
	return true
