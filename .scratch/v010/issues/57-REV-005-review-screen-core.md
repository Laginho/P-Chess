# REV-005: The new review screen: board, eval bar and classified moves
Stage: to-implement
Blocked by: REV-002, REV-003
Review: human
Difficulty: normal

- Primary files:
  - ui/review.gd
  - ui/review.tscn
  - ui/board_view.gd (a read-only mode, a class icon on a square, the best-move arrow)
  - ui/game_over.gd (`_open_review`)
  - ui/main.gd (`_show_result`, the analyser on Max)
  - New: ui/eval_bar.gd
  - New: ui/icons/classes/*.svg (one per class)
  - tests/test_review.gd
  - tests/test_badges.gd, tests/test_book.gd, tests/test_history.gd (test-only: the assertions that read the old review's `Margin/Content/Moves` tree, `Result` and `RepertoireExit` nodes)
  - docs/spec.md (§15.6)

#### What to build

The review becomes a chess.com-style game review (§15.6). The post-game panel's Review button opens it and starts analysing the game on Max at once; moves get their class as their analysis lands. The summary and the graph are REV-006.

#### Acceptance criteria

1. The review shows a board that steps through the game with ←/→ and a move list; clicking a move jumps the board there.
2. An eval bar sits on the left of the board, from the current position's PV1 score, and flips with the board's orientation.
3. Each move in the list carries its class icon (REV-003) as soon as its analysis lands; moves not analysed yet show none. The Left repertoire marker shows on the move where the player left, with the expected moves.
4. On the board, the current move's class icon sits on its destination square, and an arrow shows the best move from the position before it.
5. The icons are our own SVGs in chess.com's style and colours, one per class (Brilliant, Great, Best, Excellent, Good, Book, Repertoire in blue, Inaccuracy, Mistake, Miss, Blunder, Forced).
6. The post-game Review opens it and starts analysis on Max; a progress bar shows until it finishes. An analysis file that already exists and is not stale is read instead.
7. Copy PGN, Open in Lichess, Rematch and New game work as today; `Space` rematches. There is no coach text and no retry.
8. The review is usable at 800×600.

#### Verification

    Manual: finish a game, press Review, watch the moves fill in; step with ←/→.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_review.gd`, with a fake analyser feeding fixture JSON: icons appear per move as positions land; ←/→ move the board; the eval bar follows the flip; the board icon and arrow match the current move (red: old review). The old time-spent and badge-column tests are rewritten; `move_times` and `lichess_url` keep their tests.
- `tests/test_badges.gd`, `test_book.gd`, `test_history.gd`: assertions on the old nodes move to the new review's equivalents (test-only).

## Comments

- 2026-10-30 Written from spec §15.6 and the design brief (`docs/design-brief-v0.1.0.md`, screen 6). The time-spent column of the old review is not in §15.6 and goes.

- 2026-10-30 Attempt 1 stopped to ask (its commits are on branch `recovery/asked/20261030-230636/REV-005`): **REV-005 está bloqueado** na branch `REV-005-review-screen-core`. O tabuleiro de revisão e a navegação pelas setas foram iniciados: o teste focado falhou antes da mudança e passou depois, com 10 testes aprovados. Os demais critérios e o gate completo ainda estão pendentes. /  / A análise chega em ordem inversa, mas a classificação `Miss` depende da classe da jogada anterior; a interface atual do classificador exige todas as posições. O proxy previsto pelo fluxo estava inacessível. A [skill ticket-flow](C:/Users/bruno/.agents/skills/ticket-flow/SKILL.md) determina nesse caso: “set `Stage: blocked` with the question under `## Comments`, commit, stop.” Registrei o bloqueio e preservei os commits. /  / Você aprova ampliar o escopo para adaptar `core/classification.gd` e seus testes à análise parcial, exibindo cada ícone somente quando houver dados suficientes para garantir sua classe? /  /

- 2026-10-30 Proxy decided (opus-5.5 xhigh): Approve. Widen REV-005 to add a partial-analysis mode to `core/classification.gd` and its tests, keeping the signature of `evaluate`. Each icon appears only once its class is settled — the spec requires both backwards analysis (§15.3) and moves filling in as their analysis lands (§15.6), and only the classifier can reconcile the two without the review re-implementing the Miss rule. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261030-230639-REV-005-8bce35.json)
  > Decision: Approve. Widen REV-005 to add a partial-analysis mode to `core/classification.gd` and its tests, keeping the signature of `evaluate`. Each icon appears only once its class is settled — the spec requires both backwards analysis (§15.3) and moves filling in as their analysis lands (§15.6), and only the classifier can reconcile the two without the review re-implementing the Miss rule.
  > 
  > **Why it's needed:** today `evaluate` reads `pv` from every position starting at move 0, so it can't classify anything until all positions have landed. The other inputs are already available up front. Book and Repertoire only need the moves and the first FEN, and the check in `_great` only needs the previous FEN. The only real dependency is Miss, which needs the class of move i-1. The change can be reversed; no file format, public API or data is affected.
  > 
  > **Contract for stage 2:**
  > 1. **Unanalysed position.** It is `{"fen": <fen>}` with **no `pv` key**. This is different from a finished game's last position, which has `pv: []`. Lines 21 and 31 call `after.pv.is_empty()`, which errors when the key is missing, so check `has("pv")` first. This only applies to the in-memory array: `_write_result` runs after every position lands, so the JSON and `read_analysis` don't change.
  > 2. **When a record is `null`:**
  >    - when `positions[i]` or `positions[i + 1]` has no `pv`;
  >    - or when all of these hold: the label is Mistake or Blunder, the three Miss EP thresholds are met, `i > 0`, `result[i - 1]` is `null`, and none of Forced, Repertoire, Book or Best applies.
  >    
  >    Today the code checks Forced/Repertoire/Book/Best after the Miss/Lenient branch. Compute them before deciding to leave a move unsettled, otherwise a Forced or Book move shows no icon just because the move before it isn't analysed yet.
  > 3. **When an unsettled icon appears.** Positions land last to first, so the missing piece is normally `positions[i - 1]`, which is the next one to land. A run of consecutive possible Misses settles together once the first move of the run settles.
  > 4. **Unchanged:** a full analysis gives exactly the output it gives today, so `core/accuracy.gd` and REV-006 are unaffected. The existing `tests/test_classification.gd` suite must pass without edits; that is the regression guard.
  > 
  > **Drafts for the caller to apply to the ticket:**
  > 
  > Add to `- Primary files:`
  > ```
  >   - core/classification.gd (partial analysis: an unanalysed position has no `pv`; an unsettled ply is `null`)
  >   - tests/test_classification.gd
  > ```
  > 
  > Criterion 3, first sentence:
  > ```
  > 3. Each move in the list carries its class icon (REV-003) as soon as its class is settled: once its analysis lands, and for a possible Miss once the previous move's class is settled; moves not analysed yet show none. The Left repertoire marker shows on the move where the player left, with the expected moves.
  > ```
  > 
  > Add to `## Tests stage 2 writes`:
  > ```
  > - `tests/test_classification.gd`: positions without `pv` give `null` for the plies that touch them; a Miss candidate is `null` while the previous ply is `null`, and becomes `Miss` once that position lands; a Forced, Book, Repertoire or Best ply is classified even when its predecessor is unanalysed (red: the current classifier errors on a missing `pv`). The existing fixtures pass unchanged.
  > ```
  > 
  > `docs/spec.md` §15.4, after the sentence "It returns one record per ply with `class`, `loss`, … and `expected`.":
  > ```
  > While analysis is still landing, a position not yet analysed is passed with its `fen` and no `pv`; a ply that cannot be settled yet (either of its positions is unanalysed, or it would be a Mistake or Blunder that may be a Miss while the previous ply is unsettled) gets `null` instead of a record. A complete analysis never yields `null`.
  > ```
  > 
  > **Next for the caller:** apply the drafts, record this decision under `## Comments` and set `Stage: implementing`. Stage 2 then continues on `REV-005-review-screen-core` from `aeb5d63`: first the red test commit for the classifier, then the production change, then the review screen. How the review calls the classifier is left to stage 2. The smallest option is to run `evaluate` again on the pre-filled array at each `position_ready` and draw an icon wherever the record isn't `null`.
  > 
  > I didn't run the gate or the tests; this decision comes from reading the ticket, spec §15.3–15.6, `core/classification.gd` and `engine/analyser.gd`. Running `evaluate` again on every landing does O(n²) `legal_moves` work, which could cause a visible stutter on long games; check for it during the manual verification.

- 2026-10-30 Attempt 1 failed: exit 0. Log tail: **REV-005 está incompleto**, em `Stage: implementing`, na branch `REV-005-review-screen-core`. /  / Recuperei os dois commits da tentativa anterior, que cobrem a navegação do tabuleiro, e preservei a decisão do proxy sobre classificação parcial. Não consegui continuar o ciclo de testes: `godot` não está disponível no PATH e não encontrei o executável nas buscas locais. Por isso, o novo teste vermelho e o gate não foram executados. /  / É necessário disponibilizar o Godot compatível com o projeto nesta sessão para continuar a implementação. /  /
