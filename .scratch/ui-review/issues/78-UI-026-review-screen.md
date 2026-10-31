# UI-026: Review screen to the design
Stage: done
Blocked by: UI-021
Review: human
Difficulty: hard

- Primary files:
  - ui/review.gd, ui/review.tscn
  - ui/eval_bar.gd, ui/eval_graph.gd
  - tests/test_review.gd

#### What to build

Restyle the review to chess.com's layout as drawn in `docs/design/v0.1.0/png/Review.png`, `ReviewAnalysing.png`, `ReviewNotAnalysed.png`, `ReviewSmall.png`, `ReviewLegend.png` and `ClassLegend.png` (`.scratch/ui-redo/spec.md`). It uses UI-021's class icons.

#### Acceptance criteria

1. Board area: the player names with colour dots above and below the board; the eval bar on the left with the score at its top; the class icon on the destination square and the best-move arrow as in `Review.png`.
2. Side card: the "Game Review" header with the line "3+2 · Won on time · 41 moves"; the accuracy boxes (white's light, black's dark) with the "?" tooltip; the per-class table with each side's count and the class icon between them, zero counts muted, with a "?" by "Moves" (criterion 6); the eval graph with dots on Inaccuracy, Mistake, Miss and Blunder moves and the current-move line.
3. The move list in numbered rows with the class icon before each move, the current move boxed, and "Left repertoire · expected 8.Nh4" as a blue-bordered row.
4. The navigation buttons (first, previous, next, last), then Copy PGN, Open in Lichess and New game (green). Opened after a game, Rematch stays beside New game, as the spec requires; opened from History, Back to History replaces both.
5. States: analysing (`ReviewAnalysing.png`: the progress bar with "18 of 82 moves", the summary filling in, unsettled moves with a dashed placeholder icon); not analysed (`ReviewNotAnalysed.png`: "This game hasn't been analysed yet" with Analyze, the move list keeping its Book and Repertoire icons).
6. The "?" by "Moves" opens the "Move classes, best to worst" popover of `ReviewLegend.png`, with the canvas's one-line description per class including its threshold; it replaces the class table's tooltip (§15.6).
7. At 800×600 the layout matches `ReviewSmall.png`: names and accuracies stacked, the class table collapsed behind "Move classes".
8. The shared acceptance in `.scratch/ui-redo/spec.md` holds for the boards.

#### Verification

    Manual: review a finished game while it analyses; open an unanalysed one from History; resize to 800×600; open the legend.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_review.gd`: unsettled moves show the placeholder icon; the class table collapses below a width threshold; the legend popover lists the twelve classes in order (red: none of these exist).

## Comments

- 2026-10-31 Written from `.scratch/ui-redo/spec.md`. The canvas omits Rematch on the post-game review; the spec keeps it.

- 2026-10-31 Implementation in progress on UI-026-review-screen: red/green focused review tests cover pending icons, ordered class legend, narrow class toggle, navigation, and unanalysed book icons; latest focused run: 27 passed, 0 failed. The former pending-icon and class-tooltip assertions were updated for criteria 5 and 6. No gate evidence yet. The screenshot still differs substantially from the canvas; all remaining acceptance criteria and visual/manual checks must be completed before handoff.

- 2026-10-31 Driver retry: attempt 1 ended short of to-review (exit 0). Resume from this branch's commits; edits the stage left uncommitted are saved in run-log/recovery.txt.

- 2026-10-31 Resumed implementation: unanalysed History now shows an explanation and hides the empty analysis summary; the eval bar displays the current white-perspective score. Test-only commits `1fad1cc` and `9d1d484` failed before production commits `8c9aa39` and `95d45b6`; the focused review suite then reported 29 passed, 0 failed (`C:/Users/bruno/AppData/Local/Temp/pchess-ui026-score-green.log`). The graphical capture `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-09dc2ae2-fa5e-4fb3-bdb4-0f815ba0170f/Review.png` still differs substantially from the reference. Board player labels, side-card layout and data, class-table presentation, graph dots, move selection/repertoire row, analysing progress, compact layout and visual acceptance remain to be completed. No full gate or product acceptance has been run for these commits.

- Proxy decided (opus-5.5 xhigh): (a), resume once on the same lineup - both attempts were green, cheap ($0.77, 10.5 of 240 min) and stopped on their own with no error; the ticket is clear, so splitting it would only work around how the model behaved, and a lineup change isn't mine to make. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-182950-UI-026-4b70fe.json)

- 2026-10-31 Resume: continue from `UI-026-review-screen` at efc1d4b; its commits are the work so far. The recovery ref `refs/sweatshop-recovery/aa946201260b4eccbb7d7b7834b86b5d` is cleanup only (an untracked copy of `tests/test_review.gd`), ignore it. Put scratch copies and captures under `%TEMP%`, never inside the repo, so no untracked file is left. The stage has 240 min: do not end the turn at `implementing` with partial work. Either finish criteria 1-8 (what remains is the list in the efc1d4b comment), record the visual comparison against `docs/design/v0.1.0/png/Review*.png` and one gate log with its exit code, then hand off at `to-review`; or end `blocked` on a specific question.


- 2026-10-31 Stage 2 resumed from `0882e1c`; the finished implementation is `566792a`. The focused review suite reported 38 passed, 0 failed; the separate History/History screen/badges run reported 52 passed, 0 failed. The new tests were committed separately from production changes; red/green logs are under `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-*-red.log` and `pchess-ui026-*-green.log`. `test_summary_waits_for_analysis_and_shows_accuracy_and_counts` and `test_fixture_updates_counts_before_final_accuracy` now inspect the icon/count table rather than the replaced text-only table; accuracy still waits for complete analysis. The final gate reported 434 passed, including six Lc0 SKIPs (428 executed), 0 failed, exit 0; log `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-gate-566792a.log`.
- Graphical fixture captures for `Review`, `ReviewAnalysing`, `ReviewNotAnalysed`, `ReviewSmall`, `ReviewLegend` and `ClassLegend` are in `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-final-566792a/`; the unanalysed state at both sizes is in `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-empty/`. The compact analysis progress and expanded class table were additionally captured at `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-analysis-small2/ReviewAnalysing.png` and `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-expanded3/Expanded.png` respectively; those precede the final empty-card and typography changes. The earlier capture is `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-09dc2ae2-fa5e-4fb3-bdb4-0f815ba0170f/Review.png`.
- Comparison with `docs/design/v0.1.0/png/Review*.png` and `ClassLegend.png`: the fixture uses a six-ply game rather than the canvas data, so its positions, totals, graph and repertoire row differ. The compact view includes Rematch as required by this ticket, absent from the canvas. Remaining visual differences requiring review: the class legend uses a centred native dialog with an OK button rather than the canvas's anchored popover; the title/result occupy two lines, controls and class rows have different spacing and type sizes, and the empty-analysis card omits the canvas's chart glyph. When compact classes are expanded the list and accuracy are temporarily hidden to keep controls within the window. The screenshot tool routes `ClassLegend` to the review legend and does not populate a repertoire in its review fixture; it is not a visual proof of the standalone component or of the exit row.
- The ticket branch diverges from `sweatshop/ui-review/2026-10-31-1734` only in the lane's subsequent attempt/recovery metadata. Stage 3 must reconcile those tracker comments when rebasing onto the current lane, preserving the proxy receipt and this handoff; the gate receipt applies to the production tree at `566792a`.

Acceptance: pending | Exercise a finished game with live analysis, open an unanalysed History game, resize to 800x600, and operate the legend with mouse and keyboard; Bruno's v0.1.0 QA remains required by `.scratch/ui-redo/spec.md`.
Disclosure: decision | none | F1-F4 are resolved in the final independent re-review and lane integration below. Original visual differences remain recorded for product QA.
Disclosure: pending | release | `.scratch/ui-redo/spec.md` requires Bruno's v0.1.0 QA before the release tag.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/pchess-ui026-final-review-1793488008122/gate.json

#### Resolution (2026-10-31)
Verdict: Reopen — criteria 2, 3, 5, 6 and 8 are partial: incorrect History time control, overlapping post-game progress, offscreen current move, and a centred legend instead of the required popover.

- Reviewed HEAD: `73dacd85372e550c1977ca810b36e71c842255cb`; fixed comparison: `git diff 26bad34771dba78c9706a1095d330164207966ab...73dacd85372e550c1977ca810b36e71c842255cb`. The loop's session is `sweatshop/ui-review/2026-10-31-1734` at `e67e0a9937d16dfe7569dc6ff568bca0aabf2eed`; its changes since the fork are tracker metadata only. Preserve both the lane's recovery comments and this handoff when rebasing for integration. No rebase, merge, push or ledger entry was performed in this reopen.
- Coverage: all five changed files (`ui/review.gd`, `ui/review.tscn`, `ui/eval_graph.gd`, `tests/test_review.gd`, this ticket), every implementation commit's file split, and unchanged `ui/eval_bar.gd`. Examined the post-game caller `_show_result`, History caller `_review_history_game`, PGN time controls/copy, saved repertoire snapshots/badges, analysis queue/cache/error/cancellation paths, classification/accuracy inputs, orientation, graph navigation, move selection, compact expansion, and action visibility. No Primary-files or test/production-commit separation violation found. UI-021 is committed `done`.

##### Standards

- **S1 — P3, documented standard:** `ui/review.gd:72-81` and `ui/review.gd:240-245` create per-node palette/style overrides for accuracy and the empty-analysis card. `.scratch/ui-redo/spec.md` Foundation requires shared Theme variations instead. Prefer the shared variations; adding missing variations would require a stage-1 scope decision or a CLEAN follow-up because the theme file is outside Primary files. This remains an open note on UI-026 and does not independently drive the reopen. No material baseline smell found.

##### Spec

- **F1 — P2, criterion 2:** `ui/review.gd:645` displays `settings.control`, but the History caller in `ui/main.gd:429` always supplies `1+0`. A game saved with `TimeControl "180+2"` opens with `1+0 · Won by resignation · 3 moves`. Obtain the actual PGN time control for the displayed game, with a legacy fallback; add a regression through the History entry point, not only a direct `present` call. Keep the repair within the approved seam, or ask the proxy before extending Primary files.
- **F2 — P2, criteria 2/5/8:** `ui/review.gd:285-290` places the progress bar 25 px below the result while allocating a fixed result height. The real post-game caller (`ui/main.gd:597,614`) supplies a second line, `Space for a rematch`. At 1280x800 `_show_result()` produces a 35 px result at y=54 and a progress bar at y=79; their rectangles overlap by 10 px, with result text drawn over the bar. Compose the short review summary from game information and keep the progress below the actual result bounds. Add a test using the real post-game result. The same fixture at 800x600 did not overlap; the wide case is the confirmed failure.
- **F3 — P2, criterion 3:** `ui/review.gd:491` selects the current move without scrolling it into view. In a legal 80-ply game, opening the final position or pressing Last selects a cell at y=1096 in a 224 px-high Tree, which still displays moves 1-8. The required boxed current move is therefore invisible. Scroll the selected item into view for navigation/graph jumps and initial presentation; test a game longer than the visible list.
- **F4 — P2, criterion 6:** `ui/review.gd:140,185-189` creates an `AcceptDialog` and centres it at 480x540. The required `ReviewLegend.png` is an anchored popover beside the help control, with its own close action. The implementation's disclosure does not accept this contract change. Implement the anchored presentation while retaining keyboard access, dismissal and minimum-window containment; test positioning as well as class text/order.

| Criterion | Disposition |
|---|---|
| 1 | Pass in the reviewed fixtures: player labels/dots, orientation, left eval score, existing destination icon and best-move arrow. |
| 2 | Partial: counts/icons/accuracy/graph markers implemented; F1 and F2 fail the real caller paths. |
| 3 | Partial: repertoire row and move icons implemented; F3 hides the current selection in long games. |
| 4 | Pass for controls/actions and History versus post-game visibility; move-list synchronization is tracked under criterion 3. |
| 5 | Partial: progress counts, pending placeholders and empty state implemented; F2 affects the post-game analysing state. |
| 6 | Partial: twelve classes and thresholds implemented; F4 fails the required popover presentation. |
| 7 | Pass for the 800x600 structural layout: stacked accuracy, collapsed classes, accessible expansion and footer. |
| 8 | Partial: before/after references recorded below; F2/F4 prevent graphical acceptance. Bruno's product QA remains pending. |

- Existing proxy decision reviewed: `Proxy decided (opus-5.5 xhigh): (a), resume once on the same lineup - both attempts were green, cheap ($0.77, 10.5 of 240 min) and stopped on their own with no error; the ticket is clear, so splitting it would only work around how the model behaved, and a lineup change isn't mine to make. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-182950-UI-026-4b70fe.json)` This authorizes the implementation retry; it does not waive visual criteria or accept F1-F4. The receipt and original record are preserved.

##### Verification and visual evidence

- Reused the stage-2 gate without rerunning it: `Assert-GateEvidence` validated the receipt, log SHA256, exit marker and production-tree equality against reviewed HEAD. Log: **434 printed passed, six Lc0 SKIPs, 428 executed, 0 failed, ExitCode: 0**. The test-only/production-only commit pairs and stage-2 red/green record are preserved; no production repair was authored during this review.
- Focused graphical probe: `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-review-4192169c-91d5-460e-951b-7ce997d87d42/probe.gd`; successful error-free run: `probe-final2.log` in that directory, **ExitCode: 0**. It reproduced F1-F3, rendered the repertoire exit and all four graph-marker colours, kept expanded compact actions within y=580, and opened/closed the compact legend through viewport Enter/Esc input. Graph-marker classes were assigned synthetically to inspect rendering; this does not prove live engine classification. Earlier probe drafts had harness errors and are superseded by this run.
- Evidence root `E` below is `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-review-4192169c-91d5-460e-951b-7ce997d87d42/`. `manifest.json` pins revisions. Before captures were generated from an exported/imported `26bad347` tree, with isolated data and no script errors. After captures reuse the stage-2 `566792a` images; production at that commit is identical to reviewed HEAD. All six states were compared against their reference PNGs and matching HTML.

| Board | Before | After | Reference |
|---|---|---|---|
| Review | `E/before/Review.png` | `E/after/Review.png` | `docs/design/v0.1.0/png/Review.png` |
| ReviewAnalysing | `E/before/ReviewAnalysing.png` | `E/after/ReviewAnalysing.png` | `docs/design/v0.1.0/png/ReviewAnalysing.png` |
| ReviewNotAnalysed | `E/before/ReviewNotAnalysed.png` | `E/after/ReviewNotAnalysed.png` | `docs/design/v0.1.0/png/ReviewNotAnalysed.png` |
| ReviewSmall | `E/before/ReviewSmall.png` | `E/after/ReviewSmall.png` | `docs/design/v0.1.0/png/ReviewSmall.png` |
| ReviewLegend | `E/before/ReviewLegend.png` | `E/after/ReviewLegend.png` | `docs/design/v0.1.0/png/ReviewLegend.png` |
| ClassLegend | `E/before/ClassLegend.png` | `E/after/ClassLegend.png` | `docs/design/v0.1.0/png/ClassLegend.png` |

- Supplemental current-code captures: `E/History3plus2.png` (F1), `E/PostgameAnalysing.png` (F2), `E/PostgameAnalysingSmall.png` (compact non-overlap), `E/LongLast.png` and `E/LongLastAgain.png` (F3), `E/RepertoireAndGraphDots.png`, `E/RepertoireSmall.png`, `E/ClassesExpandedSmall.png`, and `E/LegendSmall.png`. The tool's `ClassLegend` state aliases the review help; it does not demonstrate the standalone component layout. Fixture positions/names/counts differ from illustrative canvas data; Rematch is intentionally retained by the behavioral spec. The previously disclosed typography/spacing/chart-glyph differences remain recorded for the next review.
- Limits: no live Stockfish/Lc0 game, audio, screen reader, clean-machine release test or Bruno QA was performed. The probe inspected rendered fixtures and routed legend input; it is not complete physical gameplay acceptance. All captures/logs live outside the repository. Reopen changes only ticket metadata, so the existing production gate receipt remains valid; stage 2 must create fresh gate evidence after its repairs.

Acceptance: pending | F1-F4 remain open on UI-026; live analysis and Bruno's v0.1.0 QA remain required. Fixture rendering, isolated History opening, resizing and legend keyboard checks are documented above.
Disclosure: decision | none | Existing proxy receipt preserved above: retry on the same lineup, with no contract waiver.
Disclosure: pending | integration | F1-F4 in this Resolution must be repaired and independently reviewed before merging the ticket into the lane.
Disclosure: pending | release | `.scratch/ui-redo/spec.md` still requires Bruno's v0.1.0 QA before the release tag.

#### Stage 2 reopen handoff (2026-10-31)

- F1: History review reads the saved PGN time control through `present_history`, retaining the existing fallback for legacy or unsupported controls. A History-entry regression covers `180+2` and the missing-header fallback.
- F2: The review summary removes only the rematch shortcut, retains History save/corruption warnings, and places analysis progress below the full result. Tests cover the actual post-game caller and a multiline save failure. The first full gate exposed two existing error-reporting tests broken by removing all subsequent lines; the final repair preserves them.
- F3: Selection scrolls into view after initial presentation, navigation and graph jumps; the regression uses a seeded 80-ply legal game.
- F4: The ordered class legend is a popover anchored beside Moves help, bounded at 1280x800 and 800x600, with an explicit close control and keyboard dismissal. Existing legend tests now inspect the popover rows instead of `AcceptDialog.dialog_text`; their order and threshold assertions remain. Captures at `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-reopen-visual/Legend.png` and `LegendSmall.png` show the new popup; they were taken at `76418c3`, before the final History-warning fix, which did not change the popup. The previous ticket's other visual differences and fixture limitations remain for independent review.
- Test-only commits precede their production fixes. Red/green logs for F1-F4 and the warning are `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-f1-red.log` / `-f1-green.log`, `-f2-red.log` / `-f2-green.log`, `-f3-red.log` / `-f3-green.log`, `-f4-red.log` / `-f4-green.log`, and `-warning-red.log` / `-warning-green.log` with the same `pchess-ui026` prefix. F1's first harness used the wrong History field and did not initialize the History screen; F3 initially omitted clock snapshots. These harness errors were corrected in separate test-only commits before the recorded red runs.
- Focused review suite before the final warning change: 42 passed, 0 failed; subsequent keyboard and warning tests also passed individually. The first full gate at `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-reopen-gate.log` failed in two tests because the first F2 fix hid History warnings. After the correction, the final gate on `5796130c4a5cc246db257ef9c52b3f0b36eb5871` reported 440 passed, 0 failed, exit 0; six Lc0 tests were skipped, so 434 executed. Log `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-reopen-final-gate.log`.
- The branch remains divergent from the lane in tracker metadata; stage 3 must reconcile the lane's recovery comments when rebasing and preserve the prior proxy receipt, review findings and this handoff. The prior F1-F4 findings have fixes and tests but require independent stage-3 review.

Acceptance: pending | Live analysis of a finished game, unanalysed History, physical keyboard/mouse interaction and Bruno's v0.1.0 QA remain to be verified; the fixture captures and automated input are not product acceptance.
Disclosure: pending | integration | Stage 3 must independently review the F1-F4 repairs and reconcile lane metadata before integration.
Disclosure: pending | release | `.scratch/ui-redo/spec.md` requires Bruno's v0.1.0 QA before the release tag.


#### Resolution — re-review (2026-10-31)
Verdict: Reopen — F3 remains partial: the current move is outside the visible list when a long game opens with cached analysis (criterion 3).

- Reviewed HEAD: `bc0d840da0aef35d1b865f3c5d096d477fa77c0d`; fixed comparison: `git diff 73dacd85372e550c1977ca810b36e71c842255cb...bc0d840da0aef35d1b865f3c5d096d477fa77c0d`. The independent Standards and Spec axes examined all three files changed since the previous review (`ui/review.gd`, `tests/test_review.gd`, this ticket) and all 18 commits. The earlier full-diff coverage remains above. Rechecked History time-control parsing and legacy fallback, the real post-game result, retained History errors, initial selection/navigation/graph jumps, synchronous analysis-cache replay, result/progress layout, and legend anchoring, close action and viewport keyboard routing at both window sizes.
- This is the second recorded reopen. Under `ticket-flow/stage3.md`, the unattended driver parks a second reopen for the foreman to diagnose before retrying. The remaining issue is an incomplete repair of the original F3, not a newly introduced requirement or a new finding in previously reviewed code.

##### Standards

- No new documented-standard breach or material baseline smell. Test and production changes remain separated, and source changes stay within Primary files. Existing S1 (P3: local palette/style overrides instead of shared theme variations) is unchanged and remains an open note on this ticket; it does not drive this reopen.

##### Spec

| Prior finding | Disposition |
|---|---|
| F1 — saved History time control | Resolved. The real History entry point displays saved `180+2` as `3+2`; the regression retains the missing-header fallback. |
| F2 — post-game progress overlaps result | Resolved. The real result omits the rematch shortcut; multiline History warnings remain. At 1280x800 the result ends at y=82 and progress starts at y=86; at 800x600 the result ends at y=89 and progress starts at y=94. |
| F3 — current move outside list | Still P2; criterion 3 fails. See reproduction below. |
| F4 — centred legend instead of popover | Resolved for the reported defect. The legend is anchored beside Moves help, contained at 1280x800 and 800x600, and offers an explicit close action. Viewport Enter opens it; Esc and Space close it from History without returning to History or triggering rematch. Previously disclosed typography/spacing differences remain. |

- **F3 — P2, criterion 3:** `ui/review.gd:515-517` queues a single scroll when selecting a move, before the layout resulting from cached analysis has settled. Open a finished 80-ply game with a complete, current analysis cache through `main._review_history_game` (`present_history` replays the cache at `ui/review.gd:729-733`). After ten frames the selected ply is 80, but its rectangle is `(274, 782, 210, 28)` inside a Tree only `498x224`; the screenshot displays moves 12-19 instead of the selected move 40. The earlier direct-present probe also leaves the final row outside the list, at y=224. Navigating to Last again produces a visible row at y=191. Keep the selected item visible after cache-driven layout/Tree resizing as well as navigation. Extend the long-game regression through a complete saved-analysis/History entry; the current test at `tests/test_review.gd:944-949` supplies no analysis and leaves the accuracy summary hidden, so it misses this state. A resize-triggered scroll is a candidate small repair, but must be verified after the final layout rather than assumed sufficient.

| Criterion | Re-review disposition |
|---|---|
| 1 | Previous pass retained: player labels/dots, orientation, eval score, destination icon and arrow. |
| 2 | F1/F2 resolved; previous counts, accuracy and graph assessment retained. |
| 3 | ❌ F3 persists when opening a long analysed History game; selection/navigation-only coverage is insufficient. |
| 4 | Previous control/action pass retained; History legend dismissal does not activate Back to History. |
| 5 | F2 resolved; pending icons/progress and unanalysed state retained. |
| 6 | F4 resolved: anchored popover, twelve ordered class rows/thresholds, containment and dismissal. |
| 7 | Compact structure and legend containment pass in rendered fixtures; full physical acceptance is pending. |
| 8 | Six fresh reference comparisons are recorded below; F3 prevents acceptance. Bruno QA remains pending. |

##### Verification and visual evidence

- Reused the existing final gate without rerunning unchanged code. `Assert-GateEvidence` validated receipt contents, the log SHA256, `ExitCode: 0` marker, tested commit availability and equality of production with reviewed HEAD. Tested commit: `5796130c4a5cc246db257ef9c52b3f0b36eb5871`. **440 printed passed, six Lc0 SKIPs, 434 executed, 0 failed, exit 0.** Receipt/log: `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-reopen-final-gate.json` and `pchess-ui026-reopen-final-gate.log`. Existing F1-F4/warning red and green logs were inspected; no production repair was authored during this review.
- Current-code evidence root `E` is `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-rereview-1793486870585/`. `manifest.json` pins reviewed HEAD, fixed point, before/after paths and receipt. The general graphical probe `E/probe.gd` / `E/probe.log` exits 0 without script errors, reproduces the real History header, verifies both post-game progress rectangles, captures long selection/navigation, repertoire/graph rendering and compact legend input. The targeted `E/cached_probe.gd` / `E/cached-probe-final.log` creates a legal seeded 80-ply finished game and current analysis cache in isolated data, opens the actual History caller, waits ten frames, captures `E/CachedHistoryLast.png`, and reports **`F3_CACHE_REGRESSION=FAIL`, exit 1** without script errors. That exit is the failed visibility condition, not a harness failure. Its initial draft omitted creation of the isolated analysis directory; `E/cached-probe.log` is superseded by the final log.
- Before root `B` is `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-review-4192169c-91d5-460e-951b-7ce997d87d42/before/`, the previously exported/imported `26bad347` tree. All six current screenshots below were regenerated with the repository's graphical screenshot tool, isolated data and exit 0; each was visually compared with its reference PNG and the previous review's recorded differences.

| Board | Before | Current after | Reference |
|---|---|---|---|
| Review | `B/Review.png` | `E/after/Review.png` | `docs/design/v0.1.0/png/Review.png` |
| ReviewAnalysing | `B/ReviewAnalysing.png` | `E/after/ReviewAnalysing.png` | `docs/design/v0.1.0/png/ReviewAnalysing.png` |
| ReviewNotAnalysed | `B/ReviewNotAnalysed.png` | `E/after/ReviewNotAnalysed.png` | `docs/design/v0.1.0/png/ReviewNotAnalysed.png` |
| ReviewSmall | `B/ReviewSmall.png` | `E/after/ReviewSmall.png` | `docs/design/v0.1.0/png/ReviewSmall.png` |
| ReviewLegend | `B/ReviewLegend.png` | `E/after/ReviewLegend.png` | `docs/design/v0.1.0/png/ReviewLegend.png` |
| ClassLegend | `B/ClassLegend.png` | `E/after/ClassLegend.png` | `docs/design/v0.1.0/png/ClassLegend.png` |

- The general fixture still uses six plies, illustrative names/values and no repertoire; it does not demonstrate standalone ClassLegend (the tool aliases it to ReviewLegend). Supplemental `E/RepertoireAndGraphDots.png`, `E/RepertoireSmall.png` and `E/ClassesExpandedSmall.png` preserve the repertoire/graph/compact checks; graph classes and cached evaluations are synthetic rendering data, not live engine classification. The title/result lines, type sizes, spacing, absent chart glyph and compact expansion differences remain disclosed above with their original reasons. The centred-dialog difference is now resolved.
- Existing proxy decision reviewed: `Proxy decided (opus-5.5 xhigh): (a), resume once on the same lineup`, receipt `C:/Users/bruno/AppData/Local/Temp/sweatshop-proxy/20261031-182950-UI-026-4b70fe.json`. Its complete original text remains above; it authorizes the retry and does not waive F3 or the visual/product contract.
- Only ticket metadata changes in this reopen; the gate receipt remains valid. No rebase, merge, push or ledger entry was performed. The lane `sweatshop/ui-review/2026-10-31-1734` remains at `e67e0a9`; its recovery comments still need reconciliation when an approved branch is rebased for integration. No live Stockfish/Lc0 game, physical keyboard/mouse gameplay, audio, screen reader, clean-machine release test or Bruno QA was performed.

Acceptance: pending | F3 repair requires independent review. Live analysis and Bruno's v0.1.0 QA remain pending.
Disclosure: decision | none | Existing proxy retry decision and receipt preserved; no contract waiver.
Disclosure: pending | integration | Independently review the F3 repair and complete cached-analysis entry before lane integration; reconcile lane metadata.
Disclosure: pending | release | Bruno's v0.1.0 QA remains required by `.scratch/ui-redo/spec.md`.

- 2026-10-31 Reopen diagnosis: new implementation defect, an incomplete repair of round-1 F3. Round 1 asked to keep the selected move visible on "navigation/graph jumps and initial presentation"; cd4891b added one `_moves.ensure_cursor_is_visible.call_deferred()` when a move is selected, and the regression (5a11b2c/03c45f2) opens a long game with no analysis. Opening a long History game with a complete cache replays the analysis (`present_history`, ui/review.gd:729-733); that shows the summary and shrinks the Tree after the single deferred scroll has run, so the cursor ends at y=782 in a 224 px Tree (re-review `cached_probe.gd`, `F3_CACHE_REGRESSION=FAIL`). This is not a review miss (round 1 named initial presentation), not a contract gap, and not churn (the advice was right; the execution covered one path). Next action, stage 2 on the existing `UI-026-review-screen` branch: first a red regression that opens an 80-ply finished game with a complete current analysis cache through `main._review_history_game` and asserts the selected item's rect lies inside the Tree after layout settles (reuse the re-review's `cached_probe.gd` setup); then keep the cursor visible after layout changes, e.g. re-run `ensure_cursor_is_visible` when the Tree resizes, not only on selection; verify after the final layout at 1280x800 and 800x600. F1, F2 and F4 are resolved; leave them alone.

- 2026-10-31 F3 repair: test-only commit `d503fe2` opens an 80-ply finished History game with complete current cached analysis. The graphical red run (`C:/Users/bruno/AppData/Local/Temp/ui026-cached-red.log`) failed the final-row visibility check at both 1280x800 and 800x600 after ten frames. Production commit `5c0c1b0` scrolls the selected item into view on Tree resize; the same graphical test passed at both sizes (`C:/Users/bruno/AppData/Local/Temp/ui026-cached-green.log`). Selection/navigation already scroll via `_show_ply`; the resize handler also covers cache-driven layout changes.
- Gate on `5c0c1b05e2f46f7f3a3c7ac1ab5197cfbea8082f`: 441 printed passed, 0 failed, exit 0; six Lc0 tests skipped (435 executed). Log `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-cache-gate.log`; receipt above. Independent stage-3 review remains required; no physical input, live engine game or Bruno QA was performed in this repair.

#### Lane metadata reconciliation (2026-10-31)

- 2026-10-31 Attempt 1 failed: exit 0. Log tail: O UI-026 **ainda não está concluído**. Na branch local `UI-026-review-screen`, implementei partes da navegação, dos ícones de jogadas, da legenda e do recolhimento da tabela. O [ticket](C:/Users/bruno/Desktop/Pastinha/Programas/Projects/P-Chess/.artifacts-build/lanes/ui-review/.scratch/ui-review/issues/78-UI-026-review-screen.md) permanece em `Stage: implementing`. /  / Os testes focados de review passaram: **27 passaram, 0 falharam**. A captura gráfica mostrou que a tela ainda difere bastante da referência; falta concluir a composição visual e os demais critérios antes de encaminhá-la para revisão. /  / Não executei o gate completo nem a aceitação manual; a alteração ainda não está pronta para integração. /  /

- 2026-10-31 Stage stopped (incomplete handoff): Stage left uncommitted work; saved for recovery. See C:\Users\bruno\Desktop\Pastinha\Programas\Projects\P-Chess\.artifacts-build\lanes\ui-review\.scratch\run-log\UI-026-implement-20261031-182333.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.

- 2026-10-31 Second reopen: foreman diagnosis required before retrying. Classify new defect, earlier review miss, contract gap, or review-induced churn; record cause and next action, then return to-implement only when ready.

#### Resolution — final re-review (2026-10-31)
Verdict: Approve

- Independent reviewers: the stage-2 author wrote the one-line F3 repair; stage-3 reviewer `/root` reviewed it through independent agents `/root/standards` and `/root/spec` and independently reproduced the cached-History scenario graphically. Fixed incremental comparison: `git diff bc0d840da0aef35d1b865f3c5d096d477fa77c0d...966137e0f1f097065f9f4d936ca2b9453582c72c`. All five new commits were covered. The earlier full-diff review and F1/F2/F4 dispositions remain valid.
- Rebased onto lane `sweatshop/ui-review/2026-10-31-1734` at `f79c4f3c2d2647d8effff13f891bb50ef8cdacb5`. The only conflict was this ticket's historical metadata; the lane's unique recovery/failure notes were restored above, with the original proxy receipt and every handoff/review retained. `git diff 966137e HEAD -- ui/review.gd ui/review.tscn ui/eval_graph.gd tests/test_review.gd` was empty after rebase. The lane also includes CLEAN-012's font-weight correction and regression, so the old gate receipt was superseded by a fresh integrated run.
- Standards: no new documented-standard breach or material baseline smell. The test-only commit `d503fe2` (rebased `15fe14e`) precedes production-only `5c0c1b0` (rebased `2f3cc39`), within Primary files. The new signal connection follows the surrounding signal/deferred-call conventions. Existing S1 (P3, local palette/style overrides) remains unchanged and has an open destination: [CLEAN-013](82-CLEAN-013-review-theme-variations.md), pending stage-1 specification; it does not drive a reopen.
- Spec: F3 is resolved. `ui/review.gd:231` scrolls the current selection after the Tree resizes, covering cache-driven layout shrinking; `_show_ply` still handles selection/navigation. The test at `tests/test_review.gd:962` opens a legal 80-ply finished game via the real History entry point with a complete current analysis cache, waits ten frames and checks selected-cell containment at both sizes. No scope creep or new defect was found. F1 (saved time control), F2 (progress/result and retained History errors) and F4 (anchored legend) remain resolved; their source is unchanged by this repair.

| Criterion | Final disposition |
|---|---|
| 1 | Previous pass retained: player names/dots, orientation, left eval score, destination class icon and best-move arrow. |
| 2 | F1/F2 resolved; counts/icons/accuracy/graph-marker assessment retained. |
| 3 | F3 resolved independently for cached History entry, compact resizing, class expansion/collapse and return to wide layout; previous move/repertoire and navigation assessment retained. |
| 4 | Previous controls/action visibility pass retained. |
| 5 | Previous pending placeholders, analysis progress and empty-state pass retained; F2 remains resolved. |
| 6 | Previous ordered twelve-class popover/threshold pass retained; Enter opens, Esc/Space dismiss without leaving History. |
| 7 | 800x600 capture remains usable; final move visible and compact class expansion/collapse preserves it. |
| 8 | Six final rendered comparisons below; the recorded visual differences and fixture limitations remain disclosed. Bruno's release QA is still pending. |

- Independent graphical evidence root `E`: `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-final-review-1793488008122/`. The extended previous review probe `E/cached_probe.gd` ran against the rebased code with isolated data. `E/cached-probe.log`: **F3_CACHE_REGRESSION=PASS, ExitCode: 0**, no script errors. The selected final row was y=191..219 in a 224px Tree at 1280x800; after resizing to 800x600 it was y=90..118 in a 123px Tree, remained there after class expansion/collapse, and was y=187..215 on returning to wide. Captures: `E/CachedHistoryLast.png`, `E/CachedHistorySmall.png`. Viewport Enter/Esc/Space also confirmed History legend input routing and compact containment.
- Red/green evidence inspected: `C:/Users/bruno/AppData/Local/Temp/ui026-cached-red.log` fails exactly the selected-row bounds at both dimensions (exit 1); `ui026-cached-green.log` reports FAILURES=0, exit 0. No production repair was authored by this review.
- Before root `B`: `C:/Users/bruno/AppData/Local/Temp/pchess-ui026-review-4192169c-91d5-460e-951b-7ce997d87d42/before/` (the prior exported/imported `26bad347` tree). Six final captures were regenerated with `scripts/screens.gd` using isolated data, all exit 0 without script errors, and visually compared to their reference PNGs. `E/manifest.json` pins the revisions and gate receipt.

| Board | Before | Final after | Reference |
|---|---|---|---|
| Review | `B/Review.png` | `E/after/Review.png` | `docs/design/v0.1.0/png/Review.png` |
| ReviewAnalysing | `B/ReviewAnalysing.png` | `E/after/ReviewAnalysing.png` | `docs/design/v0.1.0/png/ReviewAnalysing.png` |
| ReviewNotAnalysed | `B/ReviewNotAnalysed.png` | `E/after/ReviewNotAnalysed.png` | `docs/design/v0.1.0/png/ReviewNotAnalysed.png` |
| ReviewSmall | `B/ReviewSmall.png` | `E/after/ReviewSmall.png` | `docs/design/v0.1.0/png/ReviewSmall.png` |
| ReviewLegend | `B/ReviewLegend.png` | `E/after/ReviewLegend.png` | `docs/design/v0.1.0/png/ReviewLegend.png` |
| ClassLegend | `B/ClassLegend.png` | `E/after/ClassLegend.png` | `docs/design/v0.1.0/png/ClassLegend.png` |

- Visual limits retained: the general fixture uses six plies and illustrative names/scores/counts, and has no repertoire. The screenshot tool aliases ClassLegend to ReviewLegend rather than demonstrating the standalone component. The previously documented title/result arrangement, type sizes, spacing, absent chart glyph and temporary hidden summary/move list during compact class expansion remain recorded with their original reasons. Rematch is retained under the behavioral contract. Synthetic cached evaluations verify rendering/layout, not live engine classification.
- Existing decision reviewed: `Proxy decided (opus-5.5 xhigh): (a), resume once on the same lineup`, receipt `C:/Users/bruno/AppData/Local/Temp/sweatshop-proxy/20261031-182950-UI-026-4b70fe.json`. Its complete original text and receipt remain above; it authorizes the retry, without waiving product criteria. All four review findings are now resolved.

- Final integrated gate ran once on `e033f7d305908fdf93693c4235992d7da49e6df8`: **442 printed passed, six Lc0 SKIPs, 436 executed, 0 failed, ExitCode: 0**. Complete log: `E/gate.log`; receipt: `E/gate.json`. `Assert-GateEvidence` validated command, log hash, exit marker, tested commit and production equality before integration, and is rechecked against the closure HEAD. The log contains an anchor-sizing warning; no script errors were reported. No repeat gate was run merely for filtering.
- Integration merge: `06bfcd10b0f2f6cae917df710456a6b7d8dba852` into `sweatshop/ui-review/2026-10-31-1734`. This Resolution, the ledger entry and `Stage: done` are committed together on the lane. No PR or push from stage 3.
- Limits: no live Stockfish/Lc0 game, physical keyboard/mouse gameplay, audio, screen reader, clean-machine release test or Bruno QA in this review. Product acceptance remains separate from implementation approval.

Acceptance: pending | F1-F4 implementation findings are resolved. Live analysis/gameplay and Bruno's v0.1.0 product QA remain pending before release; synthetic cache/render/input probes are not full product acceptance.
Disclosure: decision | none | The existing proxy retry decision/receipt is preserved above; no contract waiver.
Disclosure: decision | none | All integration findings F1-F4 and the lane metadata reconciliation are resolved by this review and integration.
Disclosure: pending | none | S1 remains open in [CLEAN-013](82-CLEAN-013-review-theme-variations.md) for stage-1 specification of shared Theme cleanup.
Disclosure: pending | release | Bruno's v0.1.0 QA under `.scratch/ui-redo/spec.md` remains required before tagging, including live finished-game analysis and physical interaction.

- 2026-10-31 Foreman feature check on the integrated session 1b4af20 (includes CLEAN-012 font weights): `scripts/screens.gd` Review 1280x800, ReviewSmall 800x600 and ReviewLegend 1280x800, exit 0, captures under `C:/Users/bruno/AppData/Local/Temp/pchess-ui-review-acceptance-1b4af20/`. Nothing clipped at 800x600. Against `docs/design/v0.1.0/png/Review.png`, besides the differences already disclosed (two-line title/result, spacing, type sizes, empty-card glyph): the header lacks the chart icon and right-aligned metadata, the class table has no You/Maia column headers and its counts and icons sit together at the right edge, the "?" controls are plain text rather than round buttons, and the navigation buttons are small. The tool's fixture is a three-move game with no repertoire, so the graph and repertoire row rely on the stage-3 captures. Unexamined: a live finished game, physical input, screen reader.

Acceptance: pending | Bruno's v0.1.0 QA (Review: human); visual differences above and in earlier Comments to judge against the canvas.
Disclosure: pending | release | [Review.png](../../../docs/design/v0.1.0/png/Review.png): side-card header, class-table columns and help-button styling still differ from the canvas after CLEAN-012; Bruno decides whether QA accepts them or a follow-up ticket is needed.
