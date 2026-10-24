# CORE-005: SAN in and out
Stage: to-review
Blocked by: CORE-003
Review: agent
Difficulty: normal

- Primary files:
  - core/board.gd (SAN)
  - New: tests/test_san.gd

#### What to build

Moves in Standard Algebraic Notation, both ways. The move list, the PGN files, the openings TSVs and repertoire import all speak SAN.

#### Acceptance criteria

1. Moves print as SAN: piece letter, `x` on captures, `=Q`/`=R`/`=B`/`=N` on promotion, `O-O`/`O-O-O`, `+` for check, `#` for mate.
2. Disambiguation uses the file when that is enough, else the rank, else both (tested with three queens that can reach one square).
3. SAN parses back to the move; trailing `+`, `#`, `!` and `?` are accepted; illegal or ambiguous SAN returns an error.
4. For every legal move at depth 1 from the six perft positions, parsing the printed SAN gives back the same move.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_san.gd`: the cases above and the round-trip. Red because there is no SAN code.

## Comments

- 2026-10-24 Stage 2, two test-only commits then one production commit. Red on a14952b: `board.gd` has no `san()` or `parse_san()`, so the six SAN tests fail with a script error (29 passed, 6 failed). 73e32af adds black `O-O` and "a rook on e1 is not `O-O`". I proved it red against a `parse_san` without the king check on castling (34 passed, 1 failed: `O-O` returned `e1g1`). Green on 3a2aeb5: 35 passed, 0 failed.
- API for UI-001, CORE-006 and OPEN-001/003: `Board.san(uci) -> String` takes a move from `legal_moves()`; an illegal move gives an undefined result. `Board.parse_san(text) -> String` returns the UCI move, or `""` when the SAN is illegal, ambiguous or malformed. That follows `from_fen`'s null with no `push_error`, because bad input is expected from imports. The parser accepts more than the printer writes: extra disambiguation (`Ng1f3` from the start), a missing `x`, and a missing `=` before the promotion piece. A pawn move to the last rank without a piece is an error. Disambiguation counts only legal rivals: a pinned knight does not count (`PINNED_KNIGHT` test).
- Callers: `board.gd` only gains `san`, `parse_san`, `_san_without_check` and the `_san_pattern` static; no existing function changed, and nothing outside the tests calls the new ones yet. Degenerate inputs: a position with no legal moves parses everything to `""`. Cost: `parse_san` runs one `legal_moves()`; `san` runs one, plus a copy and one more on the resulting position when it gives check.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\3d2548b4-bba8-491a-a2b6-d9510d6cc35a\scratchpad\CORE-005-gate.json
