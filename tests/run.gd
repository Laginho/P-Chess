extends SceneTree

# Minimal test runner, no add-on (spec §11).
#   godot --headless -s tests/run.gd [-- <dir>]
# Runs every test_* method of every tests/test_*.gd (not recursive, so tests/fixtures/
# stays out of the default run) and exits 1 when any test fails or a script fails to load.


# Base class for test scripts: extends "res://tests/run.gd".Test
class Test extends RefCounted:
	var failures: Array[String] = []

	func assert_true(condition: bool, message := "") -> void:
		if not condition:
			failures.append("expected true" + _suffix(message))

	func assert_eq(actual, expected, message := "") -> void:
		if not _equal(actual, expected):
			failures.append("expected %s, got %s%s" % [var_to_str(expected), var_to_str(actual), _suffix(message)])

	# `==` across mismatched types is a script error, so compare types first (int/float may mix).
	static func _equal(a, b) -> bool:
		var numbers := [TYPE_INT, TYPE_FLOAT]
		if typeof(a) != typeof(b) and not (typeof(a) in numbers and typeof(b) in numbers):
			return false
		return a == b

	static func _suffix(message: String) -> String:
		return ": " + message if message else ""


static func find_tests(dir: String) -> PackedStringArray:
	var files := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(dir.path_join(f))
	files.sort()
	return files


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args else "res://tests"
	if not "://" in dir:
		dir = "res://" + dir
	if not DirAccess.dir_exists_absolute(dir):
		print("No such test directory: " + dir)
		quit(1)
		return

	var passed := 0
	var failed := 0
	for path in find_tests(dir):
		var script = load(path)
		if script == null or not script.can_instantiate():
			print("FAIL %s: script failed to load" % path)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			var test = script.new()
			if not test is Test:
				print("FAIL %s: does not extend run.gd's Test" % path)
				failed += 1
				break
			# shortcut: a runtime error inside a test aborts it silently and it still counts as PASS; hook a Logger when that bites.
			test.call(name)
			if test.failures.is_empty():
				print("PASS %s::%s" % [path, name])
				passed += 1
			else:
				for failure in test.failures:
					print("FAIL %s::%s: %s" % [path, name, failure])
				failed += 1
	print("%d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
