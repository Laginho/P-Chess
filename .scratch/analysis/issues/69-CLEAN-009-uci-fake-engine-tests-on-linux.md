# CLEAN-009: UCI bridge tests that fake the engine fail on Linux CI
Stage: to-implement
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - tests/test_uci.gd
  - New: tests/fixtures/<idle child>.gd (an `extends SceneTree` script that never quits)
  - engine/uci.gd (fallback only: extract the per-line body of `poll()` into `_handle_lines(lines: Array)`, see "Tests stage 2 writes")

#### What to build

Three bridge tests written in REV-001 and REV-002 fake a running engine by setting `uci.pid = OS.get_process_id()`. On Windows `OS.is_process_running(own pid)` returns true, so they pass the local gate. On Linux, Godot checks the pid with `waitpid`, which refuses a process that is not a child ("The process N does not exist or is not a child of the calling process"); `poll()` then reports the engine stopped, clears `_stdio`, and the two that poll fail (`test_stockfish_does_not_send_maia_requests` never polls, so it passes by luck). The repo's CI runs the gate on `ubuntu-latest`, and the session PR #26's `test` check has been red since REV-001 merged (run https://github.com/Laginho/P-Chess/actions/runs/41143449186: 304 passed, 2 failed).

Make both tests pass on Linux and Windows without changing what the bridge does.

#### Acceptance criteria

1. `test_search_forwards_all_info_and_bestmove_to_the_request_callback` and `test_engine_id_and_in_search_stop_preserve_the_queue` pass under Godot 4.7.2 on Linux and on Windows, and still assert the same behaviour: every search `info` and the `bestmove` reach the callback; `id name` fills `engine_id`; `stop_search()` writes `stop` only during an active search and the queue still advances.
2. No test in the suite fakes a live engine with a pid that is not a child of the test process.
3. The bridge's behaviour for Maia and Stockfish is unchanged; every other test still passes.

#### Verification

    godot --headless -s tests/run.gd
    Linux: the foreman checks the session PR's `test` check after the run (ticket branches are never pushed).

## Tests stage 2 writes (own commit, red)

- No new behaviour tests: repair the two polling tests in `tests/test_uci.gd` so each starts a real idle child Godot (`OS.execute_with_pipe(OS.get_executable_path(), ["--headless", "--path", <globalized res://>, "-s", "res://tests/fixtures/<idle>.gd"])`, as `tests/test_runner.gd:121` already does on Linux CI), sets `uci.pid` to the child's pid, keeps the file as `_stdio`, asserts `OS.is_process_running(uci.pid)` before `poll()`, and lets `uci.free()` stop the child (drop the `uci.pid = -1` lines; close the child's pipes). `test_stockfish_does_not_send_maia_requests` never polls: delete its two `uci.pid` lines.
- Red proof on Windows after the repair, each reverted: remove `_callback.call(line)` from `poll()` and test 1 goes red; remove `_stdio.store_line("stop")` from `stop_search()` and test 2 goes red. Record `git grep -n "get_process_id" tests/` before (3 hits) and after (0). Cite CI run 41143449186 as the cause.
- Fallback, only if the child route is flaky or fails on the Windows gate (record why under Comments): extract `poll()`'s per-line body into `_handle_lines(lines: Array)` with no other change; tests call it with `pid = -1`; the test-only commit is then red against the base before the production commit. An overridable liveness hook is not approved.

## Comments

- 2026-10-30 Written by the foreman from PR #26's CI after the analysis lane merged REV-001..004 (session 8bb6467+). Cause: `uci.pid = OS.get_process_id()` at `tests/test_uci.gd:92`, `:106` and `:133`; `engine/uci.gd` `poll()` checks `OS.is_process_running(pid)` first. Only terra-written REV-001/REV-002 test commits use this pattern (`git log -S "OS.get_process_id()" -- tests/`: e4c5a1d, 8faa50c, 5c16ba3). Options to weigh: drive the fake through a real child process the test starts; or a test-only way to mark the fake process alive that does not reach production paths. Prefer tests-only.
- Proxy decided (opus-5.5 xhigh): Approve CLEAN-009 as written and run it now in the analysis session, at Difficulty normal with Review agent. Fix the tests only, by using a real child process; one engine/uci.gd seam is pre-approved as a fallback. The red proof comes from mutating production code on Windows, with CI run 41143449186 cited as the cause. - The repo already runs a real child Godot and checks it with `is_process_running` on Linux CI, so no seam should be needed, and stage2.md asks for a repaired harness to be proven red for the right reason. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261030-202250-CLEAN-009-6460be.json)
- 2026-10-30 The proxy's recipe is folded into Primary files and "Tests stage 2 writes" above. The proxy did not check whether an empty `extends SceneTree` child keeps running: confirm it with one local run before relying on it, and if it exits, take the fallback seam. The foreman confirms the Linux green on PR #26's `test` check; if it is still red, the ticket reopens.
