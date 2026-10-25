# CLEAN-008: A test that awaits forever fails instead of hanging the gate
Stage: to-review
Status: ready-for-agent
Blocked by: CLEAN-001
Review: agent
Difficulty: normal

- Primary files:
  - tests/run.gd (scope: bound each awaited `test_*` method at 10 s wall-clock)
  - tests/test_runner.gd (scope: bound the child run in `_run`; one child-run case whose `test_*` awaits a signal that never fires)

#### What to build

Since [CLEAN-001](../../bot/issues/33-CLEAN-001-async-think-time-tests.md), `tests/run.gd` awaits each `test_*` method to its end. If a test awaits a signal that never fires, the whole run hangs until CI's `timeout-minutes: 15` kills the job, and no test report is printed. Before CLEAN-001 such a test passed without running its asserts. It should instead be reported FAIL after a bounded wait, and the run should continue.

#### Acceptance criteria

1. A `test_*` that awaits a signal that never fires is reported FAIL, with a message naming the timeout, within 10 s (wall-clock). The run continues with the next test and is counted in the summary.
2. Tests that finish within the bound behave exactly as today. Synchronous tests are not delayed.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_runner.gd`: a child run of a case whose `test_*` awaits a never-emitted signal ends non-zero with "0 passed, 1 failed" and the timeout message. It is red today because the child never exits. `_run` therefore waits for its child synchronously (an `await` would trip the parent's own 10 s bound) and kills it after a deadline well above 10 s (about 60 s), keeping output capture for the existing cases.

## Comments

- Created by CLEAN-001 stage 3 on 2026-10-25 as the open destination for the review's "no per-test timeout" finding (stage 2 named the risk). It does not block CLEAN-001. CLEAN-006 is the first ticket to write awaiting tests against the new runner, so a mistake there would show up as a hung CI job.
- 2026-10-25 Stage 1 triage through the proxy (foreman run):
- Proxy decided (opus): 10 s wall-clock bound per awaited `test_*`, a constant in run.gd, no CLI flag — the slowest awaiting test is about 1 s (`test_time_model.gd:219`, `test_session.gd:295`), so 10x headroom and small against the 15-min CI job.
- Proxy decided (opus): timeout = `FAIL <path>::<name>: timed out after 10 s`, counted, run continues; the suspended coroutine is abandoned — GDScript cannot cancel it. Measure the bound with `Time.get_ticks_msec()`, not a SceneTree timer (CLEAN-001 saw SceneTree timers end early after long frames). Known limit for a `shortcut:` comment: a late signal's script errors land in a later test's ErrorLog.
- Proxy decided (opus): bound `_run` itself in test_runner.gd (one spawn path for all child cases), waiting synchronously with a kill deadline of about 60 s and draining the pipes inside the poll loop; stage 2 picks the Godot API (`OS.execute_with_pipe` + `OS.is_process_running`/`OS.kill` or equivalent); a separate helper only if the existing child cases cannot stay green — an awaiting parent case would trip its own 10 s bound.
- Proxy decided (opus): criteria and Primary files confirmed as drafted, Review agent, Difficulty normal — this is the agreed bound, not a new seam; spec §11 needs no change.
- Disclosure: decision | none | test-runner change only; the gate gets about 10 s slower (the new case waits out the bound). Unchecked by the proxy: whether the ~11 s synchronous block before `test_session.gd`'s timing tests disturbs them; the gate will show.

- 2026-10-25 Stage 2 (Codex): implemented on `clean-008`, based on session `sweatshop/2026-10-25-1843` at `ff0f00d`. Dependency CLEAN-001 is `done` on this base.
  - Scope/callers examined: `tests/run.gd::_run` invokes every discovered `test_*`; `tests/test_runner.gd::_run` serves the failing, passing, unloadable, script-error and awaiting child cases. Existing async callers are `tests/test_time_model.gd` and `tests/test_session.gd`. No game code, fixtures on disk, configuration or exports changed. No CONTEXT.md or docs/adr directory exists; spec section 11 remains accurate.
  - Test-first: `01cee35` changes only `tests/test_runner.gd` and this ticket. Child processes use nonblocking pipes, synchronous polling with a 60 s kill deadline, and preserve stdout/stderr and the exit code. The new case requires a never-emitted signal to fail with the timeout message and `0 passed, 1 failed`, then checks a second child containing the same hang followed by a passing method (`1 passed, 1 failed`). The first child must take 10–12 s including process startup; the two children add about 20 s to the green suite.
  - Red on `01cee35`: `253 passed, 1 failed`, exit 1. The never-emitted signal did not finish; the harness killed the child after 60010 ms, returning -1 without a timeout report or summary. All previous runner self-tests passed. Full log: `C:\Users\bruno\AppData\Local\Temp\clean-008-red.log`.
  - Production-only commit `985eca2` changes only `tests/run.gd`: start the method through a completion-tracking coroutine, poll only pending methods against `Time.get_ticks_msec()` and the 10000 ms constant, append `timed out after 10 s`, then continue the existing failure-reporting path. Synchronous completion never waits for a frame. Script errors still enter ErrorLog and fail the test.
  - Green on `985eca2`: `254 passed, 0 failed`, exit 0, with Godot `4.7.stable.official.5b4e0cb0f` on Windows. The new timeout/continuation check, existing script-error and post-await assertions, and session/time-model integration checks all passed. No script errors; warnings are the intentional malformed-theme/time-model cases. Full log: `C:\Users\bruno\AppData\Local\Temp\clean-008-green.log`.
  - Known limit retained from the approved contract: the runner abandons a timed-out coroutine rather than cancelling it; a late signal can log errors during a later test. The `shortcut:` comment records this. The bound depends on the main loop progressing; a synchronous block cannot be interrupted. Linux/CI were not run in this stage.

Acceptance: passed | Windows headless gate on 985eca2, 254 passed and 0 failed; child-run assertions prove timeout reporting, elapsed bound and continuation
Disclosure: decision | none | approved stage-1 Proxy decided lines above retained; 10 s constant and abandoned-coroutine limit implemented as contracted
Gate evidence: C:\Users\bruno\AppData\Local\Temp\clean-008-green.json
