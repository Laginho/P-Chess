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
