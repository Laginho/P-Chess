# UI-034: Focus mode shows only the board, centred, and the two clocks
Stage: done
Status: ready-for-agent
Blocked by: UI-033
Review: human
Difficulty: normal

- Primary files:
  - ui/main.gd (`_set_focus`, line ~559)
  - ui/main.tscn (`Layout/Side`, the clock rows)
  - tests/ covering focus mode (grep `_set_focus` / `focus`)

#### What to build

Bruno's QA of v0.0.2 (2026-11-01), item 3. F11 today hides the panel's children but `Layout/Side` keeps its width and frame: the board stays on the left and the two clocks float at the top of an empty panel.

In focus mode:

1. The side panel is gone entirely (no frame, no background, no width).
2. The board sits at the window's centre.
3. The two clocks stand to the left of the board, stacked around its vertical centre: Maia's above, yours below, as in Bruno's [example](../focus-reference.png) (that image's player cards, draw and resign buttons are not wanted: only the clocks).
4. Nothing else shows. Resign stays on Esc Esc; there is no draw offer in focus mode (no hotkey exists for it).
5. The game-over card still appears over the board and works as outside focus mode.
6. F11 again restores the normal layout exactly as before, including a draw notice that was showing.

#### Acceptance criteria

1. With focus on, at 1920×1080 the board is centred horizontally and vertically; the side panel draws nothing.
2. Both clocks are visible left of the board, opponent above, running and turning as normal.
3. Ending a game in focus mode shows the game-over card.
4. Toggling F11 twice returns the layout to its pre-focus state.
5. Capture of focus mode at 1920×1080 compared by eye with `focus-reference.png` for placement. Gate green.

#### Verification

    Manual: a 1+0 game, press F11; only board and clocks show, board centred.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- Focus mode on: `Layout/Side` (or whatever replaces it) has zero width or is hidden, the board's centre equals the viewport's, and both clocks are visible (red: today Side keeps its width).

## Comments

- 2026-11-01 Written from Bruno's QA of v0.0.2 (item 3). He chose the clocks on the left, at the board's vertical centre.
- Blocked by UI-033: same `main.tscn` layout, and focus mode must centre under the new stretch mode.

- Stage 2: the session test was red before the change (side panel visible, clocks on the right, resize grip visible); the clock-gap assertion was also red against the first implementation. Gate on commit 407e86d: 492 passed, 0 failed, exit 0; six live Lc0 checks and one graphical pixel check skipped. The focus placement test passed in the gate.
- Captured and compared `C:/Users/bruno/AppData/Local/Temp/pchess-ui034-capture/focus-final.png` (1920x1080) with `focus-reference.png`: the board is centered and the clocks are stacked to its left around the vertical center. Capture uses a fixture, not a live game.
- Acceptance pending: Bruno to judge the capture and play the requested 1+0 game, including clock changes, Esc Esc and the game-over card.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/ui034-gate.json

#### Resolution (2026-11-01)

Verdict: Approve

- Reviewed the complete `a97a25d...57ae0d4` diff: `ui/main.gd`, `ui/main.tscn`, `tests/test_session.gd` and this ticket. Independent Standards and Spec reviewers examined the connected code. No production changes were authored during review.
- Standards: 0 documented violations. One optional Duplicated Code observation: the short bot/player lookup and ordering appears in `_set_flipped()` and `_set_focus()`; retained as straightforward code, with no refactor needed for this ticket. Test-only commits `cefb7f9` and `f642baf` precede production-only `407e86d`. Supplied red logs fail the intended panel/clock/grip visibility and clock-gap assertions; the final gate is green.
- Spec: 0 findings. Examined F11 and flip callers, clock-row reparenting and retained clock references, resize/layout callbacks, draw notice and its timer, resignation and flag paths, game-over actions, rematch colour/score changes, engine failure and return to Home. All production lookups after reparenting use retained clock references. No scope creep or unresolved integration finding.

**Numbered criteria:**

1. Pass: independently inspected the supplied 1920x1080 capture. A focused runtime probe at physical 1920x1080 and 800x600, with automatic and fixed-640 board sizes and both human colours, confirms board centring and a hidden side panel. The virtual canvases are 1422x800 and 1280x960 respectively.
2. Pass for implementation: in all eight probe cases both clocks are contained in the visible canvas, left of the board with the opponent above the player. A fake time source on a 1+0 clock confirms countdown and active-clock styling switch after real `BoardView.play()` move accounting. Live Lc0 play remains a human acceptance item.
3. Pass: routed viewport Esc Esc resigns in focus and displays the game-over card. Focusing Rematch and routing Space starts the opposite colour, preserves focus and reorders the clocks. The engine-stop failure path restores Home and reparents the clock rows back to the side panel.
4. Pass: routed F11 twice restores every Control rectangle and visibility under Layout, the exact side-panel child order and a visible draw notice, including with a long player name, at both resolutions and both board sizes. Existing notice-expiry/rematch tests are green in the validated gate.
5. Pass for verification: compared `C:/Users/bruno/AppData/Local/Temp/pchess-ui034-capture/focus-final.png` by eye with `.scratch/qa-layout/focus-reference.png`; placement follows the requested centred board and two clocks on its left. Revalidated the existing gate receipt against the reviewed and merged trees: tested commit `407e86d`, matching SHA256 log hash and exit marker, 492 passed, 0 failed, exit 0. Six live-Lc0 checks and one graphical pixel check were skipped. Reused the run because production did not change.

Independent probe: `C:/Users/bruno/AppData/Local/Temp/ui034-review-probe.gd`; final log `C:/Users/bruno/AppData/Local/Temp/ui034-review-probe-final.log`, eight cases, 0 failures or script errors, exit 0. The initial probe bypassed move bookkeeping; the corrected harness uses `BoardView.play()` and required no source fix. This is headless runtime evidence with a fake engine and time source, not a played live game.

Rebase onto the lane was already up to date. Integrated without squashing into `sweatshop/qa-layout/2026-11-01-1407` as `63c64db`; no PR or push is part of this stage. Stage and ledger close together in this commit.

Acceptance: pending | Bruno to judge the supplied focus capture and play the requested real 1+0 game, checking clock transitions, Esc Esc, game-over actions and the return from focus.
Disclosure: pending | release | Human visual and live-game acceptance above remain required; implementation approval and lane integration do not establish product acceptance. The gate skipped live Lc0 and graphical pixel checks as recorded above.
