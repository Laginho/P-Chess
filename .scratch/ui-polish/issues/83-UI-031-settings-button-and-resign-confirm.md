# UI-031: No Settings button outside Home; resign confirmation fits at 800×600
Stage: to-implement
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/settings.tscn, ui/settings.gd (the top-right `Open` button)
  - ui/main.gd (Ctrl+, opening, `_covers_settings`, the resign button text at line ~216)
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
