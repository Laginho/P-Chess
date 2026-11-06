# UI-038: A setting that fails to save is not reported as saved
Stage: to-review
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - core/settings.gd (`set_value`, `save_last_game`)
  - ui/name_dialog.gd (:48), ui/profile.gd (:180) (player name)
  - ui/settings.gd (:80, :91, :112, the controls that call `set_value`)
  - ui/main.gd (:572, `board_size`)
  - tests/test_settings.gd, tests/test_profile.gd, tests/test_home.gd

#### What to build

Spec: `.scratch/audit-fixes/spec.md`. Audit finding 4. `set_value` ignores the result of `ConfigFile.save()`, then emits `changed` and returns true. So the name dialog and Profile accept a name that is gone after a restart. Its doc comment already promises "False, with nothing changed"; make that hold for a failed write too.

#### Acceptance criteria

1. When the settings file cannot be written, `set_value` returns false and emits no `changed`. `get_value` and the in-memory config still hold the previous value.
2. The first-name dialog and Profile show the failure inline, using the error pattern each already has, and keep the previous name.
3. When `set_value` returns false, the Settings screen controls show the stored value again. No control is left showing a value that was not saved.
4. `board_size` in `ui/main.gd`: stage 2 checks whether the resize is applied through `changed` or directly. After a failed save, the board size on screen and the stored value must match. Record the finding in Comments.
5. `save_last_game` checks the save result and calls `push_warning` on failure, with no UI.
6. A successful write behaves as today: applied immediately, with `changed` emitted.
7. Gate green.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- tests/test_settings.gd: put a directory where the settings file goes, then call `set_value("player_name", …)`. It returns false and emits nothing. `get_value` and a freshly loaded `Settings` both return the old name (red: it returns true). The same failure in `save_last_game` leaves `last_game()` unchanged.
- tests/test_profile.gd, or the name-dialog test in tests/test_home.gd: a failed name save shows the inline error and keeps the old name.

## Comments

- 2026-11-06 Written from the grill ([spec](../spec.md)).
- Proxy decided (opus-5.5 xhigh): 9 settled, 2 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-141649-audit-fixes-c4b5e4.json)
- Proxy decided (opus-5.5 xhigh): 5 settled, 0 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-142124-audit-fixes-9f40af.json)

- 2026-11-06 Stage 2: `_resize_board` writes only through `set_value`; `_fit_board` runs on the `changed` signal, so a failed save leaves the displayed board size unchanged.
- Red/green: failed writes and UI recovery were tested before their respective fixes. The first full gate exposed `test_searching_keeps_long_player_name_inside_card_at_minimum_window` using a nonexistent settings folder; its test setup now creates the folder and asserts the write succeeds. Focused Home: 13 passed, 0 failed.
- Verification: final gate 561 passed, 0 failed, exit 0. One graphical pixel check and six live Lc0 checks skipped (no display / no engine). Log: C:/Users/bruno/AppData/Local/Temp/UI-038-gate-final.log.
- Acceptance: pending | Graphical inspection of inline errors and live Lc0 checks were not run.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/UI-038-gate-final.json
