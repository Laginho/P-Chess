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
2. It states how the bundled `engine/stockfish/stockfish.exe` loads them (`setoption name SyzygyPath ...`), showing a relative-path probe with output on this Linux box using the Linux build of Stockfish 19. It measures the base directory for relative paths and recommends the path the app should pass. It cites Windows path-list and directory separator behavior from source, gives Bruno a Windows verification command, and marks that check pending.
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

- Proxy decided (opus-5.5 xhigh): proceed on Linux and do not wait for a Windows run. Criterion 2 gets measured with the Linux build of the same Stockfish 19 release (`sf_19`). The Windows-only syntax is cited from the source and stays marked pending until Bruno checks it on Windows. Build lc0 v0.32.1 natively for criterion 5. — Syzygy probing is the same code on both platforms, the ticket is `Review: human` anyway, and the repo has done this before: Windows-only live checks were written up as "pending (Bruno)" rather than holding the work (review-explore spec scenario 1, CLEAN-009). (receipt /tmp/sweatshop-proxy/20261107-223947-RES-001-ce51d3.json)

Criteria check by independent subagent (research ticket: no new tests):
- ✅ 1: docs/research/tablebase.md:5 (file sizes, hashes and closure).
- ✅ 2: docs/research/tablebase.md:41 (Linux probe and pending Windows confirmation); corrected interactive command after review.
- ✅ 3: docs/research/tablebase.md:80 (UCI result and DTZ limitation); clarified the child's DTZ sign after review.
- ✅ 4: docs/research/tablebase.md:93 (best move and timings).
- ✅ 5: docs/research/tablebase.md:99 (ten positions per net and limitations).
- ✅ 6: docs/research/tablebase.md:133 (source sizes and extraction cost).
- ✅ 7: docs/research/tablebase.md:139 (CI-005 and LEARN-006 recommendations).
