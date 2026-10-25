extends RichTextLabel

# The game's moves in SAN, one full move per line (§8.7).

var _plies := 0


func reset() -> void:
	clear()
	_plies = 0


func add(san: String) -> void:
	if _plies % 2 == 0:
		add_text("%s%d. %s" % ["\n" if _plies else "", _plies / 2 + 1, san])
	else:
		add_text("   " + san)
	_plies += 1
