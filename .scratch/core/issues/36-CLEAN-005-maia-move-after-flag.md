# CLEAN-005: Reject Maia's move when its clock has already expired
Stage: done
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/main.gd (Maia move arrival and clock/flag ordering)
  - tests/test_clock_input_order.gd (real-Main delayed-reply seam)

#### What to build

Retain the known programmatic-move race from [BOT-005](../../bot/issues/16-BOT-005-think-time-fallback.md#comments) and [CLOCK-001](15-CLOCK-001-clocks-flag.md#comments). Maia's think-time clamp can make its delayed reply arrive when its clock has reached zero but before Main's next frame tick. `_on_maia_move` calls `BoardView.play` before `Clock.moved` flags, so the late move stays in history and a terminal result can stand. [CLOCK-002](32-CLOCK-002-move-after-flag.md) fixes human viewport input only; its `Main._input` tick does not run before a timer-driven reply.

#### Acceptance criteria

1. A Maia reply arriving with its clock at zero, before the next frame tick, does not change the board, move history, SAN or clock snapshots, and emits no move signal or move sound. The game ends on time using the position before that reply, including a reply that would otherwise mate.
2. A reply with time remaining still plays once and receives the existing increment. A reply after an already-processed flag remains ignored without a repeated result.
3. Untimed first moves, premove accounting and stale-reply cancellation after a rematch remain unchanged.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_clock_input_order.gd`, next to CLOCK-002's tests. Use fake time and explicitly delivered Maia/timer completion to reach `_on_maia_move` with no intervening frame tick; prove the late-mate case red against the current arrival order. Cover time remaining and a reply after a processed flag.

## Comments

- Created by CLOCK-002 stage 3 on 2026-10-25 to preserve the open destination promised by BOT-005's release disclosure before CLOCK-002 closes. This is a pre-existing issue, outside CLOCK-002's numbered human-input criteria; no production fix was made during review.
- Related: [CLEAN-001](../../bot/issues/33-CLEAN-001-async-think-time-tests.md) asks where flag-before-reply coverage belongs. Stage 1 should reconcile that question with this ticket to avoid duplicate scope.
- Blocked for stage-1 confirmation of scope, criteria and seam. The Maia-at-zero defect remains a release condition, not an integration blocker for the human-input fix. No one has accepted a release deferral.
- 2026-10-25 Stage 1 (human, Bruno): approved criteria 1-3, `ui/main.gd` as the production file and `tests/test_clock_input_order.gd` as the seam. No async runner needed: Maia's reply is delivered explicitly, so this does not wait on CLEAN-001. Reconciled with CLEAN-001: flag-before-reply coverage lives here (criterion 2's processed-flag case), not there. Release condition stands.
- 2026-10-25 Stage 2 (opus-5.5): `_on_maia_move` now ticks the clock before `BoardView.play`, the same order `_input` gives human drops. Tests in `tests/test_clock_input_order.gd` drive real Main: `HeldEngine` records requests, each queued request is answered FIFO (the ply-0 and ply-2 requests from setup are stale and dropped), and `HeldWaits` completes Maia's think time only when the test emits it, with no frame tick in between. Red at 234d62c against the old arrival order: 243 passed, 1 failed (late Qh5# played, mate stood, clock snapshot 0 appended). Green at ce5eee4: 244 passed, 0 failed (4 Lc0 tests skip without the engine). The 1 ms and processed-flag tests pass before and after: they guard criterion 2. Criterion 3 rests on the existing tests: untimed first moves (`test_clock_input_order`), premoves (`test_premove`), stale replies after rematch (`test_session`), all green. Callers examined: `_on_maia_move` has one, the `maia.move_ready` connection in `_ready`; `clock` is null-guarded like `_input`; Maia's untimed first move ticks a stopped clock, a no-op.

Gate evidence: C:\Users\bruno\AppData\Local\Temp\p-chess-gate-evidence\CLEAN-005-gate.json

#### Resolution (2026-10-25)

Verdict: Approve

Stage 3 (opus-5.5), review of PR #12 (`56f6416` test, `0e44047` fix, `f75f24d` handoff; rebased from `234d62c`/`ce5eee4`/`e403dff` onto `a5fbc5b`, which touched only `AGENTS.md`).

- Criterion 1 ✅ `test_a_mating_reply_arriving_at_zero_loses_on_time_before_the_move_is_played`: with White at 0 and no frame tick, the Qh5# reply leaves board, moves, SAN and `_move_clocks` unchanged, emits no `move_played` and no move sound, and the game ends `0-1, time`; a later `_process` does not repeat the flag.
- Criterion 2 ✅ `test_a_mating_reply_with_one_millisecond_left_still_plays_once` (plays once, mates, +2 s increment, snapshot 2001); `test_a_reply_after_a_processed_flag_is_ignored_without_a_repeated_result` (one `game_end`, reply never plays).
- Criterion 3 ✅ on existing tests, all green: untimed first moves `test_clock_input_order.gd::test_input_before_start_and_untimed_first_moves_remain_available`; premove accounting `test_premove.gd` (`test_main_queues_human_moves_and_executes_one_per_maia_reply`, `test_black_premoves_include_first_move_cost_and_later_increment`, `test_a_premove_that_flags_is_not_played_and_discards_the_whole_queue`, `test_premove_cannot_be_saved_from_flag_by_the_increment`, `test_first_move_premove_still_costs_100_ms_without_first_move_increment`); stale replies after rematch `test_session.gd` (`test_an_old_policy_after_rematch_is_dropped_before_a_wait_is_scheduled`, `test_two_rematches_drop_a_stale_white_move_legal_in_the_current_game`). No new test for criterion 3; by inspection the added `clock.tick()` is a no-op when no clock runs (`Clock.tick` returns on empty `_running`), which covers Maia's untimed first move and a game already over.
- Test-first: `56f6416` touches only the test and the ticket; `0e44047` only `ui/main.gd`; `f75f24d` only the ticket. Primary files respected.
- Examined: the one caller (`maia.move_ready` in `_ready`); `tick` → `stop` clears `_running` before `flagged`, so `_process` cannot flag twice; `_recording_move` is false on entry, so `_on_flagged` shows the result at once; `BoardView.play` refuses on `is_over()`. A stale reply that reaches `_on_maia_move` after a rematch now ticks the new game's clock first: the same tick `_process` runs each frame, so no behaviour change. The tick can also emit `low_time` before Maia's move, as `_input` already does for the human. Not examined: a real Lc0 game (engine absent here).
- Red-green, reproduced in review: `ui/main.gd` reverted to `234d62c` → 243 passed, 1 failed (the late Qh5# played, mate stood, snapshot 0 appended). Green after rebase: 244 passed, 0 failed, gate exit 0 on `f75f24d` (4 `test_uci.gd` tests skip without `engine/lc0/lc0.exe`; the `time_model.gd` stack trace in the log is the expected warning of `test_a_malformed_table_warns_and_is_empty`).
- Proxy decided lines: none.
- Merge: PR #12 merged as `5224e8e` after CLEAN-002 (`5e74015`) had landed on `main`; the merged `main` was gated again: 245 passed, 0 failed, exit 0 on `5224e8e` (CLEAN-002 adds one test). CI `test` passed on the PR.

Acceptance: pending | real-Main headless tests prove the path; no person has yet lost on time to a late Maia reply with the real engine (manual check owed by CLOCK-001's Verification)
Disclosure: decision | none | closes the Maia-at-zero race BOT-005 (`deferred | release`) and CLOCK-002 (`pending | release`) pointed here; fixed in `0e44047`, tests in `tests/test_clock_input_order.gd`
Gate evidence (merged main): C:\Users\bruno\AppData\Local\Temp\claude\C--Users-bruno-Desktop-Pastinha-Programas-Projects-P-Chess--claude-worktrees-clean-005-review-778209\93fa2355-6de3-41b8-878c-faf54892cbc9\scratchpad\CLEAN-005-main-gate.json
Gate evidence (PR head): C:\Users\bruno\AppData\Local\Temp\claude\C--Users-bruno-Desktop-Pastinha-Programas-Projects-P-Chess--claude-worktrees-clean-005-review-778209\93fa2355-6de3-41b8-878c-faf54892cbc9\scratchpad\CLEAN-005-review-gate.json
