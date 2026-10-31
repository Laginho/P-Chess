# UI-019: The profile
Stage: to-review
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

## Resolution — stage 2 (2026-10-31)

- Added Profile to Home, with a Back button that restores Home and its keyboard focus. Home owns the temporary Profile child, so no Main routing change was needed. The existing `Home.configure(preferences)` caller and quick-play, History and Settings signals retain their interfaces.
- Profile edits the existing `player_name` setting through Save name or Enter, trims surrounding whitespace, rejects blank names with a message, and persists changes. The real History screen test immediately shows the renamed player in a legacy PGN while leaving the saved PGN unchanged. Named PGNs retain their saved identity, as already specified by UI-018 and §15.8.
- The results table reads `History.stats` for the nine existing levels and three time controls, shows W/D/L plus flag-win/loss subsets, omits zero-game rows, and has an empty state. `core/history.gd`, its callers and saved stats were unchanged.
- The chart reuses `Analyser.read_analysis` and `Accuracy.evaluate`, selects the human through `History.human_colour`, and sorts by PGN date (filename date fallback, filename tie-break). Missing/stale/incomplete/corrupt analysis and games with no human moves are excluded. Empty and single-point series are handled; the chart shows a 0–100% scale, first/last dates and a tooltip with dated values. The scroll area keeps the name controls and Back accessible at the minimum window size.
- Agreed test seam: the real Profile/Home scenes, existing Settings/History APIs, and isolated stats/PGN/analysis fixture files in `tests/test_profile.gd`. Boundary coverage includes whitespace-only names, zero-game rows, empty series, Black and same-name identities, legacy identity, no human move, zero moves, stale/missing/incomplete/corrupt caches, a single point and 800×600 geometry. Existing production functions were not changed; new Profile presentation is called by Home and the scene tests.
- Red/green proof, with separate test-only and production-only commits: `a50d629` failed because Home had no Profile button, then `11b1aa5` passed (1 test); `2a6ce5f` failed because the table refresh did not exist, then `e04108a` passed (2 tests); `e832420`/`921bfaf` failed because the chart did not exist, then `5beb0e9` passed (3 tests); `c9d4cec` exposed invalid-cache script errors, then `a0eeb43` passed (4 tests). External logs: `C:/Users/bruno/AppData/Local/Temp/ui019-name-{red,green}.log`, `ui019-stats-{red,green}.log`, `ui019-chart-red-corrected.log`, `ui019-chart-green.log`, and `ui019-corrupt-{red,green}.log` in that directory.
- Test-harness correction: `921bfaf` corrects the independently worked one-move accuracy expectation to 10.8500% for a 0→1000 cp White-perspective change on Black's move. It was committed separately and re-proven red before production implementation. During implementation, a focused run also caught a chart numeric-inference parse error; the final focused run and full gate have no script errors.
- Full bound gate ran once after the final production commit: `godot --headless -s tests/run.gd`, tested commit `a0eeb4308cfe5ef12e7497e6a5f6a6af7102cec5`; **400 passed, 0 failed, 0 skipped**, exit 0. Log: `C:/Users/bruno/AppData/Local/Temp/UI-019-gate.log`. The log contains 29 warnings from existing premove geometry, invalid-theme and malformed-time-model fixtures, with no error entries or Profile warnings. `git diff --check` also passed.
- Handoff: `to-review` on `UI-019`, based on `sweatshop/v010/2026-10-30-2302`. Independent stage-3 review remains required; no merge, ledger closure, PR or push was performed by stage 2.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/UI-019-gate.json
Acceptance: pending | Open Profile from Home with keyboard/mouse, rename and inspect History, compare the table against known results, and visually inspect the dated accuracy chart/scrolling at normal and minimum window sizes. Headless scene, fixture and geometry checks passed as recorded above.
Disclosure: pending | release | .scratch/v010/issues/65-UI-019-profile.md#resolution--stage-2-2026-10-31 — rendered Profile layout/chart, physical keyboard/mouse navigation and known-game product acceptance remain pending; automated gate and scene checks passed.
