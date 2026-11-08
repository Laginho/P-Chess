# CLEAN-016: Reuse the shared rating validator in the dialog
Stage: to-review
Status: ready-for-agent
Blocked by: LEARN-001
Review: agent
Difficulty: normal

- Primary files:
  - ui/rating_dialog.gd (rating validation only)
  - tests/test_home.gd (existing course dialog validation coverage, test-only)

#### What to build

The rating dialog repeats the 100–3500 bounds already owned by `Course.valid_rating`; Profile calls that shared validator. Reuse the same domain validation in the dialog so changes to the accepted rating cannot drift between the two screens. Preserve all current player behavior.

#### Acceptance criteria

1. The dialog uses `Course.valid_rating` with the entered integer and selected site instead of duplicating the numeric bounds; non-integer text is still rejected before conversion.
2. Empty text, non-numeric text, fractions and values outside 100–3500 keep Start the course disabled; both endpoints remain valid, chess.com remains the default, and lichess retains its conversion hint.
3. The gate passes without changing course persistence, Profile or sandbox behavior.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None required for this behavior-preserving reuse of an existing validator. `tests/test_home.gd::test_course_requires_a_valid_rating_before_starting` already covers the invalid inputs, both boundaries, default site, conversion hint and persistence. Inspect delegation and run the existing gate; do not add an implementation-mirroring test.

## Comments

- 2026-11-08 Opened by the Standards review of [LEARN-001](105-LEARN-001-rating-sentence.md#resolution-2026-11-08): possible Duplicated Code smell in `ui/rating_dialog.gd:38`, compared with `core/course.gd:30` and `ui/profile.gd:183`. This is a maintenance judgement, not a failed acceptance criterion; no integration or release condition. The LEARN-001 closing reviewer deferred it to this triage ticket under the stage-3 scope rule.

- Triage by the driver: ready-for-agent — reuse removes duplicated rating bounds and matches Profile; existing integration coverage protects the current behavior.
- Stage 2: no new test required by the ticket; existing `test_course_requires_a_valid_rating_before_starting` covers the retained behavior. `_update` is called on initialization, presentation, input and site changes, and before save.
- Independent criteria check (read-only agent):
  - ✅ 1: `ui/rating_dialog.gd:5,42` checks integer text before delegating the entered number and selected site to `Course.valid_rating`. Existing behavior tests cannot distinguish equivalent delegation; inspected as specified by the ticket.
  - ✅ 2: `ui/rating_dialog.gd:24-25,42-47`; `tests/test_home.gd:356-369` covers default site, invalid values, endpoints and hint text. Hint visibility was inspected in code.
  - ✅ 3: `ui/rating_dialog.gd:50-54`; `tests/test_home.gd:370-381` covers persistence, sandbox level and Profile display. Gate `godot --headless -s tests/run.gd`: 603 passed, 0 failed (commit 802bcfc).

Gate evidence: /run/media/lage/New Volume/Scratch/p-chess-gates/CLEAN-016-802bcfc.json
