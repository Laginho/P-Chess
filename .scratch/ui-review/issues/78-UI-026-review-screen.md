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
