# CLEAN-005: Reject Maia's move when its clock has already expired
Stage: blocked
Status: needs-triage
Blocked by: none
Review: agent
Difficulty: normal

- Primary files (proposed; stage 1 must confirm):
  - ui/main.gd (Maia move arrival and clock/flag ordering)
  - tests/test_clock_input_order.gd or tests/test_session.gd (real-Main delayed-reply seam, to be chosen in stage 1)

#### What to build

Retain the known programmatic-move race from [BOT-005](../../bot/issues/16-BOT-005-think-time-fallback.md#comments) and [CLOCK-001](15-CLOCK-001-clocks-flag.md#comments). Maia's think-time clamp can make its delayed reply arrive when its clock has reached zero but before Main's next frame tick. `_on_maia_move` calls `BoardView.play` before `Clock.moved` flags, so the late move stays in history and a terminal result can stand. [CLOCK-002](32-CLOCK-002-move-after-flag.md) fixes human viewport input only; its `Main._input` tick does not run before a timer-driven reply.

#### Acceptance criteria (proposed)

1. A Maia reply arriving with its clock at zero, before the next frame tick, does not change the board, move history, SAN or clock snapshots, and emits no move signal or move sound. The game ends on time using the position before that reply, including a reply that would otherwise mate.
2. A reply with time remaining still plays once and receives the existing increment. A reply after an already-processed flag remains ignored without a repeated result.
3. Untimed first moves, premove accounting and stale-reply cancellation after a rematch remain unchanged.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- Stage 1 must confirm the file boundary and real-Main test seam. Use fake time and explicitly delivered Maia/timer completion to reach `_on_maia_move` with no intervening frame tick; prove the late-mate case red against the current arrival order. Cover time remaining and a reply after a processed flag.

## Comments

- Created by CLOCK-002 stage 3 on 2026-10-25 to preserve the open destination promised by BOT-005's release disclosure before CLOCK-002 closes. This is a pre-existing issue, outside CLOCK-002's numbered human-input criteria; no production fix was made during review.
- Related: [CLEAN-001](../../bot/issues/33-CLEAN-001-async-think-time-tests.md) asks where flag-before-reply coverage belongs. Stage 1 should reconcile that question with this ticket to avoid duplicate scope.
- Blocked for stage-1 confirmation of scope, criteria and seam. The Maia-at-zero defect remains a release condition, not an integration blocker for the human-input fix. No one has accepted a release deferral.
