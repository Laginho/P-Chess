# UI-008: Start at 20 % volume
Stage: implementing
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - core/settings.gd (the `volume` default)
  - tests/test_settings.gd
  - docs/spec.md (§10 table, Volume row)

#### What to build

A first launch plays sounds at 20 % instead of 100 %. Full volume on top of the Windows volume is too loud (Bruno's QA, 2026-10-26). A saved volume is kept as it is.

#### Acceptance criteria

1. With no `settings.cfg`, `get_value("volume")` is 20, and Main sets the master bus to `linear_to_db(0.2)` at startup.
2. A saved volume (any value 0–100) still loads unchanged; an invalid saved value falls back to 20.
3. §10's Volume row reads `20 %`.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_settings.gd`: the existing default/fallback assertions expect 20; red because the default is 100.

## Comments

- 2026-10-26 Written from Bruno's first QA session (item 1).
