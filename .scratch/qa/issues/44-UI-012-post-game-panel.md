# UI-012: A small post-game panel instead of the full review
Stage: implementing
Status: ready-for-agent
Blocked by: none
Review: human
Difficulty: normal

- Primary files:
  - ui/main.gd (`_show_result`)
  - ui/main.tscn
  - New: ui/game_over.gd, ui/game_over.tscn
  - tests/test_session.gd
  - docs/spec.md (§9.3)

#### What to build

When a game ends, the full review screen takes over at once, a "jumpscare" (Bruno's QA, 2026-10-26). Instead the final position stays visible with a small panel centred over the board, as on Chess.com: the result, the reason and three buttons. The review screen opens only on request.

#### Acceptance criteria

1. At the end of every game (mate, resignation, flag, draw) a panel appears over the board with the headline ("White won", "Black won", "Draw"), the reason ("by resignation"), buttons Review, Rematch and New game, and a close ✕.
2. Review opens the existing review screen for that game; Rematch does what `Space` does; New game shows the setup screen.
3. ✕ or `Esc` closes the panel and leaves the final position on screen, with a Review button under the result in the side panel.
4. `Space` still starts a rematch while the panel shows.
5. Saving the game to history, the game-end sound and the review's contents are unchanged.

#### Verification

    Manual: finish a game by resignation and by flag; the panel shows, each button works, and ✕ leaves the board.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_session.gd`: after a resignation the review is hidden and the panel visible with the right headline (red: the review shows at once); each button reaches its screen; closing shows the side-panel Review button.

## Comments

- 2026-10-26 Written from Bruno's first QA session (item 5), from a Chess.com screenshot (result, reason, Game Review / New / Rematch). No rating, leaderboard or coach: the app has none.
