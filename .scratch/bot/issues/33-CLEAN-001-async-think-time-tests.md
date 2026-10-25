# CLEAN-001: Async coverage for Maia's delayed move
Stage: done
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - tests/run.gd (scope: run a `test_*` method that awaits to its end)
  - tests/test_time_model.gd (scope: the timing integration tests around `_moves_at_once`)
  - tests/test_runner.gd (scope: one child-run case whose test_* awaits a SceneTree timer, then fails an assert)

#### What to build

Today's tests see only what Maia emits before `think()` returns. They would still pass if the
timer ran too long, or if the delayed move never came. The runner learns to finish a test that
awaits, and the timing tests follow Maia's move through its wait. From BOT-006 Review 2's
non-blocking item.

#### Acceptance criteria

1. `tests/run.gd` runs a `test_*` method that awaits (a SceneTree timer) to its end: an assert after the await that fails is reported FAIL, and the suite counts it.
2. When the delay is longer than Lc0's compute, Maia emits exactly one move, after the wait and not before it.
3. Maia's clock is charged max(delay, compute) for that move.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_time_model.gd`: a delayed move arriving once after the wait, and the clock charge. Red against today's runner, because it never resumes a test after its first await. Review 2's probes say Maia already does this, so once the runner awaits these may be green from the start; say so instead of forcing a red.
- `tests/test_runner.gd`: a child run of a case whose `test_*` awaits a SceneTree timer and then fails an assert exits non-zero with "0 passed, 1 failed". Red against today's runner, which prints PASS at the first await and quits before the timer fires (child prints "1 passed, 0 failed", exit 0).

## Comments

- Written by BOT-006 stage 3 (2026-10-24, opus-5.5), not by stage 1. It is blocked until the human approves the seam (changing the test runner) and the criteria; then set `Stage: to-implement`. Open question from Review 2: "a flag before the pending reply stops the move". That path is in `ui/main.gd` `_on_flagged` → `game.flag`, not in `maia_player`, and CLOCK-002 (core lane) covers a move dropped after the flag. Add it here, with `ui/main.gd` in Primary files, or leave it to CLOCK-002?
- 2026-10-25 Stage 1 (human, Bruno): approved the runner seam (`tests/run.gd` awaits each `test_*` method, e.g. `await test.call(name)`) and criteria 1-3 as written. Open question answered: flag-before-reply stays out of this ticket; it belongs to [CLEAN-005](../../core/issues/36-CLEAN-005-maia-move-after-flag.md), which owns `ui/main.gd`'s Maia arrival order. `ui/main.gd` is not a primary file here. [CLEAN-006](../../core/issues/37-CLEAN-006-main-rematch-lifecycle-tests.md) is blocked by this ticket for the runner change.
- Proxy decided (2026-10-25, stage 2): add tests/test_runner.gd to Primary files (scope: one child-run case whose test awaits a SceneTree timer and then fails an assert) and prove criterion 1 there — the runner's self-tests and their `_run`/`_case` helpers already live there (CORE-001, UI-004 precedent), and test_time_model.gd alone would pass vacuously against today's runner.
- 2026-10-25 Stage 2 (opus-5.5): red on aa1cd8f (243 passed, 1 failed, exit 1): `test_runner.gd::test_an_assert_after_an_await_counts` fails because the child run of an awaiting case prints "1 passed, 0 failed" and exits 0. The two timing tests (`test_a_delay_longer_than_lc0_s_compute_brings_one_move_after_the_wait`, `test_maia_s_clock_is_charged_the_delay_when_it_outlasts_lc0`) were vacuously green there, as the ticket foresaw: the old runner printed PASS at their first await. Fix on 8b82d38: `tests/run.gd` awaits `test.call(name)`, one line.
  - Harness fix on ec87f34 (test-only): under the fixed runner the timing tests failed on their harness, not on Maia (move at 138 ms for a 300 ms delay, charged 185 ms). `SlowBridge` blocks the frame for Lc0's compute, and the earlier synchronous tests run inside one long frame that Godot then catches up on in frames taking no real time; both make SceneTree timers end early. Now a `LateBridge` answers on a timer (the real `engine/uci.gd` answers on a later frame too), `_delayed_move` waits until a 50 ms timer takes real time before starting, and the bounds allow one 60 Hz tick (`FRAME_MS` 20 ms): arrival >= 280 ms, charge within 300 +/- 40 ms. A probe showed Godot timers end up to ~17 ms early even when settled. Red again by mutating `bot/maia_player.gd` (not committed): skipping the wait delivers at Lc0's 104 ms and charges 104 ms (both tests fail); a double `move_ready.emit` gives two moves (criterion 2 test fails). Logs: `C:\Users\bruno\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_ea9dedf1-afd3-427a-be68-f9943a87cc6f\clean-001-mutant-no-wait.log`, `C:\Users\bruno\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_ea9dedf1-afd3-427a-be68-f9943a87cc6f\clean-001-mutant-double-emit.log`. Five isolated runs of `test_time_model.gd` were all green.
  - Callers: no existing `test_*` method awaits (only helpers in `test_book.gd`/`test_badges.gd` do), so no other test changes behaviour under the new runner. Each timing test now takes about 1 s (0.9 s guard plus the settle).
  - Risk: a `test_*` that awaits a signal which never fires now hangs the gate; the runner has no per-test timeout (the ticket did not ask for one).
  - Green on ec87f34: 244 passed, 0 failed, exit 0 (baseline main 241 passed).

Gate evidence: C:\Users\bruno\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_ea9dedf1-afd3-427a-be68-f9943a87cc6f\clean-001-gate.json

#### Resolution (2026-10-25)

Verdict: Approve

Stage 3 (opus-5.5), review of PR #14 (`4e0a1b1` test, `24a5b7f` fix, `a94aa1a` test harness fix, `b613dd8` handoff; rebased cleanly from `aa1cd8f`/`8b82d38`/`ec87f34`/`02607b5` onto `22b2326`). Review comment: https://github.com/Laginho/P-Chess/pull/14#issuecomment-6400486238

- Criterion 1 ✅ `tests/run.gd` awaits `test.call(name)`. `test_runner.gd::test_an_assert_after_an_await_counts` runs a child case that fails after a SceneTree timer and expects exit ≠ 0 and "0 passed, 1 failed". It was red before the fix (child printed "1 passed, 0 failed", exit 0; suite 243 passed, 1 failed on `aa1cd8f`) and is green after it.
- Criterion 2 ✅ `test_time_model.gd::test_a_delay_longer_than_lc0_s_compute_brings_one_move_after_the_wait`: a 300 ms delay against Lc0's 100 ms gives exactly one move within a 900 ms guard, arriving ≥ 280 ms. Two mutants of `bot/maia_player.gd` fail it (not committed; logs in stage 2's comment): skipping the wait (arrival at 104 ms) and a double emit (two moves).
- Criterion 3 ✅ `test_maia_s_clock_is_charged_the_delay_when_it_outlasts_lc0`: the charge is within 300 ± 40 ms. The no-wait mutant charges 104 ms and fails it.
- Test-first: `4e0a1b1` and `a94aa1a` touch only tests and the ticket, `24a5b7f` only `tests/run.gd`, `b613dd8` only the ticket. Primary files respected. `tests/test_runner.gd` is in scope through the stage-2 `Proxy decided` line below.
- Examined: every `test_*` in `tests/` as callers of the runner change. None awaits today (the `await` hit in `test_badges.gd` is a message string), and `await` on a non-coroutine returns at once, so existing tests keep their frame behaviour. `_run` was already `call_deferred`, so becoming a coroutine is safe. Docs: spec §11 does not describe the call mechanism, so nothing is stale. Not examined: the timing bounds on a saturated machine (they allow 1–2 frames at 60 Hz). Five isolated stage-2 runs, this review's run and Ubuntu CI were all green.
- Gate-log note: the expected `push_warning` of `test_a_malformed_table_warns_and_is_empty` prints Godot backtraces carrying stale coroutine frames from `_delayed_move`. This is cosmetic and also appears in stage 2's log.
- Proxy decided lines: one (stage 2, 2026-10-25), adding `tests/test_runner.gd` to Primary files to prove criterion 1. Reviewed and agreed: the runner's self-tests and helpers live there, and the time-model tests alone passed vacuously against the old runner.
- Finding (non-blocking): no per-test timeout. A `test_*` that awaits a signal that never fires now hangs the run until CI's `timeout-minutes: 15` stops it. Destination: [CLEAN-008](../../core/issues/39-CLEAN-008-runner-per-test-timeout.md).
- Gate: rebased head `b613dd8` passed 248, failed 0, exit 0 (main's 245 + 3 new). CI `test` passed on the PR. PR #14 merged as `86f41a3` with no other change on `main` in between, so the merged tree equals `b613dd8`.

Acceptance: passed | headless gate 248/0 and CI on PR #14; the change is test infrastructure only
Disclosure: decision | none | stage-2 Proxy decided line added tests/test_runner.gd to Primary files; agreed in review (PR #14 comment)
Disclosure: deferred | none | no per-test timeout in tests/run.gd, bounded by CI's 15-minute job timeout; open in [CLEAN-008](../../core/issues/39-CLEAN-008-runner-per-test-timeout.md)
Gate evidence: C:\Users\bruno\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_ea9dedf1-afd3-427a-be68-f9943a87cc6f\clean-001-review-gate.json
