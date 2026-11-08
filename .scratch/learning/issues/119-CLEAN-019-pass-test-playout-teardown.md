# CLEAN-019: Share pass-test play-out teardown
Stage: to-review
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/main.gd (shared cleanup in `_finish_test_playout` and `_test_playout_error`)
  - tests/test_course_screens.gd (existing pass-test screen seam)

#### What to build

Consider sharing the identical play-out teardown used when a pass-test play-out finishes and when its probe fails. Both paths invalidate callbacks, stop and clear the clocks, cancel premoves and disable board input. Keep the player's completion and retry behavior unchanged.

#### Acceptance criteria

1. Both paths use one shared teardown for invalidating pending callbacks, clearing all clock references, cancelling premoves and disabling board input.
2. Completed play-outs still advance exactly once, recording an attempt only after both play-outs finish, without writing a sandbox game to History.
3. A probe failure still preserves the solving answers and completed play-outs, records no attempt, and lets Retry restart the interrupted play-out.

#### Verification

    Existing pass-test screen tests for completion, History isolation and probe-error retry.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- No new behavior is requested: reuse `test_pass_test_runs_positions_and_playouts_and_lists_misses` and `test_test_playout_uses_tablebase_best_move_without_maia` in `tests/test_course_screens.gd`. This is a structure-only cleanup; add coverage only if triage identifies a missing behavioral assertion at that existing seam.

## Comments

- 2026-11-08 Opened by the LEARN-008 stage-3 Standards review, [original ticket](112-LEARN-008-pass-test.md). Possible Duplicated Code at `ui/main.gd::_finish_test_playout` and `_test_playout_error`; this is a nonblocking maintainability judgement with no demonstrated defect or integration/release condition. No `Escaped-from` line applies.

- Triage by the driver: ready-for-agent — extracting the identical teardown gives the two paths one place to maintain; the existing retry test needs a completed first play-out to verify preservation across a second-play-out error.

- Stage 2: the two existing callers are `_finish_playout` and the probe callbacks in `_on_move` and `_next_turn`; the shared teardown retains the original order and assumes the active play-out clock, as both paths did before. No new degenerate input is introduced.
- Test-first evidence: `7ebd422` extends the retry scenario; clearing completed play-outs on probe error produced the expected failures in `/run/media/lage/New Volume/Scratch/CLEAN-019-mutant.log`. `e54762d` adds teardown assertions; removing clock-display detachment and premove cancellation produced failures for both paths in `/run/media/lage/New Volume/Scratch/CLEAN-019-teardown-mutant.log`. Both mutant runs were stopped after the relevant failures; the full green gate completed below. Structural sharing has no observable red against the unchanged pre-refactor behavior.
- Criterion 1 ✅ Independent check: `ui/main.gd:719`, `ui/main.gd:734`, `ui/main.gd:738`; `tests/test_course_screens.gd:52` and `tests/test_course_screens.gd:159` check clock references, premoves and input in both paths. The generation guards at `ui/main.gd:1068` and `ui/main.gd:1173` and `clock.stop()` were checked by inspection; a stale callback and clock stopping are not independently exercised by these scenarios.
- Criterion 2 ✅ Independent check: `ui/main.gd:718` advances and records only after both play-outs; `tests/test_course_screens.gd:52` checks sequential play-outs, one completed attempt and History isolation; `tests/test_course_screens.gd:159` checks no attempt after the first play-out.
- Criterion 3 ✅ Independent check: `ui/main.gd:733` retains progress, and Retry uses `_start_test_playout` at `ui/main.gd:265`; `tests/test_course_screens.gd:159` verifies error after a completed first play-out, no attempt, retained answers and result, and restart of the interrupted second play-out. Answer contents are not individually compared.
- Verification: `godot --headless -s tests/run.gd` passed at `e54762db6fc212ac0f0d2c9983fa1040149dbceb`: 674 passed, 0 failed. Two pixel checks require a display; six live Lc0 checks were skipped because the Windows engine executable is unavailable. `git diff --check` passed.
Gate evidence: /run/media/lage/New Volume/Scratch/CLEAN-019-gate.json
