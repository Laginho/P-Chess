# CLOCK-002: A move dropped after the time ran out
Stage: implementing
Blocked by: CLOCK-001
Review: agent
Difficulty: normal

- Primary files:
  - ui/main.gd
  - tests/test_clock_input_order.gd (new; real Main under the runner root, as tests/test_session.gd does)

#### What to build

When the human's time runs out, a piece they drop in that same frame is not played: the game ends on time, as if the drop had come a moment later. Today `core/clock.gd` only learns the time ran out at the next `_process` tick, and Godot handles input before `_process`, so a drop up to one frame (~16 ms) after the clock hit 0 is played first, and `Clock.moved` flags after it. Found in CLOCK-001's review.

#### Acceptance criteria

1. A piece dropped after the human's clock reached 0, before the next frame's tick, snaps back as in CLOCK-001 criterion 8: no move, no move sound, no `move_played`. The game ends `time` by CORE-004's flag rule on the position before the drop.
2. In 3+2, a drop in the frame the human's clock crossed the low-time threshold (10 s) still plays the low-time sound once, though the increment lifts the clock back above it.
3. A piece dropped while time is left plays as before.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_clock_input_order.gd`, on the seam the human chose (option (a), `Human decided (Bruno)` under Comments): instance `ui/main.tscn` under the runner's root (the runner already defers `_run` from `_initialize`, since UI-004's 6075057), with the fake engine, settings file and silent sound theme `tests/test_session.gd` uses, and await a few frames for `_ready`; swap `main.clock` for a `Clock` on a fake time source; push input through `main._unhandled_key_input` and `board_view._gui_input`, with no `_process` tick between the time crossing and the drop.
  - Criterion 1: the human's clock at 0 on the fake source, a legal drop: the piece snaps back, no `move_played`, no move sound, the move list unchanged, the game over `time` (a case where the late move would mate or take the opponent's last mating material shows the rule read the position before the drop).
  - Criterion 2: 3+2, the fake source crosses 10 s in the frame of the drop: the low-time sound plays exactly once.
  - Criterion 3: time left, the same drop plays as before.
  - Red because `Main` only ticks the clock in `_process`, after the board's input.

## Comments

- 2026-10-24 Created at CLOCK-001's close (stage 3). Today the late move stays on the board and in the move list, and the flag rule then reads the position after it: a mating late move stands as checkmate, and a late capture of the opponent's last mating material turns a loss on time into a draw. The 3+2 low-time sound can be skipped the same way. Candidate fix: `ui/main.gd` ticks the clock in `_input`, which Godot runs before the board's `_gui_input`, so the flag lands first and CLOCK-001's `_commit` guard snaps the piece back.
- Question for stage 1 (why this is `blocked`): which test seam? `ui/main.gd` needs the tree for its `@onready` nodes, starts Lc0 in `_ready`, and `_start` hard-codes `Time.get_ticks_msec`, so no existing test reaches the input order. Options: (a) instance `ui/main.tscn` under the test runner's root, swap `main.clock` for one on a fake time source, and push a mouse event through the viewport; (b) a seam `tests/test_board_view.gd` can reach, e.g. BoardView ticks a clock it is given before `_commit`, which adds `ui/board_view.gd` to Primary files.
- 2026-10-24 From UI-004's re-review (a note, not a criterion until stage 1 folds it in): option (a) works headless. A `SceneTree` script that defers its work from `_initialize` (`call_deferred`), adds `ui/main.tscn` to the root and awaits a few frames gets `_ready`, running tweens and the promotion picker's buttons, and can push input through `main._unhandled_key_input` and `board_view._gui_input`. The runner calls tests straight from `_initialize`, so this needs a `tests/run.gd` change. The same seam would host the test UI-004 owes: a rematch (Space after a flag) through the real `Main._start` clears the open picker, the held piece and a running snap-back tween. That was checked in review only, by an uncommitted probe.
- 2026-10-25 Human decided (Bruno): test seam option (a), "pode destravar o clock-002 também, aceito sua sugestão" (relayed by the supervisor session). Instance `ui/main.tscn` headless under the runner's root, deferring from `_initialize` with `call_deferred` and awaiting a few frames; swap `main.clock` for a clock on a fake time source; send input through `main._unhandled_key_input` and `board_view._gui_input`. UI-004's re-review showed it works, and `tests/test_session.gd` already runs this way. Folded into Primary files and `## Tests stage 2 writes`; Stage back to `to-implement`.
- Related: BOT-005 c2 clamps Maia's delay to its clock left, so Maia's move can land at 0 by design (note in BOT-005 ## Comments). UI-007's premoves also commit a move at the instant the opponent moves.
- Stage 2 (2026-10-25): callers examined before the red test: Godot dispatches global `_input` before BoardView's `_gui_input`; normal drops and promotion choices reach `_submit`/`_commit`, then `Main._on_move_played` accounts for the clock. `_process` must keep ticking without input. Premoves charge separately in `_next_turn`; Maia uses `_on_maia_move`/`BoardView.play`, outside this human-input fix. Boundary cases: no clock before setup, untimed first moves, exactly zero, a stopped clock, and the 10 s threshold before increment. The real scene becomes ready synchronously under the already-deferred runner, as in `test_session.gd`; no runner change or frame wait is needed. The mouse helper dispatches global input through the viewport before board-local GUI input, without a frame tick.
- First red: the new mating-drop test fails because late `d8h4` is accepted as `Qh4#`, emits `move_played` and move/check sounds, and appends SAN. Full gate before the fix: exit 1, 231 passed, 1 failed (`%TEMP%/CLOCK-002-red-1.log`). The initial sandbox run had unrelated user-data permission failures; this red was reproduced with access to Godot's user-data directory.
