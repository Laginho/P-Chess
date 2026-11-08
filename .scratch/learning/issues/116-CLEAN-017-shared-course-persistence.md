# CLEAN-017: Share the course progress persistence sequence
Stage: to-review
Status: ready-for-agent
Blocked by: LEARN-002
Review: agent
Difficulty: normal

- Primary files:
  - core/course.gd (the shared persistence sequence in save_rating, save_clock_choice and open_theory)
  - tests/test_course.gd (existing persistence coverage, test-only)

#### What to build

`save_clock_choice()` and `open_theory()` repeat the read-preserve-write sequence used by `save_rating()`: reread the current file, refuse overwriting unreadable data, preserve unrelated fields, write a temporary file, flush and rename it, then publish the in-memory progress. Share that sequence so future persistence fixes cannot drift. Preserve player behavior.

#### Acceptance criteria

1. Rating, clock and theory saves use one shared persistence sequence while retaining their distinct validation.
2. All three operations preserve unrelated progress and refuse invalid changes or overwriting unreadable data; a failed write leaves the previously published in-memory progress intact.
3. Existing rating conversion, stage selection and clock behavior stay unchanged, and the bound gate passes.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- No new test is required for behavior-preserving extraction alone. Existing `tests/test_course.gd` covers rating/clock persistence, validation, preservation and read failures; inspect both callers and run that coverage. Add a test-only regression first if triage identifies a concrete uncovered behavior defect.

## Comments

- 2026-11-08 Opened by the Standards review of [LEARN-002](106-LEARN-002-course-map-and-unit-page.md#resolution-2026-11-08): possible Duplicated Code in `core/course.gd:174–194`, compared with `save_rating()`. This is a maintenance judgment, not a criterion failure or an integration/release condition. The separate criterion-2 status defect remains on reopened LEARN-002.

- 2026-11-08 [LEARN-003 closing review](107-LEARN-003-theory-pointer.md#resolution-2026-11-08): `open_theory()` at `core/course.gd:197–226` adds a third caller of the same read-preserve-write/flush/rename sequence. Include it when triaging this optional extraction and preserve its validation, unrelated unit progress and corrupt-file refusal. No current behavior defect or integration/release condition was found; this note leaves the contract for stage-1 triage to settle.

- Triage by the driver: ready-for-agent — all three operations repeat the same persistence sequence; sharing it reduces drift while preserving each operation's validation. Include theory in the contract and existing public-interface coverage. No concrete behavior defect was identified, so extraction needs no new regression test.

- Stage 2 starts with existing public-interface tests: the cleanup changes structure only, so there is no new behavior to make red. Callers are the rating dialog and profile, the unit clock control, and the theory pointer; validation and failure return values stay unchanged.

- Stage 2 criteria check (independent read-only subagent):
  - 1 ✅ `core/course.gd:58`, `:66`, `:215`, `:224` route all three operations through the same persistence sequence, retaining their validation. Structural sharing is verified by inspection; the prior implementation had the same behavior, so there is no meaningful behavior test that fails solely without the extraction. `tests/test_course.gd:36`, `:140`, `:209` exercise the three public operations.
  - 2 ✅ `core/course.gd:66` rereads progress, applies the validated change and publishes only after flush and rename; existing tests at `tests/test_course.gd:56`, `:73`, `:140`, `:209` exercise preservation and corrupt-file refusal. Existing tests do not force a write or rename failure or exercise invalid theory IDs and malformed nested unit dictionaries; those paths were checked against the unchanged prior behavior by inspection.
  - 3 ✅ `core/course.gd:49`, `:101`, `:211` retain conversion, stage selection and clock behavior; `tests/test_course.gd:36`, `:95`, `:140` exercise them. The bound gate passed.
- Resolution: shared the reread, validation callback, temporary write, flush, rename and in-memory publication sequence for rating, clock and theory. `godot --headless -s tests/run.gd` passed 603 tests, 0 failed; two graphical pixel checks and six live Lc0 checks were skipped in this environment. No new test was added for this behavior-preserving extraction.
Gate evidence: /run/media/lage/New Volume/Scratch/CLEAN-017/gate.json
