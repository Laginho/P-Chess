# CLOCK-002: A move dropped after the time ran out
Stage: blocked
Blocked by: CLOCK-001
Review: agent
Difficulty: normal

- Primary files:
  - ui/main.gd
  - The test file stage 1 picks (question under Comments)

#### What to build

When the human's time runs out, a piece they drop in that same frame is not played: the game ends on time, as if the drop had come a moment later. Today `core/clock.gd` only learns the time ran out at the next `_process` tick, and Godot handles input before `_process`, so a drop up to one frame (~16 ms) after the clock hit 0 is played first, and `Clock.moved` flags after it. Found in CLOCK-001's review.

#### Acceptance criteria

1. A piece dropped after the human's clock reached 0, before the next frame's tick, snaps back as in CLOCK-001 criterion 8: no move, no move sound, no `move_played`. The game ends `time` by CORE-004's flag rule on the position before the drop.
2. In 3+2, a drop in the frame the human's clock crossed the low-time threshold (10 s) still plays the low-time sound once, though the increment lifts the clock back above it.
3. A piece dropped while time is left plays as before.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- Not chosen yet: see the question for stage 1 under Comments.

## Comments

- 2026-10-24 Created at CLOCK-001's close (stage 3). Today the late move stays on the board and in the move list, and the flag rule then reads the position after it: a mating late move stands as checkmate, and a late capture of the opponent's last mating material turns a loss on time into a draw. The 3+2 low-time sound can be skipped the same way. Candidate fix: `ui/main.gd` ticks the clock in `_input`, which Godot runs before the board's `_gui_input`, so the flag lands first and CLOCK-001's `_commit` guard snaps the piece back.
- Question for stage 1 (why this is `blocked`): which test seam? `ui/main.gd` needs the tree for its `@onready` nodes, starts Lc0 in `_ready`, and `_start` hard-codes `Time.get_ticks_msec`, so no existing test reaches the input order. Options: (a) instance `ui/main.tscn` under the test runner's root, swap `main.clock` for one on a fake time source, and push a mouse event through the viewport; (b) a seam `tests/test_board_view.gd` can reach, e.g. BoardView ticks a clock it is given before `_commit`, which adds `ui/board_view.gd` to Primary files.
- Related: BOT-005 c2 clamps Maia's delay to its clock left, so Maia's move can land at 0 by design (note in BOT-005 ## Comments). UI-007's premoves also commit a move at the instant the opponent moves.
