# UI-014: Match score across rematches
Stage: implementing
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/main.gd
  - ui/main.tscn (a score box beside each clock)
  - ui/game_over.gd
  - ui/game_over.tscn
  - tests/test_session.gd
  - docs/spec.md (Â§9.1)

#### What to build

Consecutive rematches form a match (Â§9.1). The game-over panel shows the running score between you and Maia, and from the first rematch on each player's score shows in a small box beside their clock.

#### Acceptance criteria

1. A win counts 1 to the winner, a draw Â½ to each side; scores show as "1", "Â½", "1Â½".
2. The game-over panel shows the running score including the game just finished, you first, for example "You 2 â€“ 1 Maia 1500".
3. From the first rematch onwards each clock row shows that player's score in a small box; the first game of a match shows no boxes.
4. A rematch (`Space` or the button) keeps the score, and the boxes follow the players across the colour swap.
5. The score resets on New game, when a game starts with any setting other than the swapped colour changed, and when the engine stops. It is not saved across launches.

#### Verification

    Manual: win, rematch, draw, rematch: the panel reads 1Â½ â€“ Â½ and the boxes follow the colours.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_session.gd`: two finished games via rematch give the right panel text and boxes after the swap; New game resets; a changed level resets (red: no score).

## Comments

- 2026-10-30 Written from spec Â§9.1. The Home screen (UI-016) adds the reset on returning Home.

