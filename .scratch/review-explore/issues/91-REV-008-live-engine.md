# REV-008: Engine lines in the Review, and live Stockfish in side lines
Stage: to-review
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
