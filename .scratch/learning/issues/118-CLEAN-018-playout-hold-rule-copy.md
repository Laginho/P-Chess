# CLEAN-018: Keep the play-out hold rule text in sync with its tunable
Stage: done
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/playout.gd (the hold pass-rule text)
  - tests/test_course_screens.gd (the play-out start-screen seam)

#### What to build

The start screen currently advertises a literal "30 moves", while the judge uses `Tunables.COURSE_HOLD_MOVES`. They agree today. Derive the advertised hold limit from that same setting so a future tuning change keeps the rule the player sees accurate.

#### Acceptance criteria

1. The hold play-out start screen displays the configured `Tunables.COURSE_HOLD_MOVES` limit instead of a separate literal; changing the tunable for verification changes that visible number.
2. With the shipped limit of 30, the displayed pass/fail rules and play-out behavior remain the same.

#### Verification

    Focused start-screen test, including a temporary nondefault-limit mutation check.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_course_screens.gd`: at the existing play-out start-screen boundary, check the advertised hold limit against the configured rule; prove sensitivity by temporarily changing the tunable during verification. Before the production correction, the hardcoded copy stays at 30. Restore the shipped value after verification.

## Comments

- Criteria check by a fresh-context agent:
  - 1 ✅ `ui/playout.gd:117` uses `Tunables.COURSE_HOLD_MOVES`, as does the judge (`core/playout_judge.gd:41`); `tests/test_course_screens.gd:898` catches the old literal when the setting is changed.
  - 2 ✅ `ui/playout.gd:117` preserves both rule strings at the shipped limit; `tests/test_course_screens.gd:898` and `:901` check them exactly, and `tests/test_playout_judge.gd:24` and `:39` cover the unchanged pass behavior and 29/30 boundary. Preservation tests also pass the original code by design.
- Verification: with `COURSE_HOLD_MOVES` temporarily changed from 30 to 17, the committed screen test failed against the original UI (advertised 30 instead of 17); after the fix the focused screen test passed with both 17 and the restored 30. Full gate at commit `23d6170`: `godot --headless -s tests/run.gd`, 650 passed, 0 failed. Two pixel checks were skipped headlessly and six live Lc0 checks were skipped because the engine is absent. Log: `/run/media/lage/New Volume/Scratch/CLEAN-018/gate.log`.

Gate evidence: /run/media/lage/New Volume/Scratch/CLEAN-018/gate.json

- Triage by the driver: ready-for-agent — deriving the displayed limit from the judge's tunable removes a real maintenance mismatch while preserving the shipped rule.

- 2026-11-08 Opened by the LEARN-007 stage-3 Standards review, [original ticket](111-LEARN-007-play-outs.md). Nonblocking cleanup: the current value and numbered LEARN-007 contract both require 30, so there is no current implementation failure or release condition. No `Escaped-from` line: this is a maintainability suggestion, not a defect shipped by a previously closed ticket.

#### Resolution (2026-11-08)
Verdict: Approve

Standards: 0 findings. Independent Standards review checked the complete diff from `e4b6c64` through `91cffcd` against the repository instructions, domain vocabulary and course test strategy. The production and test changes stay within Primary files, use the approved visible-screen seam and retain separate test-first and production commits. No baseline code smell warrants a finding.

Spec: 0 findings. Independent Spec review confirms both numbered criteria:

- 1 ✅ `ui/playout.gd:117` formats the advertised limit from `Tunables.COURSE_HOLD_MOVES`, the same constant used by `core/playout_judge.gd:41`. `tests/test_course_screens.gd:898` checks the visible hold rule against that setting. The nondefault-limit verification proves sensitivity to a future tuning change.
- 2 ✅ The shipped constant remains 30, preserving the complete hold and convert rule strings, checked at `tests/test_course_screens.gd:898` and `:901`. Judge and game behavior are unchanged; existing judge tests cover promotion, mate, pawn capture, the 29/30 boundary, result changes and probe errors.

Affected callers, failure paths and interactions examined: normal presentation through `ui/main.gd::_show_playout`, engine-start failure through `_playout_start_failed` (which still replaces the rules with its error), repeated presentation when changing goals, and consistency with the shared judge and course spec L8. Live Lc0/Maia play, native Windows execution and graphical pixels were not exercised for this text change; the existing feature-level release check remains recorded in [LEARN-007](111-LEARN-007-play-outs.md).

Test-first proof: test-only commit `2f24a69` precedes production-only correction `23d6170`. Reviewed the [red log](</run/media/lage/New Volume/Scratch/CLEAN-018-red.log>): with the setting temporarily changed to 17, the original UI advertised 30, yielding 22 passed and 1 failed at the intended assertion. The implementation run log records the corrected focused test passing with both 17 and the restored 30. The shipped setting is restored in the committed tree.

Bound gate at `23d617035cbfdab4074da809c6541e537030e177`: `godot --headless -s tests/run.gd`, **650 passed, 0 failed**, exit 0. [Log](</run/media/lage/New Volume/Scratch/CLEAN-018/gate.log>) and [receipt](</run/media/lage/New Volume/Scratch/CLEAN-018/gate.json>). Existing skips: two headless pixel checks and six live Lc0 checks because the engine is absent. Reused this green run because code is unchanged; the official `Assert-GateEvidence` helper validated its command, tested commit, log SHA-256, exit marker and identical code after rebase. `git diff --check` passed.

No review fix, proxy decision, contract change or unresolved finding was introduced. Rebase onto `sweatshop/learning/2026-11-07-2234` was a no-op; merge `b238c12` integrates the reviewed branch without squash. This commit records the ledger entry and `Stage: done` together on the session branch and updates LEARN-007's cleanup disclosure to completed.

Acceptance: passed | Both criteria are verified by the visible-screen assertions, nondefault-limit red/green check and bound gate above. This cleanup adds no pending product check; the existing Maia release check remains tracked by LEARN-007.
