# CLEAN-005: Reject Maia's move when its clock has already expired
Stage: to-review
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
