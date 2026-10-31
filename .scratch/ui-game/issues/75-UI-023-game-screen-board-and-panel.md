# UI-023: Game screen: board and side panel to the design
Stage: to-review
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

- Stage 2 gate initially found the old half-only label assertion in `test_draw_offer_accepted_on_reply_without_playing_it`; updated it to the new labelled button while retaining the draw behavior assertions.

- Stage 2 verification: gate on commit 6948bd6 printed 418 passed, 0 failed; seven are skips (six require Lc0 and one requires graphical rendering), so 411 executed in the headless run. The last-move pixel test separately passed with a graphical display. The unrelated Main screenshot was byte-identical before and after the fixture change. The four final 1280x800 and 800x600 captures and declined state are under `C:/Users/bruno/AppData/Local/Temp/pchess-ui023-work/`.
- Acceptance: pending | Manual play, drag/premove, draw offer, Esc, finish, grip, F11 and Ctrl+, remain for human verification.
- Disclosure: pending | release | UI-023 manual play and visual acceptance remain pending; screenshot fixtures do not exercise physical input or Lc0.
Previous gate receipt: C:\Users\bruno\AppData\Local\Temp\pchess-ui023-gate-final.json

#### Resolution (2026-10-31)
Verdict: Reopen — criterion 6: preserve manual move-list scrolling and clear the saved draw notice between games.

- Reviewed the complete 16-file diff `06cd54a6271fe3bcf12cc5e888d4633d8eed8ada...4a07735e7ddfec563bb2d066c2ba01f0a3e95c66` and all 13 ticket commits. Standards and Spec were independently reviewed in parallel. Standards: no documented violations or blocking smells; all commits separate tests from production. The two additional test files only update assertions of replaced behavior, as stage 2 permits.
- Callers and interactions examined: both `GameOver.present` call sites, game-over Close/Review/Rematch/New game, all users of the removed controls/material helper, the game-only move list, shared boards in review/editor/history, clock start/stop, player colour/flip/rematch score, Settings shortcut and modal guards, F11 and notice lifetime, board-fit/resize, and the four screenshot fixtures. Failure paths examined include ending/restarting while in focus and adding a move while reading older moves. Physical input, sound, actual Lc0 play and clean-machine acceptance were not exercised in this review.

**Standards:** 0 blocking findings. Existing red/green logs were inspected for controls (3 failures to 0), board colours (1 to 0), confirmation (5 to 0), focus after flip (2 to 0) and the draw-label mutant (1 to 0). Logs are `C:/Users/bruno/AppData/Local/Temp/ui023-{red,green,board-red,board-green,resign-red,resign-green,flip-red,flip-green,draw-mutant,draw-green}.log`.

**Spec:** 2 P2 regressions, both owned by this reopened ticket:

1. **P2 — `ui/move_list.gd:22`: new moves discard the user's reading position.** In a long game, scroll to the first moves, then add the next move. `_render()` calls `clear()` and rebuilds the table, resetting the manual pause in `scroll_following`; the list jumps to the latest move. With 100 plies at 800x600, the same production-widget probe kept scroll `0` on the base but jumped from `0` to `1513` on the reviewed HEAD (`max=1785`, `page=272`). Preserve the scroll/follow state through the rebuild. Stage 2 should add a regression test for adding a move while scrolled up and retain following when already at the bottom.
2. **P2 — `ui/main.gd:543`: an old draw notice returns indefinitely in the next game.** Show "Maia declined", enter F11 focus, finish the game and start a rematch before the notice expires, then leave focus. `_start()` hides the notice and stops its timer (`:376-377`) without clearing `_notice_before_focus`; `_set_focus(false)` restores the previous game's notice with no timer left to hide it. The base probe reports `notice_visible=false`; HEAD reports `notice_visible=true`, `timer_stopped=true` in the new game. Reset the saved notice state with the per-game notice reset and cover focus/rematch/unfocus in `tests/test_session.gd`.

Numbered criteria: **1 ✅** board colours/coordinates and grip implemented; **2 ✅** panel/player/action structure and running-clock styling implemented; **3 ✅** red confirmation/bar and notices implemented, with the cross-game notice regression above still open; **4 ✅** removed controls/material code and spec changes agree; **5 ✅** focus hides details and remains so after flip; **6 ❌** shared acceptance 3 forbids the two behavioral regressions above. Visual acceptance remains conditional on the already recorded differences and CLEAN-012, rather than being claimed complete.

The graphical before/after probe is `C:/Users/bruno/AppData/Local/Temp/pchess-ui023-stage3/probe.gd`; results are in `before-probe/probe.log` and `after-probe/probe.log` under that directory. The after image `after-probe/rematch-notice-800.png` shows the stale notice in a fresh black-side rematch. The 800x600 confirmation hypothesis was disproved: the board occupies x=10..450 and the panel x=490..790; the full red button remains visible without clipping. Its image is `after-probe/confirm-800.png`.

Stage-3 1280x800 captures from the exact base and reviewed HEAD, beside their references:

| Board | Reference | Before | After |
|---|---|---|---|
| Game | [reference](../../../docs/design/v0.1.0/png/Game.png) | [before](C:/Users/bruno/AppData/Local/Temp/pchess-ui023-stage3/Game-before.png) | [after](C:/Users/bruno/AppData/Local/Temp/pchess-ui023-stage3/Game-after.png) |
| GameSidePanel | [reference](../../../docs/design/v0.1.0/png/GameSidePanel.png) | [before](C:/Users/bruno/AppData/Local/Temp/pchess-ui023-stage3/GameSidePanel-before.png) | [after](C:/Users/bruno/AppData/Local/Temp/pchess-ui023-stage3/GameSidePanel-after.png) |
| GamePanelStates | [reference](../../../docs/design/v0.1.0/png/GamePanelStates.png) | [before](C:/Users/bruno/AppData/Local/Temp/pchess-ui023-stage3/GamePanelStates-before.png) | [after](C:/Users/bruno/AppData/Local/Temp/pchess-ui023-stage3/GamePanelStates-after.png) |
| Board | [reference](../../../docs/design/v0.1.0/png/Board.png) | [before](C:/Users/bruno/AppData/Local/Temp/pchess-ui023-stage3/Board-before.png) | [after](C:/Users/bruno/AppData/Local/Temp/pchess-ui023-stage3/Board-after.png) |

The component fixtures capture the whole game screen; compare their board/panel regions with the component references. Stage 2's four `*-800.png` and `declined.png` in `C:/Users/bruno/AppData/Local/Temp/pchess-ui023-work/` were also visually inspected. Sample positions/names/times/scores differ intentionally. The previously listed panel inset and shared font-weight differences remain visible; the screenshot evidence does not replace manual acceptance.

Both existing proxy decisions were examined and remain within their approved scope: `Proxy decided (opus-5.5 xhigh): Yes. Add ui/game_over.gd and scripts/screens.gd to Primary files` (receipt `C:/Users/bruno/AppData/Local/Temp/sweatshop-proxy/20261031-181943-UI-023-022105.json`) and `Proxy decided (opus-5.5 xhigh): Yes, widen the scripts/screens.gd scope for the four UI-023 boards` (receipt `C:/Users/bruno/AppData/Local/Temp/sweatshop-proxy/20261031-182516-UI-023-7773a8.json`). These identify the existing records above, not new proxy decisions.

The existing gate receipt was validated against HEAD, including the log hash, exit status and identical non-tracker tree: tested `6948bd69f4d83b62b53605fdbfc743d271639158`, 418 printed passed, 0 failed, exit 0; 411 executed and 7 skips (6 Lc0, 1 graphical pixel test). No code changed in this review, so the gate was not rerun. No merge or ledger entry: stage 2 resumes the two findings on this branch.

Acceptance: pending | Both P2 fixes, final visual acceptance and the existing manual play/input checks remain open.
Disclosure: pending | integration | The two P2 regressions above must be fixed before integrating UI-023.
Disclosure: pending | integration | [CLEAN-012](../../ui-base/issues/74-CLEAN-012-font-variation-axes.md) already requires corrected shared font weights before visual acceptance/integration of the screen redesigns; this existing condition remains in force.
Disclosure: pending | release | The existing manual drag/premove, draw, Esc, finish, grip, F11, Ctrl+, and actual Lc0 acceptance remain pending.
Disclosure: decision | none | The two existing proxy receipts above authorize only the GameOver wiring and four game-screen fixtures; no further contract change was made in review.


### Stage 2: review regressions (2026-10-31)

- Preserved an existing scroll position through move-list reconstruction and retained automatic following when the list is already at the bottom. Reset the saved focus-mode draw notice when a new game starts.
- The two regression tests failed against the reviewed production code, then passed after the fixes. The scroll test checks a nonzero position and a new row; disabling following made the latter assertion fail. Logs: `C:/Users/bruno/AppData/Local/Temp/ui023-reopen-{red,interior-red,follow-mutant,follow}.log`.
- Gate on `411ab35f17bf807e2a95a399d5feb6fd57c90704`: 420 reported passed, 0 failed, exit 0; 413 executed and 7 skipped (6 require Lc0 and 1 requires a graphical display). Log: `C:/Users/bruno/AppData/Local/Temp/ui023-reopen-gate.log`.

Acceptance: pending | Human visual comparison and manual play, drag/premove, draw, Esc, finish, grip, F11, Ctrl+, and Lc0 remain pending.
Disclosure: pending | integration | [CLEAN-012](../../ui-base/issues/74-CLEAN-012-font-variation-axes.md) must be resolved before visual acceptance and integration. The two review regressions are corrected and await stage-3 review.
Disclosure: pending | release | Complete the recorded manual play/input and Lc0 acceptance.
Gate evidence: C:/Users/bruno/AppData/Local/Temp/ui023-reopen-gate.json
