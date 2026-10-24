# UI-005: Settings store and screen
Stage: to-review
Blocked by: UI-004
Review: agent
Difficulty: normal

- Primary files:
  - New: core/settings.gd
  - New: ui/settings.tscn, ui/settings.gd
  - ui/main.gd, ui/board_view.gd, bot/maia_player.gd (read their settings)
  - New: tests/test_settings.gd

#### What to build

Settings live in `user://settings.cfg` and are edited on a settings screen (§10). This ticket covers the settings whose features already exist; UI-006, UI-007, OPEN-002 and OPEN-004 add their own rows.

#### Acceptance criteria

1. Settings are stored with `ConfigFile` in `user://settings.cfg`; a missing file gives the §10 defaults.
2. The screen edits: legal-move dots (on), animation length (120 ms, 0 allowed), board / pieces / sounds themes (brown, cburnett, the UI-003 default), volume (100%), threshold `τ` (2%), temperature `T` (1.0), panic intensity (medium), auto-claim threefold (on).
3. Each change takes effect without a restart.
4. Values persist across a restart.
5. An out-of-range or corrupt value falls back to its default; it never crashes.

#### Verification

    Manual: change each setting, restart, check it stuck.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_settings.gd`: defaults with no file, save and reload, a corrupt value falling back. Red because `core/settings.gd` does not exist.

## Comments

- Stage 2, harness fix: after 298b272 every assert of `test_a_corrupt_file_gives_the_defaults` held, but ConfigFile logs its own parse error for a corrupt file and the runner counts any logged error as a failure. The test now turns `Engine.print_error_messages` off around that one load. Red again by mutation: a store that sets volume 0 on a failed load fails it (`expected 100, got 0`), with three other tests.
- Stage 2, handoff. Cycles: f499917 red (`Preload file "res://core/settings.gd" does not exist`), 298b272 green except for the harness issue above, 8fff240 harness fix, 4ddb143 the screen and the wiring. Gate: 113 passed, 0 failed (107 before, plus 6 new).
- Interface: `core/settings.gd` is `Settings.new(path := "user://settings.cfg")`, `get_value(key)`, `set_value(key, value) -> bool` (saves at once, emits `changed(key, value)`, refuses out-of-range values), `valid(key, value)` static. Keys: `legal_dots`, `animation_ms`, `board_theme`, `piece_theme`, `sound_theme`, `volume`, `tau`, `temperature`, `panic`, `auto_claim`, in one `[settings]` section.
- My own judgement, no proxy: the ranges, which the spec does not give, are animation 0–1000 ms, volume 0–100%, `τ` 0–20%, `T` 0.1–3.0. A theme only has to be a non-empty name; the loaders already fall back on one that is missing. The BOT-003 note (a `T` above `T_max`, or `τ` below `τ_min`, makes panic steadier, not wilder) stays possible with these ranges; I did not narrow them to rule it out.
- Panic was never wired: Maia did not see its clock. For the panic setting to take effect, `MaiaPlayer.think(game, time_left, start_time)` now takes Maia's clock in ms and applies `MovePicker.panic`; without a start time (the old one-argument call in `test_maia_player.gd`) there is no panic, so those tests are unchanged. Its test sits in `tests/test_settings.gd`, because `tests/test_maia_player.gd` is not in Primary files.
- The screen opens from a Settings button in the top-right corner, over the setup screen or a game. While it is open it takes every key, so Esc closes it instead of resigning. Checked headless with a scratch script that drives `ui/main.tscn`: the 10 rows show, every edit reaches the board, the sounds, Maia and the game at once, and a new store reads them back. The theme lists come from `ThemeLoader.list_themes`; this lane has no `themes/` folder, so here each list holds only the current name.
- Not done: the manual check (change each setting, restart the app, see that it stuck) needs a person at the window.

Gate evidence: C:/Users/Lage/AppData/Local/Temp/claude/D--Desktop-Projects-P-Chess--artifacts-build-lanes-core/20e64fe9-c86c-4b42-8aea-7239294666af/scratchpad/UI-005-gate.json
