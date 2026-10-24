# CORE-002: Position and FEN
Stage: to-implement
Blocked by: CORE-001
Review: agent
Difficulty: normal

- Primary files:
  - New: core/board.gd
  - New: tests/test_fen.gd

#### What to build

`core/board.gd` holds a chess position and reads and writes FEN. It also gives the position key (FEN without the halfmove and fullmove counters) that repetition (§7) and the opening book (§6.2) match on.

#### Acceptance criteria

1. Parsing then printing FEN returns the same string for the start position, Kiwipete and CPW perft positions 3–6 (FENs in CORE-003).
2. All six FEN fields are kept: placement, side to move, castling rights, en-passant square, halfmove clock, fullmove number.
3. Invalid FEN (wrong rank count, unknown piece letter, bad side to move, bad castling field) returns an error value; it never crashes.
4. The position key is the FEN without its last two fields; two positions that differ only in move counters have the same key.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_fen.gd`: round-trip of the six FENs, the invalid cases and the position key. Red because `core/board.gd` does not exist.

## Comments
