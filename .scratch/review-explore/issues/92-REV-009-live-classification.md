# REV-009: Live classes for side-line moves
Stage: implementing
Status: ready-for-agent
Blocked by: REV-008
Review: human
Difficulty: hard

- Primary files:
  - engine/live_analysis.gd (settle criterion, per-FEN results, order of searches)
  - engine/analyser.gd (`_parse_info` reads `nodes`, if REV-008 did not)
  - ui/review.gd (class icons on the square and the line rows, green arrow in side lines)
  - tests/test_live_analysis.gd, tests/test_review.gd
  - docs/spec.md (§15.6)

#### What to build

Spec: `.scratch/review-explore/spec.md`. Each move you play in a side line gets its class (Best, Blunder, …) as real-time feedback, with the same rules and data shape as game moves, so a move classifies the same whether it was played in the game or explored. Icons only, no feedback text.

#### Acceptance criteria

1. A side-line position is **settled** when its live search reaches `Tunables.ANALYSIS_NODES` nodes or `Analyser.converged` holds on its completed depths, whichever comes first. Its result, in the stored-analysis shape (`fen`, `pv` with 2 lines, `best_move`), is kept per FEN for the line's life and dropped with the line.
2. A side-line move's class is computed once both its before and after positions are settled, by `Classification.evaluate` over the game moves up to the branch plus the line moves, with the stored game analysis for the game positions; it never changes while the line exists. Book, Repertoire, Forced and Miss therefore behave as for game moves.
3. When the game has no stored analysis for the positions the first line move needs (the branch position, and the one before it, which Miss looks at), those positions are searched live and settled too. A move whose class still depends on an undecided earlier class shows no icon.
4. The class icon shows on the destination square while the move is shown, and beside the move in its line row.
5. If you move on before a position settled, the engine first settles the positions the shown move needs, then searches the shown position; meanwhile the block shows "Stockfish is thinking…". The class arrives when ready.
6. The green "should have played" arrow on a side-line move shows the best move of its settled before position, and nothing before that.
7. Replacing part of the line drops the classes of the removed moves; going back to a line position already settled searches nothing new for its class.
8. For the same engine data, a move gets the same class played in the game (stored analysis) and explored as a side line.
9. Gate green.

#### Verification

    Manual (Bruno, Windows, real Stockfish): from a Blunder, try moves until one is Best; play fast through a line and watch the classes arrive; compare an explored game move with its game class.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- tests/test_live_analysis.gd, with a fake bridge: a position settles at the node budget and, earlier, on convergence (red: nothing settles); results are cached per FEN; an unsettled earlier position is finished before the shown one.
- tests/test_review.gd: a side-line move gets an icon on its square and row once both positions settle, and keeps it as the search goes on (red: no icon); the same scripted engine data gives the game move's class; overwriting drops classes; the green arrow appears only after settling; on an unanalysed game the branch positions are searched live.

## Comments

- 2026-11-05 Written from the grill (spec.md). The proxy chose MultiPV 2 for the live search (not 3) so live classes match game classes.

- 2026-11-05 Stage 2: ticket-approved seams are the live controller with a fake UCI bridge and Review with `analysis_bridge_factory`. Inspected callers: search/switch/stop, Review navigation/overwrite/terminal/hide, streamed game analysis, Classification.evaluate and its Miss/Great dependencies. Degenerate inputs to cover: one legal move, terminal after-position, absent game analysis, pending earlier classes, rapid switches, cache removal and engine failure.

- 2026-11-05 Test harness correction: the stored/live comparison must supply one clock snapshot per game move to `present`, as required by PGN generation. Fixed those fixtures before implementation; the corrected test fails on the missing side-line icons and green arrow.
