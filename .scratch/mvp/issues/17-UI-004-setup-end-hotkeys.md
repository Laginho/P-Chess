# UI-004: Setup, game end, rematch and hotkeys
Stage: to-implement
Blocked by: CLOCK-001
Review: agent
Difficulty: normal

- Primary files:
  - ui/setup.tscn, ui/setup.gd
  - ui/main.tscn, ui/main.gd
  - core/game.gd (claim, resign)
  - New: tests/test_session.gd

#### What to build

The full game loop of §9.1 and §9.2: the complete setup screen, a clear game-end display, `Space` for a rematch with colours swapped, `Esc` twice to resign, a Claim draw button and `F11` focus mode.

#### Acceptance criteria

1. The setup screen picks colour (white / black / random), time control, Maia level and opening mode. Only Free is enabled until the opening tickets land.
2. At game end the result and its reason are shown (checkmate, stalemate, time, resignation, 50-move, repetition, insufficient material).
3. `Space` after the game starts a rematch with the same settings and the colours swapped (from the colours actually played, also after random). During a game `Space` does nothing.
4. The first `Esc` shows a hint; a second `Esc` within 2 s resigns. After 2 s the hint goes away and the next press starts over.
5. A Claim draw button is enabled only when CORE-004 reports a threefold claim; auto-claim is on (a constant until UI-005 makes it a setting). Maia never claims.
6. `F11` toggles focus mode: only the board and the clocks are visible.
7. There is no abort button.
8. Rematch settings and the double-`Esc` timing are logic that is tested without a window.

#### Verification

    Manual: resign with Esc Esc; Space rematch swaps colours; F11 focus mode; claim a threefold.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_session.gd`: rematch swaps colours and keeps settings; the double-`Esc` window at 1.9 s and 2.1 s with a fake clock. Red because the session logic does not exist.

## Comments
