# CLOCK-001: Clocks and flag
Stage: done
Blocked by: BOT-004
Review: agent
Difficulty: normal

- Primary files:
  - New: core/clock.gd
  - New: ui/clock.tscn, ui/clock.gd
  - ui/main.tscn, ui/main.gd
  - ui/setup.tscn, ui/setup.gd (time control)
  - core/game.gd (flag)
  - New: tests/test_clock.gd
  - ui/board_view.gd (scope: `_commit` refuses a move the game rejects)
  - tests/test_board_view.gd

#### What to build

Real clocks for both sides in the three time controls (§5), with the flag ending the game through CORE-004's rule. Maia still moves at once; its think time is BOT-005.

#### Acceptance criteria

1. The setup screen offers exactly 1+0, 3+2 and 5+0.
2. Clocks count in milliseconds. The increment is added after each timed move of that side. A side's first move is untimed (criterion 4) and adds no increment, as on Lichess: in 3+2 both clocks read 3:00 when White's clock starts, and White's second move adds 2 s.
3. The display shows `m:ss`, and tenths under 10 s (`0:09.4`).
4. Each clock starts with its side's first move, as on Lichess: no clock runs while a side makes its first move.
5. The low-time sound plays once per game for the human, at 10% of the starting time or 10 s, whichever is lower: 6 s at 1+0, 10 s at 3+2 and 5+0.
6. A clock reaching 0 ends the game by CORE-004's flag rule (a loss, or a draw on insufficient material). Maia can flag.
7. `core/clock.gd` takes an injected time source; the tests use a fake one and never wait.
8. A piece held when the game ends (a flag) snaps back when dropped: no move is played, no sound plays and `move_played` is not emitted. The same holds for a promotion picked after the flag.

#### Verification

    Manual: a 1+0 game lost on time; a game won on time against Maia (set Maia's clock low by hand).
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_clock.gd`: with a fake time source: increment, first-move start rule, the low-time threshold for each control, and the flag event. Red because `core/clock.gd` does not exist.
- `tests/test_board_view.gd`: hold a piece, flag the game, drop it: no `move_played`, no sound, no move. Red because `_commit` ignores `game.play`'s false return.

## Comments

- Proxy decided (opus): the increment is added after every timed move of a side; a side's first move is untimed (criterion 4) and adds no increment, as on Lichess (in 3+2 both clocks read 3:00 when White's clock starts) — criterion 4 and §5 make the first move untimed like Lichess, and an increment on it is 2 s free; folded into criterion 2.
- For HIST-002 (not edited on this branch): its criterion 2 computes time spent as clock before − clock after + increment, which shows 2 s for a side's first move in 3+2 under the rule above. Proxy's draft for stage 1 to apply on the base: "2. The move list shows the time spent on every move for both sides: the clock before the move, minus the clock after it, plus the increment; a side's first move is untimed and shows 0 s (a pure function, tested)."
- Proxy decided (opus): ui/board_view.gd (scope: _commit) and tests/test_board_view.gd join Primary files with a new criterion 8; _commit returns early, snapping the piece back, when game.play(move) is false — the flag is the first way a game ends while a piece is held, and _commit ignored play()'s false return and still emitted sounds and move_played, which put a phantom SAN in the move list; the guard also covers a promotion picked after a flag.
- Stage 2: core/game.gd needed no change; Game.flag (CORE-004) already applies the rule, and main connects Clock.flagged to it. Red→green: test_clock.gd failed to load without core/clock.gd (92c2e75), 9/9 pass at e3ccac4; the board-view test emitted ["move", "e4"] after the flag (dd90948), passes at d1910f1. A headless smoke run of ui/main.tscn showed the three controls in setup and a 1+0 flag ending the game "0-1, time" with White's clock at 0:00.0. Manual checks in Verification (a real 1+0 loss, a win on time against Maia) not run. A move landing after the time ran out (at most a frame late) flags in Clock.moved, but the move itself stays on the board; if that move was mate, the mate stands.

- Stage-2 receipt (superseded at close, see Resolution): D:\Desktop\Projects\P-Chess\.artifacts-build\gate-evidence\CLOCK-001-core-gate.json, commit 3791c3f, exit 0, 102 passed, 0 failed.
Gate evidence: D:\Desktop\Projects\P-Chess\.artifacts-build\gate-evidence\CLOCK-001-core-close.json

#### Resolution (2026-10-24)

Verdict: Approve

Stage 3 (opus-5.5). The Standards and Spec axes ran as separate sub-agents. Standards: no violation; one judgement call, the board-view test reads the private `_drag_from` (no public accessor exists). Spec: criteria 1–8 met, no scope creep; criterion 8's promotion path has no dedicated test. I read the whole diff and the code around it.

Criteria:

1. ✅ `ui/setup.gd` fills its Control option from `Clock.CONTROLS`, whose keys are exactly 1+0, 3+2, 5+0 (`test_only_the_three_time_controls`). Start emits the chosen text and `main._start` builds the clock from it.
2. ✅ `Clock.moved` adds the increment only when the mover's clock was running, so first moves add none (`test_no_clock_runs_while_a_side_makes_its_first_move`, `test_increment_is_added_after_each_timed_move`).
3. ✅ `Clock.format`, truncated: 10000 → `0:10`, 9449 → `0:09.4`, 59999 → `0:59`, 0 → `0:00.0`.
4. ✅ No clock runs until both sides have moved once: White's starts on Black's first move, Black's on White's second.
5. ✅ `low_time_ms = mini(start / 10, 10000)` gives 6 s, 10 s, 10 s; `_warned` fires once per side per game, and `main` plays the sound only for the human's side. A miss in a one-frame window in 3+2 is in CLOCK-002 (below).
6. ✅ `tick()` flags the running side at 0 and `main._on_flagged` calls `Game.flag`, CORE-004's rule; Maia flags in `test_maia_can_flag_and_the_game_ends_on_time` (1-0, time). Edge, disclosed by stage 2 and routed to CLOCK-002: a drop within the frame the human's clock hits 0 (Godot handles input before `_process`) is played before the flag, so the flag rule reads the position after that move and a mating late move stands. I judged this one-frame window a follow-up, not a failed criterion.
7. ✅ `Clock._init(control, time_source)`; the tests drive a `FakeTime` and never wait; `main` passes `Time.get_ticks_msec`.
8. ✅ `_commit` returns through `_end_snap_back` when `game.play` refuses, before any sound or `move_played` (`test_a_piece_held_when_the_game_ends_snaps_back_without_a_move`). A promotion picked after the flag reaches the same guard through the picker's `picked`; not separately tested.

Rules: test-only 92c2e75 and dd90948 alternate with production-only e3ccac4, d1910f1 and 3791c3f; the ticket rides in the test commits and in 3e78baf. Only Primary files changed (`core/game.gd` needed none). No rebase was needed: the branch sat on the session tip. Merged as c160ef0.

Red-green: stage 2's reds (92c2e75: `core/clock.gd` missing; dd90948: `["move", "e4"]` emitted after the flag). Mutation check in review, restored afterwards: dropping `_commit`'s guard, removing the 10 s cap from `low_time_ms`, and removing the late-move flag from `moved` each failed its test (99 passed, 3 failed).

Examined: every caller of what changed: `_commit` (`_drop`, the picker's `picked`, and `play` for Maia, which checks legality and game over first); `setup.started` (only `main._start`); `Game.flag` (main and tests). Also: `_on_move_played` working out the mover from `side_to_move`; a flag while Maia thinks (her later move hits `BoardView.play`'s game-over check), while a piece is held, or while the picker is open; the setup overlay keeping input off the board before a clock exists; `_set_flipped` order under `F`; `maia.median_ms()` at a flag (Maia has always moved by then). Not examined: the manual checks in Verification, the windowed app, the exported build.

`Proxy decided` lines: two, both (opus), under Comments: criterion 2's untimed first move without increment, and criterion 8 with `ui/board_view.gd` and `tests/test_board_view.gd` added to Primary files.

Gate: the stage-2 receipt held (3791c3f, exit 0, `102 passed, 0 failed`), but the follow-ups below changed other tickets after it. Rerun on session commit 484ee9b: exit 0, `102 passed, 0 failed` (receipt in the `Gate evidence:` line above). Production is identical to 3791c3f.

Follow-ups created at this close (484ee9b): CLOCK-002 (`.scratch/core/issues/32-CLOCK-002-move-after-flag.md`, blocked on a test-seam question for stage 1), and notes under `## Comments` of HIST-002 and BOT-005.

Acceptance: pending | the manual checks in Verification: a 1+0 game lost on time, and a game won on time against Maia (Maia's clock set low by hand). So far: gate 102/102 on 484ee9b, and stage 2's headless smoke run of `ui/main.tscn` showed the three controls and a 1+0 flag ending "0-1, time" (Comments).
Disclosure: decision | none | Proxy decided (opus), see ## Comments: a side's first move is untimed and adds no increment, as on Lichess; folded into criterion 2.
Disclosure: decision | none | Proxy decided (opus), see ## Comments: criterion 8 added, with `ui/board_view.gd` (`_commit`) and `tests/test_board_view.gd` in Primary files; `_commit` snaps back when `game.play` refuses the move.
Disclosure: pending | release | HIST-002 criterion 2 must give a side's untimed first move 0 s, or it shows 2 s in 3+2. The proxy's draft is under HIST-002 `## Comments` for stage 1 to fold.
Disclosure: deferred | release | a drop within one frame after the human's clock reaches 0 is played before the flag: it stays in the move list, the flag rule reads the position after it (a late mate stands; a late capture of the opponent's last mating material turns a loss on time into a draw), and the 3+2 low-time sound can be skipped the same way. Open follow-up: CLOCK-002 (`.scratch/core/issues/32-CLOCK-002-move-after-flag.md`). Maia meets the same path through BOT-005 c2's clamp (note in BOT-005 `## Comments`).
Disclosure: pending | release | the manual checks in Verification have not been run by a person (Acceptance above).
