# UI-026: Review screen to the design
Stage: to-implement
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
Disclosure: pending | integration | Stage-3 Resolution below records four P2 findings (F1-F4); resolve them before integration. The original visual differences remain recorded above.
Disclosure: pending | release | `.scratch/ui-redo/spec.md` requires Bruno's v0.1.0 QA before the release tag.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/pchess-ui026-gate-566792a.json

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
