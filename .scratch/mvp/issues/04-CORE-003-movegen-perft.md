# CORE-003: Legal move generation and perft
Stage: to-implement
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
