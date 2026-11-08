# LEARN-008: Pass test
Stage: done
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
Gate evidence: /run/media/lage/New Volume/Scratch/LEARN-008-review-gate.json

#### Resolution (2026-11-08)
Verdict: Approve

Standards: 0 documented-standard violations, 1 nonblocking smell. The independent Standards review checked the full diff against AGENTS.md, the domain vocabulary, ADRs and the course testing decisions. All changes stay within Primary files plus tracker metadata. Each of the original 14 stage-2 commits separates tests from production; `ui/pass_test.gd` is a production screen, confirming the recorded driver false positive. Possible Duplicated Code: `_finish_test_playout` and `_test_playout_error` repeat `_playout_generation += 1`, clock cleanup, premove cancellation and input disabling. This maintainability judgement has no demonstrated contract failure and is tracked in [CLEAN-019](119-CLEAN-019-pass-test-playout-teardown.md), without refactoring during review.

Spec: 0 findings. The independent Spec review and integrating reviewer examined the complete diff and confirm all eight numbered criteria:

- 1 ✅ `PassTest.present_start` shows both parts, Start, and the previous score/date; the full screen scenario checks these visible controls.
- 2 ✅ `Course.draw_test_positions` selects only test-pool positions, uses fresh positions first and falls back to previous positions only when needed. Logic tests cover both cases.
- 3 ✅ `Solving.present_test` uses the shared grader, serializes Commit and advances without feedback or Retry. Visibility/generation guards discard cancelled asynchronous answers.
- 4 ✅ Test play-outs use `test_playouts`, `Clock("none")`, the probe's legal best move and the existing play-out judge. The screen test verifies the perfect reply without Maia requests and preserves answers when retrying a probe failure.
- 5 ✅ Threshold tests distinguish four from five correct and require both play-outs to pass.
- 6 ✅ The result card displays six marked boards, each miss's played/best move, both play-out outcomes, the failed-attempt Retry or mastery with review timing. Screen tests and the inspected captures cover these presentations.
- 7 ✅ The first mastered date survives later failures and reload; screen assertions check Mastered on the unit page and course map.
- 8 ✅ Completed attempts persist date, positions, score, play-out outcomes and pass/fail; tests check consecutive failed and successful attempts.

Affected callers, failure paths and cross-feature interactions examined: unit-part navigation, solving entry/grade signals, shared grader and play-out judge, perfect-opponent callbacks, probe errors and retry, stale-answer cancellation, Back navigation, course persistence, mastery presentation, sandbox shortcuts and History isolation. Missing test content and save refusal were checked by inspection. The real-tablebase manual attempt, native Windows execution and live Lc0 gameplay were not exercised; no additional material changed path remains unexamined.

Test-first proof: original test-only `221360f` precedes course implementation `c4cd8fa`; screen test `0c69ad4` precedes `3f27f10`. Inspected [missing-functions red evidence](</run/media/lage/New Volume/Scratch/learn-008-red.log>) and [missing-screen red evidence](</run/media/lage/New Volume/Scratch/learn-008-ui-red.log>). The replaced navigation assertion has its own [red proof](</run/media/lage/New Volume/Scratch/learn-008-nav-red.log>). [Mutation evidence](</run/media/lage/New Volume/Scratch/learn-008-mutant-red.log>) catches the wrong pass threshold and Maia replacing the perfect opponent; separate red logs cover disabled Retry controls.

Rebased onto `sweatshop/learning/2026-11-07-2234`, preserving all commits and both driver/foreman notes; only tracker metadata conflicted. The base's CLEAN-018 screen/test changes required a fresh gate. At `84d614e81d6e7307c72c741849fa8f977388a9df`, `godot --headless -s tests/run.gd` passed with **654 passed, 0 failed**, exit 0. [Log](</run/media/lage/New Volume/Scratch/LEARN-008-review-gate.log>) and [receipt](</run/media/lage/New Volume/Scratch/LEARN-008-review-gate.json>). The official `Assert-GateEvidence` helper validated the command, commit, log SHA-256 and exit marker. Existing skips: two headless pixel checks and six live Lc0 checks because the Windows engine executable is absent. `git diff --check` passed.

No production review fix, proxy decision or contract change was introduced. Merge `5fc2cc6` integrates the ticket without squash; this closure commits `Stage: done` and its ledger entry together on the session branch.

Acceptance: pending | The automated two-miss/retry/mastery scenario passed with a fake probe, and the [start](</run/media/lage/New Volume/Scratch/learn-008-capture/start2.png>) and [result](</run/media/lage/New Volume/Scratch/learn-008-capture/result2.png>) captures were inspected. The requested manual attempt against the real tablebase remains to be played.
Disclosure: pending | release | Before release, perform the manual Verification above: miss two positions in a real-tablebase attempt, finish the play-outs, retry and verify the new positions. Fake-probe screen coverage does not establish that complete real-helper interaction.
Disclosure: deferred | none | [CLEAN-019](119-CLEAN-019-pass-test-playout-teardown.md) tracks optional teardown sharing; it imposes no integration or release condition.
