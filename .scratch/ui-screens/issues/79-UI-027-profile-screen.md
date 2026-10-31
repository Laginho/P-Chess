# UI-027: Profile screen to the design
Stage: to-implement
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
