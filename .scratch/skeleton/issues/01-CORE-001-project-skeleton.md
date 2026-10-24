# CORE-001: Project skeleton and test runner
Stage: reviewing
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

- 2026-10-24 Stage stopped (incomplete handoff): Stage left uncommitted work; saved for recovery. See D:\Desktop\Projects\P-Chess\.artifacts-build\lanes\skeleton\.scratch\run-log\CORE-001-implement-20261024-013543.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.
- 2026-10-24 Bruno decided: stage 2 lineup switched from haiku-5.5 to opus-5.5 high after two failed attempts (no ticket-flow run, no commit); start clean.
- 2026-10-24 Stage 2 (opus-5.5): started clean on branch `core-001`; the recovery refs from the earlier attempts were not used. Two red/green cycles:
  - Cycle 1 (6d54410 red, f652d2a green): runner, assert helpers, `--` dir argument, `.gitignore`. Red: `tests/run.gd` did not exist (Godot: "Can't load script").
  - Cycle 2 (20b16cb red, 835a659 green): mutation testing showed that a test hitting a script error was printed as PASS and the run exited 0, because a script error aborts the test function before any assert runs. That breaks criterion 2. An `OS.add_logger` logger (Godot 4.5+ `Logger`) now turns each error raised during a test into a failure. Red: `test_script_error_in_a_test_fails_it` failed with exit code 0 and "1 passed, 0 failed".
  - Mutants checked by hand and killed: `quit(0)` always (2 tests fail), `assert_eq` ignoring non-array values (2 tests fail).
  - Design notes: test scripts `extends "res://tests/run.gd".Test`, which needs no `class_name` and so no import cache on a fresh checkout. `assert_eq(actual, expected)` compares types first, because `==` across mismatched types is a script error in Godot 4. A script error in the runner's own `_initialize` would skip `quit()` and hang Godot, which is why the comparison is guarded.
  - Verification: `run.gd -- tests/fixtures/failing` exits 1 with `FAIL ...test_fail.gd::test_fails_on_purpose: expected 5, got 4`. `git check-ignore engine/uci.gd engine/lc0/lc0.exe` prints only `engine/lc0/lc0.exe`. Gate: 8 passed, 0 failed, exit 0.
Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-skeleton\db00fb50-93bf-49ae-909b-91a63bf953b3\scratchpad\CORE-001-gate.json

- 2026-10-24 Stage stopped (incomplete handoff): Invalid committed handoff: CORE-001: missing Gate evidence receipt. See D:\Desktop\Projects\P-Chess\.artifacts-build\lanes\skeleton\.scratch\run-log\CORE-001-implement-20261024-013853.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.
- 2026-10-24 Foreman: the handoff was valid (gate green 8/8, receipt for 835a659 present). The driver's Field parser missed the receipt because the line was written as a bullet (`- Gate evidence:`). Moved it to its own line on `core-001` (ticket-only commit, so the receipt stays valid) and restored `to-review`.
