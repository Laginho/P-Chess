# LEARN-008: Pass test
Stage: to-implement
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
