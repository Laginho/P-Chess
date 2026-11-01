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
Gate evidence: C:\Users\bruno\AppData\Local\Temp\p-chess-ui037-corner-gate.json

#### Resolution (2026-11-01)

Verdict: Reopen — criterion 1 fails on the board's resize corner.

- Reviewed all four files in `git diff a4f1c455...039d039c`: this ticket, `tests/test_input_modes.gd`, `tests/test_premove.gd`, and `ui/board_view.gd`. OCR excluded all four as `unsupported_ext`; all were reviewed directly. Standards and Spec ran independently through the two code-review agents. No production or test changes authored during review.
- Standards: no actionable documented-standard violations or heuristic findings. Every stage-2 commit was checked: tests and production are separated, including the test-only fixture correction and replaced drawing assertion. Stage-2 red/green counts above remain supplied evidence, not a repeated mutation run.
- Spec: **P3, `ui/board_view.gd:288` — canceling only in `_gui_input` misses the `ResizeGrip`.** Select `b1`, then right-click at `board.global_position + board._corner() + Vector2.ONE * (board._side() - 2)`. This point is inside the board and inside the grip's last 4×4 internal pixels. The child control consumes GUI dispatch, so the changed cancellation branch is never reached and `_selected` remains `b1`. This violates criterion 1's "right-click anywhere on the board". Suggested fix within the existing `_input` seam: intercept and cancel this selection gesture before GUI dispatch, consume the canceling press so it cannot start a drawing, and add a regression using routed `Viewport.push_input` over the real resize control. The independent Spec reviewer confirmed the finding and P3 severity after reading the probe evidence.
- Criterion 1: ❌ normal board clicks pass both on the player's turn and while Maia thinks; the resize-corner click leaves the selection active. Criteria 2–5: ✅ implementation and focused tests pass. Side-panel clicks clear selection and trigger the real button; friendly-piece reselection supports targets, a move and a drag; geometric `f3e5` own-piece recapture remains queued; ordinary right-drag drawing works.
- Examined `_input`/`_gui_input`/`_drop`/`_pick_up`, `_end_snap_back`/`_cancel_interaction`, promotion and Alt, premove target geometry and projected positions, queue cancellation/replacement, held pieces across Maia replies, flags/game over/rematch, board orientations, Main input/clock/side-panel actions, and the child resize control. Reviewed surrounding tests for retained behavior.
- Independent focused runs: `test_input_modes.gd` **20 passed, 0 failed**; `test_premove.gd` **26 passed, 0 failed**, both exit 0. Logs: [input modes](C:/Users/bruno/AppData/Local/Temp/p-chess-ui037-stage3-input.log), [premove](C:/Users/bruno/AppData/Local/Temp/p-chess-ui037-stage3-premove.log). Temporary one-file test directories removed.
- Graphical/live verification: real Main at 1000×800 with OpenGL, installed Lc0/Maia 1500, actual 3+2 clock, click-click enabled, and isolated external user data. All pointer events went through `Viewport.push_input`; no injected replies or altered think time. The live game played `e2e4 c7c5 g1f3`, naturally consuming the queued knight after Maia replied (Lc0 policy latency 91.788 ms). Own-turn and thinking-time cancellation, panel buttons, and reselection passed. A separate routed matrix passed own-piece recapture, reselection, cancellation and drawing for both premove styles and both orientations.
- Evidence: [graphical/live harness](C:/Users/bruno/AppData/Local/Temp/p-chess-ui037-review/review.gd), [log](C:/Users/bruno/AppData/Local/Temp/p-chess-ui037-review/review.log), [corner failure capture](C:/Users/bruno/AppData/Local/Temp/p-chess-ui037-review/resize-corner-after-right-click.png), [live premove capture](C:/Users/bruno/AppData/Local/Temp/p-chess-ui037-review/maia-thinking-queued.png). The graphical run reports **1 review failure**, exit 1, specifically the corner cancellation above. Captures inspected by the reviewer; temporary engine junctions removed.
- Gate: receipt command, commit, log SHA256, exit marker and production equality validated with `Assert-GateEvidence`: **494 passed, 0 failed**, tested commit `97d65b26fea01672269d2f6bde1a5af1cca8eccc`. Reused without another full gate run because code is unchanged. Headless gate skips graphical last-move pixels and six live-engine cases; the separate ticket probes above do not replace those whole-suite cases.
- Limits: automated live pointer verification and reviewer capture inspection are not human hands-on play. Whole-suite graphical execution, other sizes/themes, unrelated live-engine cases and release acceptance were not assessed. The pending acceptance/disclosure above remains open; fix and reverify criterion 1 before integration. No merge, ledger entry, push or PR.

- The stage-3 corner failure above was the reason for reopening; its fix is pending review.

#### Reopen handoff (2026-11-01)

- A routed regression using the real resize-grip control reproduced the failure on the player's turn and during premove: **20 passed, 1 failed** before the fix, **21 passed, 0 failed** after. Logs: `C:\Users\bruno\AppData\Local\Temp\p-chess-ui037-corner-red.log` and `C:\Users\bruno\AppData\Local\Temp\p-chess-ui037-corner-green.log`.
- The board now consumes a right press over a selection before a child control can receive it, preserving premove cancellation and ordinary drawing without a selection. Gate on commit `0aaf54614c03d358455cc05ddb3c302d5ed619ec`: **495 passed, 0 failed**, exit 0; graphical pixels and six live-Lc0 tests skipped in this headless run.
- The manual 3+2 acceptance and its integration disclosure above remain pending.
