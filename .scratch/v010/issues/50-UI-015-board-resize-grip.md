# UI-015: Board resize grip
Stage: implementing
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/main.gd (`_fit_board`)
  - ui/main.tscn
  - New: ui/resize_grip.gd
  - core/settings.gd (`board_size`)
  - ui/settings.gd (only if the setting needs a row)
  - tests/test_settings.gd
  - tests/test_board_view.gd
  - docs/spec.md (§8.7, §15.10)

#### What to build

A grip on the board's bottom-right corner lets you drag the board bigger or smaller (§8.7). The size is remembered.

#### Acceptance criteria

1. A grip shows on the board's bottom-right corner with the `nwse-resize` cursor.
2. Dragging it resizes the board; it stays square, the side panel takes the remaining width, and the board never drops below a minimum (a constant) nor grows past what the window fits.
3. The chosen size is saved in the `board_size` setting (default "Fit to window") and restored on the next launch, clamped to the current window.
4. Double-clicking the grip returns to fit-to-window; in fit-to-window the board follows window resizes as today.

#### Verification

    Manual: drag the board small, restart, check the size; double-click resets.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_settings.gd`: `board_size` defaults to fit and round-trips a saved size; an invalid value reads as the default (red: no key).
- `tests/test_board_view.gd` or a main scene test: a set size is clamped between the minimum and the fit size; fit mode follows a resize (red: no grip).

## Comments

- 2026-10-30 Written from spec §8.7 and §15.10.
