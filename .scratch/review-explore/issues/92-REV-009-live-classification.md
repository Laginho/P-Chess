# REV-009: Live classes for side-line moves
Stage: to-review
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

- 2026-11-05 Replaced-contract tests updated in their own test-only commit: `test_side_line_navigation_replacement_and_game_invariants` now expects the green arrow from an already stored before-position; `test_live_engine_updates_only_shown_position_pauses_queue_and_restores_errors` supplies a settled branch and settles the first live position before testing the existing stop/drain behavior; `test_engine_line_click_plays_matching_game_prefix_and_replaces_side_continuation` supplies stored branch history so it continues to test shown-position PV clicks; `test_terminal_engine_lines_have_one_message_and_never_search` keeps prerequisite analysis alive until terminal classification inputs settle, while still forbidding a search of the terminal FEN. All assertions on retained behavior remain unchanged.

- 2026-11-05 Additional regression coverage: rapid three-move exploration receives classes in order while the shown move waits; Book and Repertoire preserve the game prefix and override engine loss bands. Both checks pass and fail with production mutations that bypass prerequisites or omit opening context. Updated-contract tests also fail with targeted mutations disabling PV clicks/live updates/the green arrow or restoring immediate terminal cancellation (logs beside the gate receipt). The PV-click fixture additionally needed its stored PV0 `best_move`, now required when the supplied history becomes fully classifiable; corrected in this test-only commit.


#### Resolution (2026-11-05, stage 2)

Implemented live side-line classes through the existing `Classification.evaluate`, using the full game prefix, stored game positions and frozen live results. Each settled position is cached by FEN; normal positions retain two completed PVs, forced positions one, and terminal positions their game terminal score, matching the stored analyser shape. Settlement uses the game node budget or convergence on completed depths. Unlimited updates may continue for the shown position without changing classification inputs or a published class.

The controller finishes needed positions before searching the shown position. Unanalysed branch history and earlier undecided class dependencies settle live, while the shown block remains in its thinking state. Class icons appear on the destination square and side-line row; the green arrow becomes available from the settled before-position. Returning reuses cached results; replacement removes the discarded classes and FEN results. Terminal positions receive classes after their nonterminal prerequisites finish, without searching the terminal board, and then release Stockfish. Leaving the line discards all temporary data. Game analysis, summary, graph and exports retain their existing behavior. Updated `docs/spec.md` §15.6; the analyser already parsed nodes and needed no change.

Verification:

- Bound gate on `cc8ef1dc8908ed404463ba09bddea9ce9cf5e897`: `godot --headless -s tests/run.gd`, exit 0, **552 passed, 0 failed**. Receipt and log are under `/run/media/lage/New Volume/Scratch/rev009/`; receipt log SHA-256 verified. The headless run skips the existing last-move pixel assertion and six real-Lc0 checks because the Windows engine is absent.
- Eight new regression tests pass in the full gate: three controller tests cover node-budget settlement, convergence/forced moves, frozen cache lifetime and prerequisite ordering/cache pruning; five Review tests cover equality with stored game classes, immutable square/row icons, unanalysed Miss history, overwrite/cache reuse, terminal moves, rapid three-move exploration and Book/Repertoire precedence.
- Red/green evidence is retained in separate commits: `27ebc2b` → `a9bfb67` (missing settled cache, 0 passed / 1 failed); `b05424e` → `74dd58d` (missing prerequisite scheduling, 5 passed / 1 failed); corrected `beb3dce` → `677d708` (missing icons/arrow, 0 passed / 1 failed); `06d9f18` → `04f8794` (unanalysed history and replacement, 0 passed / 1 failed); `97e476d` → `1133caa` (terminal prerequisite missing, 0 passed / 1 failed). Harness corrections are documented above.
- The additional fast-exploration and opening-context tests each fail with their corresponding production mutation and pass after restoring source. All four adjusted prior-contract tests also fail under targeted production mutations (green arrow, live view, PV handler, immediate terminal cancellation). Logs: `mutation-fast.log`, `mutation-book.log`, `mutation-green.log`, `mutation-live-view.log`, `mutation-pv-click.log`, `mutation-terminal-old.log`, beside the receipt. Restored source is the committed code tested by the full gate.
- Inspected Xvfb captures at [1280×800](</run/media/lage/New Volume/Scratch/rev009/classes-1280.png>) and [800×600](</run/media/lage/New Volume/Scratch/rev009/classes-800.png>): Best icon on c5 and its line row, green before-position arrow, blue shown-position arrow, both engine rows, Back to game and actions remain visible. The graphical run used `--position 3000,3000` with a fake engine.
- All fourteen implementation commits preserve test/source separation, conventional English subjects citing REV-009 and explanatory bodies. Changes stay within Primary files; no refactor or additional seam was required.

Acceptance: pending | Bruno's Windows checks with real Stockfish from Verification remain: explore a Blunder until a Best move, play rapidly and watch classes arrive, and compare an explored game move with its game class. Fake-engine checks and graphical captures pass; real engine output, timing and CPU load are not validated on Linux.
Disclosure: pending | integration | Complete Bruno's real-Stockfish Windows acceptance before merging the session into main, per [the approved test seam](../spec.md#test-seams). Automated implementation checks permit the next review stage; they do not satisfy that product check.
Gate evidence: /run/media/lage/New Volume/Scratch/rev009/gate.json
