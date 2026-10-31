# UI-027: Profile screen to the design
Stage: to-review
Blocked by: UI-021
Review: agent
Difficulty: normal

- Primary files:
  - ui/profile.gd, ui/profile.tscn
  - ui/accuracy_chart.gd
  - the stats reader the profile uses today, only if a new total is needed
  - tests/test_profile.gd
  - docs/spec.md (§15.8, the Profile paragraph)

#### What to build

Restyle the profile to `docs/design/v0.1.0/png/Profile.png`, with the layout Bruno chose on 2026-10-31 (`.scratch/ui-redo/spec.md`).

#### Acceptance criteria

1. Name card: the initial avatar, the name, "Playing since <Mon YYYY>" from the first saved game (omitted with no games), and the Name field with Save. Behaviour unchanged (§15.8).
2. Four tiles: Games (total), Avg. accuracy (the mean of your accuracy over analysed games, "–" with none), W / D / L (green / grey / red) and Flag W / L.
3. Results table, headed "Results by level and time control": one row per level that has games; a "W D L" column per time control ("–" when none); then Flag wins and Flag losses per level, summed across time controls.
4. Accuracy over time: the canvas's line-and-dots chart in its card, with the spec's data: every analysed game in date order, a 0–100 axis, the first and last dates labelled, the empty-series message kept.
5. `docs/spec.md` §15.8's Profile paragraph describes the tiles and the per-level flags.
6. The shared acceptance in `.scratch/ui-redo/spec.md` holds for the board.

#### Verification

    Manual: open Profile on a fixture history; rename yourself.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_profile.gd`: the four tiles' values from a fixture history; flags summed per level across time controls; "Playing since" from the first game (red: no tiles).

## Comments

- 2026-10-31 Written from `.scratch/ui-redo/spec.md`. Bruno took the canvas layout and kept the spec's chart (all games, 0–100).
- Stage 2: focused profile tests pass (4/4); the games tile, summary/table and filename-date tests were observed red before their implementations. The former below-scroll Back assertion was updated for the canvas header.
- Gate: 413 reported passed, 0 failed, including 6 Lc0 skips (407 executed); exit 0. Tested commit: b5a9d1fc8a558740ac2a3ab32aee476080ada9fa.
- Screenshot checks: `C:\Users\bruno\AppData\Local\Temp\pchess-ui027-c881251d-7437-4691-8ad3-01a7acfb027c\profile-1280.png` (earlier iteration) and `C:\Users\bruno\AppData\Local\Temp\pchess-ui027-final-87105672-a105-47a1-bf74-c0b09c3b69bc\profile-800.png` (final). The 800px table headings are compact; the fixture has one row and no analysed games. The app-wide Settings control remains visible above the screen. Stage 3 must capture the final 1280px screen, compare a populated fixture to the reference and attach before/after images.
- Acceptance: pending | Manual Profile rename and graphical comparison with populated history, including the 800×600 layout.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\pchess-ui027-gate.json

- 2026-10-31 Foreman: the escalated prerequisite is resolved by the owner. The shared font-axis fix was merged to main as PR #37 (CLEAN-012, f0789db; it supersedes UI-030), and the session took it in sync merge 9ad4daf (gate 436 passed, 0 failed). Restoring `to-review` per the re-review's own resume instructions: rebase `ui-027` onto the session, run the gate on the resulting production, recapture populated Profile at 1280x800 and 800x600 and verify the resolved weights.
