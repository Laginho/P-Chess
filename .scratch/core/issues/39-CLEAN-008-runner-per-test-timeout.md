# CLEAN-008: A test that awaits forever fails instead of hanging the gate
Stage: to-implement
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
