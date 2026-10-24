# CORE-002: Position and FEN
Stage: to-review
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

- 2026-10-24 Stage 2: red on 8ccc45f (`test_fen.gd` fails to load, `core/board.gd` missing; 8 passed, 1 failed), green on 443b1bf (12 passed, 0 failed, exit 0). API for CORE-003 on: `Board.from_fen(fen)` returns the board or `null` (no `push_error`, so bad input never counts as a script error), `to_fen()`, `position_key()`, `piece_at("e4")`, public `side_to_move` / `castling` / `en_passant` / `halfmove_clock` / `fullmove_number`, and `squares` (64, a1 = 0, FEN letter or ""). No callers yet: the file is new. Beyond criterion 3 the parser also rejects a castling field out of `KQkq` order or repeated, an en-passant square on the wrong rank for the side to move, a negative halfmove clock, fullmove 0, and anything but exactly six fields. It does not check king count or piece legality; that is movegen's ground (CORE-003).

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\4e9483fb-7d4c-4415-8015-5b70d1a1fc01\scratchpad\CORE-002-gate.json
