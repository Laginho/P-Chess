extends "res://tests/run.gd".Test


func test_rating_round_trip_and_conversion():
	var path := "user://course_test_%d.json" % Time.get_ticks_usec()
	var script = load("res://core/course.gd")
	assert_true(script != null, "course module exists")
	if script == null:
		return
	var course = script.new(path)
	assert_eq(course.rating(), {})
	for example in [[1600, "chess.com", 1600, "maia-1900"], [1100, "lichess", 800, "maia-1100"], [1249, "chess.com", 1249, "maia-1500"], [1250, "chess.com", 1250, "maia-1600"], [2000, "chess.com", 2000, "maia-1900"]]:
		assert_true(course.save_rating(example[0], example[1]))
		course = script.new(path)
		assert_eq(course.rating(), {"number": example[0], "site": example[1]})
		assert_eq(course.chess_com_rating(), example[2])
		assert_eq(course.maia_level(), example[3])
	for invalid in [99, 3501, 1.5, "1400"]:
		assert_true(not course.save_rating(invalid, "chess.com"))
	assert_true(not course.save_rating(1400, "other"))
	DirAccess.remove_absolute(path)


func test_unreadable_progress_is_not_overwritten():
	var path := "user://course_bad_%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"units": {"valuable": true}')
	file = null
	var original := FileAccess.get_file_as_string(path)
	var script = load("res://core/course.gd")
	if script == null:
		assert_true(false, "course module exists")
		return
	var course = script.new(path)
	assert_eq(course.rating(), {})
	assert_true(not course.save_rating(1400, "lichess"))
	assert_eq(FileAccess.get_file_as_string(path), original)
	DirAccess.remove_absolute(path)


func test_existing_progress_survives_rating_change_and_read_failure():
	var folder := "user://course_existing_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("course.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"units":{"rook":{"mastered":true}},"clock":"none"}')
	file = null
	var course = load("res://core/course.gd").new(path)
	assert_true(course.save_rating(1400, "chess.com"))
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_eq(saved.get("units", {}).get("rook", {}).get("mastered"), true)
	assert_eq(saved.get("clock"), "none")
	DirAccess.remove_absolute(path)
	assert_eq(DirAccess.make_dir_absolute(path), OK)
	course = load("res://core/course.gd").new(path)
	assert_eq(course.rating(), {})
	assert_true(not course.save_rating(1400, "lichess"), "failed read cannot be replaced")
	assert_true(DirAccess.dir_exists_absolute(path))
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)


func test_stage_follows_converted_rating_and_loads_units():
	var path := "user://course_stage_%d.json" % Time.get_ticks_usec()
	var script = load("res://core/course.gd")
	var existing = script.new(path)
	assert_true(existing.has_method("stage"), "course selects a stage")
	if not existing.has_method("stage"):
		return
	var course = script.new(path, "res://tests/fixtures/course/course.json")
	assert_eq(course.stage(), {})
	assert_true(course.save_rating(1499, "lichess"))
	assert_eq(course.stage().get("name"), "Foundation")
	assert_eq(course.units().size(), 1)
	assert_eq(course.units()[0].get("title"), "Rook endings")
	assert_true(course.save_rating(1500, "lichess"))
	assert_eq(course.stage().get("name"), "Club")
	DirAccess.remove_absolute(path)


func test_unit_progress_and_status_are_derived_from_saved_work():
	var path := "user://course_progress_%d.json" % Time.get_ticks_usec()
	var script = load("res://core/course.gd")
	var course = script.new(path, "res://tests/fixtures/course/course.json")
	assert_true(course.has_method("unit_progress"), "course reports unit progress")
	if not course.has_method("unit_progress"):
		return
	var unit = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/course/rook.json"))
	var examples := [
		[{}, "new", [false, 0, 2, 0, "not taken"], "–"],
		[{"theory_opened": true, "practice": {"one": {"solved": true, "first_try": true}, "two": {"solved": false, "first_try": false}}, "playouts": {"a": true}, "test_attempts": [{"passed": false}]}, "in progress", [true, 1, 2, 1, "not passed"], "50% (1 of 2)"],
		[{"mastered_date": "2026-01-01", "test_attempts": [{"passed": true}]}, "mastered", [false, 0, 2, 0, "passed"], "–"],
		[{"mastered_date": "2026-01-01", "test_attempts": [{"passed": true}], "review_checks": [{"passed": false}]}, "needs review", [false, 0, 2, 0, "passed"], "–"],
		[{"mastered_date": "2026-01-01", "review_checks": [{"passed": false}, {"passed": true}]}, "mastered", [false, 0, 2, 0, "passed"], "–"]
	]
	for example in examples:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"units": {"rook": example[0]}}))
		file = null
		course = script.new(path, "res://tests/fixtures/course/course.json")
		var progress: Dictionary = course.unit_progress(unit)
		assert_eq(progress.status, example[1])
		assert_eq([progress.theory_done, progress.solved, progress.total, progress.playouts_passed, progress.test], example[2])
		assert_eq(progress.first_try, example[3])
	DirAccess.remove_absolute(path)


func test_clock_choice_persists_and_preserves_other_progress():
	var path := "user://course_clock_%d.json" % Time.get_ticks_usec()
	var script = load("res://core/course.gd")
	var course = script.new(path)
	assert_true(course.has_method("clock_choice"), "course exposes play-out clock")
	if not course.has_method("clock_choice"):
		return
	assert_eq(course.clock_choice(), "5+5")
	assert_true(course.save_rating(1600, "chess.com"))
	assert_true(course.save_clock_choice("none"))
	course = script.new(path)
	assert_eq(course.clock_choice(), "none")
	assert_eq(course.rating(), {"number": 1600, "site": "chess.com"})
	assert_true(not course.save_clock_choice("3+2"))
	assert_eq(course.clock_choice(), "none")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file = null
	assert_true(not course.save_clock_choice("5+5"))
	assert_eq(FileAccess.get_file_as_string(path), "{broken")
	DirAccess.remove_absolute(path)


func test_passed_test_and_failed_review_determine_mastery():
	var path := "user://course_mastery_%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"units": {"rook": {"test_attempts": [{"passed": true}], "review_checks": [{"missed": true}]}}}))
	file = null
	var course = load("res://core/course.gd").new(path, "res://tests/fixtures/course/course.json")
	var unit = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/course/rook.json"))
	assert_eq(course.unit_progress(unit).status, "needs review")
	assert_eq(course.unit_progress(unit).test, "passed")
	DirAccess.remove_absolute(path)


func test_pending_review_does_not_clear_failed_completed_review():
	var path := "user://course_review_%d.json" % Time.get_ticks_usec()
	var checks := [{"done": true, "missed": true}, {"done": false, "missed": false}]
	var unit = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/course/rook.json"))
	for example in [[checks, "needs review"], [[checks[0], {"done": true, "missed": false}], "mastered"], [[{"done": false, "passed": true}, checks[0], {"done": false, "passed": true}], "needs review"]]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"units": {"rook": {"mastered_date": "2026-11-01", "review_checks": example[0]}}}))
		file = null
		var course = load("res://core/course.gd").new(path, "res://tests/fixtures/course/course.json")
		assert_eq(course.unit_progress(unit).status, example[1])
	DirAccess.remove_absolute(path)


func test_failed_playout_is_in_progress():
	var path := "user://course_playout_%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"units":{"rook":{"playouts":{"a":false}}}}')
	file = null
	var course = load("res://core/course.gd").new(path, "res://tests/fixtures/course/course.json")
	var unit = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/course/rook.json"))
	assert_eq(course.unit_progress(unit).status, "in progress")
	assert_eq(course.unit_progress(unit).playouts_passed, 0)
	DirAccess.remove_absolute(path)


func test_missing_unit_files_are_not_listed():
	var path := "user://course_missing_unit_%d.json" % Time.get_ticks_usec()
	var course = load("res://core/course.gd").new(path, "res://tests/fixtures/course/missing.json")
	assert_true(course.save_rating(1500, "chess.com"))
	assert_eq(course.units().size(), 1)
	assert_eq(course.units()[0].id, "rook")
	DirAccess.remove_absolute(path)


func test_opening_theory_persists_without_losing_other_progress():
	var path := "user://course_theory_%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"rating": {"number": 1600, "site": "chess.com"}, "units": {"rook": {"practice": {"one": {"solved": true}}}, "other": {"theory_opened": true}}}))
	file = null
	var script = load("res://core/course.gd")
	var course = script.new(path)
	assert_true(course.has_method("open_theory"), "course records opening theory")
	if not course.has_method("open_theory"):
		DirAccess.remove_absolute(path)
		return
	var unit := {"id": "rook", "positions": [{"id": "one", "pool": "practice"}]}
	assert_true(course.open_theory(unit))
	course = script.new(path)
	assert_true(course.unit_progress(unit).theory_done)
	assert_eq(course.unit_progress(unit).solved, 1)
	assert_eq(course.rating(), {"number": 1600, "site": "chess.com"})
	assert_true(course.unit_progress({"id": "other"}).theory_done)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file = null
	assert_true(not course.open_theory(unit))
	assert_eq(FileAccess.get_file_as_string(path), "{broken")
	DirAccess.remove_absolute(path)
