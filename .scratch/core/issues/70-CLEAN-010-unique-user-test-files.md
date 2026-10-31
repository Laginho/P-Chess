# CLEAN-010: Tests that write fixed file names in the shared user:// folder
Stage: to-implement
Status: needs-triage
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - tests/test_input_modes.gd (`SETTINGS_PATH := "user://test_ui006_settings.cfg"`)
  - tests/test_premove.gd (`SETTINGS_PATH := "user://test_ui007_settings.cfg"`)
  - tests/test_settings.gd (`PATH := "user://test_settings.cfg"`)
  - tests/test_time_model.gd (`MALFORMED := "user://time_model_malformed.json"`)

#### What to build

Godot's `user://` folder is shared by every checkout of the project on the machine. These four test files write, read and delete a fixed file name there, so two gates running at once (parallel lanes, review loops) can delete or overwrite each other's file mid-test and fail at random. The other storage tests already use a per-run name (`"user://test_book_%d" % Time.get_ticks_usec()`); PR #26 moved its own new tests (test_analyser.gd, test_uci.gd) to the same pattern.

Give each of these files a per-run name in the same pattern, removed when the test ends.

#### Acceptance criteria

1. No test under `tests/` opens, saves or deletes a fixed file name directly under `user://`; `grep -n '"user://[^"%]*\.\(cfg\|json\|txt\)"' tests/` finds nothing (`tests/test_themes.gd`'s `user://missing`, which is never written, is exempt).
2. Each test still removes its file at the end; assertions are unchanged.
3. The gate passes with the test count unchanged.

#### Verification

    godot --headless -s tests/run.gd

## Comments

- 2026-10-30 Opened by the PR #26 review loop: the human asked to fix the fixed `user://` names in that PR's tests (done there) and ticket the rest. Not a runtime defect; it only bites concurrent gates.
