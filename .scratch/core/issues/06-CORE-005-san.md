# CORE-005: SAN in and out
Stage: implementing
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

- 2026-10-24 Review note (not required by the criteria): the tolerances documented above (missing `x` on a piece capture, missing `=`, extra disambiguation, `Kg1` for `O-O`) have no dedicated test. The perft round trip only feeds `parse_san` the printer's own output. Stage 2 may pin the ones it keeps in its test commit.

#### Review (2026-10-24)

Verdict: Reopen — criterion 3: pawn SAN without a departure file parses as a capture instead of returning an error

Stage 3 (opus-5.5). The Standards and Spec axes ran as separate sub-agents. I also read the whole diff and ran `parse_san` in Godot on the inputs below.

Criteria:

1. ✅ `test_moves_print_as_san`: pushes, piece moves, pawn and en-passant captures, `Bxf7+`, `Qh4#`, both castlings, all four promotions and `exd8=Q+`.
2. ✅ `test_disambiguation_uses_file_then_rank_then_both`: the three queens give `Qdd4` (file), `Q4d4` (rank) and `Qa1d4` (both). Knights and rooks cover file and rank on their own, and a pinned knight does not count as a rival.
3. ❌ Legal SAN, trailing marks and ambiguity all behave correctly, but some illegal SAN is accepted. SAN always writes a pawn capture with its departure file (FIDE Laws, Appendix C), so a pawn move without a file names the pawn on the destination file. `parse_san` instead matches any pawn that reaches the square, so it returns a capture:
   - `rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2`: `d5` → `e4d5`, and `xd5` → `e4d5`. Both should be `""`; `exd5` and `ed5` stay valid.
   - `rnbqkbnr/pppp1ppp/8/4p3/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 0 2`: `e5` → `d4e5`.
   - `4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1`: `d6` → `e5d6` (en passant).
   Impact: a mistyped or corrupt move in a PGN, TSV or repertoire import silently becomes a capture instead of an error. No valid SAN parses wrong: a push lands on an empty square, a capture on an occupied one, and an en-passant square is never also a push target. So the fix only rejects invalid input.
4. ✅ `test_every_printed_move_of_the_perft_positions_parses_back`: every depth-1 move from the six chessprogramming.org perft positions.

What is left for stage 2: criterion 3 only. First a test-only commit where the four inputs above are red. Then a production commit in `parse_san`: a pawn SAN with no departure file must come from the destination file. The perft round trip must stay green.

Test-first: I checked `diff --stat` on every commit:
- a14952b: `tests/test_san.gd` and the Stage line (red).
- 73e32af: `tests/test_san.gd` only.
- 3a2aeb5: `core/board.gd` only.
- f01e36c: the ticket only.

All code files are in Primary files.

Examined:
- Callers: `board.gd` only gains `san`, `parse_san`, `_san_without_check` and `_san_pattern`. No existing function changed, and `test_fen`, `test_perft` and `test_rules` are green in the 35/35 gate. No production code calls the new functions yet. The planned callers (UI-001, CORE-006, OPEN-001, OPEN-003) go through the API documented above.
- Failure paths, all returning `""`: empty or malformed text, a position with no legal moves, `e8` with no promotion piece, an ambiguous `Qd4`/`Qad4`/`Q1d4`, and `O-O` when a rook rather than the king stands on e1. `san()` on an illegal move is undefined, as documented.
- Tolerances examined and kept as documented: a missing `x` on a piece capture (`Nd5` for `Nxd5`), a missing `=`, and extra disambiguation. In each case the piece and destination are the ones named, so these are not findings. `Kg1` for `O-O` returns `e1g1`; the king really does go to g1, so it falls in the same category.
- Standards: the repo documents no coding standards, so these are judgement calls only. `static var _san_pattern` instead of `const` is required, because a RegEx is an object. The untyped `var after = copy()` matches `copy()`'s untyped return. No change asked.
- Not examined: Godot versions other than the local 4.x the gate ran on.

Gate: the stage-2 receipt above still holds for 3a2aeb5 (exit 0, 35 passed, 0 failed). Review changed no code.
