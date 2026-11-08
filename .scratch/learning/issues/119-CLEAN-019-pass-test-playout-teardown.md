# CLEAN-019: Share pass-test play-out teardown
Stage: implementing
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
