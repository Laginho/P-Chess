# UI-031: No Settings button outside Home; resign confirmation fits at 800×600
Stage: done
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/settings.tscn, ui/settings.gd (the top-right `Open` button)
  - ui/main.gd (Ctrl+, opening, `_covers_settings`, the resign button text at line ~216)
  - ui/icon_button.gd (opt-in wrapping when the label does not fit its button; buttons whose label fits draw exactly as before)
  - ui/home.gd, ui/searching.gd (`_sync_settings_button`)
  - scripts/screens.gd (hides `Open` for captures)
  - tests/test_home.gd, tests/test_session.gd, tests/test_badges.gd

#### What to build

Follow-up of the UI redo (`.scratch/ui-redo/spec.md`), decided by Bruno on 2026-10-31.

1. **Settings is reached from Home's Settings button and `Ctrl+,` only.** The top-right Settings button (`settings_screen`'s `Open`) still shows on Profile, where the canvas (`docs/design/v0.1.0/png/Profile.png`) draws none; no other screen shows it any more (the game screen hides it, the rest cover it). Remove that button and the visibility bookkeeping that exists only for it. `Ctrl+,` keeps opening and closing the panel wherever it works today.
2. **"Click again to resign" fits at 800×600.** At the minimum window the armed Resign label runs about 30 px past the side panel's right edge (seen on `1baf422` and after the PR #36 fidelity pass). It must stay inside its button at 800×600 and 1280×800, with no other panel control moving.

#### Acceptance criteria

1. No screen shows a Settings button other than Home's; Profile at 1280×800 matches `Profile.png` in that corner. `test_home.gd`'s "Settings remains available in Profile" assertion is replaced by one that `Ctrl+,` opens Settings from Profile.
2. `Ctrl+,` opens and closes Settings from every screen where it did before; Esc still closes it.
3. With Resign armed, at 800×600 the label sits fully inside the Resign button and the panel does not widen.
4. Gate green.

#### Verification

Capture Profile at 1280×800 and Game with Resign armed at 800×600 (`scripts/screens.gd`, isolated root; usage in `docs/design/v0.1.0/README.md`) and compare them with the reference PNGs by eye; cite the PNGs in a comment.

    godot --headless -s tests/run.gd

## Comments

- 2026-10-31 Opened by the parent session after PRs #34–#36 merged. Profile's Settings button was left in place by UI-027 because `ui/main.gd` belonged to the ui-game lane; the resign overflow was a taste call listed by the PR #36 fidelity pass, and Bruno chose a ticket over blocking UI-023.

- Proxy decided (opus-5.5 xhigh): Yes. Add `ui/icon_button.gd` to Primary files and let it draw a label on two lines, but only when the label can't fit on one line. Keep `text` exactly "Click again to resign". ? That keeps 1280?800 matching `GamePanelStates.png` (one line with the flag), fits at 800?600 and leaves the exact-label assertion at `test_session.gd:442` alone. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-230343-UI-031-04774f.json)
  - Wrap on word boundaries only when needed and opt in only for Resign; keep 15 px Bold if it fits, at least 14 px otherwise. Preserve all control rectangles including Resign. Compare captures at both sizes; the flag may be omitted only when wrapped.
- Test harness correction: `test_profile_has_no_extra_settings_button_and_shortcut_opens_settings` uses an isolated returning-player preference file so the first-launch dialog does not intercept the shortcut. The updated `test_game_has_no_settings_button` and `test_game_over_result_shows_on_the_card_not_the_side_panel` replace assertions on the removed node; `test_enabling_checking_during_catalog_load_rejects_bad_repertoire_and_allows_repaired_retry` opens the real Settings panel directly because the retired button cannot open it during the covered searching screen.

- Red/green: Profile button assertion failed before removal and passed afterward; the layout test failed before the fix (800?600 panel 260?316 px and Draw moved) and passed with both window sizes and unchanged panel, Draw and Resign rectangles. The Profile shortcut test uses real viewport key input.
- Visual verification: [Profile 1280?800](C:/Users/bruno/AppData/Local/Temp/pchess-ui031-capture-bab81191-bd33-4761-8976-706c8bcde158/Profile.png) has no top-right Settings button, as in [Profile reference](../../../docs/design/v0.1.0/png/Profile.png). [Game 800?600](C:/Users/bruno/AppData/Local/Temp/pchess-ui031-capture-bab81191-bd33-4761-8976-706c8bcde158/Game800.png) shows the full confirmation in two lines above the bar; 14 px is necessary because 15 px takes 44 px for two lines, but only 40 px is available above the bar. [Game 1280?800](C:/Users/bruno/AppData/Local/Temp/pchess-ui031-capture-bab81191-bd33-4761-8976-706c8bcde158/Game1280.png) retains the one-line text and flag as in [GamePanelStates reference](../../../docs/design/v0.1.0/png/GamePanelStates.png).
- Gate: `godot --headless -s tests/run.gd` ? 487 passed, 0 failed. The log includes one premove anchor warning and warnings from invalid-theme and malformed-model fixtures.
- Disclosure: decision | none | Proxy receipt above approves the opt-in wrapping seam and 14 px minimum; the confirmation text and shortcut availability remain unchanged.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\pchess-ui031-gate.json

#### Resolution (2026-10-31)
Verdict: Approve

- Standards: 0 documented violations, 0 actionable smell findings. Spec: 0 findings. Reviewed the complete `31726ee...e3ab496` diff, all seven commits, Primary-file boundaries and separate test/production commits; no review fixes were needed.
- Examined callers and failure paths: Home Settings and Profile navigation; Ctrl+, and Esc through viewport input, focus traversal and choice popups; setup/game/post-game availability and focus/review/history/name-dialog/searching exclusions; catalog-load Settings changes; Resign arming, expiry and reset; every shared icon-button consumer and screenshot caller. No remaining production references to the removed Open node or visibility handlers. Other `clip_text` scene uses are Labels, so only Resign takes the new drawing branch. Player persistence is unchanged; the Profile test cleans its isolated preferences/history.
- Criterion 1: passed. The Open node, signal and visibility bookkeeping are removed; Home retains its Settings button and the Profile replacement test exercises Ctrl+, opening and closing. A fresh graphical Profile capture has the same empty upper-right corner as the reference.
- Criterion 2: passed. Shortcut routing and Settings focus/Esc handling are unchanged; the existing real-input regression tests cover the supported screens, exclusions, popup closure and focus release.
- Criterion 3: passed. Fresh graphical captures show the exact confirmation in two 14 px Bold lines above the bar at 800x600 and in one line with its flag at 1280x800. The layout regression checks unchanged panel, Draw and Resign rectangles at both sizes. The other icon-button drawing paths remain unchanged.
- Criterion 4: passed. Validated the receipt command, exit 0, SHA-256 log hash, available tested commit `45cd248c5ece811f8c6a7f9567e0cdb342ff95a3` and unchanged production through session merge `fd8030c09b6166f5882b6c3a1e7237e7a9a76a43`. Reused the green gate: 487 passed, 0 failed. Its log discloses six Lc0-dependent skips because `engine/lc0/lc0.exe` is absent and one graphical last-move-pixel skip; these are outside this ticket's changed behavior. Existing anchor and malformed-fixture warnings remain.
- Red/green evidence inspected: `C:/Users/bruno/AppData/Local/Temp/pchess-ui031-settings-red.log` fails on the extra Profile button and `pchess-ui031-settings-green.log` passes; `pchess-ui031-layout-red.log` fails on panel widening and Draw movement, and `pchess-ui031-layout-green.log` passes. The later full gate also covers the added Resign-rectangle assertion.
- Decision review: the ticket's `Proxy decided (opus-5.5 xhigh)` record was checked against `C:/Users/bruno/AppData/Local/Temp/sweatshop-proxy/20261031-230343-UI-031-04774f.json`. The approved seam is opt-in, width-dependent wrapping with unchanged text, a 14 px minimum, fixed control rectangles and omission of the flag only when wrapped; the implementation and both game captures satisfy those conditions.
- Fresh review captures, made with the real graphical renderer and a separate data root per invocation: [Profile 1280x800](C:/Users/bruno/AppData/Local/Temp/pchess-ui031-stage3-b5567ecd-4cb7-480d-90a4-2523f013b970/Profile-1280x800/Profile-1280x800.png), [Resign 800x600](C:/Users/bruno/AppData/Local/Temp/pchess-ui031-stage3-b5567ecd-4cb7-480d-90a4-2523f013b970/GamePanelStates-800x600/GamePanelStates-800x600.png), [Resign 1280x800](C:/Users/bruno/AppData/Local/Temp/pchess-ui031-stage3-b5567ecd-4cb7-480d-90a4-2523f013b970/GamePanelStates-1280x800/GamePanelStates-1280x800.png). Compared by eye against [Profile reference](../../../docs/design/v0.1.0/png/Profile.png) and [confirmation reference](../../../docs/design/v0.1.0/png/GamePanelStates.png), and against the stage-2 captures above.
- Not examined in this review: physical keyboard/mouse interaction, screen-reader output, audio and live Lc0 play. The gate receipt and captures are local evidence, not CI or clean-machine acceptance.
- Integrated without squash into `sweatshop/ui-polish/2026-10-31-2256`; no conflict, no push or PR from this stage.

Acceptance: passed | All four UI-031 criteria verified by the gate receipt, real-input regression tests and fresh graphical captures above; broader v0.1.0 human QA remains outside this ticket.
Disclosure: decision | none | The proxy receipt above approves the wrapping seam and 14 px minimum; review confirmed unchanged wording, control geometry and Settings shortcut behavior.
