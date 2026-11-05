# REV-007: Side lines in the Review, and the Best move arrow setting
Stage: to-review
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

Acceptance: pending | Automated Settings access and live arrow checks now pass during the focused agreed-draw notice interval; complete manual post-game and History exploration remains pending. See the Draw-notice repair handoff below.
Disclosure: pending | release | Complete manual post-game and History exploration remains pending; see the Draw-notice repair handoff below for automated evidence and its limits.
Gate evidence: /run/media/lage/New Volume/Scratch/rev007-draw-notice-repair/gate.json


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

- 2026-11-05 Gate exposed an old expectation in `test_settings_shortcut_availability_and_mouse_close`: the shortcut used to be disabled in Review. Criterion 8 replaces it; the test now expects the panel and closes it before preserving the remaining focus, mouse-close and game-hotkey assertions.


#### Repair handoff (2026-11-05)

- Enabled actual Review board mouse input. Viewport tests cover drag and click-click for a game continuation and an alternative; both failed before the scene change and passed afterward.
- Put Settings above Review and blocked Review shortcuts while the Settings panel is open. The real Ctrl+, and arrow checkbox test failed before the change and passed afterward, including Esc, F, arrows and Space. History and name-dialog covering assertions remain in the suite.
- Retained the already-played board when updating the Review, preserving move animations without weakening the BoardView game-reset setter. The game continuation and both side-line animation checks failed before the change and passed afterward.
- Updated `test_settings_shortcut_availability_and_mouse_close` for the replaced Review shortcut contract. Restoring the previous screen order made the updated expectation fail; restoring the repair made it pass. The rest of that test's assertions are preserved.
- Focused interaction and animation tests passed both headless and in an Xvfb graphical session. Gate on `78b9b3e`: `godot --headless -s tests/run.gd`, 531 passed, 0 failed. The headless last-move pixel test and Lc0-dependent checks skipped; no engine was downloaded.
- Manual post-game and History exploration is still pending; the graphical automated run does not claim product acceptance.

Disclosure: decision | none | [Proxy receipt](/tmp/sweatshop-proxy/20261105-175641-REV-007-2bed17.json) widens Review BoardView mouse input and `ui/main.gd` Settings ordering and keyboard access for criteria 1, 2 and 8.


#### Resolution (2026-11-05)
Verdict: Reopen — criterion 8 still fails after opening Review from focused gameplay.

Re-reviewed `2cb5235..2100187`, the previous R1/R2/R3 findings, affected callers and the repair's cross-feature interactions. No production or test changes were authored in this review. The implementation remains on `REV-007-side-line`; no merge or ledger entry was made. This is the second reopen, for the driver's foreman diagnosis before another implementation retry.

**Standards:** no findings. The repair commits separate tests from production and place the `ui/main.gd` child-order change in its own commit. The `tests/test_session.gd::test_settings_shortcut_availability_and_mouse_close` update is allowed by `ticket-flow/stage2.md`'s replaced-behavior rule: criterion 8 replaces the old Review shortcut assertion, the added Esc closes that newly opened panel, and all retained-behavior assertions are unchanged. The recorded `Proxy decided (opus-5.5 xhigh)` scope expansion matches its receipt and was honored; its decision disclosure above remains valid. No concurrent change to the session's child order was present.

**Spec:** one remaining P2 finding, within R2. R1 and R3 are repaired; no scope creep found.

- **R2 (P2), criterion 8 ❌ — Settings is still unreachable in Review opened after a focused game.** Focus mode hides `settings_screen` in `ui/main.gd:639-640`. The result card's Review action (`ui/game_over.gd:87-89`) opens Review without restoring Settings visibility. Although Settings is now ordered above Review, Ctrl+, still requires `settings_screen.visible` (`ui/main.gd:260`), so the panel never opens in this supported entry path. This is the prior review's missed focus-mode variant of R2, rather than a new requirement.

  Reproduction with real viewport input in an Xvfb graphical session: start a game, press F11, play `f3 e5 g4 Qh4#`, and click the result card's Review button. Review is visible with `focus=true` and `settings_root=false`. Show game ply 0 with stored `best_move=e2e4` (the blue arrow is present), then press Ctrl+,: `panel=false`. Play `d2d4` to enter a side line and press Ctrl+, again: `line=true`, `panel=false`. As a control, clearing focus makes the identical shortcut open the panel. The final probe completes without GDScript errors. The focused graphical tests all pass because their Settings setup never enters gameplay focus mode.

  Remaining repair: make Settings reachable when Review is entered from a focused game, preserving the existing focused-game shortcut restriction and History/name-dialog covering behavior. Extend the existing focused post-game Review scenario (`test_checkmate_opens_review_with_result_and_both_sides_moves`) or equivalent coverage through the same Review-scene seam with actual Ctrl+, and the real arrow checkbox, including a side line and Settings keyboard ownership. Do not clear focus only in the test setup to bypass this entry path. Any additional Primary-file scope expansion still goes through the proxy.

Numbered criterion record:

1. ✅ R1 repaired: real viewport drag and click-click start the alternative line; graphical scene checks pass.
2. ✅ The same viewport test confirms the game's own next move advances without branching, in both input modes.
3. ✅ Retained overwrite, matching continuation and navigation-bound checks pass graphically; reviewed the `already_played` path against explicit navigation.
4. ✅ Retained exit, History two-Esc and flip checks pass; the Settings test confirms its first Esc leaves the side line intact and the second leaves the line.
5. ✅ Retained scene checks preserve game state, summary, graph marker and PGN; the repair adds no persistence/export path.
6. ✅ Retained wide class-table collapse/restoration checks pass; the repair does not change compact layout.
7. ✅ Retained scene checks preserve blank side-line evaluation and absent class/green/blue annotations.
8. ❌ R2 remains for focused post-game entry. Normal Review Settings access, real checkbox, immediate arrow update and keyboard ownership pass graphically.
9. ✅ Default, persistence and row placement are unchanged from the approved checks in the first review.
10. ✅ R3 repaired: the game continuation, first side-line move and continuation retain their animation, which then finishes; the shared BoardView game-reset setter is unchanged. Live board-setting checks also pass.
11. ✅ Reused the valid green gate receipt at `/run/media/lage/New Volume/Scratch/rev007-review/gate-final.json`: tested commit `78b9b3e`, command `godot --headless -s tests/run.gd`, exit 0, **531 passed, 0 failed**. The log's SHA-256 matches the receipt and only this tracker ticket changed after the tested commit. Lc0-dependent checks and the existing last-move pixel test skipped in that headless run. No unchanged full gate was rerun.

Additional verification: **8 focused graphical checks passed, 0 failed**, including the three new repair tests, side-line navigation/exits, updated Settings availability, History/name-dialog covering and blue-arrow pixels. The separate focused-game probe exposes the remaining contract failure. Read the full repair diff and examined move/sound/tween callbacks, explicit navigation/reset, real viewport mouse/key dispatch, Settings ordering/focus/shortcut ownership, focused post-game entry, History/name-dialog/searching coverage and annotation updates. Full manual product acceptance in both entry paths, physical promotion and real engines remain unverified.

External evidence: [focused graphical log](/run/media/lage/New Volume/Scratch/rev007-rereview/focused.log), [focused-game probe](/run/media/lage/New Volume/Scratch/rev007-rereview/focus-settings-probe.gd), [focused-game result](/run/media/lage/New Volume/Scratch/rev007-rereview/focus-settings-probe.log). Run the probe with `xvfb-run -a godot --path . --position 3000,3000 --rendering-method gl_compatibility -s '/run/media/lage/New Volume/Scratch/rev007-rereview/focus-settings-probe.gd'`. Its fake clock is retained locally so its callbacks remain valid; an earlier external probe harness error was corrected before the final reproduction.

- 2026-11-05 Second reopen: foreman diagnosis required before retrying. Classify new defect, earlier review miss, contract gap, or review-induced churn; record cause and next action, then return to-implement only when ready.

- 2026-11-05 Reopen diagnosis: the repair was incomplete, and round 1's review also missed something. No contract gap and no churn. Evidence: round 1's R2 (`2cb5235`) reported "Settings cannot be opened while Review is shown" through `_covers_settings()` only. The repair (`a532ce9`, `1ba9575`, `da1a076`) fixed that ordering path and tested Review entered with focus off. Round 2 (`a3dab24`) reproduced the remaining entry path, Review opened from a focused game's result card. There, `ui/main.gd` `_set_focus` hides `settings_screen` and `ui/game_over.gd` Review never restores it. Round 2 calls this "the prior review's missed focus-mode variant of R2", not a new requirement. Round 2 already covered the affected paths (normal, focused post-game and History entry; name dialog; searching), so it serves as the consolidated review. Round 2's earlier fixes (R1, R3) passed with no regressions from the review's advice. Next action: stage 2 on the hard model (two `Verdict: Reopen`). Repair as round 2's Resolution says: Settings reachable in a Review entered from a focused game, with the focused-game shortcut restriction kept, and covered through the focused post-game Review scenario with a real Ctrl+, and the real checkbox, including a side line. Back to `to-implement`.

- 2026-11-05 Focus repair seam and caller analysis: the approved Review scene seam will exercise F11, the focused game's result-card Review button, Ctrl+, and the actual Best move arrow checkbox through viewport input. Review visibility changes through `present`/`present_history`/`open_analysis`, result preparation, rematch, Home/Setup and History; `_set_focus` is called by F11, Home and player-row refresh. Boundaries covered by the new scenario are entering Review without clearing focus, game and side-line Settings keyboard ownership, toggling focus while Review remains visible, and leaving Review through a focused rematch. Existing session tests retain History, name-dialog and searching coverage. The repair remains within the already-approved `ui/main.gd` Settings access scope; no new seam or contract expansion is needed.

- 2026-11-05 Red proof: committed test `52aa05a` failed against the retained production code, with three assertions: Ctrl+, could not open Settings at the game position, inside its side line, or after turning focus back on while Review was visible. The external runner reported 0 passed, 1 failed and no script errors; log: `/run/media/lage/New Volume/Scratch/rev007-focus-repair/red.log`. Settings visibility now follows both gameplay focus and Review visibility; Review exits restore the focused-game restriction, and `_set_focus` preserves access while Review is shown.

- 2026-11-05 Test harness correction: the new focused-game scenario must restore checkbox focus after direction keys and deliver Space release as well as press, because the CheckBox toggles on release. The existing `_review_key` helper sends only a press. These changes affect only the new test, not production behavior or the approved seam; corrected red/green evidence is recorded at handoff.

- 2026-11-05 Corrected red/green proof: the committed test at `e5e5097`, with `ui/main.gd` restored to that commit's unmodified production, failed only the same three Settings-access assertions (0 passed, 1 failed; `red-final.log`). Restoring the visibility repair made the complete scenario pass (1 passed, 0 failed; `green-final.log`), including actual checkbox mouse/Space toggles, immediate arrow updates, Settings keyboard ownership, two-Esc side-line exit, both Review focus transitions and focused rematch restrictions. Logs are in `/run/media/lage/New Volume/Scratch/rev007-focus-repair/`.

#### Focus-mode repair handoff (2026-11-05)

- Repaired the remaining R2/criterion 8 path in `ui/main.gd` (`2a13608`): Settings visibility now follows both focus and Review visibility. Opening Review from the focused result card exposes Settings, focus transitions keep it reachable inside Review, and leaving Review for a focused rematch hides it again. The existing child order, History/name-dialog/searching coverage checks and Settings keyboard handling are preserved.
- Added `test_settings_remain_available_in_review_after_focused_game` in `tests/test_review.gd`, committed before production. It enters F11 focus, finishes `f3 e5 g4 Qh4#`, clicks the actual result-card Review button, and exercises real Ctrl+, and the Best move arrow checkbox at a game position and in a side line. It checks immediate arrow updates, Settings ownership of F/arrows/Space/Esc, the second Esc leaving the line, both focus transitions inside Review, and Settings remaining unavailable in a focused rematch. Corrected test commit `e5e5097` failed three Settings-opening assertions against unchanged production and passed after the repair; the harness corrections are recorded above.
- **10 focused graphical checks passed, 0 failed** under Xvfb, including this new scenario, the existing focused checkmate entry, mouse drag/click-click, side-line navigation/exits, animations, normal Review Settings, History/name-dialog/searching coverage and actual blue-arrow pixels. [Graphical log](/run/media/lage/New Volume/Scratch/rev007-focus-repair/graphical.log); [runner](/run/media/lage/New Volume/Scratch/rev007-focus-repair/focused.gd).
- Full bound gate on committed code `2a136081068cbd3ec4588a4c54a26fd4068bc041`: `godot --headless -s tests/run.gd`, exit 0, **532 passed, 0 failed**. The runner reports six Lc0-dependent skips and the existing graphical-only last-move pixel skip; no engine was downloaded. [Receipt](/run/media/lage/New Volume/Scratch/rev007-focus-repair/gate.json); [gate log](/run/media/lage/New Volume/Scratch/rev007-focus-repair/gate.log). After the tested commit, only this ticket changes.
- Manual post-game and History exploration, physical promotion input and real engine behavior remain unverified. This handoff makes no claim of complete product acceptance and leaves the pending manual release check explicit above. Stage 2 stops at `to-review`; no merge or independent-review verdict is claimed.

#### Resolution (2026-11-05)
Verdict: Reopen — criterion 8 still has a transient Settings access failure after a focused agreed draw.

Re-reviewed `a3dab24..4ec85d9`, the previous R2 finding and the affected visibility/input paths; read the cumulative implementation diff as context. Independent Standards and Spec reviews examined the repair. No production or test changes were authored during this review; the ticket branch is preserved, with no merge or ledger entry.

**Standards:** no source/test findings or actionable baseline smells. The new test and production commits stay within Primary files and separate tests from production. The corrected test at `e5e5097` fails exactly the three Settings-opening assertions against unchanged production (`red-final.log`) and passes with the repair (`green-final.log`). One non-blocking process deviation: the new test, production and handoff commits cite REV-007 in their subjects but omit the explanatory bodies requested by `ticket-flow`. The stage-3 reviewer accepts retaining those commits and the existing evidence; rewriting their history has no product benefit or runtime impact. Future commits should include the reason and ID in the body. This is not a reopen trigger.

The recorded `Proxy decided (opus-5.5 xhigh)` scope expansion matches [its receipt](/tmp/sweatshop-proxy/20261105-175641-REV-007-2bed17.json). The latest repair honors that scope; no additional contract change or concurrent child-order change was found.

**Spec:** one confirmed remaining finding; no scope creep.

- **R2 (P3), criterion 8 ❌ — DrawNotice briefly prevents opening Settings in Review after a focused agreed draw.** `_set_focus` reparents `draw_notice` as a direct Main child after Settings (`ui/main.gd:615`). `_covers_settings()` treats every visible later Control as a covering screen (`ui/main.gd:281-283`), including this non-modal label. After an agreed draw, its existing timer keeps it visible for three seconds (`ui/main.tscn:285`). The latest visibility repair exposes the Settings root correctly, but Ctrl+, is rejected until the notice expires. This is bounded by the remaining notice duration, rather than permanent loss of Settings access. It is the previous round-2 review's missed draw-notice variant of R2, not a regression created by the latest visibility expression.

  Reproduction at `4ec85d9`, with actual viewport F11, Offer draw, result-card Review and Ctrl+, input: enter focus, play `e2e4`, offer a draw and have fake Maia accept (`evaluation=-2.0`, reply `e7e5`). Open Review immediately and select game ply 0. The probe reports `REVIEW=true FOCUS=true SETTINGS_ROOT=true COVERS=true`; the sole visible covering sibling is `DrawNotice`, and `PANEL=false` after Ctrl+,. Play `d2d4` and repeat: `LINE=true LINE_PANEL=false`, with about 2.8 seconds left on the notice timer. Wait for its natural expiry and repeat the same shortcut: `NOTICE_AFTER_TIMEOUT=false PANEL_AFTER_TIMEOUT=true`. The final graphical run has no GDScript errors.

  Remaining repair: keep Settings reachable in Review while the draw notice is visible, preserving History/name-dialog/searching coverage and the focused-game restriction. Extend the approved Review-scene viewport-input coverage with this agreed-draw path and test the shortcut before the notice timeout, at a game position and in a side line. Do not hide the notice or wait it out in the test setup. This remains within the existing Settings-access scope; no numbered criterion was added or rewritten.

Numbered criterion record:

1. ✅ Retained actual viewport drag/click-click scene checks pass.
2. ✅ Retained viewport checks advance the game's own continuation without branching.
3. ✅ Retained navigation, replacement and continuation checks pass.
4. ✅ Retained exit, History two-Esc and flip checks pass; Settings retains keyboard ownership in the tested normal and focused checkmate paths.
5. ✅ Retained game/summary/graph/PGN invariants pass; the visibility repair adds no persistence or export path.
6. ✅ Retained wide-layout collapse/restoration checks pass; compact behavior is unchanged by the new repair.
7. ✅ Retained side-line score/icon/arrow suppression checks pass.
8. ❌ R2 remains during the focused agreed-draw notice interval. The focused checkmate path, both Review focus transitions, immediate checkbox updates and focused rematch restriction now pass graphically.
9. ✅ Default-on persistence and check-row placement remain as previously reviewed.
10. ✅ Retained animation and live board-setting checks pass graphically.
11. ✅ Reused the valid green [gate receipt](/run/media/lage/New Volume/Scratch/rev007-focus-repair/gate.json): tested commit `2a136081068cbd3ec4588a4c54a26fd4068bc041`, `godot --headless -s tests/run.gd`, exit 0, **532 passed, 0 failed**. The log SHA-256 matches; only this tracker ticket changed after the tested commit. Six Lc0-dependent checks and the existing graphical-only last-move pixel check skipped. No unchanged full gate was rerun.

Verification in this review: **10 focused graphical checks passed, 0 failed**, including focused checkmate entry, real Settings checkbox/keyboard input, viewport drag/click-click, side-line navigation/exits, move animation, History/name-dialog/searching coverage and blue-arrow pixels. [Review graphical log](/run/media/lage/New Volume/Scratch/rev007-focus-repair/review-graphical.log). The separate agreed-draw probe exposes the remaining gap: [script](/run/media/lage/New Volume/Scratch/rev007-spec-review/draw-notice-probe.gd), [result](/run/media/lage/New Volume/Scratch/rev007-spec-review/draw-notice-probe.log). Run with `xvfb-run -a godot --path . --position 3000,3000 --rendering-method gl_compatibility -s '/run/media/lage/New Volume/Scratch/rev007-spec-review/draw-notice-probe.gd'`.

Coverage: examined Review visibility callbacks and their callers (`present`, `open_analysis`, result preparation, rematch, Home/Setup and History), focus transitions/reparenting, Settings covering checks and input ownership, and the draw-notice timeout. Manual product acceptance in both entry paths, physical promotion and real engines remain unverified. The existing [CLEAN-014](93-CLEAN-014-review-line-scroll.md) follow-up stays open and adds no requirement to this repair.

Disclosure: decision | none | The recorded proxy scope expansion remains valid; the latest visibility repair and remaining R2 repair stay inside the approved Review Settings-access scope. See the proxy receipt linked above.
Disclosure: deferred | none | The stage-3 reviewer accepts retaining existing commit messages without explanatory bodies, to preserve implementation/evidence history; subjects identify REV-007 and the deviation has no runtime impact. This is recorded under Standards above.

- 2026-11-05 Draw-notice repair caller analysis: `_covers_settings()` is called only by Main's Ctrl+, handler. Focus reparents the existing non-modal `draw_notice` Label after Settings; a visible notice is incorrectly classified as a covering screen. The approved Review-scene seam will cover an actual focused Offer draw/result-card Review path, Ctrl+, before the unchanged notice timeout, and the real arrow checkbox on a game position and in a side line. The boundary is distinguishing that notice from visible covering screens; retained session tests cover History, the name prompt, searching, hidden screens, and focused gameplay. No new seam or contract expansion is needed.

#### Draw-notice repair handoff (2026-11-05)

- Repaired the remaining R2/criterion 8 gap in production commit `3157ff0`: `_covers_settings()` excludes the existing non-modal draw-notice Label, which focus reparents after Settings. All other covering-screen checks and the focused-game restriction remain in place. The notice stays visible and its timeout is unchanged. This is within the previously approved Settings-access scope; no contract change was needed.
- Test-only commit `b3fcd24` adds `test_settings_open_in_review_while_focused_draw_notice_is_visible`. The test uses real viewport F11, Offer draw, result-card Review, Ctrl+, and checkbox input. It verifies opening Settings and immediate arrow updates at a game position and in a side line before the natural notice timeout, plus Settings/side-line Esc behavior. Against unchanged production, it failed exactly the two Settings-opening assertions, with no script errors: **0 passed, 1 failed**. [Red log](/run/media/lage/New Volume/Scratch/rev007-draw-notice-repair/red.log).
- With the repair, **11 focused graphical checks passed, 0 failed** under Xvfb, including the new agreed-draw path, focused checkmate entry, normal Review settings, viewport drag/click-click, side-line navigation/exits, animations, blue-arrow pixels, and History/name-dialog/searching coverage. [Graphical log](/run/media/lage/New Volume/Scratch/rev007-draw-notice-repair/graphical.log); [runner](/run/media/lage/New Volume/Scratch/rev007-draw-notice-repair/focused.gd).
- Full bound gate on committed code `3157ff0fd317f9dea13a0adbc065c019c033c0c1`: `godot --headless -s tests/run.gd`, exit 0, **533 passed, 0 failed**. The runner reports six Lc0-dependent skips and the existing graphical-only last-move pixel skip. [Receipt](/run/media/lage/New Volume/Scratch/rev007-draw-notice-repair/gate.json); [gate log](/run/media/lage/New Volume/Scratch/rev007-draw-notice-repair/gate.log). Only this ticket changes after the tested commit.
- Complete manual post-game and History exploration, physical promotion input and real engines remain unverified. The earlier integration-blocking draw-notice finding is repaired and awaits independent review; the manual release check remains pending above. Stage 2 hands off at `to-review` without a merge or review verdict.

