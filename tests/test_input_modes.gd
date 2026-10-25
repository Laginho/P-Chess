extends "res://tests/run.gd".Test

# UI-006: the promotion decision and the board's mouse input, using the real game and scenes.
const PromotionPicker = preload("res://ui/promotion_picker.gd")


func test_auto_queen_mode_premove_and_alt_decision():
	# Columns: ordinary, ordinary + Alt, premove, premove + Alt.
	var expected := {
		"off": [false, false, false, false],
		"on": [true, false, true, false],
		"only on premoves": [false, false, true, false],
	}
	var picker = PromotionPicker
	for mode in expected:
		var column := 0
		for premove in [false, true]:
			for alt in [false, true]:
				assert_eq(picker.should_auto_queen(mode, premove, alt), expected[mode][column],
						"%s premove=%s Alt=%s" % [mode, premove, alt])
				column += 1
