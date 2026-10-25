# UI-006: Click-click moves, auto-queen, arrows
Stage: done
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

#### Resolution (2026-10-25)

Verdict: Approve

Stage 3 reviewed `ff0eb4f...e7f0230`, with independent Standards and Spec sub-agents. The session tip `ff0eb4f` was already an ancestor, so rebase changed nothing. Integrated into `sweatshop/core/2026-10-25-0159` as `ee13d66`; the merge tree is identical to the reviewed branch. No production or test changes were needed in review.

Examined: the complete diff and every commit's file statistics; BoardView's `_gui_input`, `_pick_up`, `_drop`, `_open_picker`, `_commit`, `play`, game setter and cancellation paths; PromotionPicker signals; Main's startup/settings routing, bot moves and turn lock; settings validation and persistence; coordinate mapping and annotation lifecycle. Failure paths include illegal/off-board targets, repeated selection, selected-piece dragging, disabling click-click, flagging, replacement games, Alt promotion and invalid stored preferences. Not examined interactively: mouse capture/gesture feel, appearance, exported builds, or picker layout after resizing/flipping.

##### Standards

No documented-standard violations or actionable baseline smells found. All 11 commits preserve test/production separation, with ticket metadata allowed; production changes stay within Primary files, including the proxy-approved Main routes. No regression identified. The UI-007 handoff is permitted tracker metadata. Its inherited UI-002 note is updated below to acknowledge that `_held_moves` cleanup is now fixed while retaining the pending-picker follow-up.

##### Spec

No missing/partial numbered requirements, scope creep or incorrect implementation found under the recorded proxy scope. Main's two assignments follow the expanded Primary files. The existing Maia-turn mouse lock remains an explicit UI-007/release condition.

Criteria:

1. ✅ Click-click defaults off; selection, legal moves, deselection, both orientations and continued dragging are covered, including dragging an already selected piece. Flag/rematch and preference changes cannot commit a stale selection.
2. ✅ Off/on/only-on-premoves and Alt follow the 12-case decision table. Board input exercises ordinary drag and click promotions; the real picker supports underpromotion. Premove execution belongs to UI-007.
3. ✅ Right-drag records square-pair arrows and right-click records circles in both orientations. Invalid/unmatched gestures record nothing; drawing does not play a move.
4. ✅ Left press clears completed and pending drawings while preserving click-click move behavior. A later right release cannot restore a cancelled drawing.
5. ✅ Both preferences have validated defaults, persist through ConfigFile reload, and reach BoardView through the real settings scene/Main lifecycle at startup and after edits.

Red/green: reviewed the separate test/code pairs and their retained `.godot/ui006*-red.log` / `*-green.log` output. Decision: `0 passed, 1 failed` → `1 passed, 0 failed`; click-click: `1 passed, 5 failed` → `6 passed, 0 failed`; promotion/settings: `6 passed, 4 failed` → `10 passed, 0 failed`; drawings: `10 passed, 3 failed` → `13 passed, 0 failed`; selection transitions: `13 passed, 2 failed` → `15 passed, 0 failed`. The first four fail on absent production behavior/properties; the last fails the selected-piece drag and disable-selection assertions. Tests call production scripts/scenes.

Gate: reused the unchanged-code receipt above for `dcb3d1b199b3bc0cbe86c30770397204a0363664`: bound command exit 0, `152 passed, 0 failed`, including all 15 input-mode tests and the live Lc0 check. Stage 3 verified the log SHA-256, successful exit marker, available tested commit and tracker-only changes using the installed `Assert-GateEvidence` helper. `git diff --check` passes. The full gate was not rerun because production and tests are unchanged.

`Proxy decided` reviewed: `(gpt-6-astra high, fallback)` authorizes the two Main routes and criterion-focused tests while retaining the turn-input lock. Its release impact remains assigned to the open UI-007 ticket; no new proxy decision was made in review.

Acceptance: pending | Interactive game, promotion, drawing and restart checks remain unperformed by a person; automated evidence is recorded above and in Stage 2 handoff.

Disclosure: decision | none | Existing proxy decision under Comments: use Main's established settings router; missing new keys receive defaults without migration.

Disclosure: pending | release | [UI-007](20-UI-007-premoves.md): reconcile opponent-turn arrows/circles with right-click premove cancellation and inspect the remaining open-picker interaction before release.

Disclosure: pending | release | Manual product acceptance in Verification remains pending; this implementation approval permits session integration and does not establish gesture feel or visual quality.
