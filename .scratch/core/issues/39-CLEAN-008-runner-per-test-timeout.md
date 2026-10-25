# CLEAN-008: A test that awaits forever fails instead of hanging the gate
Stage: blocked
Status: needs-triage
Blocked by: CLEAN-001
Review: agent
Difficulty: normal

- Primary files (proposed; stage 1 must confirm):
  - tests/run.gd (scope: bound each awaited `test_*` method)
  - tests/test_runner.gd (scope: one child-run case whose `test_*` awaits a signal that never fires)

#### What to build

Since [CLEAN-001](../../bot/issues/33-CLEAN-001-async-think-time-tests.md), `tests/run.gd` awaits each `test_*` method to its end. If a test awaits a signal that never fires, the whole run hangs until CI's `timeout-minutes: 15` kills the job, and no test report is printed. Before CLEAN-001 such a test passed without running its asserts. It should instead be reported FAIL after a bounded wait, and the run should continue.

#### Acceptance criteria (proposed)

1. A `test_*` that awaits a signal that never fires is reported FAIL, with a message naming the timeout, within a bound stage 1 chooses. The run continues with the next test and is counted in the summary.
2. Tests that finish within the bound behave exactly as today. Synchronous tests are not delayed.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_runner.gd`: a child run of a case whose `test_*` awaits a never-emitted signal ends non-zero with "0 passed, 1 failed". It is red today because the child never exits, so the case needs its own bound on the child process.

## Comments

- Created by CLEAN-001 stage 3 on 2026-10-25 as the open destination for the review's "no per-test timeout" finding (stage 2 named the risk). It does not block CLEAN-001. CLEAN-006 is the first ticket to write awaiting tests against the new runner, so a mistake there would show up as a hung CI job.
- Blocked until stage 1 triages it and confirms the bound and the scope.
