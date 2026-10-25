# CLEAN-001: Async coverage for Maia's delayed move
Stage: to-implement
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - tests/run.gd (scope: run a `test_*` method that awaits to its end)
  - tests/test_time_model.gd (scope: the timing integration tests around `_moves_at_once`)

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

## Comments

- Written by BOT-006 stage 3 (2026-10-24, opus-5.5), not by stage 1. It is blocked until the human approves the seam (changing the test runner) and the criteria; then set `Stage: to-implement`. Open question from Review 2: "a flag before the pending reply stops the move". That path is in `ui/main.gd` `_on_flagged` → `game.flag`, not in `maia_player`, and CLOCK-002 (core lane) covers a move dropped after the flag. Add it here, with `ui/main.gd` in Primary files, or leave it to CLOCK-002?
- 2026-10-25 Stage 1 (human, Bruno): approved the runner seam (`tests/run.gd` awaits each `test_*` method, e.g. `await test.call(name)`) and criteria 1-3 as written. Open question answered: flag-before-reply stays out of this ticket; it belongs to [CLEAN-005](../../core/issues/36-CLEAN-005-maia-move-after-flag.md), which owns `ui/main.gd`'s Maia arrival order. `ui/main.gd` is not a primary file here. [CLEAN-006](../../core/issues/37-CLEAN-006-main-rematch-lifecycle-tests.md) is blocked by this ticket for the runner change.
