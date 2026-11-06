# UI-038: A setting that fails to save is not reported as saved
Stage: done
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

#### Resolution (2026-11-06)
Verdict: Approve

- Standards: independent axis reviewed all eight changed files in `125f8b0...1fa746f`; no documented-standard violations or actionable smells. All production and test changes stay within Primary files. Commits `4e53561` / `231c286` and `3ab82bb` / `949e349` separate tests from production; `2a2af89` is a test-only harness correction.
- Spec: independent axis reviewed the complete diff and found no missing criteria, regressions or scope creep. The Home fixture now creates its settings directory because failed writes correctly return false.
- Examined callers and interactions: all production `Settings.set_value` calls in NameDialog, Profile, Settings and Main; `save_last_game` in Home/Main; Settings `_follow`, Main `_apply` / `_fit_board`, and the resize grip. Failure checks cover an unwritable destination, retained name/config/last-game state, no `changed`, inline errors and control restoration. Theme, volume, board and live-analysis preferences remain applied through successful `changed` notifications.

Criteria:

1. PASS: candidate values/config replace the old state only after a successful save; a failed save returns false before emitting `changed`. The failure/reload test preserves the old name and last game.
2. PASS: NameDialog stays open with an inline error; Profile retains its displayed name and explains failed persistence separately from an empty name.
3. PASS: checkbox, SpinBox and OptionButton restore stored values without sending another change signal. An additional headless probe submitted rejected Volume and scaled Threshold text; after layout their visible text was `20` and `2.0`, matching stored values.
4. PASS: Main `_resize_board` only requests the setting; `_apply("board_size", ...)` invokes `_fit_board` via `changed`. The grip requests a size without directly resizing the board. The required stage-2 finding is recorded above.
5. PASS: `save_last_game` warns and returns on failed save, preserving its old config and showing no UI.
6. PASS: successful writes still update state and emit `changed`; existing persistence and Settings-to-board tests passed in the recorded gate.
7. PASS: verified receipt command, exit status, tested commit, log SHA-256 and unchanged code at handoff, after the no-op session rebase and on integration. Reused the existing gate: 561 passed, 0 failed, exit 0; one pixel check and six live Lc0 checks were skipped. No gate rerun or production edits during review.

- Red/green evidence: stage 2 records failure-before-fix for both cycles above; the commit sequence independently confirms test/production separation. Review did not repeat those cycles.
- Additional execution: [headless review probe](C:/Users/bruno/AppData/Local/Temp/UI-038-review-probe.log), exit 0. Profile at 800x600 retained identical column dimensions after the error appeared; the error fits the name card. NameDialog's error and OK button have separate rectangles. This verifies layout geometry and visible control text, without a graphical capture.
- Reviewed existing `Proxy decided (opus-5.5 xhigh): 9 settled, 2 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-141649-audit-fixes-c4b5e4.json)`: Q6 requires every settings caller to preserve the saved value on failure; Q9 explicitly accepts automated failure-path checks without Windows manual acceptance.
- Reviewed existing `Proxy decided (opus-5.5 xhigh): 5 settled, 0 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-142124-audit-fixes-9f40af.json)`: Q14 selects directory-backed write failures and existing test seams. The implementation follows that decision.

Acceptance: pending | Automated checks and headless layout probe passed; graphical inspection and live Lc0 remain unrun. Manual Windows acceptance was explicitly waived for this batch by proxy Q9.
Disclosure: decision | none | [Spec decisions and test seams](../spec.md): failed writes preserve the prior state, every caller handles rejection, and automated failure checks are the agreed seam (proxy Q6/Q14).
Disclosure: pending | none | [Headless evidence](C:/Users/bruno/AppData/Local/Temp/UI-038-review-probe.log): no graphical inspection, actual disk-full/permission-error exercise or live Lc0 run; proxy Q9 accepts the automated seam without an integration/release hold.

- Integrated locally into `sweatshop/audit-fixes/2026-11-06-1433` with merge commit `ba99e930acf3978d892a399ec2d64e22be6acc49`. No push or ticket PR; the session driver owns publication.
