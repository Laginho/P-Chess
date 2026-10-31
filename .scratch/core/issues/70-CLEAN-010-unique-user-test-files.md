# CLEAN-010: Tests that write fixed file names in the shared user:// folder
Stage: done
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

- Stage 2: the criterion 1 filename scan was red on all four named paths before the change. This ticket changes test infrastructure only and adds no test methods; the pre-change tree declares 344 test methods.

- Verification: filename scan found no fixed direct user:// cfg/json/txt paths; 344 declared test methods before and after. Gate on 8e91384: 337 passed, 0 failed, exit 0; 6 of the reported passes were SKIPs because engine/lc0/lc0.exe is absent.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\CLEAN-010-gate.json

#### Resolution (2026-10-31)
Verdict: Approve

- Standards: no documented violations or actionable smells. Reviewed all five changed files, the runner's per-method instantiation, Settings persistence, scene injection and neighboring temporary-file patterns.
- Spec: all numbered criteria pass; no scope creep or changed assertions. The four test files are the only non-tracker changes, committed together as test infrastructure in 8e91384; 12a1b95 contains only handoff metadata. No production code or new test methods were introduced.
- Criterion 1: replayed the fixed direct-user:// filename scan against session base 6fa1205 and the reviewed tree: four matches before, none after. PID separates concurrent processes and ticks distinguish test instances within a process.
- Criterion 2: traced every use of the four paths through write, reload and removal, including the input-scene early-return cleanup. Existing cleanup remains; the eight settings tests using files now also remove them on completion. Assertions are unchanged.
- Criterion 3: reused the green gate on 8e91384 after validating its command, exit status, log SHA-256 and code equality with the reviewed and integrated trees. The log reports 337 passed, 0 failed, exit 0: 331 executed and six live-Lc0 tests skipped because engine/lc0/lc0.exe is absent. The unchanged textual count of 344 includes seven methods inside runner-fixture strings, leaving the same 337 runnable tests.
- Evidence: C:\Users\bruno\AppData\Local\Temp\CLEAN-010-gate.log and the receipt above. The filename scan and unchanged test bodies reproduce the red/green infrastructure proof without adding tests or rerunning unchanged code.
- Integration: rebase onto sweatshop/core/2026-10-31-0338 required no changes; merge 6fe3a24 preserves both implementation commits. No reviewer code fixes were needed.
- Coverage limits: static review and the recorded headless gate; simultaneous gate execution and live Lc0 behavior were not exercised. File-open failures and process crashes retain their existing cleanup behavior.

Acceptance: passed | Criteria 1-3 verified above; gate receipt binds the passing run to unchanged integrated code.
