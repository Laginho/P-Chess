# CLEAN-003: Consider shared cleanup for isolated history tests
Stage: blocked
Status: needs-triage
Blocked by: none
Review: agent
Difficulty: normal

- Primary files (proposed; stage 1 must confirm):
  - tests/test_history.gd (isolated-storage cleanup)
  - tests/test_session.gd (isolated-storage cleanup)
  - tests/test_premove.gd (isolated-storage cleanup)
  - tests/test_input_modes.gd (isolated-storage cleanup)
  - New: tests/history_storage.gd (shared test-only cleanup, if extraction is approved)

#### What to build

Consider consolidating the repeated cleanup of isolated History storage in the four scene-test harnesses. [HIST-001](21-HIST-001-history-stats.md) recorded this optional possible Duplicated Code observation in its first review and re-review. No runtime defect was found; a shared helper should be introduced only if it makes ownership and cleanup clearer.

#### Acceptance criteria (proposed)

1. Any approved extraction keeps cleanup restricted to each harness's owned storage root and its `games` child, tolerating absent directories without accessing normal player history or stats.
2. Existing isolated History injection, startup assertions and behavior assertions remain unchanged; no production code changes.
3. The bound gate passes with the refactored harnesses.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- Stage 1 must confirm whether this optional extraction is worthwhile, its helper seam and the applicable validation approach before implementation. Preserve the existing production-backed tests; do not invent a behavior failure for a mechanical cleanup refactor.

## Comments

- Created by HIST-001 stage 3 on 2026-10-25 to retain the non-blocking review observation in an open destination. The same directory-existence correction was previously needed in multiple harnesses. This follow-up does not block HIST-001 integration or release.
- Blocked for stage-1 triage and confirmation of the proposed scope and validation approach. No helper or refactor was implemented during review.
