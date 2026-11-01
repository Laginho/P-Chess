# UI-037: Click-click's second click: right cancels, outside cancels, own piece reselects
Stage: to-review
Status: ready-for-agent
Blocked by: UI-036
Review: agent
Difficulty: normal

- Primary files:
  - ui/board_view.gd (`_input` ~line 256, `_gui_input` right-click branch ~line 263, left press with `_selected` ~line 295, `_drop` ~line 350)
  - tests/test_premove.gd, and the board input tests (grep `click_click`)

#### What to build

Bruno's QA of v0.0.2 (2026-11-01), items 5–7. With a piece selected by click-click (first click picked it, no drag), the second click must behave as on Chess.com:

1. **Right click cancels the selection and draws nothing** (item 5). Today `interrupts` (line ~267) counts `_selected` only while premoving, so on your own turn the right click starts an arrow and the piece stays selected. Any selection, premove or not, is cleared and the right click draws no arrow or circle.
2. **A left click outside the board cancels the selection** (item 6). `_gui_input` never sees clicks outside the board control, so today the piece stays selected after clicking the panel or the margin. Use the existing `_input` override: a left press outside `get_global_rect()` while `_selected` clears it. The click still reaches the button it landed on.
3. **A left click on another of your pieces selects that piece** (item 7), instead of cancelling as `_drop(clicked=true)` → `_end_snap_back()` does today: when no held move goes to the clicked square and the input position has one of your pieces there, pick that piece up (targets shown, ready for its own second click or drag). Bruno's exception, a premove that captures your own piece (UI-010), needs no special case: in premove input `_held_moves` already includes geometric own-piece targets, so such a click finds a move and queues it. Only own pieces the held piece's geometry does not reach are reselected while premoving.

#### Acceptance criteria

1. Own turn: select a piece by click, right-click anywhere on the board; the selection is gone and no drawing appears. Same while premoving.
2. Select a piece by click, click the side panel; the selection is gone and the panel button still works.
3. Own turn: select the knight, click the bishop; the bishop is selected with its targets shown, and a click on a bishop target plays it.
4. While Maia thinks: select the knight on f3, click your pawn on e5; a Nf3xe5 premove is queued (UI-010 unchanged). Select the rook, click a piece of yours its geometry does not reach; that piece is selected.
5. Right-drag drawing with no selection works as before. Gate green.

#### Verification

    Manual: a 3+2 game with click-click; try the three second clicks on your turn and while Maia thinks.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- Right click with a non-premove selection clears `_selected` and adds no drawing (red: an arrow starts).
- A left press outside the board clears `_selected` (red: it stays).
- Second click on another own piece selects it (red: selection cleared); the own-piece premove recapture still queues.

## Comments

- 2026-11-01 Written from Bruno's QA of v0.0.2 (items 5, 6, 7). Item 6 arrived cut off; Bruno confirmed it is the click outside the board.
- Blocked by UI-036: both edit `board_view.gd`.
- Red/green: right-click selection 17 passed, 1 failed -> 18 passed; outside routed click 18 passed, 1 failed -> 19 passed; reselection and recapture 44 passed, 2 failed -> 46 passed. Logs: `C:\Users\bruno\AppData\Local\Temp\p-chess-ui037-*-red.log` and `C:\Users\bruno\AppData\Local\Temp\p-chess-ui037-*-green.log`.
- Updated `test_left_press_clears_all_drawings_and_cancels_an_unfinished_one`: its old selection-preservation assertion contradicted criterion 1; the updated assertion fails against the original production code. The outside-click fixture was corrected to use a sized SubViewport because the headless root is 64x64.
- Gate: 494 passed, 0 failed, exit 0. Graphical last-move pixels and live Lc0 tests skipped in the headless environment without Lc0.

Acceptance: pending | Manual 3+2 click-click game on the player's turn and while Maia thinks, as specified in Verification.
Disclosure: pending | integration | UI-037 Verification requires the manual 3+2 game before acceptance.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\p-chess-ui037-gate.json
