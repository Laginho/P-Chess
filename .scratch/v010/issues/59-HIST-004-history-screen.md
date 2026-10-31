# HIST-004: The history screen
Stage: to-implement
Blocked by: REV-004, REV-005, HIST-003
Review: agent
Difficulty: normal

- Primary files:
  - New: ui/history_screen.gd
  - New: ui/history_screen.tscn
  - core/history.gd (list games, read headers, infer the reason, thumbnail ply)
  - core/settings.gd (`history_tab`)
  - ui/settings.gd (its row)
  - ui/review.gd (opened from the history)
  - ui/setup.gd, ui/setup.tscn (a History button until Home exists)
  - ui/main.gd
  - New: tests/test_history_screen.gd
  - tests/test_history.gd
  - tests/test_settings.gd
  - docs/spec.md (§15.7)

#### What to build

A screen lists every saved game as a card, in tabs, and opens any of them in the review (§15.7). Delete is HIST-005 and the analysis queue HIST-006; here a card shows whether its game is analysed and a review of an unanalysed game offers Analyze.

#### Acceptance criteria

1. Tabs All, 1+0, 3+2 and 5+0, newest game first; the default tab is the `history_tab` setting (default All).
2. Each card shows a thumbnail from your side of the board at the deepest ply that still matches a catalog opening, with that ply's move highlighted. Without a match the thumbnail shows ply 10, or the last ply of a shorter game; a game with no moves shows the start position with no highlight.
3. Each card shows the opening name only when the game matched the catalog, the date, each player's colour, "{name} x Maia 1500" (your side is the player named "You" until UI-018), the result and reason ("Won on time", "Lost by checkmate", "Draw by agreement") and the number of moves.
4. The reason comes from the `Reason` header. For games without it, the moves are replayed: checkmate, stalemate, insufficient material and the 50-move rule are read off the final position, a decisive `Normal` game that is not mate is a resignation, and any other draw shows just "Draw".
5. Each card shows its analysis state: not analysed, stale, or both accuracies; Copy PGN is a small square icon button that is easy to hit.
6. Review opens the game in the review. Repertoire and Left repertoire are checked against the game's snapshot file (HIST-003), and a game without one gets no repertoire markers. That review has Back to History (also on `Esc`) instead of Rematch and New game, and `Space` does nothing.
7. A game with no analysis opens with an Analyze button in place of the summary; pressing it analyses the game on Max and fills the review in.
8. The setup screen gets a History button that opens the screen; History has a way back.

#### Verification

    Manual: open History with a few saved games, switch tabs, review one, go back with Esc.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_history.gd`: the thumbnail ply for a catalog game, an unknown opening, a 6-ply game and an empty game; the inferred reason for each legacy case (red: no functions).
- `tests/test_history_screen.gd`: tabs filter by control; a card shows the right text for a won-on-time game; a history review has Back to History, `Esc` returns, `Space` does nothing; a snapshot-less game shows no repertoire markers (red: no screen).
- `tests/test_settings.gd`: `history_tab` default and choices.

## Comments

- 2026-10-30 Written from spec §15.7 and the design brief (screen 5).

- 2026-10-31 Attempt 1 failed: exit 0. Log tail: O HIST-004 **ainda não está concluído**. Na branch `hist-004`, registrei o primeiro ciclo: a configuração `history_tab`, com padrão `All` e as quatro opções previstas. /  / O teste falhou antes da implementação, como esperado, e depois passou no conjunto isolado: **10 testes, 0 falhas**. O ticket permanece em `Stage: implementing`; ainda faltam a tela de histórico, a integração com revisão e navegação, os demais testes e o gate final. /  / Commits: `1558ea2` e `2c6272b`. A árvore de trabalho está limpa. /  /
