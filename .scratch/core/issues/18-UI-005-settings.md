# UI-005: Settings store and screen
Stage: implementing
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
