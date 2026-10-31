# UI-023: Game screen: board and side panel to the design
Stage: implementing
Blocked by: UI-021
Review: human
Difficulty: hard

- Primary files:
  - ui/game_over.gd (remove the side Review button wiring only)
  - scripts/screens.gd (GameOver call site and the four game-screen screenshot fixtures only)
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

- Proxy decided (opus-5.5 xhigh): Yes. Add `ui/game_over.gd` and `scripts/screens.gd` to Primary files, scoped to removing the side Review button and updating the one call site. No restyling. Criterion 4 can't pass without them: `present` takes the side Button and calls `.show()` on it in `_close`. This is the same kind of scoped addition the proxy approved for CLEAN-001. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-181943-UI-023-022105.json)

- Proxy decided (opus-5.5 xhigh): Yes, widen the `scripts/screens.gd` scope for the four UI-023 boards — the fixture should show the game screen the way `_start` leaves it, or shared acceptance 1 and 4 compare against a state the app never shows. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-182516-UI-023-7773a8.json)

- Stage 2: updated the former side-Review and Settings-button assertions in `test_game_over_panel_actions`, `test_settings_blocks_focused_resign_button_from_space`, and `test_settings_shortcut_availability_and_mouse_close`; the latter two retain the input/focus checks using Ctrl+,. Updated the exact parsed move-list strings in `test_badges.gd` and `test_clock_input_order.gd` because a table exposes adjacent cells without newline separators. Removed `test_material.gd` with the retired counter.
- The graphical last-move test is skipped by the headless gate; it was run separately with a display and passed. Captures at 1280x800 and 800x600 are in `C:/Users/bruno/AppData/Local/Temp/pchess-ui023-work/`. The fixture has six moves, default player You and equal clocks, instead of the reference sample's ten moves, Bruno, score and clock times. The implementation uses the shared robot icon and theme typography; UI-021's open CLEAN-012 tracks the shared font weight issue. The panel uses its available width without the reference's 12px inset.
- Manual acceptance pending: play with drag and premove, offer a draw, press Esc once, finish a game, resize with the grip, F11 and Ctrl+,.
