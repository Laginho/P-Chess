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

- 2026-10-31 Attempt 1 failed: exit 0. Log tail: O UI-026 **ainda não está concluído**. Na branch local `UI-026-review-screen`, implementei partes da navegação, dos ícones de jogadas, da legenda e do recolhimento da tabela. O [ticket](C:/Users/bruno/Desktop/Pastinha/Programas/Projects/P-Chess/.artifacts-build/lanes/ui-review/.scratch/ui-review/issues/78-UI-026-review-screen.md) permanece em `Stage: implementing`. /  / Os testes focados de review passaram: **27 passaram, 0 falharam**. A captura gráfica mostrou que a tela ainda difere bastante da referência; falta concluir a composição visual e os demais critérios antes de encaminhá-la para revisão. /  / Não executei o gate completo nem a aceitação manual; a alteração ainda não está pronta para integração. /  /

- 2026-10-31 Stage stopped (incomplete handoff): Stage left uncommitted work; saved for recovery. See C:\Users\bruno\Desktop\Pastinha\Programas\Projects\P-Chess\.artifacts-build\lanes\ui-review\.scratch\run-log\UI-026-implement-20261031-182333.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.

- Proxy decided (opus-5.5 xhigh): (a), resume once on the same lineup - both attempts were green, cheap ($0.77, 10.5 of 240 min) and stopped on their own with no error; the ticket is clear, so splitting it would only work around how the model behaved, and a lineup change isn't mine to make. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-182950-UI-026-4b70fe.json)

- 2026-10-31 Resume: continue from `UI-026-review-screen` at efc1d4b; its commits are the work so far. The recovery ref `refs/sweatshop-recovery/aa946201260b4eccbb7d7b7834b86b5d` is cleanup only (an untracked copy of `tests/test_review.gd`), ignore it. Put scratch copies and captures under `%TEMP%`, never inside the repo, so no untracked file is left. The stage has 240 min: do not end the turn at `implementing` with partial work. Either finish criteria 1-8 (what remains is the list in the efc1d4b comment), record the visual comparison against `docs/design/v0.1.0/png/Review*.png` and one gate log with its exit code, then hand off at `to-review`; or end `blocked` on a specific question.

- 2026-10-31 Second reopen: foreman diagnosis required before retrying. Classify new defect, earlier review miss, contract gap, or review-induced churn; record cause and next action, then return to-implement only when ready.

- 2026-10-31 Reopen diagnosis: new implementation defect, an incomplete repair of round-1 F3. Round 1 asked to keep the selected move visible on "navigation/graph jumps and initial presentation"; cd4891b added one `_moves.ensure_cursor_is_visible.call_deferred()` when a move is selected, and the regression (5a11b2c/03c45f2) opens a long game with no analysis. Opening a long History game with a complete cache replays the analysis (`present_history`, ui/review.gd:729-733); that shows the summary and shrinks the Tree after the single deferred scroll has run, so the cursor ends at y=782 in a 224 px Tree (re-review `cached_probe.gd`, `F3_CACHE_REGRESSION=FAIL`). This is not a review miss (round 1 named initial presentation), not a contract gap, and not churn (the advice was right; the execution covered one path). Next action, stage 2 on the existing `UI-026-review-screen` branch: first a red regression that opens an 80-ply finished game with a complete current analysis cache through `main._review_history_game` and asserts the selected item's rect lies inside the Tree after layout settles (reuse the re-review's `cached_probe.gd` setup); then keep the cursor visible after layout changes, e.g. re-run `ensure_cursor_is_visible` when the Tree resizes, not only on selection; verify after the final layout at 1280x800 and 800x600. F1, F2 and F4 are resolved; leave them alone.
