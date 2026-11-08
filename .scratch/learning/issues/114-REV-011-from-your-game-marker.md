# REV-011: The from-your-game marker in Review
Stage: blocked
Blocked by: LEARN-006, LEARN-009
Review: agent
Difficulty: normal

- Primary files:
  - ui/review.gd (`present` move-list rows, `_fit_exit_rows`; the marker row beside the "Left repertoire" one)
  - ui/main.gd (the marker's link opens the unit page)
  - core/course.gd (adding a from-your-game position, once per FEN)
  - New: core/own_game_scan.gd (finding your result-changing moves in rook and pawn against rook, over the probe)
  - New: tests/test_own_game_scan.gd
  - tests/test_review.gd
  - tests/test_course.gd

#### What to build

When Review shows a game that reached rook and pawn against rook, each of your moves in that material that changed the result for your side gets a marker row under it, in the "Left repertoire" pattern but green, linking to the unit (spec §L10, design `ReviewMarker.dc.html`). The position before the move joins the unit as "From your game", and Continue offers it (LEARN-009).

#### Acceptance criteria

1. The scan looks only at your moves played from positions with exactly king, rook and one pawn against king and rook (either colour, either side with the pawn).
2. For each such move it asks the probe for the result for your side before and after; a different result marks the move.
3. Each marked move gets a full-width row under its move-list row: "Rook and pawn against rook · this move turned <before> into <after>" and "Practise in Rook endgames", green, not selectable as a move, sized like the "Left repertoire" rows.
4. Clicking the row opens the unit page.
5. The position before each marked move is added to the unit's from-your-game positions with your side, the goal from the result before the move (win or hold) and the unit's default line length; the same FEN is never added twice.
6. Games that never reach that material are not probed, and their Review is unchanged.
7. When the probe is unavailable, Review shows no markers and adds nothing, with no error dialog.

#### Verification

    Manual: review a saved game that lost a drawn rook ending; follow the marker to the unit.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_own_game_scan.gd`: with a fake probe over a fixture PGN reaching the material: a result-changing move is found; a kept-result move isn't; positions outside the material aren't probed (red: no scan).
- `tests/test_review.gd`: presenting that game with a fake probe adds one marker row under the move; clicking it emits the unit request (red: no row).
- `tests/test_course.gd`: adding the same FEN twice keeps one from-your-game position (red: no function).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L10.

- 2026-11-08 Attempt 1 stopped to ask (its commits are on branch `recovery/asked/20261108-062806/REV-011`): O REV-011 está **bloqueado** na branch `ticket/REV-011`. Preservei um teste para impedir posições duplicadas por FEN, mas a execução foi interrompida antes de verificar a falha esperada; a implementação ainda não começou. /  / Qual deve ser o comprimento padrão das linhas para posições “From your game”? A unidade atual não define um padrão; suas posições usam 2, 3 e 4 movimentos. Minha sugestão é definir **3 movimentos** explicitamente nos dados da unidade. /  / O proxy do fluxo falhou sem retornar uma decisão. A [skill ticket-flow](/home/lage/.agents/skills/ticket-flow/SKILL.md) determina que, nessa situação, se registre `Stage: blocked` e, em sessão acompanhada, se apresente a falha ao usuário. A pergunta e o trabalho preservado estão no [ticket REV-011](/home/lage/Projects/P-Chess/.artifacts-build/lanes/learning/.scratch/learning/issues/114-REV-011-from-your-game-marker.md).
