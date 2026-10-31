# UI-024: Game-over card to the design
Stage: to-review
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

- 2026-10-31 Stage 2: card copy, score, result variants and focused-button Space covered by session tests. Updated `test_checkmate_opens_review_with_result_and_both_sides_moves` and `test_review_opens_for_no_move_resignation_flag_and_claimed_draw` for the new card text; the updated assertions were red against the old text before the final fix.
- Screenshot evidence (fixture): `C:/Users/bruno/AppData/Local/Temp/pchess-ui024-variants-f3ec8047-e7ac-4ac7-8baa-9dd1e98f79e4/win.png`, `loss.png`, `draw.png` at 1280x800 and `small.png` at 800x600. The screenshot fixture constructs the card directly, so the displayed 0-0 score, resignation reason and surrounding panel do not represent a completed interactive match.
- Visual differences from the reference: the shared flag icon is outlined, the shared robot icon differs from the canvas robot, and the card has no drop shadow. Long player names can be clipped in the fixed-width name label.
- Acceptance: pending | Play win, loss and draw; verify real Copy PGN and close, and assess the recorded visual differences and long player names.
- Disclosure: pending | integration | Review the recorded visual differences and long-name clipping against the design and usability criteria; see the screenshot evidence above.
- Disclosure: pending | release | Manual win/loss/draw, real clipboard and close acceptance remains outstanding; see the ticket verification above.
- Gate: `godot --headless -s tests/run.gd`: 422 reported passed, 0 failed; 7 reported passes were skipped (six Lc0-dependent tests and one graphical pixel test), so 415 executed. The first run failed only on the old review text expectations; these were updated before the successful run.
Gate evidence: C:/Users/bruno/AppData/Local/Temp/pchess-ui024-final-gate.json
