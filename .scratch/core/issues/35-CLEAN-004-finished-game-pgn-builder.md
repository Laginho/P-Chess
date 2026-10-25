# CLEAN-004: Consider shared finished-game PGN construction
Stage: blocked
Status: needs-triage
Blocked by: none
Review: agent
Difficulty: normal

- Primary files (proposed; stage 1 must confirm):
  - core/history.gd (finished-game PGN construction)
  - ui/review.gd (clipboard PGN construction)
  - core/pgn.gd (shared pure builder, if extraction is approved)
  - tests/test_history.gd, tests/test_review.gd, tests/test_pgn.gd (existing export assertions and any approved shared-builder seam)

#### What to build

Consider sharing the finished-game headers and per-move clock-record construction currently repeated in History.save and Review._game_pgn. [HIST-002](22-HIST-002-review-screen.md) recorded this optional possible Duplicated Code observation during stage-3 review. The current exports agree for Main's supplied metadata; this is a maintainability consideration, not a demonstrated defect. Introduce a shared builder only if it makes the two callers clearer and preserves their existing responsibilities.

#### Acceptance criteria (proposed)

1. Any approved extraction preserves player colours/names, time control, result, termination, exact per-move clocks and History's optional Opening header.
2. Saved and copied PGNs continue to represent the current game after a rematch. Existing history write-error behavior and review export actions remain unchanged.
3. Existing production-backed PGN round-trip and session tests, plus the bound gate, pass.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- Stage 1 must confirm whether extraction is worthwhile, its file boundary, test seam and proportionate validation before implementation. Preserve existing behavior assertions; do not invent a behavior failure for a mechanical extraction.

## Comments

- Created by HIST-002 stage 3 on 2026-10-25 as the open destination for the optional duplicated-PGN-construction observation. No refactor was performed during review, and this follow-up does not block HIST-002 integration or release.
- Blocked for stage-1 triage and confirmation of the proposed scope and validation approach.
