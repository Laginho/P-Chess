# CORE-003: Legal move generation and perft
Stage: done
Blocked by: CORE-002
Review: agent
Difficulty: hard

- Primary files:
  - core/board.gd
  - New: tests/test_perft.gd

#### What to build

Full legal move generation in `core/board.gd` (castling, en passant, promotion, check), proven by perft against the Chess Programming Wiki numbers (§11). Every rule, the board view and the bot sit on it.

#### Acceptance criteria

1. Start position, perft depths 1–4: 20, 400, 8,902, 197,281.
2. Kiwipete (`r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1`), depths 1–3: 48, 2,039, 97,862.
3. Depth 3: position 3 (`8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1`) 2,812; position 4 (`r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1`) 9,467; position 5 (`rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8`) 62,379; position 6 (`r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10`) 89,890.
4. Making a move and taking it back (or copying the position) leaves the FEN unchanged, for every move at depth 2 from Kiwipete.
5. A move carries its promotion piece: the four promotions of one pawn push are four distinct moves.
6. The board reports whether the side to move is in check.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_perft.gd`: the perft counts above and the make/unmake round-trip. Red because there is no move generator.

## Comments

- 2026-10-24 Stage 2, two red/green cycles:
  - Cycle 1, criteria 1–6: red on bf75670 (`legal_moves`/`in_check` do not exist; 12 passed, 6 failed), green on 1402a05 (18 passed, 0 failed). Perft matched every CPW count on the first green run.
  - Cycle 2, beyond the criteria: red on ae1a88a (18 passed, 3 failed), green on a84b928 (21 passed, 0 failed). make_move records the en-passant square only when a legal capture exists, as Lichess and python-chess write FEN. Otherwise the position key after a double push differs from the same position reached another way, and CORE-004's repetition counts would be off by one. Also, a side without a king is never in check, and a pawn on its last rank has no moves. Both boards are ones `from_fen` accepts (CORE-002 left king count and pawn ranks to movegen); before the guards, the first gave wrong moves and the second indexed past the board.
- API for CORE-004/005, UI and BOT: `legal_moves()` returns UCI strings (`e2e4`, `e7e8q`, castling as the king's move `e1g1`), the form BOT-002's bridge speaks. `make_move(uci)` mutates and does not check legality: a caller holding outside input checks `legal_moves()` first. `copy()` returns an independent board (through `from_fen(to_fen())`; the whole suite runs in about 13 s). `in_check()` is for the side to move. No unmake: criterion 4 is met by copy-make. Perft itself lives in the test, not in board.gd.
- Callers: none outside the tests. `from_fen`, `to_fen` and `piece_at` are unchanged. `copy()` calls `from_fen`, which accepts every FEN `make_move` can produce: the en-passant square is on the right rank for the side to move, and the counters stay in range.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\440af560-54d3-4332-b034-77458e5e0acf\scratchpad\CORE-003-gate.json

- 2026-10-24 Stage 3: two behaviours found on positions that only an outside FEN produces. First, `from_fen` does not check that an en-passant square has an enemy pawn behind it. Probe: from `4k3/8/8/3Pn3/8/8/8/4K3 w - e6 0 1`, `legal_moves()` offers `d5e6` and `make_move("d5e6")` removes the knight on e5. Second, `from_fen` keeps the en-passant field as written, while `make_move` writes it only when the capture is legal. So a start FEN carrying a square with no legal capture gets a different `position_key` from the same position reached later.
- Proxy decided (opus): defer both en-passant findings in `Board.from_fen` with no follow-up ticket — only an outside FEN reaches them, no planned feature sends one to `from_fen`, and a CLEAN cycle would cost more than the defect, as with the CORE-002 counter deferral.

#### Resolution (2026-10-24)

Verdict: Approve

Stage 3 (opus-5.5). The Standards and Spec axes ran as separate sub-agents and found nothing to fix. I also read the whole diff myself and ran one probe. I found two behaviours outside the criteria, both reachable only through an outside FEN, and the proxy deferred them. I made no code changes in review.

Criteria:

1. ✅ `test_start_position_perft_to_depth_4` asserts 20, 400, 8,902 and 197,281 depth by depth. The test's perft walks production `legal_moves()`, `copy()` and `make_move()`.
2. ✅ `test_kiwipete_perft_to_depth_3` asserts 48, 2,039 and 97,862. Its FEN matches the ticket character by character.
3. ✅ `test_positions_3_to_6_perft_at_depth_3` asserts 2,812, 9,467, 62,379 and 89,890. All four FENs match the ticket character by character.
4. ✅ `test_moving_a_copy_leaves_the_original_fen_unchanged` takes every depth-2 pair from Kiwipete. It plays the second move on a copy, checks that the parent's FEN is unchanged, and checks the root FEN at the end. If `copy()` returned a shallow or shared board, the test would fail. There is no unmake, and the criterion allows copying instead.
5. ✅ `test_each_promotion_is_its_own_move`: `e7e8q`, `r`, `b` and `n` are each in `legal_moves()`, and each one puts its own piece on e8.
6. ✅ `test_reports_whether_the_side_to_move_is_in_check` covers a rook on the rank and on the file, pawns of both colours, the rule that only the side to move counts, and a pawn that does not attack straight ahead. `in_check()` uses the same `_attacked()` that perft relies on for every legality decision.

Test-first: I checked `diff --stat` on every commit:
- bf75670: `tests/test_perft.gd` and the Stage line only (red).
- 1402a05: `core/board.gd` only.
- ae1a88a: `tests/test_perft.gd` only (red).
- a84b928: `core/board.gd` only.
- 2055cd7: the ticket only.
- d9c09cb: the `--no-ff` merge into the session.

Both code files are in Primary files.

Examined:
- Callers: none outside the tests (I grepped every `.gd` for `board.gd` and `Board`). `from_fen`, `to_fen`, `position_key` and `piece_at` are unchanged, and `test_fen.gd` stays green.
- Failure paths:
  - `make_move` does not validate its input; this is documented, and a malformed string indexes out of range.
  - `copy()` returns null only if `to_fen` writes something `from_fen` rejects, and `make_move` never does. It writes the en-passant square on the correct rank for the side to move. It only ever removes castling letters, and writes `-` when none are left. Its counters never go negative.
- Castling legality: `_king_safe_after` moves only the king and leaves the rook at home. A rank attack that the moved rook would block has to cross the king's home square, and `_add_castling` already refuses castling out of check there. Perft agrees.
- En-passant recording: `_king_safe_after` with a victim square catches a discovered check along the rank. The test case "dxe3 would open the rank" covers it.
- Degenerate boards that `from_fen` accepts:
  - A kingless side and a pawn on its last rank are tested.
  - A white pawn on rank 1 single-steps without crashing; this is untested.
  - An en-passant square with no enemy pawn behind it was probed (see Comments).
- Cross-feature, a note for CORE-004: positions loaded through `from_fen` keep their en-passant field as written, while positions reached by play record it only when the capture is legal. The two Disclosures below give the impact.
- Performance: the whole suite takes about 13 s (measured in stage 2). Perft copies the board through `from_fen(to_fen())` at every node.
- Not examined: the Linux CI run (CI-001 is not built yet) and perft beyond the depths in the ticket.

Red-green, from stage 2 and checked here:
- Cycle 1 is red at bf75670 because `legal_moves` and `in_check` do not exist yet, and green at 1402a05.
- Cycle 2 is red at ae1a88a and green at a84b928. 1402a05 records the en-passant square after every double push. It indexes `_attacked(-1)` when a side has no king, and it indexes past the board for a pawn on its last rank. The three new tests fail on each of those.

Gate: the stage-2 receipt above (a84b928, exit 0, log hash checked) still holds. The ticket branch already sat on the session tip, and only this ticket changed after a84b928. Result: 21 passed, 0 failed.

Proxy decided lines: one, the en-passant deferral under Comments.

Acceptance: passed | gate 21/21 on a84b928 (receipt above): every CPW perft count in §11 matches, plus the copy-make, promotion and check tests

Disclosure: decision | none | stage-2 decision, see ## Comments (cycle 2): make_move writes the en-passant square only when a legal capture exists, as Lichess and python-chess do, so the position key after a double push matches the same position reached another way (CORE-004 repetition). The FEN after 1. e4 is therefore `... b KQkq - 0 1`, not `e3`.
Disclosure: deferred | none | Proxy decided (opus), see ## Comments: Board.from_fen (CORE-002) keeps an en-passant square with no enemy pawn behind it. From 4k3/8/8/3Pn3/8/8/8/4K3 w - e6 0 1, legal_moves() offers d5e6 and make_move("d5e6") removes the knight on e5 (probed). Unreachable through play, because make_move writes the square only after a real double push. Nothing crashes or indexes out of range, because from_fen pins the square to rank 3 or 6. The fix belongs to the first ticket that feeds outside FENs to from_fen, together with the CORE-002 counter guard.
Disclosure: deferred | none | Proxy decided (opus), see ## Comments: from_fen keeps the en-passant field as written, while make_move writes it only when the capture is legal. A start FEN with an en-passant square but no legal capture (standard FEN, PGN §16.1.3.4, writes one after every double push) gets a different position_key from the same position reached later, so CORE-004 repetition would count it one short. Only an outside FEN reaches this, and none is planned. Fix: from_fen normalises the square to "-" unless a legal en-passant capture exists, triggered by the same ticket as above.
