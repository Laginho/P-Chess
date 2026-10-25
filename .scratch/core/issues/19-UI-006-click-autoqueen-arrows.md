# UI-006: Click-click moves, auto-queen, arrows
Stage: to-review
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

#### Stage 2 handoff (2026-10-25)

- Implemented click-click selection and deselection, including dragging a selected piece and immediately clearing selection when the preference is disabled. Drag-only input remains the default. Flags and replacement games cannot play stale selections.
- `PromotionPicker.should_auto_queen(mode, premove, alt)` is the shared decision for UI-007. BoardView's `auto_queen` property applies it to ordinary drag/click promotions; Alt opens the existing picker, including underpromotion. `click_click` and `auto_queen` are validated ConfigFile settings, routed by Main on startup and after edits.
- BoardView `drawings` holds square pairs (`PackedStringArray`); equal endpoints are circles. Right drags preview an arrow, left presses clear completed and pending drawings, and a replacement game clears annotations. Square coordinates preserve drawings through orientation and size changes.
- Red/green cycles, each with separate test-only and production-only commits:
  - `965943d` → `9530d7c`: decision absent (`0 passed, 1 failed`) → `1 passed, 0 failed`; covers all 12 mode/premove/Alt combinations.
  - `10cccb6` → `1176512`: click selection absent (`1 passed, 5 failed`) → `6 passed, 0 failed`.
  - `9830ea4` → `28a2d21`: promotion setting and preference routing absent (`6 passed, 4 failed`) → `10 passed, 0 failed`.
  - `56ce018` → `00801fb`: drawing input absent (`10 passed, 3 failed`) → `13 passed, 0 failed`.
  - `9c4b3d2` → `dcb3d1b`: selected-piece drag and disabling an active selection failed (`13 passed, 2 failed`) → `15 passed, 0 failed`.
- Focused tests ran through `tests/run.gd` against a copy of `tests/test_input_modes.gd` in the ignored `.godot/ui006-tests` directory; every test invokes the production scripts/scenes. The full bound gate includes the committed test in its normal location.
- Gate on `dcb3d1b199b3bc0cbe86c30770397204a0363664`: `godot --headless -s tests/run.gd`, exit 0, `152 passed, 0 failed` (15 new tests). The live Lc0 test also passed. Existing malformed-time-model fixtures emit expected fallback warnings; no script errors were reported.
- Additional headless lifecycle smoke exercised arrow/circle rendering and the settings screen: its form fits at 800×600 (box position 200,55; size 400×489). `git diff --check` passes. No production or test changes follow the tested commit.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\p-chess-ui006-20261025\UI-006-gate.json

Acceptance: pending | Verification's interactive game, promotion and drawing checks have not been run by a person; automated input/lifecycle checks and the full gate pass as recorded above.

Disclosure: decision | none | Proxy decision under Comments: add only Main's two existing-router assignments and criterion-focused tests; existing configuration files receive defaults without migration.

Disclosure: pending | release | [UI-007](20-UI-007-premoves.md): Main still ignores board input during Maia's turn, so arrows/circles are currently available only while the board accepts input. The proxy retained this scope; UI-007 must reconcile opponent-turn drawing with right-click premove cancellation (handoff note on the open ticket).

Disclosure: pending | release | Manual product acceptance remains pending as stated above; headless checks do not establish visual appearance or the feel of actual mouse gestures.
