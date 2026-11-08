# LEARN-008: Pass test
Stage: to-review
Blocked by: LEARN-004, LEARN-007
Review: agent
Difficulty: normal

- Primary files:
  - New: ui/pass_test.gd, ui/pass_test.tscn (start screen and result card)
  - ui/solving.gd (a test mode: no Retry, no feedback until the end)
  - ui/playout.gd (a perfect-opponent mode)
  - ui/main.gd (wiring the test flow)
  - core/course.gd (drawing positions, recording attempts, the mastered date)
  - core/tunables.gd (`COURSE_TEST_POSITIONS`, `COURSE_TEST_PASS`)
  - tests/test_course.gd
  - tests/test_course_screens.gd
  - scripts/screens.gd (`BOARDS`: TestStart, TestResult)

#### What to build

The unit's last part (spec §L8, design `TestStart.dc.html`, `TestResult.dc.html`): 6 test-pool positions solved on the solving board, then one convert and one hold against the perfect opponent (the probe's best move) with no clock, then a result card. Passing masters the unit.

#### Acceptance criteria

1. The start screen shows the two steps and the last attempt (score and date) if any; Start test begins.
2. An attempt draws `COURSE_TEST_POSITIONS` (6) test-pool positions, preferring ones not used in the previous attempt, never practice positions.
3. Each position allows one commit, graded as in LEARN-006, with no feedback or Retry between positions.
4. The two play-outs use the test play-out positions, no clock, and the perfect opponent: each of its moves is the probe's best move. Fail and pass rules are LEARN-007's.
5. The attempt passes with at least `COURSE_TEST_PASS` (5) positions right and both play-outs passed.
6. The result card shows each position as a small board with ✓/✗, each miss with your move and the best one, each play-out with its outcome, and either "Unit mastered" (with when the review checks come) or "Not passed yet" with Retry with new positions.
7. A pass records the mastered date; the course map and unit page show the unit mastered. A later failed attempt doesn't remove mastery.
8. Every attempt is recorded (date, positions, result).

#### Verification

    Manual: take the test and miss two positions on purpose; retry and check the positions changed.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_course.gd`: drawing 6 from the test pool avoids the previous attempt's positions when the pool allows; pass threshold; mastered date recorded once and kept after a later fail (red: no test functions).
- `tests/test_course_screens.gd`: a full attempt with a fake probe ends on the result card with the misses listed (red: no screen).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L8.

- 2026-11-08 Stage stopped (incomplete handoff): Invalid committed handoff: test and production in one commit: 6e3dd50e mixes ui/pass_test.gd with scripts/screens.gd; e286bb1e mixes ui/pass_test.gd with ui/main.gd; 3f27f10b mixes ui/pass_test.gd with ui/main.gd. Split it; a test fixture kept beside production goes in the binding's `Test files:`. See /home/lage/Projects/P-Chess/.artifacts-build/lanes/learning/.scratch/run-log/LEARN-008-implement-20261108-045850.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.
- 2026-11-08 Foreman: the incomplete-handoff park above is a driver false positive. `driver.ps1`'s `$TestFiles` pattern `[._-](test|spec)\.[^/.]+$` classifies the production screen `ui/pass_test.gd` as a test file. Checked each of the 14 stage-2 commits (`221360f`..`2891082`): every one touches only `tests/` or only production (`ui/`, `scripts/`, `core/`) plus the tracker. Branch `LEARN-008` is intact at `to-review`, gate 654/0 per the handoff. Restored `to-review` for stage 3; no work redone.
- Stage 2: updated `test_course_navigation_unit_progress_and_clock` because opening the test replaces the former behavior of leaving the unit page visible. The updated assertion was proved red against the pre-implementation main screen.
- Stage 2: the independent criterion check identified missing probe-error handling and game-shortcut isolation; both were fixed and covered by red/green tests. Retry, threshold, and opponent tests were also checked against targeted mutants.
- Criterion 1 ✅ `ui/pass_test.gd:108`, `ui/main.gd:606`; `tests/test_course_screens.gd:7` checks both steps, Start, and prior score/date.
- Criterion 2 ✅ `core/course.gd:201`; `tests/test_course.gd:4` checks test-only draws, disjoint retry, and fallback when fresh positions are scarce.
- Criterion 3 ✅ `ui/solving.gd:127`, `ui/main.gd:618`; `tests/test_course_screens.gd:7` checks grading and no feedback, while `tests/test_course_screens.gd:668` exercises shared asynchronous commit serialization and cancellation.
- Criterion 4 ✅ `ui/main.gd:633`, `ui/main.gd:1110`, `core/playout_judge.gd:16`; `tests/test_course_screens.gd:7` and `tests/test_course_screens.gd:110` cover test positions, outcomes, no clock, perfect reply, and probe-error retry.
- Criterion 5 ✅ `core/course.gd:224`; `tests/test_course.gd:49` checks four versus five correct and both play-outs.
- Criterion 6 ✅ `ui/pass_test.gd:122`; `tests/test_course_screens.gd:7` checks six marked boards, misses, outcomes, retry and review timing.
- Criterion 7 ✅ `core/course.gd:125`, `core/course.gd:248`; `tests/test_course.gd:4` checks mastery survives a later failure and reload, and `tests/test_course_screens.gd:7` checks the unit and map.
- Criterion 8 ✅ `core/course.gd:224`, `ui/main.gd:663`; `tests/test_course.gd:4` and `tests/test_course_screens.gd:7` check recorded dates, positions, outcomes and results.
- Verification: `godot --headless -s tests/run.gd` passed, 654 passed and 0 failed. Headless pixel checks and live Lc0 tests were skipped where a display or Windows executable was unavailable. TestStart and TestResult captures were generated and inspected under Xvfb; a two-miss retry was exercised through the screen test with a scripted probe, not manually played against the real tablebase.
Gate evidence: /run/media/lage/New Volume/Scratch/LEARN-008-gate.json
