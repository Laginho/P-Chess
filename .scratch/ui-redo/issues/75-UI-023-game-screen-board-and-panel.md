# UI-023: Game screen: board and side panel to the design
Stage: to-implement
Blocked by: UI-021
Review: human
Difficulty: hard

- Primary files:
  - ui/main.gd, ui/main.tscn
  - ui/board_view.gd, ui/board_view.tscn
  - ui/clock.gd, ui/clock.tscn
  - ui/move_list.gd, ui/move_list.tscn
  - ui/resize_grip.gd
  - ui/settings.gd, ui/settings.tscn (the Open button leaves the game screen)
  - tests/test_session.gd, tests/test_material.gd, tests/test_board_view.gd, tests/test_settings.gd
  - docs/spec.md (§8.4, §8.7, §9.2, §9.3)

#### What to build

Restyle the game screen to `docs/design/v0.1.0/png/Game.png`, `GameSidePanel.png`, `GamePanelStates.png` and `Board.png`, and drop what Bruno chose to drop on 2026-10-31 (`.scratch/ui-redo/spec.md`).

#### Acceptance criteria

1. The board matches `Board.png`: Lichess brown squares; the last move highlighted `#cdd26a` on light and `#aaa23a` on dark squares; coordinates inside the squares in the opposite square colour; the resize grip's icon at the bottom-right corner. Every screen that shows a board gets this look.
2. The side panel matches `GameSidePanel.png`: a card with Maia's row on top (match score box from the first rematch, robot avatar, "Maia", clock), the move list in numbered rows with alternating shading and the current move boxed, the Offer draw (½) and Resign (flag) buttons, your row at the bottom (score box, initial avatar, name, colour, clock), and Claim draw below. The running clock is the light one.
3. `GamePanelStates.png`: the resign confirm is a red "Click again to resign" button with a 2 s bar draining under it; "Maia declined" and "Draw agreed" show as a notice above the buttons.
4. Removed, as Bruno decided: the in-game Settings button (Settings stays on Home and on `Ctrl+,`), the material-difference counters, and the side-panel Review button left after closing the game-over card. Code and tests used only by them go too (`material_balance` and `tests/test_material.gd`, unless something else uses them). `docs/spec.md` §8.4, §8.7, §9.2 and §9.3 say so.
5. Focus mode (`F11`) still shows only the board and the clocks.
6. The shared acceptance in `.scratch/ui-redo/spec.md` holds for the four boards.

#### Verification

    Manual: play a game (drag, premove, offer a draw, press Esc once, finish); resize the board with the grip; F11; Ctrl+, opens Settings.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_session.gd`: closing the game-over card leaves no Review button in the side panel; the game screen has no Settings button; `Ctrl+,` still opens Settings (red: both buttons still exist).
- `tests/test_board_view.gd`: the last-move squares use the design's two highlight colours (red: one translucent overlay today).

## Comments

- 2026-10-31 Written from `.scratch/ui-redo/spec.md`. Bruno chose to drop the in-game Settings button, the material counters and the panel Review button, which the canvas leaves out.
