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
  - ui/board_view.gd (scope: the `game` setter clears the held piece, its targets, the pending promotion, the open picker and the slide and snap-back tweens)
  - New: tests/test_session.gd
  - bot/maia_player.gd (request-local state, generation invalidation, stale guards before policy processing and after the wait, injectable wait completion)
  - tests/run.gd (defer test execution until the root enters the tree)
  - tests/test_runner.gd (runner lifecycle and existing failure reporting)

#### What to build

The full game loop of §9.1 and §9.2: the complete setup screen, a clear game-end display, `Space` for a rematch with colours swapped, `Esc` twice to resign, a Claim draw button and `F11` focus mode.

#### Acceptance criteria

1. The setup screen picks colour (white / black / random), time control, Maia level and opening mode. Only Free is enabled until the opening tickets land.
2. At game end the result and its reason are shown (checkmate, stalemate, time, resignation, 50-move, repetition, insufficient material).
3. `Space` after the game starts a rematch with the same settings and the colours swapped (from the colours actually played, also after random). During a game `Space` does nothing. A rematch invalidates all previous-game Maia requests: old policies are discarded before sampling or scheduling a delay, and already waiting replies are discarded before emitting a move. The current reply plays exactly once regardless of completion order, including after two rematches when an old move becomes legal again.
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
- Reopen integration seam: real `ui/main.tscn` in the headless tree, a fake UCI bridge and manually completed timer signals. Drive Esc/Space through Main and assert the current game's moves for an old policy arriving after rematch, reversed wait completion and two rematches with a legal stale move. Red because Main matches replies by arrival order and Maia shares request state across games.
- `tests/test_runner.gd`: tests can add a node to the active tree and receive `_ready`; existing subprocess cases still prove assertion, script-load and runtime failures exit nonzero. Red because tests currently run inside `_initialize`.

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

> Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\8af4bc7b-c9e7-43b9-8742-e8033e03765a\scratchpad\UI-004-review-gate.json
>
> #### Resolution (2026-10-24)
>
> Verdict: Approve
>
> Stage 3 (opus-5.5). The Standards and Spec axes ran as separate sub-agents. Standards: no violation; one judgement call, `FakeTime` is duplicated in `tests/test_session.gd` and `tests/test_clock.gd` (4 lines, and the shared home `tests/run.gd` is outside Primary files). Not scheduled. Spec: one finding, criterion 2 in focus mode (below), fixed in review; no scope creep. I read the whole diff and the code around it.
>
> Examined: every caller of `_show_result` (game-ending move, flag, Esc resign, Claim draw) runs it exactly once per game, and `Clock.stop` is idempotent, so the flag path's second stop is harmless. `setup.started` has one listener (`main._start`). `maia.move_ready` has one listener (`_on_maia_move`). The `_replies_owed` / `_stale_replies` counters hold because `UCI.request_policy` queues FIFO and emits exactly one `policy_ready` per request, so the old game's reply always arrives before the new game's. `BoardView.play` and `Game.play` refuse moves once the game is over. `Game.resign` and `Game.claim_draw` are guarded. `auto_claim` is set after `Game.new()`, which is harmless because the start position cannot repeat. Not examined: the app in a window, and a live Lc0 stale reply.
>
> Criteria:
>
> 1. ✅ `ui/setup.gd` adds colour, level, control and an Opening option (Free, Catalog, My repertoire) with every item except Free disabled; Free is index 0, so it is the default. Random is drawn before `started` emits.
> 2. ✅ after the review fix. `_show_result` writes "<White wins|Black wins|Draw> by <reason> (<result>)" plus "Space for a rematch", with `reason` taken from `core/game.gd`, which covers all seven. Before the fix, F11 hid `result_label`, so a game that ended in focus mode showed no result. Fixed in c4bd40f (below).
> 3. ✅ `Space` rematches only when a clock exists and the game is over, so it does nothing on the setup screen or during play. `rematch()` swaps `settings.colour`, which holds the colour actually played (`test_rematch_swaps_colours_and_keeps_the_rest`, `test_rematch_of_a_rematch_is_the_first_game_and_leaves_the_input_alone`).
> 4. ✅ `ResignKey`: a first press arms the key and `_process` shows the hint while it is armed. A second press within 2000 ms resigns and disarms; after the window the next press starts over (tests at 1.9 s and 2.1 s on a fake clock). Esc works only while a game is on. Edge, not a criterion: if the game ends some other way within 2 s of a first Esc, the hint stays for the rest of those 2 s while Esc does nothing.
> 5. ✅ `claim_draw.disabled = not game.can_claim_draw()` after every move, disabled again at game end, and `AUTO_CLAIM` is a commented shortcut constant. Maia's path never calls `claim_draw`. With auto-claim on, a threefold ends the game at once, so the button cannot be enabled until UI-005 adds the setting (disclosed below).
> 6. ✅ F11 hides the move list, material and Claim draw. During play `result_label` is empty (`_start` clears it and `_show_result` is its only writer), so only the board and the clocks show. The transient Esc hint and the game-end result stay visible (Proxy decided, Comments).
> 7. ✅ no abort control in `ui/` (grep for "abort" finds nothing).
> 8. ✅ `tests/test_session.gd` calls production `Main.rematch` and `Main.ResignKey` with an injected time source. No window and no waiting.
>
> Rules: test-only 7fce98b (with ticket metadata) comes before production-only a12bbfe; 95f7fdf touches only the ticket. Review fix c4bd40f: `ui/main.gd` plus ticket metadata. Only Primary files changed (`core/game.gd` needed none; `ui/move_list.gd`'s `reset()` was added by Proxy decided). No rebase was needed: the branch sat on the session tip 427da7a. Merged as 39fa0fd.
>
> Review fix c4bd40f: author stage 3 (opus-5.5). Independent reviewer: a separate Haiku sub-agent, which examined `git show c4bd40f -- ui/main.gd` against criteria 2 and 6 and `ui/main.tscn`'s side-panel children. Its verdict was Approve: `result_label` is empty during play, including on a rematch, and nothing else reads it.
>
> Red-green: stage 2's red 7fce98b gave `102 passed, 1 failed` (`test_session.gd` failed to load because `Main.rematch` and `Main.ResignKey` were missing). Green a12bbfe gave `107 passed, 0 failed`. Mutation check in review, run in a throwaway worktree: `rematch()` without the swap, `armed()` without the window, and `press()` without the disarm together gave `104 passed, 3 failed`, one failing test per mutant. One mutant cannot be separated: `<=` against `<` at exactly 2000 ms. The criterion's "within 2 s" does not fix the boundary, so this mutant is equivalent. The fix itself has no test: criterion 8 does not cover focus mode, and F11 is on the manual Verification list.
>
> Gate: rerun after the fix, on c4bd40f: exit 0, `107 passed, 0 failed` (receipt in the `Gate evidence:` line above). The merge 39fa0fd has the same tree as c4bd40f.
>
> Not findings (no criterion, no regression): `maia.latencies_ms` now accumulates across rematches, so the console's median covers the whole app session, and a dropped stale reply adds one sample timed from the newer `think()`. This is a diagnostic print only.
>
> `Proxy decided` lines: two, both (opus), under Comments. The first adds `ui/move_list.gd`'s `reset()` to Primary files. The second keeps the Esc hint and shows the result in focus mode.
>
> Acceptance: pending | the manual checks in Verification (Esc Esc resign, Space rematch swapping colours, F11 focus mode, claiming a threefold) have not been run by a person. So far: gate 107/107 on c4bd40f, and stage 2's headless `--quit-after 30` launch of the main scene loaded with no script error (Comments).
> Disclosure: decision | none | Proxy decided (opus), see ## Comments: `ui/move_list.gd` joins Primary files for a `reset()` that the rematch calls.
> Disclosure: decision | none | Proxy decided (opus), see ## Comments: in focus mode the Esc hint stays visible and the game-end result shows. Fixed in review as c4bd40f, which removes `result_label` from `_set_focus`'s list; independently reviewed (above).
> Disclosure: pending | release | with `AUTO_CLAIM` on, the Claim draw button can never be enabled, so "claim a threefold" cannot be checked until UI-005 (`.scratch/core/issues/18-UI-005-settings.md`, criterion 2: auto-claim threefold setting) lets auto-claim be turned off.
> Foreman acceptance check (integrated session 09f8153, after UI-005 merged): auto-claim is now the `auto_claim` setting (default on, `core/settings.gd:22`), applied in `ui/main.gd:154` and `:193`, so "claim a threefold" is now checkable by hand: turn auto-claim off in Settings, repeat a position three times, click Claim draw. Not run by a person; the pending above stays until then.
> Disclosure: pending | release | dropping Maia's stale reply after a rematch mid-think has no test (it needs a window and Lc0); check it by hand by rematching while Maia thinks.
> Disclosure: pending | release | the manual checks in Verification have not been run by a person (Acceptance above).

#### Reopen (2026-10-24, session PR #8 review)

Reviewer: independent review of session PR #8 by gpt-6.1-sol xhigh (verdict "do not merge"), relayed by the supervisor foreman. Its gate run was green, 113/0/0; the finding is a regression the suite does not cover.

3. ❌ regression: `rematch` (`ui/main.gd:153`) swaps in the new game without clearing BoardView's interaction state from the old one. Repro A: lose on time with the promotion picker open, press Space: the old picker stays over the new game. Repro B: rematch while holding the e5 pawn: the stale target `e5e6` survives, and a legal `e7e6` in the new game is rejected.

What is left: before the game is swapped, clear the drag, held/queued moves, the pending promotion, the picker and any running tweens; add rematch lifecycle tests that drive the real `Main`/`BoardView` path through both repros (today's rematch tests only exercise the settings-dictionary helper). The fix likely needs a reset on `ui/board_view.gd`, which is not in Primary files: ask the proxy before touching it. Every other criterion verdict above stands.

Note for stage 2: the block quoted above is the previous review's record, kept for history; the live fields are the ones below it. Write the new receipt as `Gate evidence: <path>` at the very start of its own line, with no list dash and nothing after the path: the installed driver misses a `- Gate evidence:` line (fix pending in Agent-Skills#4).

Verdict: Reopen — criterion 3: a rematch keeps the old game's BoardView interaction state (promotion picker, held move)

Proxy decided (opus): `ui/board_view.gd` joins Primary files, limited to the `game` setter clearing the held piece, its targets, the pending promotion, the open picker (via its existing `_close("")`, guarded against a null `_picker` for boards built outside a scene) and the slide and snap-back tweens — all of it is private to BoardView, a reset in the setter makes every new game start clean with no extra call for `main._start` to remember, and replacing the node would lose the flip, theme and signal wiring.

- 2026-10-24 Stage 2 after the reopen (opus-5.5):
  - Red: d7aad4d (test-only, plus ticket metadata and a note under UI-007) gives `113 passed, 2 failed`. With the picker open at a flag, a new game leaves it visible with `a7a8` pending. With `e5` held at a flag, a new game keeps `e5` held and its `e5e6` target, so after Maia's e2e4 the e7-to-e6 drop opens the picker instead of playing.
  - Green: 7891185 (`ui/board_view.gd` only). The `game` setter ends the slide, kills the snap-back tween (now stored in `_snap`), clears the held moves and the pending promotion, closes the picker if it is open, and drops the held piece. Gate exit 0, `115 passed, 0 failed`. `godot --headless --quit-after 30` loads the main scene with no script error.
  - Not met as the reopen asked: the tests do not drive the real `Main`. The runner calls every test from `SceneTree._initialize`, before the root enters the tree (a probe printed `root inside tree: false`), so neither `main.tscn` nor `board_view.tscn` ever gets `_ready`, and Main's `@onready` nodes stay null. Making Main testable that way needs a change to `tests/run.gd`, which is outside Primary files. The tests instead drive the board scene through the same `board_view.game = Game.new()` assignment that `Main._start` makes (ui/main.gd:153), with the picker wired by hand and slides off, since a tween needs the tree.
  - Not tested: killing the snap-back tween, since tweens only run in the tree. That kill stops a stale `_end_snap_back` from dropping a piece picked up in the first 0.15 s of the new game.
  - Callers of the setter: `main._ready` (fresh board, nothing held, picker hidden), `main._start` (the rematch) and tests. The CLOCK-001 test builds `BoardView.new()` with a null `_picker`, which the guard covers. That test still passes.

> Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\93202eda-48f6-4cd8-8f92-1905edf073bb\scratchpad\UI-004-reopen-gate.json
>
> #### Resolution (2026-10-24, re-review)
>
> Verdict: Approve
>
> Stage 3 (opus-5.5), re-review after the session PR #8 reopen: the ❌ item (criterion 3) and the diff since the last review, d7aad4d (test-only, plus ticket metadata and a note under UI-007), 7891185 (`ui/board_view.gd` only) and 0b29179 (ticket only). The Standards and Spec axes ran as separate sub-agents. Standards found no violation and no baseline smell. The tests reach into BoardView's private state the same way `tests/test_board_view.gd` does. Spec found the fix meets the reopen, with two gaps in test coverage, not in behaviour (below). The UI-007 line is a note on an open ticket, not scope creep.
>
> Examined: the `game` setter's callers. `main._ready` builds a fresh board, with the picker hidden and nothing held, so the setter changes nothing there. `main._start` runs it for the first game and for a rematch. `tests/test_board_view.gd` builds `BoardView.new()` with a null `_picker`, which the guard covers. `_apply("auto_claim")` writes to the game, not through the setter. `_picker._close("")` hides the picker, frees its buttons and emits `cancelled`, which runs `_end_snap_back`, and the setter's own `_end_snap_back` after it is idempotent. `_end_slide` kills a slide still running from the old game. A mouse button still held across Space finds `_drag_from` empty, so motion and release do nothing. Outside the setter, `_drop` now keeps the snap-back tween in `_snap` so that the setter can kill it. This stays within the Proxy decided scope, which names the snap-back tween. Not examined: the app in a window, by a person.
>
> Criteria:
>
> 3. ✅ (was ❌). A rematch now starts on a clean board. I checked this on the real `Main`, in the tree, with an uncommitted review probe: a `SceneTree` script that defers from `_initialize`, adds `ui/main.tscn` to the root, and drives `_on_flagged`, `_unhandled_key_input` (Space) and `board_view._gui_input`, on a fresh `Main` per scenario. Repro A (picker open at a flag, then Space): no picker, its buttons freed, nothing pending. Repro B (e5 held at a flag, then Space): nothing held, and e7e6 plays after Maia's e2e4. Snap-back race (a piece snapping back at the flag, Space, then d2 picked up at once): d2 is still held 0.4 s later. On HEAD all 10 checks pass. On d7aad4d (no fix) 6 fail, covering both repros and the race. With only `_snap.kill()` removed, only the race check fails, so the kill is needed.
>
> Every other criterion verdict of the first review stands (quoted above).
>
> The regression was the first stage-3 pass's miss. That pass read `_start` and traced the game-over guards in `BoardView.play` and `Game.play`, but did not check what BoardView holds, or has pending for promotion, when a new game is assigned.
>
> Rules: test-only d7aad4d comes before production-only 7891185, and 0b29179 touches only the ticket. All code changes are in Primary files. No rebase was needed: the branch sat on the session tip 2c234be. Merged as 1ee143f, whose tree matches 0b29179.
>
> Red-green: in a throwaway worktree on d7aad4d the suite gives `113 passed, 2 failed`. The two new tests fail on the stale picker with `a7a8` pending, and on the stale `e5` held with its `e5e6` target. Green is stage 2's gate on 7891185: exit 0, `115 passed, 0 failed` (receipt in the `Gate evidence:` line above; its log shows the same counts). No production code changed after that, so the receipt is reused.
>
> Not met as the reopen asked, and not a reopen: the committed tests drive BoardView through the same assignment `Main._start` makes, not through the real `Main`, and no committed test covers the snap-back kill. The runner calls tests from `_initialize`, before the root is in the tree, and `tests/run.gd` is outside Primary files. The probe shows the seam works. The test it would host is noted under CLOCK-002 ## Comments, whose blocked question is about the same seam.
>
> `Proxy decided` lines: three, all (opus), under Comments. They cover `ui/move_list.gd`'s `reset()`, the Esc hint and the result in focus mode, and `ui/board_view.gd`'s `game` setter (this reopen).
>
> Acceptance: pending | the manual checks in Verification have not been run by a person: Esc Esc resign, a Space rematch that swaps colours, F11 focus mode, and claiming a threefold with auto-claim off in Settings. So far: the gate at 115/115 on 7891185, and the in-tree probe of the rematch path above.
> Disclosure: decision | none | Proxy decided (opus), see ## Comments: `ui/move_list.gd` joins Primary files for the `reset()` the rematch calls.
> Disclosure: decision | none | Proxy decided (opus), see ## Comments: in focus mode the Esc hint stays visible and the game-end result shows (review fix c4bd40f).
> Disclosure: decision | none | Proxy decided (opus), see the Reopen block: `ui/board_view.gd` joins Primary files, limited to the reset in the `game` setter and the `_snap` field it kills.
> Disclosure: deferred | none | no committed test drives the real `Main` rematch or the snap-back kill; it waits on a runner that hosts scenes in the tree. Not accepted by a person: the open destination is `.scratch/core/issues/32-CLOCK-002-move-after-flag.md` ## Comments (the same seam question). The behaviour was checked in this review by the probe above.
> Disclosure: pending | release | dropping Maia's stale reply after a rematch mid-think has no test, because it needs a window and Lc0. Check it by hand by rematching while Maia thinks.

#### Reopen (2026-10-25, review of the PR #8 sync with PR #7)

Reviewer: independent review by gpt-6.1-sol xhigh of session head 7d32e80 (the merge of main a27302e, the bot lane's PR #7), verdict "do not merge", relayed by the supervisor foreman. Gate 133/0 on that head; the rest of the conflict resolution was approved.

3. ❌ regression at integration: PR #7 made Maia's reply wait on the clock (`await` in `bot/maia_player.gd` `_on_policy`, around line 92), so replies can now finish out of order. `ui/main.gd` (around line 220) drops stale replies with a counter (`_replies_owed` / `_stale_replies`) that assumes they arrive first in, first out. Repro, on the real Main scene headless: an old reply for Maia as black is still waiting; the human gives up and rematches; the new reply as white finishes first. Main discards the current reply, then tries to play the old black move on the initial board, and Maia's turn hangs. With two quick rematches the old move can be legal again: the probe saw a stale d2d4 played in the new game after the current e2e4 was discarded.

What is left: tag each Maia request, and the reply it produces, with the game (generation) that asked for it; drop stale work before the policy is processed and again after the `await`; replace the arrival-order counter. Add a regression test with the completion order reversed (a fake bridge or timer can finish the new request before the old one). `bot/maia_player.gd` is not in Primary files: ask the proxy before touching it. Every other criterion verdict above stands.

Reopen diagnosis: new defect at integration, not an earlier review miss of UI-004's own code: the counter was correct while Maia answered synchronously, and BOT-005/BOT-006's await (merged later, PR #7) broke its FIFO assumption; the earlier reviews named the stale-reply path as untested (Disclosure above). Next action: stage 2 (two reopens, so the hard implementer) implements generation-tagged requests with a reversed-order regression test, with the proxy deciding whether `bot/maia_player.gd` joins Primary files. Evidence: the supervisor's relay of the gpt-6.1-sol xhigh review of 7d32e80; `ui/main.gd` `_replies_owed`/`_stale_replies`; `bot/maia_player.gd` `_on_policy` await.

Note for stage 2: the block quoted above is the previous review's record, kept for history; the live fields are the ones below it. Write the new receipt as `Gate evidence: <path>` at the very start of its own line, with no list dash and nothing after the path. A stage 3 that adds notes to other tickets after the gate makes the driver park a valid approval; put such notes before the gate commit.

Verdict: Reopen — criterion 3: Maia's out-of-order late replies after a rematch are matched by arrival order, so the current reply is dropped and a stale move is played

Proxy decided (gpt-6-astra high, fallback): add `bot/maia_player.gd` for request snapshots, generation cancellation and stale guards, plus narrowly scoped runner support for real Main lifecycle tests — UCI policies remain FIFO, but Maia's waits can complete out of order, so cancellation belongs before and after that wait. Preserve `policy_ready(policy)` and `move_ready(move)`; retain cancelled FIFO snapshots until their policies arrive. Scope and criterion 3 were updated above from this read-only proxy decision.

#### Stage 2 after the integration reopen (2026-10-25)

- Implementation: `Main._start` calls `MaiaPlayer.begin_game` before assigning the new game. Maia snapshots each request's generation, game, ply, timestamp, picker and clock/settings context before invoking the bridge, matches FIFO policies before awaiting, and checks validity before sampling and after the wait. Cancelled FIFO entries remain queued until their own policies arrive. Main's arrival counters are removed; both signal signatures and the bridge protocol are preserved. Standalone `think` callers automatically start a generation when their game changes.
- Callers and boundaries examined: Main is the only production `think` caller and `move_ready` listener; existing Maia, settings and time-model tests also call `think`, including synchronous bridges and the no-clock path. `begin_game` invalidates requests even when a new game starts on the human's turn. Empty pending queues, ended games and changed plies are rejected. The full gate covers existing picker/panic settings, time-model calibration, clocks and live Lc0 behavior.
- Runner cycle: test-only b6ceb92 was red with `8 passed, 1 failed` in the focused runner suite (the new node was neither inside the tree nor ready). Runner-only 6075057 defers execution from `_initialize`; green `9 passed, 0 failed`, including the existing assertion, script-load and runtime-error subprocess cases. No generic async runner support was needed.
- Reply cycle: test-only 2b2222a was red with `9 passed, 1 failed` in the focused suite because the injectable wait-completion constructor seam did not exist. Production-only 6b5d3a4 passed the real Main reversed-completion regression (`17 passed, 0 failed` focused). The later test-only commits 8d688bd and 9af1609 add the queued-policy/two-rematch boundaries, silence fixture audio and update the off-tree fixture comment/anchors. Those cases also have mutation-based red proof below.
- Behavioral red proof on the committed tests: removing only the pre-policy guard gave `18 passed, 1 failed`; an old policy scheduled a wait, added a latency sample and displaced the current reply. Removing only the post-wait guard gave `17 passed, 2 failed`; the new game gained stale `e7e5`, and after two rematches a stale legal `d2d4` played as the human. Both mutations were restored before the gate. These tests exercise production Maia's actual `await`, with manually emitted timeout signals and the real Main Esc/Space path; they do not copy cancellation logic or depend on a window or elapsed time.
- Validation: committed code 9af1609, `godot --headless -s tests/run.gd`, exit 0, `137 passed, 0 failed`, no skipped tests or script errors. The live Maia test played 30 plies through Lc0 (median 16.2 ms, diagnostic only). Expected malformed-table warnings remain from the existing time-model tests. Final diff and per-commit file separation reviewed; only the approved Primary files and this ticket changed.
- Environment: the initial unprivileged full-suite attempt could not write `user://` fixtures and was stopped. The focused red/green runs and the successful gate used the normal writable user-data environment. This did not require any repository workaround.

Acceptance: pending | criterion 3's integration regression is covered by the three committed real Main tests above. The original visual/manual Verification checks (including F11 and claiming a threefold with auto-claim off) remain pending; stage 2 does not approve its own implementation.
Disclosure: decision | none | read-only proxy decision above (gpt-6-astra high, fallback) expands Primary files and criterion 3 for generation cancellation and the minimal active-tree test seam; no saved data, settings or external signal/protocol change.
Disclosure: pending | release | original manual product acceptance remains pending as recorded above. The prior "stale reply has no test" disclosure is superseded by the committed deterministic regression tests; a live-window rematch while Lc0 thinks was not performed.
Disclosure: deferred | none | the earlier missing committed Main promotion-picker/snap-back lifecycle tests still have their open destination in `.scratch/core/issues/32-CLOCK-002-move-after-flag.md`; this runner now supports that in-tree seam, but this reopen only addresses Maia reply cancellation.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\p-chess-ui004-20261025\UI-004-9af1609-gate.json

#### Resolution (2026-10-25, integration re-review)

Verdict: Approve

Stage 3 re-reviewed the last criterion 3 failure and every change from session base `cd10e33` to handoff `6bcc2e5`. The Standards and Spec axes ran as independent, read-only sub-agents. No production or test fixes were needed during review. Earlier criterion verdicts stand.

##### Standards

No documented standards violations or actionable baseline smells found. Cancellation is owned by MaiaPlayer, Main's arrival counters are removed, existing signal signatures remain intact, and deterministic integration tests cover queued policies, reversed wait completion and two rematches. The runner change is limited to enabling the lifecycle those tests require. The request snapshot is created and consumed within one module; a separate request type would add an abstraction without a concrete benefit. `_is_current` centralizes the cancellation predicate. The review inspected the full diff, Main's lifecycle and callbacks, UCI's FIFO dispatch, and existing Maia callers; tooling-enforced rules were excluded.

##### Spec

No missing or partial requirements, incorrect implementation, or scope creep found in the integration-reopen diff. Criterion 3 requires obsolete policies to be discarded before sampling or scheduling a delay, and waiting replies to be discarded before emitting. Maia consumes each FIFO snapshot and rejects obsolete requests before filtering, sampling, latency recording or delay calculation; it checks generation, game, ply and game-over state again after the wait. Cancelled pending snapshots remain queued to consume their own eventual policies. Main invalidates the prior generation on every new game, including when the human has the opening turn. UCI's serial queue supports the retained FIFO policy matching. Each snapshot is removed before awaiting and resumes once; Main advances the game synchronously when a current reply arrives. Enqueuing before invoking the bridge preserves synchronous replies, and replies without a clock still emit immediately. The three real-Main regressions cover the reopened failure. Runner argument handling, assertion/load/runtime failures and exit codes remain intact.

Standards: 0 findings; Spec: 0 findings.

- Criterion 3: ✅ `Main._start` starts a new generation before replacing the board game. A queued stale policy cannot displace the current policy, and a stale wait cannot play even if its move becomes legal after two rematches. The new tests drive real Main Esc/Space handlers and Maia's production await through fake bridge policies and manually completed timer signals. Criteria 1, 2 and 4–8 retain their prior approvals; manual acceptance remains separate below.
- Callers and failure paths examined: Main's `_start`, `_next_turn`, `_on_maia_move`, move/flag/resign paths; UCI `request_policy`, queue dispatch and `poll`; all Maia/settings/time-model test callers, including synchronous bridges and the no-clock path; empty pending queues, ended games and changed plies; runner assertion, script-load and runtime-error subprocess fixtures. The clock-before-input defect and additional BoardView lifecycle coverage remain tracked by [CLOCK-002](32-CLOCK-002-move-after-flag.md#comments). No live-window input/visual checks were performed in this review.
- Files and commit rules: inspected every commit's file statistics. Test-only `b6ceb92` precedes runner-only `6075057`; test-only `2b2222a` precedes production-only `6b5d3a4`; `8d688bd` and `9af1609` are test-only additions/corrections with the behavioral red proof recorded below. `6bcc2e5` changes only ticket metadata. All changed source/test files are within the proxy-approved Primary files. No squash or unrelated refactor.
- Red-green evidence from stage 2: runner `b6ceb92` was `8 passed, 1 failed`, then `6075057` was `9 passed, 0 failed`. Reply-cycle `2b2222a` was `9 passed, 1 failed`, then `6b5d3a4` was `17 passed, 0 failed` focused. On the final tests, removing the pre-policy guard produced `18 passed, 1 failed`; removing the post-wait guard produced `17 passed, 2 failed`. Both mutations were restored before the committed gate. This review checked the tests against the actual guard placement and callers; it did not rerun the mutations.
- Gate: reused the existing successful `godot --headless -s tests/run.gd` run on `9af1609`: exit 0, `137 passed, 0 failed`, no skips or script errors, including 30 live Lc0 plies. Verified the receipt with the installed `Assert-GateEvidence`, SHA-256 of its log, recorded exit status and equality of tested code with the reviewed handoff. Only expected malformed-table warnings occur. No code changed during review, so no repeat gate was needed.
- Integration: the ticket branch was already based on session tip `cd10e33`; rebase was a no-op. Merged without conflicts into `sweatshop/core/2026-10-24-1911` as `b30c724`; its tree matches reviewed handoff `6bcc2e5`. This close changes only the ticket and ledger. No push or PR is part of this session-stage handoff.
- Proxy decisions reviewed: the three `(opus)` decisions add the move-list reset, preserve the transient Esc hint/result in focus mode, and scope BoardView's interaction reset. The `(gpt-6-astra high, fallback)` decision adds generation cancellation, request snapshots and the minimal active-tree test seam while preserving signal signatures and FIFO policy snapshots. The implementation stays within those decisions; no additional contract decision was made in review.

Acceptance: pending | automated criterion 3 acceptance passes in the committed real-Main tests and the verified 137/0 gate. Original visual/manual Verification (Esc Esc, Space colour swap, F11, Claim draw with auto-claim off) and a live-window rematch while Lc0 thinks have not been checked by a person.
Disclosure: decision | none | four proxy decisions preserved under Comments and reviewed above: three opus decisions for move-list reset, focus messages and BoardView reset; one gpt-6-astra high fallback decision for request cancellation and runner scope. No saved-data or signal/protocol migration.
Disclosure: pending | release | original visual/manual acceptance remains pending as recorded in Verification and the Acceptance line. The historical claim that stale replies have no automated test is superseded by the three committed real-Main regressions.
Disclosure: deferred | none | committed Main promotion-picker/held-piece/snap-back lifecycle coverage remains an open follow-up under [CLOCK-002 Comments](32-CLOCK-002-move-after-flag.md#comments); this review does not claim that coverage was added. The active-tree runner prerequisite is now available.
