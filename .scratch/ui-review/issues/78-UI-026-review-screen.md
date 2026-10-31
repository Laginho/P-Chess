# UI-026: Review screen to the design
Stage: implementing
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
