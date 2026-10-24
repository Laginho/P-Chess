# CLOCK-001: Clocks and flag
Stage: implementing
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
