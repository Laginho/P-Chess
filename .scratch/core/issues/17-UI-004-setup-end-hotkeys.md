# UI-004: Setup, game end, rematch and hotkeys
Stage: done
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

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\8af4bc7b-c9e7-43b9-8742-e8033e03765a\scratchpad\UI-004-review-gate.json

#### Resolution (2026-10-24)

Verdict: Approve

Stage 3 (opus-5.5). The Standards and Spec axes ran as separate sub-agents. Standards: no violation; one judgement call, `FakeTime` is duplicated in `tests/test_session.gd` and `tests/test_clock.gd` (4 lines, and the shared home `tests/run.gd` is outside Primary files). Not scheduled. Spec: one finding, criterion 2 in focus mode (below), fixed in review; no scope creep. I read the whole diff and the code around it.

Examined: every caller of `_show_result` (game-ending move, flag, Esc resign, Claim draw) runs it exactly once per game, and `Clock.stop` is idempotent, so the flag path's second stop is harmless. `setup.started` has one listener (`main._start`). `maia.move_ready` has one listener (`_on_maia_move`). The `_replies_owed` / `_stale_replies` counters hold because `UCI.request_policy` queues FIFO and emits exactly one `policy_ready` per request, so the old game's reply always arrives before the new game's. `BoardView.play` and `Game.play` refuse moves once the game is over. `Game.resign` and `Game.claim_draw` are guarded. `auto_claim` is set after `Game.new()`, which is harmless because the start position cannot repeat. Not examined: the app in a window, and a live Lc0 stale reply.

Criteria:

1. ✅ `ui/setup.gd` adds colour, level, control and an Opening option (Free, Catalog, My repertoire) with every item except Free disabled; Free is index 0, so it is the default. Random is drawn before `started` emits.
2. ✅ after the review fix. `_show_result` writes "<White wins|Black wins|Draw> by <reason> (<result>)" plus "Space for a rematch", with `reason` taken from `core/game.gd`, which covers all seven. Before the fix, F11 hid `result_label`, so a game that ended in focus mode showed no result. Fixed in c4bd40f (below).
3. ✅ `Space` rematches only when a clock exists and the game is over, so it does nothing on the setup screen or during play. `rematch()` swaps `settings.colour`, which holds the colour actually played (`test_rematch_swaps_colours_and_keeps_the_rest`, `test_rematch_of_a_rematch_is_the_first_game_and_leaves_the_input_alone`).
4. ✅ `ResignKey`: a first press arms the key and `_process` shows the hint while it is armed. A second press within 2000 ms resigns and disarms; after the window the next press starts over (tests at 1.9 s and 2.1 s on a fake clock). Esc works only while a game is on. Edge, not a criterion: if the game ends some other way within 2 s of a first Esc, the hint stays for the rest of those 2 s while Esc does nothing.
5. ✅ `claim_draw.disabled = not game.can_claim_draw()` after every move, disabled again at game end, and `AUTO_CLAIM` is a commented shortcut constant. Maia's path never calls `claim_draw`. With auto-claim on, a threefold ends the game at once, so the button cannot be enabled until UI-005 adds the setting (disclosed below).
6. ✅ F11 hides the move list, material and Claim draw. During play `result_label` is empty (`_start` clears it and `_show_result` is its only writer), so only the board and the clocks show. The transient Esc hint and the game-end result stay visible (Proxy decided, Comments).
7. ✅ no abort control in `ui/` (grep for "abort" finds nothing).
8. ✅ `tests/test_session.gd` calls production `Main.rematch` and `Main.ResignKey` with an injected time source. No window and no waiting.

Rules: test-only 7fce98b (with ticket metadata) comes before production-only a12bbfe; 95f7fdf touches only the ticket. Review fix c4bd40f: `ui/main.gd` plus ticket metadata. Only Primary files changed (`core/game.gd` needed none; `ui/move_list.gd`'s `reset()` was added by Proxy decided). No rebase was needed: the branch sat on the session tip 427da7a. Merged as 39fa0fd.

Review fix c4bd40f: author stage 3 (opus-5.5). Independent reviewer: a separate Haiku sub-agent, which examined `git show c4bd40f -- ui/main.gd` against criteria 2 and 6 and `ui/main.tscn`'s side-panel children. Its verdict was Approve: `result_label` is empty during play, including on a rematch, and nothing else reads it.

Red-green: stage 2's red 7fce98b gave `102 passed, 1 failed` (`test_session.gd` failed to load because `Main.rematch` and `Main.ResignKey` were missing). Green a12bbfe gave `107 passed, 0 failed`. Mutation check in review, run in a throwaway worktree: `rematch()` without the swap, `armed()` without the window, and `press()` without the disarm together gave `104 passed, 3 failed`, one failing test per mutant. One mutant cannot be separated: `<=` against `<` at exactly 2000 ms. The criterion's "within 2 s" does not fix the boundary, so this mutant is equivalent. The fix itself has no test: criterion 8 does not cover focus mode, and F11 is on the manual Verification list.

Gate: rerun after the fix, on c4bd40f: exit 0, `107 passed, 0 failed` (receipt in the `Gate evidence:` line above). The merge 39fa0fd has the same tree as c4bd40f.

Not findings (no criterion, no regression): `maia.latencies_ms` now accumulates across rematches, so the console's median covers the whole app session, and a dropped stale reply adds one sample timed from the newer `think()`. This is a diagnostic print only.

`Proxy decided` lines: two, both (opus), under Comments. The first adds `ui/move_list.gd`'s `reset()` to Primary files. The second keeps the Esc hint and shows the result in focus mode.

Acceptance: pending | the manual checks in Verification (Esc Esc resign, Space rematch swapping colours, F11 focus mode, claiming a threefold) have not been run by a person. So far: gate 107/107 on c4bd40f, and stage 2's headless `--quit-after 30` launch of the main scene loaded with no script error (Comments).
Disclosure: decision | none | Proxy decided (opus), see ## Comments: `ui/move_list.gd` joins Primary files for a `reset()` that the rematch calls.
Disclosure: decision | none | Proxy decided (opus), see ## Comments: in focus mode the Esc hint stays visible and the game-end result shows. Fixed in review as c4bd40f, which removes `result_label` from `_set_focus`'s list; independently reviewed (above).
Disclosure: pending | release | with `AUTO_CLAIM` on, the Claim draw button can never be enabled, so "claim a threefold" cannot be checked until UI-005 (`.scratch/core/issues/18-UI-005-settings.md`, criterion 2: auto-claim threefold setting) lets auto-claim be turned off.
Foreman acceptance check (integrated session 09f8153, after UI-005 merged): auto-claim is now the `auto_claim` setting (default on, `core/settings.gd:22`), applied in `ui/main.gd:154` and `:193`, so "claim a threefold" is now checkable by hand: turn auto-claim off in Settings, repeat a position three times, click Claim draw. Not run by a person; the pending above stays until then.
Disclosure: pending | release | dropping Maia's stale reply after a rematch mid-think has no test (it needs a window and Lc0); check it by hand by rematching while Maia thinks.
Disclosure: pending | release | the manual checks in Verification have not been run by a person (Acceptance above).
