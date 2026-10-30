# REV-002: Analyse a game with Stockfish and store the result
Stage: to-implement
Blocked by: CI-004, REV-001
Review: agent
Difficulty: hard

- Primary files:
  - New: engine/analyser.gd
  - New: scripts/analyse.gd (headless: analyse one PGN, write its JSON)
  - core/tunables.gd (if BOT-011 has not created it yet, create it)
  - engine/uci.gd (only to parse MultiPV `info` lines, if that belongs there)
  - New: tests/test_analyser.gd
  - New: tests/fixtures/analysis/ (recorded Stockfish transcripts)
  - docs/spec.md (§15.3)

#### What to build

Given a saved game, run Stockfish over every position and write `user://analysis/<game file name>.json` (§15.3). Nothing in the UI calls it yet; the review (REV-005) and the queue (HIST-006) do. Until then a headless script analyses one PGN, which is also how fixtures get recorded.

#### Acceptance criteria

1. Positions are analysed backwards, last to first, with `MultiPV 2`; one `ucinewgame` per game and the hash kept for the whole game.
2. Each position is searched with `go nodes` at the budget (3 000 000, from `core/tunables.gd`). The search is stopped early once it has reached depth 12 and the last 3 completed depths have the same PV1 move and an expected-points change under 0.01 (EP as §15.4, cp clamped ±1000, mates ±1000). The rule is a pure, tested function.
3. Threads: "Background" sends `Threads 1`; "Max" sends logical cores − 1 (at least 1).
4. Every FEN is checked with `core/board.gd` before it is sent; an invalid position aborts that game's analysis with an error and nothing is sent, so Stockfish never sees it.
5. The JSON stores, per position: up to two PV lines (move list, `cp` or `mate`, depth) and the best move; a position with one legal move stores only PV1; a game-over position stores no PV and its terminal score (checkmate +1000 for the side that gave it, any draw 0). It also stores the engine version (from `id name`) and the node budget. The PGN is never touched.
6. A file whose engine version or budget differs from the current one reads as **stale**; a missing file reads as not analysed.
7. Progress is reported per position (a signal with done/total), so a caller can fill moves in as they land; analysis can be cancelled, and a cancelled game leaves no partial file.
8. `godot --headless -s scripts/analyse.gd -- <pgn>` analyses one game on Max and writes its JSON.

#### Verification

    Manual: run scripts/analyse.gd on a saved game; check the JSON and the time it took.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_analyser.gd`, with a fake bridge replaying fixture transcripts (CI has no Stockfish): positions are sent last to first; the convergence function stops at depth 12 with 3 stable depths and not before; an invalid FEN sends nothing; forced and terminal positions are stored as criterion 5; stale detection on version and budget (red: no analyser).

## Comments

- 2026-10-30 Written from spec §15.3. Speed figures in the spec are this machine's.
