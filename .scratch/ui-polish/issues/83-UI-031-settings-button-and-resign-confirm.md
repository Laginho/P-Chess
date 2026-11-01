# UI-031: No Settings button outside Home; resign confirmation fits at 800×600
Stage: implementing
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
