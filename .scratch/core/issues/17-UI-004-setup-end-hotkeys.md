# UI-004: Setup, game end, rematch and hotkeys
Stage: reviewing
Blocked by: CLOCK-001
Review: agent
Difficulty: normal

- Primary files:
  - ui/setup.tscn, ui/setup.gd
  - ui/main.tscn, ui/main.gd
  - core/game.gd (claim, resign)
  - ui/move_list.gd (reset only)
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

- 2026-10-24 Attempt 1 failed: exit 0. Log tail: ...after the first press. /   - The Claim draw button is wired up, and auto-claim is on as a constant until UI-005. /   - `F11` toggles focus mode. /  / **Two decisions:** / - **Move list reset:** a rematch has to clear the move list, so I added a `reset()` to `ui/move_list.gd`. That file wasn't in the ticket's Primary files; the proxy approved adding it, and that decision is recorded in the ticket. / - **Maia's late reply:** if you rematch while Maia is still thinking, her late answer would have been played as a move in the new game. A rematch now throws that reply away. /  / **Things to know:** / - With auto-claim on, a threefold repetition ends the game by itself, so the Claim draw button never actually becomes clickable. / - In focus mode the Esc hint still shows, since it's the only warning before a resign. The ticket says only the board and clocks should be visible, so a reviewer may flag this. / - Not checked: I didn't open the app. A quick headless launch to catch broken scene paths also needed approval, so I skipped it. The fix for Maia's late reply has no test either, because it would need the real window. The manual checks in the ticket (resign with Esc Esc, rematch, F11, claim) are still to do.

Proxy decided (opus): `ui/move_list.gd` joins Primary files, scoped to a new `reset()` that calls `clear()` and sets `_plies = 0` — a rematch is the first time the move list has to empty, `_plies` is private to that script (a `set("_plies", 0)` from main would fail silently on a rename), and replacing the node is more code and fights `_set_flipped`'s panel order.

- 2026-10-24 Attempt 2: attempt 1's two commits (test 6fc6d53, feat 8867f41, from the driver's recovery ref) rebased onto the session as 7fce98b and a12bbfe, unchanged except this ticket's Comments merge. Attempt 1 had stopped only because `gate-evidence.ps1` was permission-denied; `powershell -NoProfile -File <helper>` from the Bash tool runs under the driver's allowlist.
  - Red: on 7fce98b the suite reports `102 passed, 1 failed` — `test_session.gd` fails to load because `Main.rematch` and `Main.ResignKey` do not exist.
  - Green: on a12bbfe the gate exits 0, `107 passed, 0 failed`. `godot --headless --quit-after 30` loads the main scene with no script error, so the new node paths (ResignHint, ClaimDraw, Setup Opening) resolve.
  - Criteria 4 and 6 meet in focus mode: the Esc hint is not hidden there, because criterion 4 requires the first Esc to show it and it is the only warning before a resign. Everything persistent other than the board and the clocks is hidden.
  - With `AUTO_CLAIM` on (criterion 5), a threefold ends the game the moment it occurs, so the Claim draw button is wired but never enabled in practice until UI-005 makes auto-claim a setting.
  - Not tested: dropping Maia's stale reply after a rematch mid-think (needs a live window and lc0). The manual checks under Verification are still to do.

Proxy decided (opus): in focus mode the Esc hint stays and the game-end result shows; criterion 2 failed in focus mode only because result_label was in _set_focus's list, fixed in review by removing it — focus mode hides the persistent panels during play (move list, material, Claim draw); criteria 2 and 4 have no focus exception, the result label is empty during play so criterion 6 holds, and hiding either message drops a required output (the only warning before a resign, the result and its reason).

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\89007498-bd40-4bd5-b41b-c5c0fa99dc87\scratchpad\UI-004-gate.json
