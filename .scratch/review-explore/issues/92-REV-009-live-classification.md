# REV-009: Live classes for side-line moves
Stage: to-implement
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

#### Resolution (2026-11-05, stage 3)
Verdict: Reopen — criterion 2 fails on an explored continuation from a stored draw result; returning to a settled position regresses the unlimited shown-position search required by REV-008 criteria 2–4.

Reviewed the complete diff `1b491d7..59a12ca` against all nine numbered criteria and the retained REV-008 behavior. Independent `code-review` agents `review_standards` and `review_spec` reviewed the Standards and Spec axes. The reviewer authored no source or test changes. All implementation commits and the green gate receipt are preserved on `REV-009-live-classification`; the ticket returns to stage 2 with the two findings below as its open repair work. No merge or ledger entry was made.

**Standards:** no documented-standard violation or actionable baseline smell found. Source, tests and the §15.6 documentation change stay within Primary files. All fifteen commits use conventional English subjects citing REV-009 and explanatory bodies; test-only commits remain separate from production-only commits. The documented harness corrections and later mutation-checked test-only coverage follow `stage2.md`. The short repeated evaluation setup in Review was considered and does not warrant a cleanup ticket.

**Spec:** two confirmed findings; no scope creep. Both need behavioral repairs and regression tests at the existing approved seams, so they return to stage 2 instead of being implemented during review.

1. **Stored terminal draw data is reused as the before-position of a legal explored continuation.** `ui/review.gd:713` (`_line_positions`) keeps every stored position with a `pv` key, including an empty terminal PV. A final agreed or claimed-repetition draw can still have legal moves when reconstructed for Review exploration. Reproduction: play `e2e4`, agree a draw, present the game with stored initial analysis and final `{"pv": [], "best_move": "", "terminal_score": 0}`, then explore `c7c5` and settle its after-position. `board.play` succeeds, but `Classification.evaluate` reads `before.pv[0]` at `core/classification.gd:23`; both `_refresh_line_classes` and `_line_requirements` generate out-of-bounds errors and the side-line class stays null. This fails criterion 2 and the icon behavior in criterion 4. Obtain usable before-position analysis for the explored continuation while preserving the game's stored draw result. Add coverage through the existing Review/fake-bridge seam; changing `core/classification.gd` is outside this ticket's Primary files. Reproducer and observed errors: [probe.gd](</run/media/lage/New Volume/Scratch/rev009-review-spec/probe.gd>), [probe.log](</run/media/lage/New Volume/Scratch/rev009-review-spec/probe.log>). Run from this worktree with `godot --headless --path . --script '/run/media/lage/New Volume/Scratch/rev009-review-spec/probe.gd'`.
2. **Returning to a cached FEN stops live analysis indefinitely and restores an older PV.** `engine/live_analysis.gd:63` (`_next_fen`) returns an empty target once the shown FEN has a settled class result; `_schedule` drains the other search and never starts the shown search. `search` also publishes the frozen settlement snapshot as the live result. Reproduction at the controller seam: settle START at depth 16, receive a later live update at depth 24, switch to AFTER and settle it, then return to START and drain AFTER. The displayed depth regresses from 24 to 16, callback count stays 2 rather than starting another shown-position search, and `_search_fen` remains empty after `_process`. The effort spec still requires an unlimited search on the shown position; REV-008 criteria 2–4 require live rising depth and a search on position switches. REV-009 criterion 7 reuses settled inputs **for the class**; it does not retire the live search. Preserve frozen classes and prerequisite-cache reuse while restoring unlimited live updates on return. The existing cache-return tests currently assert no new search at all, so distinguish class-input reuse from live searching in their repair. Evidence: [cache-probe.gd](</run/media/lage/New Volume/Scratch/rev009-review-spec/cache-probe.gd>), [cache-probe.log](</run/media/lage/New Volume/Scratch/rev009-review-spec/cache-probe.log>). Run with `godot --headless --path . --script '/run/media/lage/New Volume/Scratch/rev009-review-spec/cache-probe.gd'`.

Numbered criterion record:

1. ✅ Node-budget or completed-depth convergence freezes a per-FEN result; forced positions use one PV and terminal positions use the analyser's terminal shape. Cache pruning and disposal follow line lifetime. The draw result's misuse as a before-position is finding 1 under criterion 2.
2. ❌ Normal positions use the shared evaluator, full game prefix, opening context and frozen inputs, but finding 1 prevents classification after a stored terminal draw with legal continuations. Pending Miss dependencies are otherwise retained and published classes stay fixed.
3. ✅ Missing branch and predecessor positions settle live without changing stored game analysis; backtracking obtains earlier undecided Miss dependencies. Finding 1 must also make the synthetic terminal-draw branch usable for exploration.
4. ❌ Square and row icons work for tested normal/terminal side moves, but the legal continuation in finding 1 never receives its icon.
5. ❌ Prerequisite ordering and thinking placeholders work for fresh positions, including rapid exploration. Finding 2 leaves a returned cached position without the shown-position live search.
6. ✅ The green arrow reads the settled before-position and is absent while that input is pending.
7. ✅ Replacements remove discarded classes and cached FENs; navigation reuses frozen class results. The separate live-search regression is finding 2, not permission to recompute an existing class.
8. ✅ The same scripted usable engine data yields the stored game's class; Book/Repertoire context is preserved. Finding 1 concerns obtaining valid classification inputs after a terminal draw, rather than a different label for identical usable inputs.
9. ✅ Reused the valid gate receipt for `cc8ef1dc8908ed404463ba09bddea9ce9cf5e897`: `godot --headless -s tests/run.gd`, exit 0, **552 passed, 0 failed**. Independently verified the log SHA-256, tested-commit ancestry and that only this tracker ticket changed afterward. The existing last-move pixel assertion and six real-Lc0 checks skipped. No unchanged full gate was rerun. The two additional review probes expose behavior missing from that suite; their logs are diagnostic evidence, not replacement gate receipts.

Coverage: examined the complete changed source and tests, stage-2 commit boundaries, the analyser parser and convergence shape, Classification's Miss/Great/Book/Repertoire/Forced dependencies, required-position backtracking, multi-PV completion, forced and terminal positions, rapid navigation, replacement and cache retention, UCI handshake/callback/drain ordering, engine failure and cached-result lifetime, Review exit/hide/Rematch and queue/direct-analysis pause/resume callers, game exports/summary/graph isolation, and the retained REV-008 live-search contract. The two probes ran headless at the already approved fake-bridge seams. Real Stockfish output/timing, CPU load, Bruno's Windows acceptance, graphical rendering and physical input were not independently exercised during this review; prior captures remain stage-2 evidence.

Acceptance: pending | The two implementation findings above require repair and a new green gate after code changes. Bruno's real-Stockfish Windows scenarios from Verification remain pending before main integration.
Disclosure: pending | integration | [REV-009 stage-3 findings](#resolution-2026-11-05-stage-3) are open on this ticket at `Stage: to-implement`; resolve both before session integration. The earlier real-Stockfish Windows acceptance condition also remains in force before merging the session into main.
