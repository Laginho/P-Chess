# UI-019: The profile
Stage: implementing
Blocked by: REV-004, UI-018
Review: agent
Difficulty: normal

- Primary files:
  - New: ui/profile.gd
  - New: ui/profile.tscn
  - New: ui/accuracy_chart.gd
  - ui/home.gd, ui/home.tscn (the Profile button)
  - core/history.gd (read-only use of `stats`; an accuracy series if needed)
  - New: tests/test_profile.gd
  - docs/spec.md (§15.8)

#### What to build

A Profile screen, opened from Home (§15.8): your name, your results per level and time control, and your accuracy over time.

#### Acceptance criteria

1. Home gets a Profile button; Profile has a way back.
2. The name is editable here; a change updates the `player_name` setting (UI-018) and shows at once in History.
3. A table shows W/D/L per level and time control, with flag wins and flag losses, from the stats; rows with no games are left out.
4. A small chart plots your accuracy per analysed game in date order; unanalysed games and games where you made no move are left out; with none, it says so.

#### Verification

    Manual: open Profile, rename yourself, check History; compare the table with a few known results.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_profile.gd`: the table matches seeded stats and hides empty rows; the chart series comes from fixture analysis files in date order, skipping unanalysed and no-move games; renaming updates the setting (red: no screen).

## Comments

- 2026-10-30 Written from spec §15.8 and the design brief (screen 7). Richer stats are deferred past v0.1.0.
