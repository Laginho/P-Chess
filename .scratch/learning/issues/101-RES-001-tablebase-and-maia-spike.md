# RES-001: Tablebase and Maia spike
Stage: implementing
Blocked by: none
Review: human
Difficulty: normal

- Primary files:
  - New: docs/research/tablebase.md (the only repo change; downloads and throwaway scripts stay outside the repo)

#### What to build

Answer the facts the learning spec leaves open (spec "Further Notes", §L5, §L12) before anything is built on them, and write the answers to `docs/research/tablebase.md` with sources and the commands used.

#### Acceptance criteria

1. The doc lists every Syzygy file rook and pawn against rook needs, including the smaller endings it can turn into (after captures and promotions), with each file's size and the total, from the official Syzygy file listing.
2. It states how the bundled `engine/stockfish/stockfish.exe` loads them (`setoption name SyzygyPath ...`, a relative path from the exe, Windows path separators), shown working on this machine with the output of one probe.
3. It answers, with real Stockfish output: can we get win, draw or loss for the side to move in a 5-piece position, and a distance to zeroing (or a usable stand-in) per legal move? If Stockfish can't give a per-move distance, it names the alternative (for example probing the `.rtbz` files ourselves) with its cost, and says which the grader (§L6) should use.
4. It states how to get the tablebase-best move (the perfect opponent, §L8) and how long one probe and one best move take.
5. It reports how Maia-1 (1500 and 1900) plays at least 10 rook-and-pawn-against-rook positions (5 to convert, 5 to hold) against the tablebase: how often its move keeps the result, and whether holds look too easy or converts too hard.
6. It gives the size of the Lichess puzzle and standard game databases, and whether positions for the unit can be picked from them cheaply (they are CC0, ADR 0002).
7. It ends with a short recommendation for CI-005 (which files, from where, with hashes) and LEARN-006 (how to probe).

#### Verification

    Manual: Bruno reads docs/research/tablebase.md.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None: research ticket, no production code.

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md`.
