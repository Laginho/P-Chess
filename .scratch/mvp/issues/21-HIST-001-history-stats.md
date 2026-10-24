# HIST-001: Game history and stats
Stage: to-implement
Blocked by: CORE-006, UI-004
Review: agent
Difficulty: normal

- Primary files:
  - New: core/history.gd
  - core/pgn.gd (writer, if a header or clock case is missing)
  - ui/main.gd
  - New: tests/test_history.gd

#### What to build

Every finished game is saved as PGN with clocks, and per-level stats are kept (§9.4).

#### Acceptance criteria

1. At game end the game is saved to `user://games/` as one PGN file, with `[%clk]` after every move giving that side's clock after the move.
2. Headers: the players are "Maia 1500" (the net's level) and "You"; `TimeControl` is `60+0`, `180+2` or `300+0`; `Result`; `Termination` (`Normal` or `Time forfeit`); `Opening` when a name is known (filled by OPEN-002). No rating headers.
3. Stats per (level, time control): wins, draws, losses, flag wins and flag losses, updated at each game end and persisted under `user://`.
4. A saved PGN parses back with `core/pgn.gd` to the same moves and clocks.
5. A failed write is reported and does not crash the app.

#### Verification

    Manual: play two games, open the files in user://games/.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_history.gd`: saving a finished game to a temp folder and parsing it back; stats after a flag win and a draw. Red because `core/history.gd` does not exist.

## Comments
