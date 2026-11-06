# REV-008: Engine lines in the Review, and live Stockfish in side lines
Stage: done
Status: ready-for-agent
Blocked by: REV-007
Review: human
Difficulty: hard

- Primary files:
  - New: engine/live_analysis.gd (owns the live Stockfish bridge: search a FEN without limit, switch to another FEN, stop; emits each line update)
  - New: tests/test_live_analysis.gd
  - ui/review.gd (engine-lines block, live eval bar and blue arrow in side lines, clicking a line, queue pause/resume)
  - ui/review.tscn (only if the block needs nodes)
  - engine/analyser.gd (`_parse_info`, only to reuse it for live lines and read `nodes`)
  - engine/uci.gd (only if switching searches needs it)
  - tests/test_review.gd
  - docs/spec.md (§15.6)

#### What to build

Spec: `.scratch/review-explore/spec.md`. The two engine lines show between the eval graph and the move list (prototype variant A, branch `prototype/review-engine-lines`, `251ff4c`; captures in `/run/media/lage/New Volume/Scratch/review-lines-proto/`): stored lines on game positions, live Stockfish lines in side lines. Clicking a line plays it. While you explore, the background analysis queue is paused.

#### Acceptance criteria

1. A game position with stored analysis shows the block between the eval graph and the move list: two rows, each an eval chip in White's view (light when White is better, dark when Black is; `+0.8`, `-1.2`, `M3`), then the PV in SAN trimmed with an ellipsis to the column width, and "depth N" right-aligned on the first row. Same two rows in the compact layout, where the block hides with the graph and the list when "Move classes" opens the table. Hidden on a game position without stored analysis.
2. Entering a side line starts the Review's own engine through `analysis_bridge_factory` (Threads cores − 1, MultiPV 2, unlimited search on the shown position) and pauses the analysis queue. Until the first `info` line for the shown position, the block shows muted "Stockfish is thinking…" rows.
3. In a side line, the block, the eval bar and the blue arrow (when `best_move_arrow` is on) follow the live search of the shown position, the depth rising as it goes.
4. Changing the shown position stops the running search and starts one on the new position; a line, score or arrow from another position never shows for the shown one.
5. A terminal position (checkmate, stalemate, fifty-move rule, insufficient material) shows one row, "Checkmate", "Stalemate" or "Draw", with no chip, and starts no search.
6. Clicking a move inside an engine line plays that line up to and including the move; clicking a row's chip plays only its first move. Moves that match the game's continuation from a game position only advance the game; the first move that differs starts the side line, or, inside a line, replaces what follows (REV-007 criterion 3).
7. Leaving the line in any way, or leaving the Review, stops the engine process and resumes the queue. When Rematch or New game is pressed in a line, the queue stays paused for the whole game, as it is today.
8. If the current game is being analysed when a line starts, its analysis pauses with the queue: the progress bar stays at its value and Stop still works; leaving the line resumes it.
9. If Stockfish is missing or stops, the side line keeps working without it and `AnalysisError` shows "Analysis: <error>"; leaving the line removes only that message, restoring any error the game's analysis already showed.
10. Gate green.

#### Verification

    Manual (Bruno, Windows, real Stockfish): explore a blunder; watch depth rise; click a line; Back to game; Rematch from a line; explore a queued game from History.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- tests/test_live_analysis.gd, with a fake bridge: a FEN sends the setup and `go infinite`; switching FEN sends `stop` and only then the new search; `info` lines of the old FEN after the switch are dropped; stop ends the process (red: the file does not exist).
- tests/test_review.gd: stored lines render in the block with depth and White's-view chips, hidden without analysis (red: no block); entering a line pauses the queue and leaving resumes it, Rematch keeps it paused (red: queue untouched); a clicked line plays up to the clicked move, the matching prefix advances the game; a terminal position shows one row and no search; an engine error keeps the line usable and leaving restores the earlier message.

## Comments

- 2026-11-05 Written from the grill (spec.md). Note: `ui/main.gd` pauses the queue and then hides the Review when a game starts, so a resume on the Review's hide would undo that pause (criterion 7).

- 2026-11-05 Stage 2: seams confirmed by the ticket: live controller with a fake UCI bridge, and the Review scene with `analysis_bridge_factory`. Callers inspected: navigation, streamed game analysis, class toggle, main game start/hide, queue cancel/resume and the shared analyser parser. Degenerate cases include rapid position switches before bestmove, missing/stopped engine, one legal move, terminal positions and absent stored PVs.

- 2026-11-05 Test harness correction: the delayed-handshake fake initially used Godot’s own PID, which `OS.is_process_running` rejects because it tracks launched children. It now owns a temporary headless child and releases it synchronously. The corrected test exercises the real UCI command queue through the agreed fake-bridge seam.

- 2026-11-05 Test harness correction: compact viewport mouse coordinates must include the root stretch transform (`1280×960` logical at `800×600` physical); `get_screen_transform()` omits that scale on the headless DisplayServer. Corrected the real-click test and verified it fails when the production PV click handler is disabled.


#### Resolution (2026-11-05, stage 2)

Implemented stored and live engine lines, White-perspective chips, SAN links and depth in both layouts. The Review owns a separate unlimited MultiPV-2 search while exploring; position switches stop and drain the previous search, and stale callbacks cannot update the displayed position. Live scores and the best-move arrow follow the shown FEN. Terminal positions display one message without a search. Clicking a PV follows the matching game prefix before branching or replaces the continuation at the side-line cursor.

Queue and direct game analysis pause during exploration, with visible progress frozen and Stop available. Returning or hiding Review releases the live process and resumes analysis; the Rematch handoff preserves main's gameplay pause. Stop of a paused direct analyser persists after leaving the line. Missing/stopped live Stockfish leaves exploration usable, and its error stays separate from the game's error, including when the queued game is stopped. Updated `docs/spec.md` §15.6. All source and test edits stay within Primary files; `ui/review.tscn` required no change.

Verification:

- Bound gate on `3e1019e25e8faa6ff24f7ac9d418257970f829fb`: **544 passed, 0 failed**, exit 0. Receipt and log are under `/run/media/lage/New Volume/Scratch/rev008/`; receipt SHA-256 verified. The headless gate skips the existing last-move pixel assertion and six real-Lc0 checks because the Windows engine is absent.
- Red/green commits retain the evidence: the controller first failed on its missing production file; the stored-lines scene test failed with 61 passed / 1 failed before the block, then 62 passed / 0 failed. Focused scene tests failed on absent live searches/queue pause, PV clicks and terminal messages. The corrected real-UCI-queue fixture exposed cancellation before `uciok`, and the out-of-order-PV test exposed PV2 being published as PV1 (1 passed / 2 failed); all three controller tests now pass.
- Additional red cases caught direct analysis restarting after Stop and Stop hiding the live engine's missing-engine message. Both pass after their production fixes. Disabling the production PV click handler makes the compact real-viewport click test fail; restoring it passes both headless and in Xvfb (**1 passed, 0 failed** in the graphical run). The tests use the root stretch transform for physical mouse input.
- Inspected Xvfb captures of stored and live lines at both sizes: [stored 1280](</run/media/lage/New Volume/Scratch/rev008/stored-1280.png>), [stored 800](</run/media/lage/New Volume/Scratch/rev008/stored-800.png>), [live 1280](</run/media/lage/New Volume/Scratch/rev008/live-1280.png>), [live 800](</run/media/lage/New Volume/Scratch/rev008/live-800.png>). Two engine rows, Back to game and actions remain visible; live score and blue arrow use the fake engine's shown position. The graphical run used `--position 3000,3000`.

Acceptance: pending | Bruno's Windows checks with real Stockfish from this ticket's Verification remain: explore a blunder, watch depth rise, click lines, Back to game, Rematch and a queued History game. Automated fake-engine checks and graphical captures pass; real engine output/timing and CPU load are not validated on Linux.
Disclosure: pending | integration | Complete Bruno's real-Stockfish Windows acceptance before merging into main, as required by this ticket's Verification and [the approved test seam](../spec.md#test-seams).
Gate evidence: /run/media/lage/New Volume/Scratch/rev008/gate.json

#### Resolution (2026-11-05)
Verdict: Approve

Reviewed the complete diff `d9da283..f64e9c5` against all ten numbered criteria. Independent `code-review` Standards and Spec agents (`standards_review` and `spec_review`) found no implementation blocker. The reviewer authored no source or test changes. Rebasing onto the session left the ticket branch unchanged. Integrated into `sweatshop/review-explore/2026-11-05-1723` with merge commit `153d4545d3f67a9148f4355b39c706e0d5d4016c`; its tree exactly matches the reviewed ticket branch.

**Standards:** source, tests and documentation remain within Primary files. The implementation history preserves separate test-only and production-only commits, including the documented test-harness corrections. One documentary deviation was found during the final commit-message check: the sixteen stage-2 commits have conventional English subjects citing REV-008, but omit the explanatory bodies required by `ticket-flow`. The stage-3 reviewer accepts preserving those messages to retain the red/green history and its evidence; this has no runtime impact. The optional score-conversion duplication heuristic was considered: the chip and eval bar have separate display responsibilities and mate formatting, and the small shared expression is not treated as a confirmed defect or an additional ticket requirement.

**Spec:** no missing numbered requirement, scope creep or regression found. The terminal checks, stale-search isolation, queue ownership and error restoration follow the written contract. Product acceptance with real Stockfish remains separate from this implementation verdict.

Numbered criterion record:

1. ✅ Stored rows sit between graph and move list, with White-perspective light/dark chips, SAN, ellipsis and first-row depth. Compact visibility follows Move classes; positions without analysis hide the block. Scene tests cover scores, mate text, ordering, toggling and actual viewport chip/PV clicks.
2. ✅ Entering a side line pauses the queue and creates the Review's own bridge through `analysis_bridge_factory`, with cores − 1 threads, MultiPV 2 and `go infinite`. Both rows show the thinking placeholder before results.
3. ✅ Live lines, eval bar and the enabled blue arrow use the shown position. PV2 cannot become PV1 when it arrives first; lower/upper bounds cannot replace exact scores. Arrow-setting updates remain immediate.
4. ✅ Search switches send Stop and drain bestmove before starting the latest FEN. Generation checks, draining and the Review's FEN check reject stale updates. The real UCI command queue fixture covers switching before `uciok`.
5. ✅ Checkmate, stalemate, fifty-move and insufficient-material positions display one message without a chip or new search. Reaching a terminal side-line position releases the running live process.
6. ✅ A chip plays the first move and a SAN link plays through the clicked move. The frozen PV advances a matching game prefix before branching, and replaces the continuation after a side-line cursor. The compact viewport test exercises real mouse input.
7. ✅ Back to game, graph/game navigation, First/Last, Esc and hiding Review discard the line and release the live process. Normal exits resume the queue. Rematch marks the gameplay handoff so hiding Review preserves Main's pause; New game follows the existing Home/Setup and later game-start pause flow.
8. ✅ Queue and direct game analysis stop while exploring, preserving the displayed progress and Stop control. Exiting resumes analysis; Stop of a paused direct analyser prevents its restart, and Stop removes a paused queued game.
9. ✅ Missing or stopped Stockfish leaves legal exploration available. Its message stays separate from the earlier game error, survives Stop of the queued game, and is removed/restored correctly on leaving the line.
10. ✅ Reused the valid green [gate receipt](</run/media/lage/New Volume/Scratch/rev008/gate.json>): tested commit `3e1019e25e8faa6ff24f7ac9d418257970f829fb`, `godot --headless -s tests/run.gd`, exit 0, **544 passed, 0 failed**. Independently verified the log SHA-256 and the helper's `Assert-GateEvidence` on the session merge. Only tracker metadata differs from tested code. The existing graphical last-move pixel assertion and six real-Lc0 checks skipped. No unchanged full gate was rerun.

Red/green evidence examined: controller `a0fcb30` → `130c770`; stored rows `4f9187b` → `1eaca91`; live integration and clicks `93c1858` → `5678a00`; terminal/queue cases `a7f817c` → `ea3858e`; corrected delayed-handshake/PV2 cases `035a343`/`dc7a5c4` → `41028ec`; Stop/error cases `c0e387c` → `9da07f5`. The viewport harness correction `a18fd39` has the documented production-handler mutation check. Durable regression coverage lives in `tests/test_live_analysis.gd` and `tests/test_review.gd`; the detailed red/green logs remain beside the receipt.

Coverage: examined the complete changed source and tests, shared analyser parsing and its callers, UCI handshake/queue/callback ordering, rapid position switches, Review navigation and visibility, Settings arrow updates, Main's Rematch/Home/History/game-start callers, queued and direct analysis lifecycle, progress/Stop, PV input and terminal/error paths. Inspected the [800×600 live capture](</run/media/lage/New Volume/Scratch/rev008/live-800.png>): both engine rows, Back to game, navigation and actions remain visible. Real Stockfish output/timing, CPU load, Bruno's complete Windows acceptance and physical input beyond the recorded fake-engine checks were not verified in this review.

Acceptance: pending | Bruno's Windows checks with real Stockfish from Verification remain outstanding: explore a blunder, watch depth rise, click lines, Back to game, Rematch and a queued History game. Automated implementation checks permit session integration.
Disclosure: pending | integration | Complete Bruno's real-Stockfish Windows acceptance before merging the session into main, per [the approved test seam](../spec.md#test-seams). This implementation approval and session merge do not satisfy that product check.
Disclosure: deferred | none | The stage-3 reviewer accepts retaining the sixteen stage-2 commit subjects without explanatory bodies to preserve the test-first and gate-evidence history. Subjects cite REV-008; this documentary deviation has no integration, release or runtime impact.
