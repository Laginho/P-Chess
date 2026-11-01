# UI-035: After closing the game-over card, the panel offers New game and Rematch
Stage: done
Status: ready-for-agent
Blocked by: UI-034
Review: agent
Difficulty: normal

- Primary files:
  - ui/game_over.gd (`_close`, line ~81)
  - ui/main.gd (`_show_result`, `_set_focus`, the `Actions` row and `_show_home`)
  - ui/main.tscn (`Layout/Side/Actions`)
  - tests/ covering the game-over card

#### What to build

Bruno's QA of v0.0.2 (2026-11-01), item 8: "depois do fim do jogo, se eu clico no X do popup de final, eu não consigo mais sair daquela tela." Confirmed in code: the X (and Esc) only hides the card; with the game over, Esc's resign no-ops, Offer draw and Resign do nothing, and only an unadvertised Space rematch leaves the screen.

Once the game is over, the panel's Actions row swaps Offer draw / Resign for **New game** (goes Home, like the card's New game) and **Rematch** (like the card's Rematch), with the same button style. A new game restores Offer draw / Resign. In focus mode (UI-034) the panel is hidden, so closing the card there also leaves focus mode, which brings the row back.

#### Acceptance criteria

1. After any game end, closing the card with X or Esc leaves New game and Rematch visible in the panel; New game shows Home, Rematch starts the rematch.
2. Starting any new game shows Offer draw and Resign again, enabled as today.
3. Closing the card in focus mode leaves focus mode, and the two buttons show.
4. Gate green.

#### Verification

    Manual: lose a 1+0 game on time, close the card with X, press New game; Home shows.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- End a game, close the card, and assert a visible panel button leads to Home (red: none exists).

## Comments

- 2026-11-01 Written from Bruno's QA of v0.0.2 (item 8). The canvas has no post-game panel state (`GamePanelStates.png` shows only in-game states). Default taken: Chess.com's behaviour, the action row becomes New game / Rematch. Correct it if the X should instead go back Home or reopen the card.
- Blocked by UI-034: same files (`main.gd` focus and panel code).

- Stage 2: the new session test was red before the implementation (post-game actions absent and focus not restored), then passed in the gate. Gate on e052e51: 493 passed, 0 failed, exit 0; six live Lc0 checks and one graphical pixel check skipped. The test covers X and routed Esc, both post-game actions, focus restoration, and restoration of in-game actions.
- Acceptance pending: play a real 1+0 game, let the clock expire, close the card with X and select New game.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/ui035-gate.json

#### Resolution (2026-11-01)

Verdict: Approve

- Reviewed the complete `dfb95cf...d2c0565` diff: `ui/game_over.gd`, `ui/main.gd`, `ui/main.tscn`, `tests/test_session.gd` and this ticket. Independent Standards (`standards_ui035`) and Spec (`spec_ui035`) reviewers read the connected code. No production changes were authored during review; restored the encoding of the quoted QA text above.
- Standards: 0 documented violations or actionable baseline smells. All changes stay within Primary files. Test-only commit `4a5462f` precedes production-only `e052e51`; handoff `d2c0565` changes only ticket metadata. The supplied red log `C:/Users/bruno/AppData/Local/Temp/ui035-red.log` reports the intended missing post-game actions and failure to restore the panel (48 passed, 1 failed).
- Spec: 0 findings. Examined all result callers: resignation, claimed/agreed draw, flag and terminal board moves; X/Esc routing, Home/setup, rematch colour and score handling, normal/focus layouts and clock reparenting, new-game resets, history saving, review actions and engine-stop/start failure paths. Existing guards and storage behavior are preserved. No unresolved integration finding or scope creep.

**Numbered criteria:**

1. Pass for implementation: all result paths reach the shared action swap. An independent runtime probe covers resignation, an actual 1+0 clock flag with a fake time source, checkmate, agreed draw and a threefold claim. Routed mouse clicks on X and routed Esc close the card; both actions remain visible, enabled, within the canvas and reachable with Tab. Routed mouse/Enter activation opens Home or starts the opposite-colour rematch.
2. Pass: after both panel actions, starting the next game restores visible, enabled Offer draw and Resign and hides New game and Rematch. The committed regression test and independent probe both verify this reset.
3. Pass: routed F11 enables focus before game end; both X and Esc then leave focus and restore the panel. Both post-game actions work after that transition at physical 1920x1080 and 800x600.
4. Pass: revalidated `ui035-gate.json` against the reviewed and merged trees: tested commit `e052e51`, matching SHA256 log hash and exit marker, 493 passed, 0 failed, exit 0. Six live-Lc0 checks and one graphical pixel check were skipped. Reused the existing run because production did not change.

Independent probe: `C:/Users/bruno/AppData/Local/Temp/ui035-review-probe.gd`; final log `C:/Users/bruno/AppData/Local/Temp/ui035-review-probe.log`: eight cases, 0 failures or script errors, exit 0. It uses the real scene/input routing with an isolated fake engine, history and clock. The initial probe expected a manual repetition claim while the default auto-claim setting was enabled; explicitly disabling auto-claim corrected that harness expectation without changing production. Graphical appearance and live Lc0 play were not independently checked.

Rebase onto the lane was already up to date. Integrated without squashing into `sweatshop/qa-layout/2026-11-01-1407` as `7494540`; no PR or push is part of this stage. Stage and ledger close together in this commit.

Acceptance: pending | Bruno to play a real 1+0 game, let the clock expire, close the card with X and select New game; Home must show.
Disclosure: pending | release | The real-game acceptance above and live-Lc0/graphical checks remain pending. The gate's six live-engine skips and one graphical pixel skip are recorded in `C:/Users/bruno/AppData/Local/Temp/ui035-gate.log`; implementation approval and lane integration do not establish product acceptance.
