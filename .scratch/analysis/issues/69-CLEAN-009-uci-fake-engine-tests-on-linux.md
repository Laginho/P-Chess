# CLEAN-009: UCI bridge tests that fake the engine fail on Linux CI
Stage: to-implement
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - tests/test_uci.gd
  - engine/uci.gd (only if a test seam is unavoidable, see Comments)

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

- None new: the two existing tests are the ones to repair. Red evidence is CI run 41143449186 (Linux). If stage 2 can run Godot on Linux locally (WSL), record that red run too.

## Comments

- 2026-10-30 Written by the foreman from PR #26's CI after the analysis lane merged REV-001..004 (session 8bb6467+). Cause: `uci.pid = OS.get_process_id()` at `tests/test_uci.gd:92`, `:106` and `:133`; `engine/uci.gd` `poll()` checks `OS.is_process_running(pid)` first. Only terra-written REV-001/REV-002 test commits use this pattern (`git log -S "OS.get_process_id()" -- tests/`: e4c5a1d, 8faa50c, 5c16ba3). Options to weigh: drive the fake through a real child process the test starts; or a test-only way to mark the fake process alive that does not reach production paths. Prefer tests-only.
