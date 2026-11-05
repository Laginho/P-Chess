# REV-007: Side lines in the Review, and the Best move arrow setting
Stage: implementing
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/review.gd (side-line state, move-list rows, navigation, `Esc`, class-table collapse, blue arrow on game positions)
  - ui/review.tscn (Back to game node if needed; BoardView mouse input)
  - ui/board_view.gd (a best-move arrow property, drawn translucent blue under `review_arrow` and the drawings)
  - core/settings.gd (`DEFAULTS`: `best_move_arrow`)
  - ui/settings.gd (the row)
  - ui/main.gd (`_apply` board settings; Settings above Review, Ctrl+, access and keyboard ownership while open)
  - tests/test_review.gd, tests/test_board_view.gd, tests/test_settings.gd
  - docs/spec.md (§15.6 side lines and arrow, §15.10 the new setting)

#### What to build

Spec: `.scratch/review-explore/spec.md`. In the Review you can play moves from any position and walk them as a temporary side line, then go Back to game. No engine yet: side-line positions show no eval, lines, classes or arrows. Also a new **Best move arrow** setting that draws the stored best move of the shown game position as a translucent blue arrow, and the Review's board starts following your board settings.

Today the Review's `BoardView` already accepts moves for both sides, but nothing listens to `move_played`, so a dragged move just sits on the board until the next navigation.

#### Acceptance criteria

1. At game ply N, a legal move (drag or click-click) that is not game move N+1 starts a side line: the board shows it with its sound, and the move appears as a row under the row of move N, visibly distinct from game rows, in a block that holds a **Back to game** button.
2. At game ply N outside a line, playing game move N+1 just shows ply N+1; no line starts.
3. Inside a line, ←/→ and Previous/Next step from the branch position to the line's last move and stop there. At a line position, playing the line's next move steps forward; playing any other move replaces every line move after that position.
4. Back to game and `Esc` discard the line and show ply N. Clicking a game move, clicking the graph, First or Last discard the line and show that ply. From History, `Esc` in a line is Back to game and a second `Esc` is Back to History. `F` flips in a line as it does elsewhere.
5. A line never changes the summary, the class table counts, the graph (its marker stays at ply N), Copy PGN, Open in Lichess or any file on disk.
6. In the wide layout, entering a line collapses the class table behind the "Move classes" button as the compact layout does; Back to game, or any other way out of the line, restores it. The compact layout is unchanged.
7. In a side-line position the eval bar shows no score, and the board shows no class icon and no green or blue arrow.
8. With `best_move_arrow` on, a game position with stored analysis shows its stored `best_move` (the move from the shown position) as a translucent blue arrow, `#3f94e0` at about 65% from one constant, drawn under the green arrow and the user's drawings; terminal positions, positions without analysis and side-line positions show none. Off, none anywhere. Changing it in Settings while the Review is open redraws at once.
9. Settings has a "Best move arrow" check row right after "Legal-move dots", default on, saved like the others.
10. The Review's board follows board theme, piece theme, click-click, auto-queen, legal dots and animation length, at start and when changed.
11. Gate green.

#### Verification

    Manual: post-game Review and History Review; start a line, overwrite it, walk it, leave it each way; toggle Best move arrow.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- tests/test_review.gd, through the Review scene: a played off-game move adds a line row under the branch row (red: no row, nothing listens); the game's next move advances the ply (red: the board changes, `_ply` does not); overwrite, ←/→ bounds, each way out discards the line and lands on the right ply; summary, counts, graph and `_pgn` unchanged by a line; wide layout collapses and restores the class table.
- tests/test_board_view.gd: the best-move arrow draws only when set (red: the property does not exist).
- tests/test_settings.gd: `best_move_arrow` defaults to true and round-trips (red: unknown key).
- tests/test_review.gd: the blue arrow follows `best_move` of the shown game position and the setting (red: none drawn).

## Comments

- 2026-11-05 Written from the grill (spec.md). Prototype of the engine-lines placement: branch `prototype/review-engine-lines` (`251ff4c`); the engine block itself is REV-008.

- 2026-11-05 Stage stopped (incomplete handoff): Stage left uncommitted work; saved for recovery. See /home/lage/Projects/P-Chess/.artifacts-build/lanes/review-explore/.scratch/run-log/REV-007-implement-20261105-172352.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.

- 2026-11-05 Foreman: the stopped attempt never loaded `ticket-flow`. The skill was not installed for Codex on the Linux box, so the session worked as a plain coder: no ticket branch, no commits, no test-first, no handoff. That is environmental: the skills are now linked under `~/.agents/skills`, and Codex lists `ticket-flow`. Its uncommitted work is saved as stash `refs/sweatshop-recovery/95e8d923fd2e450182e6ddb1885b2a3f` (commit `a3bea32`; 8 files, +296/−14: `ui/review.gd`, `ui/board_view.gd`, `ui/main.gd`, `ui/settings.gd`, `core/settings.gd`, `docs/spec.md`, `tests/test_review.gd`, `tests/test_settings.gd`). The session said the gate passed with 526 tests, not checked. Stage 2 may reuse it (`git stash show -p a3bea32`), but under the normal flow: the tests must be seen red against the code without the fix, and the gate re-run for evidence. Back to `to-implement`.

- 2026-11-05 Resolution: Added a disposable side line with branch navigation and exits, the default-on best-move arrow, and live Review board preferences. The full gate on commit `0f8a102` reported 528 passed, 0 failed; Lc0-dependent checks and the existing last-move pixel test skipped on this headless Linux run. A graphical Xvfb test verified the blue arrow appears and clears; disabling its draw call made the test fail. The settings test failed on the missing key before its implementation; the side-line scene test failed on missing line state before implementation.

Acceptance: pending | Stage-3 review below reproduces failures of criteria 1, 8 and 10. Manual post-game and History exploration remains pending after those repairs.
Disclosure: pending | integration | Criteria 1, 8 and 10 fail the user input and animation probes in the review below; repair and review again before integration. Manual Review exploration in both entry paths also remains outstanding.
Gate evidence: /tmp/REV-007-gate.json


#### Resolution (2026-11-05)
Verdict: Reopen — criteria 1, 8 and 10 fail user input and animation checks.

Reviewed `dca596d..4565ab7` against this ticket's numbered criteria and Primary files. No production changes were authored during this review, and the implementation commits remain on `REV-007-side-line`; no merge or ledger entry was made.

**Standards:** no documented-standard breaches. All changed source/test files are Primary files, and the commits separate tests from production. The prior run log records missing-setting and missing-line-state red checks, plus a rendering-test failure when the blue-arrow draw call is disabled. A possible duplication between `_show_ply` and `_show_line` is a judgement-call heuristic, not a confirmed defect or a reason to refactor in this ticket.

**Spec:** three confirmed contract failures; no scope creep found.

- **R1 (P1), criterion 1 ❌ — the Review board ignores real mouse input.** `ui/review.tscn:166` leaves BoardView at `MOUSE_FILTER_IGNORE`, and Review never enables it. Reproduction: present a game beginning `e4 e5`, show ply 0, enable click-click and dispatch real viewport mouse press/release events at d2 and d4. No move is played and `_line_active` stays false. Dragging d2 to d4 also does nothing. Changing only the instantiated board's mouse filter to `MOUSE_FILTER_STOP` makes the identical inputs play `d2d4` and start the line. The new scene tests call `board.play()` and bypass the failing GUI dispatch. Add coverage through viewport input for both drag and click-click, including the game's own next move (criterion 2).
- **R2 (P2), criterion 8 ❌ — Settings cannot be opened while Review is shown.** `ui/main.gd:258-281` rejects Ctrl+, because `_covers_settings()` sees Review above Settings. The real hotkey opens the panel during a game, but leaves it hidden in both a game position and a side line in Review. Directly calling `preferences.set_value()` proves the update callback, not the requested Settings interaction. Provide a reachable Settings panel above Review and verify the actual check row updates the blue arrow immediately. When enabling this path, check input ownership: forcibly showing the current panel and pressing Esc lets Review discard a side line before Settings handles the key. That forced-panel case is an interaction to address with the access repair, not a fourth presently reachable regression. `ui/main.gd` is currently scoped to `_apply` in Primary files; stage 2 must use the proxy if the repair needs a broader seam.
- **R3 (P2), criterion 10 ❌ — played moves cancel their configured animation.** `_on_board_move` synchronously calls `_show_ply` or `_show_line` (`ui/review.gd:792,803`); assigning `_board_view.game` (`:854,911`) invokes the shared board setter's `_end_slide()` (`ui/board_view.gd:57`). At `animation_ms=500`, the game's own continuation, the first alternative and its continuation all have `slide_seconds=0.5` but `_slide_to=""` immediately after play. An otherwise identical standalone BoardView retains `_slide_to="d4"`. Test the observable tween behavior, not only the copied duration property, and preserve the board setter's existing game-reset behavior.

Numbered criterion record:

1. ❌ R1: real drag/click-click cannot enter a line; the row and sound logic only runs when play is called directly.
2. ✅ Continuation logic advances the game without branching through the scene/API seam; actual mouse entry is blocked by R1.
3. ✅ The retained scene tests cover overwrite, matching continuation and branch/end bounds; reviewed button/key routing. Full user exercise awaits R1.
4. ✅ The retained scene tests cover line return, graph, First/Last, game-row selection, History's two Esc presses and F; reviewed discard on leaving Review. Full user exercise awaits R1.
5. ✅ Reviewed separate line/game state, class/summary/graph updates and the unchanged `_pgn`/`_url` export callbacks. Scene assertions retain the game and graph marker. No new persistence path exists.
6. ✅ Wide capture confirms class-table collapse, and scene tests confirm restoration; compact layout code retains its existing collapse behavior.
7. ✅ Scene tests confirm blank score, class icon and both arrows on line moves. The branch cursor at index 0 still shows the actual game position's annotations, which is consistent with its position.
8. ❌ R2: stored-position arrow selection, layering, terminal/no-analysis suppression and live callback were reviewed, but Settings is unreachable while Review is open.
9. ✅ Default-on persisted setting and check-row placement immediately after Legal-move dots are present; retained round-trip test passes.
10. ❌ R3: startup/live preference routing is present, but the newly started move animation is immediately cancelled.
11. ✅ Existing gate evidence is valid for the unchanged reviewed code: `/tmp/REV-007-gate.json` tests `0f8a102`, exit 0, **528 passed, 0 failed**. Its log SHA-256 matches the receipt; the only later committed file is this tracker ticket. Lc0-dependent tests and graphical-only pixel checks are not exercised by the headless gate; the prior handoff records a separate graphical arrow test. Reused the receipt without rerunning unchanged code.

Additional usability observation, outside the numbered contract: after 20 line moves at 1280×800, the selected row is below the list viewport and the list remains at scroll zero. Tracked separately as [CLEAN-014](93-CLEAN-014-review-line-scroll.md); it does not add a requirement to this repair pass.

Coverage: read the full diff and affected callers; examined actual viewport mouse input, real Ctrl+, dispatch, BoardView move/sound/tween callbacks, side-line state/replacement/discard, tree selection and deferred exits, class toggling, game analysis arriving during a line, PGN/link isolation, settings startup/change callbacks and annotation draw order. Inspected captures at 1280×800 and 800×600, including a 20-move line. Not verified: physical promotion input, real Stockfish/Lc0, or complete manual product acceptance in both post-game and History entry paths.

External reproduction artifacts (not required to understand or reproduce the findings above): `/run/media/lage/New Volume/Scratch/rev007-review/` contains `input-probe.gd`, `input-probe.log` (drag and click-click results), `settings-path-probe.gd`, `spec-probe.gd` and graphical `probe.gd`/`probe.log` plus captures. Run a headless probe with `godot --headless --path . -s '<absolute script path>'`; run `probe.gd` with `xvfb-run -a godot --path . --position 3000,3000 --rendering-method gl_compatibility -s '<absolute script path>'`. The final graphical run completes without script errors; earlier harness mistakes (empty PV fixture and a nonexistent Tree scrollbar accessor) were corrected only in that external probe.


- Proxy decided (opus-5.5 xhigh): Yes. Stage 2 may widen both scopes, limited to the bullets below. Criteria 1, 2 and 8 can't be met without these changes, both files are already Primary files, and review R2 sent this question to the proxy. Precedent: BOT-005 and CLOCK-001 widened scope the same way. (receipt /tmp/sweatshop-proxy/20261105-175641-REV-007-2bed17.json)

  Scope: enable Review BoardView mouse input; put Settings above Review, allow Ctrl+, there and give Settings keyboard ownership while open. Test real viewport drag/click-click, game and side-line moves, toggling the real arrow row in both contexts, and Esc twice. Block all Review shortcuts while Settings is open. Preserve History and name-dialog covering behavior and existing game hotkeys. The proxy suggested ordering Settings after Review and before History, with a Review input guard; keep `ui/settings.gd` input unchanged. Commit tests first and the `ui/main.gd` change separately. If another lane changes this child sequence, disclose an integration dependency. Stage 3 should record the decision disclosure.

- 2026-11-05 Animation regression test failed before the fix: game continuation, first side-line move and continuation each immediately cleared the active slide.
