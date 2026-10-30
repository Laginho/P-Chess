# CLEAN-009: UCI bridge tests that fake the engine fail on Linux CI
Stage: done
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

- 2026-10-30: The idle SceneTree child stayed alive in a Windows Godot 4.7 probe. Before repair, `git grep -n "get_process_id" -- tests/` found three hits in test_uci.gd; after repair it found none. Linux CI failure: https://github.com/Laginho/P-Chess/actions/runs/41143449186.

- Windows Godot 4.7 mutation checks: removing `_callback.call(line)` failed the forwarding test (and the queue callback assertion); removing `_stdio.store_line("stop")` failed the queue command assertion. Both mutations were reverted. Gate on e40f327: 306 passed, 0 failed.

Acceptance: pending | The foreman must confirm Linux Godot 4.7.2 on session PR #26 and Windows Godot 4.7.2 before that PR merges into main. The existing Windows gate is Godot 4.7.stable, not 4.7.2; see the gate log and Resolution below.
Disclosure: pending | integration | Before session PR #26 merges into main, the foreman must record both Linux 4.7.2 CI and Windows 4.7.2 verification. Local session integration is approved; exact-version acceptance remains pending. https://github.com/Laginho/P-Chess/actions/runs/41143449186 records the original Linux failure; C:\Users\bruno\AppData\Local\Temp\clean009-gate.log records Windows 4.7.stable only.
Disclosure: decision | none | The existing proxy decision approves the tests-only child-process repair and assigns Linux confirmation to the foreman after session integration; receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261030-202250-CLEAN-009-6460be.json. No production contract changed and the fallback seam was not used.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\clean009-gate.json

#### Resolution (2026-10-30)
Verdict: Approve

- Standards: 0 findings. Independent Standards review found no documented violation or material smell. The change follows the existing subprocess pattern and remains within Primary files.
- Spec: 0 implementation findings. Independent Spec review found no missing behavior, scope creep or regression. Criterion 1 is partially verified: all original callback, engine-id, conditional-stop and queue assertions remain, and both polling tests pass on Windows Godot 4.7.stable. Windows 4.7.2 and Linux 4.7.2 execution remain the explicit acceptance checks above. Criterion 2 passes: all three own-process PID fakes are removed and the only test assignments are the two real child PIDs. Criterion 3 passes for unchanged production and the Windows suite; Linux execution remains pending.
- Coverage: fixed diff `14cf96471e90f376e5013f79978c89b96014ad4e...53ccccea243f633de607682cbcada407d2c0b886`; total_files=3, reviewed_files=3, skipped_files=0, coverage_rate=100%. OCR preview excluded all three files as unsupported_ext; all were reviewed directly using its resolved default rules. Reviewed `tests/test_uci.gd`, `tests/fixtures/idle_child.gd` and this ticket; also traced `engine/uci.gd`, `tests/test_runner.gd` and `tests/run.gd`.
- Examined callers and failure paths: `_idle_child()` in both polling tests, child liveness before `poll()`, every search info/bestmove callback, `id name`, stop with and without an active search, queue advancement, `free()` -> `stop()` -> child termination, pipe closure in normal and missing-method paths, fixture exclusion from default discovery, and Maia/Stockfish request isolation. Production code is byte-for-byte unchanged. Exact-version Windows 4.7.2 and Linux runtime behavior were not executed during this review.
- Red/green proof: read C:\Users\bruno\AppData\Local\Temp\clean009-callback.log (10 passed, 2 failed, missing forwarded callbacks) and C:\Users\bruno\AppData\Local\Temp\clean009-stop.log (11 passed, 1 failed, missing stop command). Both mutations were reverted before the green gate on test commit `e40f327`; the commit contains only tests and ticket metadata. Handoff `53cccce` contains only ticket metadata. The repaired harness preserves the original behavior assertions and follows the approved mutation-red recipe.
- Gate: reused the existing receipt for tested commit `e40f3275b6eed48606ec3cf33ba95920f1c8a7f6`; validated command, exit 0, log SHA-256 and unchanged code using `Assert-GateEvidence`. Read 306 PASS lines, 0 FAIL lines and 0 SKIP lines, with summary `306 passed, 0 failed`. The log identifies Godot 4.7.stable on Windows. No gate rerun was needed because rebase/review changed no tested code.
- Proxy decision reviewed: `Proxy decided (opus-5.5 xhigh): Approve CLEAN-009 as written and run it now in the analysis session, at Difficulty normal with Review agent.` The existing receipt and complete decision above authorize the real-child harness, keep the bridge unchanged and leave Linux confirmation to the foreman. The exact-version Windows evidence gap is also disclosed rather than treated as verified acceptance.
- Integration: rebased `clean-009` onto `sweatshop/analysis/2026-10-30-1831` with no changes, then merged locally with `--no-ff` as `062eba2`. This resolution, `Stage: done` and the ledger line are committed together on the session. The foreman owns push and the remaining PR #26 checks.
