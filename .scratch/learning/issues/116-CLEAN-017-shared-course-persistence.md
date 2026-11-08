# CLEAN-017: Share the course progress persistence sequence
Stage: to-implement
Status: needs-triage
Blocked by: LEARN-002
Review: agent
Difficulty: normal

- Primary files:
  - core/course.gd (the shared persistence sequence in save_rating and save_clock_choice)
  - tests/test_course.gd (existing persistence coverage, test-only)

#### What to build

`save_clock_choice()` repeats the read-preserve-write sequence already used by `save_rating()`: reread the current file, refuse overwriting unreadable data, preserve unrelated fields, write a temporary file, flush and rename it, then publish the in-memory progress. Consider sharing that sequence so future persistence fixes cannot drift between the two setters. Preserve player behavior.

#### Acceptance criteria

1. Rating and clock saves use one shared persistence sequence while retaining their distinct validation.
2. Both setters preserve unrelated progress and refuse invalid changes or overwriting unreadable data; a failed write leaves the previously published in-memory progress intact.
3. Existing rating conversion, stage selection and clock behavior stay unchanged, and the bound gate passes.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- No new test is required for behavior-preserving extraction alone. Existing `tests/test_course.gd` covers rating/clock persistence, validation, preservation and read failures; inspect both callers and run that coverage. Add a test-only regression first if triage identifies a concrete uncovered behavior defect.

## Comments

- 2026-11-08 Opened by the Standards review of [LEARN-002](106-LEARN-002-course-map-and-unit-page.md#resolution-2026-11-08): possible Duplicated Code in `core/course.gd:174–194`, compared with `save_rating()`. This is a maintenance judgment, not a criterion failure or an integration/release condition. The separate criterion-2 status defect remains on reopened LEARN-002.
