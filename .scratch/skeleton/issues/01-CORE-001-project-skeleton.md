# CORE-001: Project skeleton and test runner
Stage: to-implement
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - New: project.godot
  - New: tests/run.gd
  - New: tests/test_runner.gd
  - New: tests/fixtures/failing/test_fail.gd
  - .gitignore

#### What to build

An empty Godot 4.7 project with the spec's test runner (§11): `godot --headless -s tests/run.gd` runs every test and exits non-zero when one fails. Every later ticket's gate is that command. The `.gitignore` is narrowed so that `engine/uci.gd` (§2) can be committed while the downloaded engine stays ignored.

#### Acceptance criteria

1. `godot --headless -s tests/run.gd` loads every `tests/test_*.gd`, runs each method whose name starts with `test_`, and prints one pass/fail line per test and a summary count.
2. The runner exits 0 when every test passes, and non-zero when a test fails or a test script fails to load.
3. Tests fail through assert helpers (at least `assert_true` and `assert_eq`); a failure prints the file, the test name, and the expected and actual values.
4. An optional directory argument after `--` runs the tests in that directory instead of `tests/`: `godot --headless -s tests/run.gd -- tests/fixtures/failing` runs the deliberately failing fixture and exits non-zero. The default run does not pick up `tests/fixtures/`.
5. `.gitignore` lists `engine/lc0/`, `engine/weights/`, `.godot/` and `build/`, and no longer `engine/`: `git check-ignore engine/uci.gd` prints nothing and `git check-ignore engine/lc0/lc0.exe` prints the path.
6. No add-on is used (§11).

#### Verification

    godot --headless -s tests/run.gd -- tests/fixtures/failing   # must exit non-zero
    git check-ignore engine/uci.gd engine/lc0/lc0.exe
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_runner.gd`: the assert helpers report a failure for unequal values, and a run of the fixture directory returns a non-zero exit code. Red because the runner does not exist yet.

## Comments

- 2026-10-24 Attempt 1 failed: exit 0. Log tail: `CORE-001` is the project skeleton ticket: `.scratch/skeleton/issues/01-CORE-001-project-skeleton.md`, stage `to-implement`, no blockers. /  / It asks for: / - An empty Godot 4.7 project (`project.godot`). / - A test runner, `tests/run.gd` and `tests/test_runner.gd`, that runs `test_*` methods and exits non-zero on failure. It needs `assert_true` and `assert_eq` helpers that print file, test name, expected and actual. / - A `-- <dir>` argument so `tests/fixtures/failing` can be run on its own. The default run must skip `tests/fixtures/`. / - A `.gitignore` that drops `engine/` and adds `engine/lc0/`, `engine/weights/`, `.godot/`, `build/`. /  / Gate: `godot --headless -s tests/run.gd`. /  / Do you want me to implement it directly, or run it through the `ticket-flow` skill? The repo's bindings for `ticket-flow` name gpt-6.1-sol models for stages 2 and 3, which I can't run, so I'd need your go-ahead to use a different model for those stages.
