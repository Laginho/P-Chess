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
