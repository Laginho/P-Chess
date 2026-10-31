# UI-024: Game-over card to the design
Stage: implementing
Blocked by: UI-021, UI-023
Review: agent
Difficulty: normal

- Primary files:
  - ui/game_over.gd, ui/game_over.tscn
  - ui/main.gd (only the card's Copy PGN wiring)
  - tests/test_session.gd

#### What to build

Restyle the game-over panel to `docs/design/v0.1.0/png/GameOver.png`, `GameOverStates.png` and `GameOverCard.png` (`.scratch/ui-redo/spec.md`).

#### Acceptance criteria

1. The card matches `GameOverCard.png` over a dimmed final board: a head tinted by the result (green win, red loss, grey draw) with a trophy, flag or ½ icon, "You won!", "You lost" or "Draw" and the reason; both players with their avatars, the winner ringed in gold; the match score ("2 – 1", halves as ½) labelled "Match".
2. The main button reads **"Review"** (Bruno's decision, not the canvas's "Game Review"), with the star icon and the canvas's green style. Below it, "New game" and "Rematch". New game returns Home as today; the canvas's "New 3+2" is not adopted.
3. A Copy PGN icon at the top left copies the game's PGN, as the review's Copy PGN does; the ✕ at the top right closes the card.
4. The loss and draw variants match `GameOverStates.png`.
5. The shared acceptance in `.scratch/ui-redo/spec.md` holds for the three boards.

#### Verification

    Manual: win, lose and draw a game; use Copy PGN and ✕ on the card.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_session.gd`: the card's Copy PGN puts the game's PGN on the clipboard; the main button reads "Review" (red: no Copy PGN on the card).

## Comments

- 2026-10-31 Written from `.scratch/ui-redo/spec.md`. The "Review" label is Bruno's decision of 2026-10-29, confirmed 2026-10-31.
