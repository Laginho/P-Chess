# CORE-006: PGN read and write
Stage: to-implement
Blocked by: CORE-005
Review: agent
Difficulty: normal

- Primary files:
  - New: core/pgn.gd
  - New: tests/test_pgn.gd
  - New: tests/fixtures/pgn/ (sample files)

#### What to build

`core/pgn.gd` reads and writes PGN. Saved games with `%clk` (§9.4) and imported repertoires with variations (§6.4) both go through it.

#### Acceptance criteria

1. Parses headers, the mainline, variations nested at least two levels deep, `{}` comments, NAGs (`$n`) and move suffixes, and the result token.
2. A file with several games returns every game.
3. `[%clk h:mm:ss]` and `[%clk h:mm:ss.f]` in a move's comment give that move's clock in milliseconds.
4. Writing a game with headers and clocks, then reading it back, returns the same headers, moves and clocks.
5. An illegal move returns an error naming the game and the move number; it never crashes.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_pgn.gd`: fixtures with nested variations, several games, `%clk` and an illegal move, plus the write–read round-trip. Red because `core/pgn.gd` does not exist.

## Comments
