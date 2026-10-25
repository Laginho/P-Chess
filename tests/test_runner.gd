extends "res://tests/run.gd".Test

# The runner tests itself: assert helpers in-process, exit codes through a child Godot.


func test_assert_eq_reports_unequal_values():
	var t = load("res://tests/run.gd").Test.new()
	t.assert_eq(4, 5)
	assert_eq(t.failures.size(), 1)
	assert_true("expected 5, got 4" in t.failures[0], t.failures[0])


func test_assert_eq_accepts_equal_values():
	var t = load("res://tests/run.gd").Test.new()
	t.assert_eq([1, "a"], [1, "a"])
	assert_eq(t.failures.size(), 0)


func test_assert_true_reports_false():
	var t = load("res://tests/run.gd").Test.new()
	t.assert_true(false)
	t.assert_true(true)
	assert_eq(t.failures.size(), 1)


func test_failing_fixture_exits_nonzero_and_names_the_failure():
	var run := _run("tests/fixtures/failing")
	assert_true(run.code != 0, "exit code %d" % run.code)
	assert_true("test_fail.gd" in run.output, run.output)
	assert_true("test_fails_on_purpose" in run.output, run.output)
	assert_true("expected 5, got 4" in run.output, run.output)


func test_passing_dir_exits_zero_and_runs_only_test_methods():
	var dir := _case("passing", """extends "res://tests/run.gd".Test
func test_ok():
	assert_true(true)
func test_also_ok():
	assert_eq(1, 1)
func helper():
	assert_true(false)
""")
	var run := _run(dir)
	assert_eq(run.code, 0)
	assert_true("2 passed, 0 failed" in run.output, run.output)


func test_unloadable_script_exits_nonzero():
	var dir := _case("broken", """extends "res://tests/run.gd".Test
func test_broken(:
""")
	var run := _run(dir)
	assert_true(run.code != 0, "exit code %d" % run.code)
	assert_true("test_case.gd" in run.output, run.output)


func test_script_error_in_a_test_fails_it():
	var dir := _case("erroring", """extends "res://tests/run.gd".Test
func test_errors():
	var empty := []
	assert_eq(empty[0], 1)
""")
	var run := _run(dir)
	assert_true(run.code != 0, "exit code %d" % run.code)
	assert_true("0 passed, 1 failed" in run.output, run.output)


func test_an_assert_after_an_await_counts():
	var dir := _case("awaiting", """extends "res://tests/run.gd".Test
func test_fails_after_a_timer():
	await Engine.get_main_loop().create_timer(0.05).timeout
	assert_true(false, "after the await")
""")
	var run := _run(dir)
	assert_true(run.code != 0, "exit code %d" % run.code)
	assert_true("after the await" in run.output, run.output)
	assert_true("0 passed, 1 failed" in run.output, run.output)


func test_default_run_skips_fixtures():
	var files: PackedStringArray = load("res://tests/run.gd").find_tests("res://tests")
	assert_true("res://tests/test_runner.gd" in files, str(files))
	for f in files:
		assert_true(not f.begins_with("res://tests/fixtures/"), f)


func test_tests_can_ready_nodes_in_the_active_tree():
	var tree = Engine.get_main_loop()
	var node := Node.new()
	tree.root.add_child(node)
	assert_true(node.is_inside_tree(), "tests run after the root enters the tree")
	assert_true(node.is_node_ready(), "scene lifecycle runs before test assertions")
	node.free()


func _run(dir: String) -> Dictionary:
	var output := []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tests/run.gd", "--", dir]
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	return {"code": code, "output": "".join(output)}


func _case(name: String, source: String) -> String:
	var dir := "user://runner_cases/" + name
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir + "/test_case.gd", FileAccess.WRITE)
	f.store_string(source)
	f.close()
	return dir
