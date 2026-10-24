# CORE-001: Project skeleton and test runner
Stage: done
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
Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-skeleton\54b4b3e9-6c80-4ba2-a07c-22381145ea2b\scratchpad\CORE-001-review-gate.json

- 2026-10-24 Stage stopped (incomplete handoff): Invalid committed handoff: CORE-001: missing Gate evidence receipt. See D:\Desktop\Projects\P-Chess\.artifacts-build\lanes\skeleton\.scratch\run-log\CORE-001-implement-20261024-013853.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.
- 2026-10-24 Foreman: the handoff was valid (gate green 8/8, receipt for 835a659 present). The driver's Field parser missed the receipt because the line was written as a bullet (`- Gate evidence:`). Moved it to its own line on `core-001` (ticket-only commit, so the receipt stays valid) and restored `to-review`.

#### Resolution (2026-10-24)

Verdict: Approve

Stage 3 (opus-5.5). The Standards and Spec axes ran as separate sub-agents and found nothing.

Criteria:

1. ✅ `find_tests` lists `test_*.gd` in the directory. The runner calls every `test_*` method, prints a `PASS|FAIL <path>::<method>` line for each one, then `N passed, M failed`. The gate log has 8 PASS lines and the summary.
2. ✅ The runner exits with `quit(0 if failed == 0 else 1)`. A script that fails to load (`null`, or `can_instantiate()` false) counts as a failure. A runtime error inside a test is caught by the `ErrorLog` logger and also fails it. Covered by `test_passing_dir_exits_zero_and_runs_only_test_methods`, `test_unloadable_script_exits_nonzero` and `test_script_error_in_a_test_fails_it`.
3. ✅ `assert_true` and `assert_eq` live on `Test`. A FAIL line names the path, the method and `expected X, got Y`. For `assert_true` the line says only `expected true`: a failed bool assert can only have been `false`, so I count it as met.
4. ✅ The `-- <dir>` argument works with or without `res://`, and a missing directory exits 1. The scan is not recursive, so `tests/fixtures/` stays out of the default run (`test_default_run_skips_fixtures`). I reran the fixture in review: non-zero exit, `FAIL res://tests/fixtures/failing/test_fail.gd::test_fails_on_purpose: expected 5, got 4`, `0 passed, 1 failed`.
5. ✅ `.gitignore` lists `engine/lc0/`, `engine/weights/`, `.godot/` and `build/`. `git check-ignore engine/uci.gd engine/lc0/lc0.exe` printed only `engine/lc0/lc0.exe`.
6. ✅ No `addons/` directory and no plugin in `project.godot`.

Test-first: I checked `diff --stat` on every commit. 7e9f256 holds the tests, the fixture and the Stage line (red). 2859e87 is production only (`.gitignore`, `project.godot`, `tests/run.gd`). 6aa1b35 is test only (red), cda8f9c is production only (`tests/run.gd`), and 89dfbcb and ae90d96 touch only the ticket. Every file is inside Primary files.

Examined:
- Callers: nothing calls the runner yet, but every later ticket's gate does. The 24 test files named in later tickets are all flat `tests/test_*.gd`, so the non-recursive scan finds them. The fixtures those tickets name (`tests/fixtures/pgn/`, `lc0_verbose.txt` and others) sit under `tests/fixtures/` and stay out of the default run.
- Failure paths: a missing directory, a parse error, a script that does not extend `Test`, a runtime error inside a test, and `assert_eq` across mismatched types.
- Cross-feature, a note for later tickets: `ErrorLog` fails any test during which Godot logs an error. That includes `push_error` and Godot's own errors, for example `load()` on a missing path. A later ticket that reports bad input through `push_error` has to keep its tests off that path, or change the runner.
- Not examined: the Linux CI run (CI-001), and an absolute OS path as the `--` argument (no criterion covers it).

Fix in review (bf08dac, docs only, by stage 3): spec §12 still listed `engine/` in `.gitignore`. It now lists `engine/lc0/` and `engine/weights/`, matching §2 and criterion 5. No behaviour changed, so it needed no independent review.

Rebase: rebased onto session 6561da3. The only conflicts were in this ticket (the Stage line and the order of Comments), and I kept both histories. After the rebase the production tree is identical to the tested 835a659: `git diff 835a659 core-001 -- . ':!.scratch'` is empty.

Red-green, from stage 2:
- Cycle 1: red because `tests/run.gd` did not exist (`Can't load script`); green at 2859e87.
- Cycle 2: red because `test_script_error_in_a_test_fails_it` exited 0 with `1 passed, 0 failed`; green at cda8f9c.

Gate: `godot --headless -s tests/run.gd` on bf08dac gave 8 passed, 0 failed, exit 0, with the receipt in the Gate evidence line above. The stage-2 receipt for 835a659 is superseded because the docs fix changed a file after it.

Proxy decided lines: none. `Bruno decided` (the lineup switch) is a human decision about the run, not about the contract.

Acceptance: passed | rerun in review on bf08dac: the fixture exits non-zero, check-ignore ignores only `engine/lc0/lc0.exe`, and the gate passes 8/8 (receipt in the Gate evidence line above)

No disclosures: no contract change, no pending product check, no known defect.
