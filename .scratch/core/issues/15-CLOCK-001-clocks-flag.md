# CLOCK-001: Clocks and flag
Stage: to-implement
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

#### What to build

Real clocks for both sides in the three time controls (§5), with the flag ending the game through CORE-004's rule. Maia still moves at once; its think time is BOT-005.

#### Acceptance criteria

1. The setup screen offers exactly 1+0, 3+2 and 5+0.
2. Clocks count in milliseconds; the increment is added after each move of that side.
3. The display shows `m:ss`, and tenths under 10 s (`0:09.4`).
4. Each clock starts with its side's first move, as on Lichess: no clock runs while a side makes its first move.
5. The low-time sound plays once per game for the human, at 10% of the starting time or 10 s, whichever is lower: 6 s at 1+0, 10 s at 3+2 and 5+0.
6. A clock reaching 0 ends the game by CORE-004's flag rule (a loss, or a draw on insufficient material). Maia can flag.
7. `core/clock.gd` takes an injected time source; the tests use a fake one and never wait.

#### Verification

    Manual: a 1+0 game lost on time; a game won on time against Maia (set Maia's clock low by hand).
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_clock.gd`: with a fake time source: increment, first-move start rule, the low-time threshold for each control, and the flag event. Red because `core/clock.gd` does not exist.

## Comments
