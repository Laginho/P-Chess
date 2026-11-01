# UI-035: After closing the game-over card, the panel offers New game and Rematch
Stage: implementing
Status: ready-for-agent
Blocked by: UI-034
Review: agent
Difficulty: normal

- Primary files:
  - ui/game_over.gd (`_close`, line ~81)
  - ui/main.gd (`_show_result`, `_set_focus`, the `Actions` row and `_show_home`)
  - ui/main.tscn (`Layout/Side/Actions`)
  - tests/ covering the game-over card

#### What to build

Bruno's QA of v0.0.2 (2026-11-01), item 8: "depois do fim do jogo, se eu clico no X do popup de final, eu nÃ£o consigo mais sair daquela tela." Confirmed in code: the X (and Esc) only hides the card; with the game over, Esc's resign no-ops, Offer draw and Resign do nothing, and only an unadvertised Space rematch leaves the screen.

Once the game is over, the panel's Actions row swaps Offer draw / Resign for **New game** (goes Home, like the card's New game) and **Rematch** (like the card's Rematch), with the same button style. A new game restores Offer draw / Resign. In focus mode (UI-034) the panel is hidden, so closing the card there also leaves focus mode, which brings the row back.

#### Acceptance criteria

1. After any game end, closing the card with X or Esc leaves New game and Rematch visible in the panel; New game shows Home, Rematch starts the rematch.
2. Starting any new game shows Offer draw and Resign again, enabled as today.
3. Closing the card in focus mode leaves focus mode, and the two buttons show.
4. Gate green.

#### Verification

    Manual: lose a 1+0 game on time, close the card with X, press New game; Home shows.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- End a game, close the card, and assert a visible panel button leads to Home (red: none exists).

## Comments

- 2026-11-01 Written from Bruno's QA of v0.0.2 (item 8). The canvas has no post-game panel state (`GamePanelStates.png` shows only in-game states). Default taken: Chess.com's behaviour, the action row becomes New game / Rematch. Correct it if the X should instead go back Home or reopen the card.
- Blocked by UI-034: same files (`main.gd` focus and panel code).
