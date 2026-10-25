# CLEAN-007: Consider the shared History cleanup in the remaining scene-test harnesses
Stage: blocked
Status: needs-triage
Blocked by: CLEAN-003
Review: agent
Difficulty: normal

- Primary files (proposed; stage 1 must confirm):
  - tests/test_review.gd (isolated-storage cleanup)
  - tests/test_clock_input_order.gd (isolated-storage cleanup)
  - tests/history_storage.gd (only if stage 1 widens the helper for `openings`/`repertoires` children)
  - tests/test_badges.gd (`_clean`, only if the helper is widened)
  - tests/test_book.gd (`_clean`, only if the helper is widened)

#### What to build

[CLEAN-003](34-CLEAN-003-history-test-cleanup.md) moved the isolated History cleanup of four harnesses into `tests/history_storage.gd`. Two more harnesses outside its Primary files still carry the identical inline `tree_exiting` lambda (`games` child then root): `tests/test_review.gd` and `tests/test_clock_input_order.gd`. `tests/test_badges.gd` and `tests/test_book.gd` keep their own `_clean` helpers, which also remove `openings` (and in badges `repertoires`) children, so they match the helper only if it is widened. No runtime defect was found.

#### Acceptance criteria (proposed)

1. Each migrated harness keeps cleanup restricted to its own storage root and the children it already removed, tolerating absent directories, without touching normal player history, stats, books or repertoires.
2. Existing isolated injection, startup assertions and behavior assertions remain unchanged; no production code changes.
3. The bound gate passes with the refactored harnesses, unchanged in test count.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- Stage 1 must confirm the scope (the two identical lambdas only, or a widened helper for badges/book) and the validation approach. Preserve the existing production-backed tests; do not invent a behavior failure for a mechanical cleanup refactor.

## Comments

- Created by CLEAN-003 stage 3 on 2026-10-25 to give the remaining duplicates an open destination: the two identical lambdas found by the review's grep, plus stage 2's out-of-scope note on test_badges/test_book. Optional Duplicated Code observation; does not block CLEAN-003 integration or release.
- Blocked for stage-1 triage and confirmation of the proposed scope. No refactor was implemented during review.
