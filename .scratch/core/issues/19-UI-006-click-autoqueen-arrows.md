# UI-006: Click-click moves, auto-queen, arrows
Stage: implementing
Blocked by: UI-005
Review: agent
Difficulty: normal

- Primary files:
  - ui/board_view.gd
  - ui/promotion_picker.gd
  - core/settings.gd, ui/settings.tscn, ui/settings.gd
  - ui/main.gd (`_apply`: route `click_click` and `auto_queen` to BoardView)
  - New: tests/test_input_modes.gd

#### What to build

The other input options of §8.1 and the drawing of §8.3: click-click moves, the three auto-queen modes, and right-mouse arrows and circles.

#### Acceptance criteria

1. Click-click setting (off by default): when on, clicking a piece then a legal square plays the move, and clicking elsewhere deselects. Dragging still works.
2. Auto-queen setting off / on / only on premoves, default off. Off opens the promotion picker. On promotes to a queen, and holding `Alt` while dropping opens the picker. "Only on premoves" auto-queens premoves only (premoves arrive in UI-007; the decision function is tested here).
3. A right-drag between two squares draws an arrow; a right click on one square draws a circle.
4. A left click on the board clears every drawing.
5. Both new settings persist.

#### Verification

    Manual: click-click a game; promote under each auto-queen mode; draw and clear arrows.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_input_modes.gd`: auto-queen decision (mode × premove × Alt), click-click selection and continued dragging, right-drag arrows/right-click circles/left-click clearing, settings defaults and persistence, and settings-screen → store → board wiring. Red because these behaviors and keys do not yet exist.

## Comments

- Proxy decided (gpt-6-astra high, fallback): Add the two Main settings routes and criterion-focused tests; retain the existing turn-input lock for UI-006 — this completes the settings contract through UI-005's established router while leaving opponent-turn input integration with UI-007.
- Pre-test caller inspection: BoardView `_gui_input` calls `_pick_up`/`_drop`; `_drop` opens the picker or commits, and `play`/the picker's signal also call `_commit`. The `game` setter and picker cancellation clear held input. Existing callers are Main (game replacement, bot `play`, settings) and board/session tests. Cover an empty/off-board target, illegal or repeated selection, dragging with click-click enabled, a game ending while selected, and a replacement game so the new selection cannot survive a rematch.
