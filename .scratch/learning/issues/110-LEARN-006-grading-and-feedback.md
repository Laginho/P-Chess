# LEARN-006: Grading a line, and the feedback
Stage: done
Blocked by: CI-005, LEARN-005, LEARN-010
Review: agent
Difficulty: hard
Gate evidence: /run/media/lage/New Volume/Scratch/LEARN-006/gate.json

- Primary files:
  - New: core/grader.gd (grading a committed line against a probe, spec §L6)
  - core/course.gd (recording commits: solved, first try)
  - core/tunables.gd (`COURSE_DTZ_MARGIN`)
  - ui/solving.gd, ui/solving.tscn (the feedback state)
  - ui/board_view.gd (only if the playback needs a hook it lacks)
  - ui/main.gd (creating LEARN-010's probe beside the other engines)
  - New: tests/test_grader.gd
  - tests/test_course.gd
  - tests/test_course_screens.gd
  - scripts/screens.gd (`BOARDS`: SolvingFeedback)

#### What to build

Commit grades the line by tablebase and shows the feedback designed in `SolvingFeedback.dc.html` (spec §L6, §L7). The probe is LEARN-010's (`engine/tablebase.gd`, spec §L5); the grader only talks to its answers, so tests use a fake. The line plays back one ply at a time with ✓/✗ on your moves; at the first ✗ it stops and shows the correct move and line; Next and Retry follow. The course records solved and first try.

#### Acceptance criteria

1. `ui/main.gd` creates LEARN-010's probe beside the other engines and frees it with them. Commit asks the probe about the positions of the line, and the grader reads only its answers: the result for the side to move, each legal move's result and distance to zeroing, and the best move.
2. A move of yours passes when the result for your side after it equals the result before it and, when that result is a win, its distance to zeroing is at most the best move's plus `Tunables.COURSE_DTZ_MARGIN`. Any other move of yours fails. A hold position's every drawing move passes. Distances are the probe's root-move distances in plies (a zeroing move that keeps the win is 1). `COURSE_DTZ_MARGIN` is in plies and at least 1, because Syzygy distances can be one ply high (RES-001).
3. Opponent moves in the line never fail it; where the probe has a strictly better defence than the one entered (a better result for the defender, or the same loss with a larger distance), the feedback shows "Better defence: <SAN>" beside it.
4. Grading stops at your first failing move; moves after it are shown greyed and unmarked.
5. The correct line shown after a ✗ starts with the probe's best move at that point and continues with best moves for both sides up to the position's line length.
6. Feedback plays the line back on the board ply by ply, each of your moves gaining ✓ or ✗; at the first ✗ the board shows the position before it with an arrow for the correct move.
7. The banner says "Solved, first try", "Solved" or "Not solved" with the reason (result changed, or too slow); Retry clears the line on the same position, Next opens the next position (the same rule as LEARN-005 criterion 9).
8. The first commit of a position records first try if it passes; any passing commit records solved; a later pass never records first try. The unit page's solved count and first-try rate update.
9. When every practice position is solved, the solving part shows done and Continue moves on.
10. If the probe fails (engine or files missing), Commit shows an error and records nothing.

#### Verification

    Manual, with LEARN-010's helper built and the tables present: in the Lucena position, commit a correct line, then a line with a slow detour; retry it correctly; check the unit page counts.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_grader.gd`: with a scripted fake probe: a result-keeping line passes; a result-changing move fails; a winning move over the margin fails ("too slow"); an opponent's weaker defence passes with the better one reported; grading stops at the first failure; exactly best + margin passes, best + margin + 1 fails "too slow"; an equally good defence shows no "Better defence" (red: no grader).
- `tests/test_course.gd`: first try only on the first commit; solved on any pass; solving done when all are solved (red: no recording).
- `tests/test_course_screens.gd`: committing with a fake probe shows the feedback state with ✓/✗ and Retry/Next; a fake probe answering `ok = false` shows the error on Commit and records nothing (red: no feedback state).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L5–§L7. `hard`: the grading rules interact (result, margin, stopping) and the probe parses engine output. How the probe gets a distance per move depends on RES-001; if RES-001 says Stockfish can't give it, this ticket uses RES-001's alternative and says so in its first commit.

- 2026-11-07 RES-001 review follow-up (integration condition): Stockfish 19 computes root-move DTZ internally but does not expose it through UCI scores. RES-001 recommends evaluating Fathom (MIT); that requires a native adapter/helper, packaging and tests absent from this ticket's Primary files and fake-UCI seam. Before implementation, reconcile spec L5, criterion 1 and the test seam through stage 1/the proxy; preserve the DTZ-margin requirement unless Bruno approves a product change. Do not infer DTZ from centipawns or silently replace a failed tablebase probe with engine evaluation. This comment records the open decision, not approval to change the contract. See `docs/research/tablebase.md` and RES-001's dated Resolution.

- Proxy decided (opus-5.5 xhigh): split (B). The native probe becomes a new prerequisite ticket, LEARN-010, and LEARN-006 stays `to-implement` but gets `Blocked by: LEARN-010`. Stage 2 of LEARN-006 stops this session without code; LEARN-010 can run next — The probe is shared by LEARN-006, LEARN-007, LEARN-008 and REV-011 (spec L5 says everything that grades uses one probe). Folding a C build, a Windows release step and a helper protocol into an already `hard` ticket would mix that risk with the grading screens. (receipt /tmp/sweatshop-proxy/20261108-020737-LEARN-006-0937d8.json)

- 2026-11-08 Contract reconciled before implementation: [LEARN-010](117-LEARN-010-tablebase-probe.md) owns the shared native probe, its fake-UCI and real-file seams, build and Windows packaging. LEARN-006 consumes that interface and preserves its grading/feedback scope, DTZ margin and error-without-recording requirement. Stage 2 stops here without code or a ticket branch, as the proxy directed; resume LEARN-006 after LEARN-010 is done. RES-001/CI-005's Windows Stockfish check still verifies table loading; LEARN-010 adds acceptance for the application's actual probe path, pending Bruno before release.

- 2026-11-08 Attempt 1 failed: exit 0. Log tail: LEARN-006 permanece `to-implement`, aguardando o novo [LEARN-010](/home/lage/Projects/P-Chess/.artifacts-build/lanes/learning/.scratch/learning/issues/117-LEARN-010-tablebase-probe.md), que fornecerá DTZ exato via Fathom. /  / O proxy aprovou a separação. Tickets e especificação atualizados no commit `703fe57`; recibo e dependências validados. Apenas documentação mudou. /  / A [skill ticket-flow](/home/lage/.agents/skills/ticket-flow/SKILL.md) determina parar quando “the ticket needs more than one seam (back to stage 1)”. Próxima etapa: **LEARN-010**.

### Stage 2 (2026-11-08)

- LEARN-010 is done and merged into the learning session. Implementing on `LEARN-006` from `d4b6190`; no contract change.
- Callers/boundaries before tests: the new grader consumes only `probe(fen, callback)` answers; Course readers are unit/map/solving and future Continue. Solving Commit currently emits an unhandled line signal; existing entry tests cover repeated commits without a configured probe. Main owns engine nodes. Boundaries to preserve: black-first SAN, empty practice, exact DTZ margin, draw/terminal positions, failed reads/writes, asynchronous errors, repeated Commit, Back/Retry/Next during pending callbacks, and reopening an already solved position. Approved seams: scripted probe/grader, Course public persistence/progress, scene controls with a fake probe.

- Course test harness correction: JSON reload returns numeric counts as floats, so the reloaded commit count is compared as a number separately from the boolean fields, instead of a type-strict dictionary comparison. The original red (`13 passed, 1 failed`) proved the missing public recording method; the corrected assertion preserves that regression.


#### Implementation and red/green evidence

- `c350f38` (test-only plus ticket) **0 passed, 1 failed** → `2596f45` (production-only) **1 passed, 0 failed**: a committed result-keeping line is graded through scripted probe answers.
- `adc3eaf` (test-only) **1 passed, 4 failed** → `b2535ae` (production-only) **5 passed, 0 failed**: result changes, exact/over-margin root DTZ, all drawing moves, strictly better/equal opponent defences, first-failure stopping, best continuation and probe errors (including correction).
- `1d7e2c5` (test-only) **13 passed, 1 failed**, missing recording → `1edf979` (production-only) adds atomic commit recording. The JSON numeric comparison correction is documented above and committed separately in `661660d`; corrected Course suite **14 passed, 0 failed**. Existing progress is preserved, solved is cumulative, and later passes cannot acquire first try.
- `d83668a` (test-only) **8 passed, 3 failed**, missing feedback → `8ded8f5` (production-only) **3 passed, 0 failed** for the new feedback methods; the combined grader/Course/course-screen suite then passed **30 passed, 0 failed**. Main owns the shared adapter; Commit starts it lazily. Feedback reveals marks using a Timer, stops before failure with the correct arrow/line, provides Retry/Next, and records only a complete successful grade. Repeated Commit is serialized; stale callbacks after leaving the screen do not record.
- Capture fixture correction `583c344` uses a legal black defence. `scripts/screens.gd` now accepts `SolvingFeedback` with `miss` (default) and `solved` states. Both 1280×800 captures were generated offscreen via Xvfb with isolated data roots and visually inspected: `feedback-miss.png` and `feedback-solved.png` in the evidence directory.
- Independent criterion check identified an actual playback boundary miss: `Game.play()` stopped after an automatic draw while the entered/graded Board sequence continued. `80a3552` (test-only) **0 passed, 1 failed**, reproducing both capture to bare kings and halfmove 99→102 → `27039da` (production-only) **4 passed, 0 failed** for feedback regressions. Playback now advances the already validated Board sequence. Normal Game rules are unchanged. The independent original seven-ply reproduction now reaches its expected final FEN.
- `b6f189f` strengthens correction tests: full five-ply best continuation from a later failure, actual mate termination, and root DTZ=1. Grader suite **6 passed, 0 failed**. A one-ply correction mutant fails **4 passed, 2 failed**; removing mate termination fails **5 passed, 1 failed**. This replaces the earlier fake terminal answer at a position with legal moves.
- `7aab497` adds Main construction/child ownership/injection/Commit-start/free and rendered `Better defence` regressions: **2 passed, 0 failed**. Independently removing injection, startup, child ownership or rendered advice makes its respective test fail (**0 passed, 1 failed** each). All temporary mutations were restored before the gate. These coverage additions are test-only commits.

#### Independent criteria check

Fresh-context read-only checker `criteria_check` examined the full ticket and `d4b6190..7aab497`, independently exercised all 13 relevant committed methods successfully across focused runs, and rechecked criterion 6 after its repair. It also verified that callbacks after screen destruction do not record or log script errors. No remaining concrete miss. Evidence: `/run/media/lage/New Volume/Scratch/LEARN-006/criteria-check/`.

- ✅ 1: `ui/main.gd:34,161–163` constructs/owns/injects the shared adapter; `ui/solving.gd:128–133` starts it on Commit; `core/grader.gd:38–44` reads only its position/move answers. Regression: `test_main_owns_starts_injects_and_frees_the_solving_probe` and `test_result_keeping_line_passes_with_marks_on_own_moves`.
- ✅ 2: `core/grader.gd:48–52` compares mover results and root-move DTZ; `core/tunables.gd:39` sets a one-ply margin. Regression: `test_winning_distance_boundary_is_in_root_plies_and_draws_ignore_it` and `test_correction_stops_at_real_mate_and_zeroing_win_is_one_ply`.
- ✅ 3: `core/grader.gd:60–61` compares defender result / distance in a loss; `ui/solving.gd:226–227` renders the SAN advice beside the opponent move. Regression: `test_opponent_better_defence_is_advice_and_never_a_failure` and `test_feedback_shows_better_defence_beside_the_opponent_move`.
- ✅ 4: `core/grader.gd:24,53–59` leaves later plies grey/unmarked and stops grading; `ui/solving.gd:229` renders them grey. Regression: `test_first_failure_stops_marks_and_shows_best_line_for_both_sides` and `test_failed_feedback_stops_before_bad_move_with_arrow_and_grey_tail`.
- ✅ 5: `core/grader.gd:66–79` follows best moves for both sides from failure for up to 2N−1 plies. Regression: `test_first_failure_stops_marks_and_shows_best_line_for_both_sides` checks five plies from a later failure; `test_correction_stops_at_real_mate_and_zeroing_win_is_one_ply` checks actual mate truncation.
- ✅ 6: `ui/solving.gd:208,234–258` reveals marks ply by ply, stops before the failure and shows its best-move arrow. The independent check found that live `Game.play()` stopped at drawn positions; fixed in `27039da` after red regression `80a3552`. Regression: `test_commit_feedback_replays_marks_retry_next_and_updates_unit_counts`, `test_failed_feedback_stops_before_bad_move_with_arrow_and_grey_tail` and `test_feedback_replays_legal_hold_line_through_material_and_fifty_move_draws`. Independent seven-ply reproduction now reaches the expected FEN.
- ✅ 7: `ui/solving.gd:29–30,193–195` provides Retry/Next and the three banners/reasons; Next reuses `core/course.gd:202–208`. Regression: the passing/failing feedback scene tests plus existing `test_next_practice_prefers_unsolved_positions_from_games` cover the priority and solved fallback.
- ✅ 8: `core/course.gd:240–266` records commits without reclaiming first try or clearing solved status; `:137–174` derives counts. Regression: `test_commits_record_first_try_once_solved_forever_and_solving_done` checks reload/preservation/corrupt storage; passing/failing feedback scene tests check visible first-try rate and counts.
- ✅ 9: `core/course.gd:174` derives solving done; existing `ui/unit_page.gd:44,78–80` advances Continue past finished solving. Regression: `test_commits_record_first_try_once_solved_forever_and_solving_done` and `tests/test_course_screens.gd:458–466`. Home Continue remains LEARN-009.
- ✅ 10: `core/grader.gd:39–40,67–69` propagates errors before any recording; `ui/solving.gd:136–139,172–179` shows the error and restores entry. Regression: `test_probe_errors_even_in_correction_do_not_return_a_grade`, `test_probe_failure_and_cancelled_async_commit_record_nothing` and existing adapter missing-helper/file tests.

#### Real-file and visual verification

Final-code Linux Main→Solving→shared Fathom helper→bundled tablebase smoke passed. Lucena FEN `4K1k1/4P3/8/8/8/8/7r/R7 w - - 0 1`, N=2: the real probe chose `a1g1` (DTZ 9). Correct line `a1g1 g8h7 g1e1` passes; result-keeping detour `a1a6 h2b2 a6g6` fails as too slow (first move DTZ 11 > 9 + 1), leaves the board at the root and points to `a1g1`. Retry with the correct line says Solved; Next opens the second unsolved position, whose correct first commit says Solved, first try. Unit page reports **2 solved**, **50% (1 of 2)** first try and solving done. All checks passed (`REAL_SMOKE_ERRORS []`). Reproduction script `real-smoke.gd` and final log `real-smoke-final.log` live in `/run/media/lage/New Volume/Scratch/LEARN-006/`; run from the repository with `godot --headless -s '<absolute script path>'` and the helper/tables installed. The script uses isolated progress/history and cleans it afterwards.

Native Windows CI/release startup remains LEARN-010's previously documented release verification condition; this stage ran Linux, the approved fake-probe seams, real-file Lucena UI flow and offscreen captures. No new proxy decision or contract change. The existing approved LEARN-010 split is consumed as written.

#### Bound gate and handoff

Foreground bound gate at tested commit `7aab4973270048eb29c9be91d76f2499846717c4`: `godot --headless -s tests/run.gd`, **637 passed, 0 failed**, exit 0. All three real-file tablebase tests passed. Existing skips: two graphical-only pixel checks under headless and six live Lc0 methods because `engine/lc0/lc0.exe` is absent on this Linux checkout. Feedback was separately captured/inspected via Xvfb; the real tablebase/Lucena checks did run. Log: `/run/media/lage/New Volume/Scratch/LEARN-006/gate.log`. The `Gate evidence:` receipt records the tested commit and log hash. `git diff --check` passed.

Stage 2 hands off at `to-review` on `LEARN-006`. Only this tracker ticket changes after the tested commit. No merge or ledger entry; stage 3 reviews and integrates into `sweatshop/learning/2026-11-07-2234`.

### Stage 3 review and integration (2026-11-08)

#### Resolution (2026-11-08)
Verdict: Approve

Reviewed the full `d4b6190...ecb6903` diff and all 15 ticket commits, with independent read-only reviewers `/root/review_standards` and `/root/review_spec`. Neither reviewer nor the closing agent authored production repairs. All ten numbered criteria pass; no unresolved implementation finding or new contract change.

##### Standards

**0 findings.** The independent reviewer checked `AGENTS.md`, `CONTEXT.md`, the domain/tracker guidance, all ADRs, the learning design README and the code-review smell baseline. There is no `CODING_STANDARDS.md` or `CONTRIBUTING.md`. All changed production and test files are in Primary files; tracker edits preserve the separate Stage axis. Domain vocabulary and ADR boundaries are respected. Every commit separates tests from production; the original missing-behavior regressions and the held-draw repair have test-first evidence. Later test strengthening and the capture-fixture correction introduce no scope breach. Dictionary probe answers implement the approved interface, and scene lookups follow existing repository conventions; no substantive heuristic smell warrants a follow-up.

##### Spec

**0 findings.** The independent reviewer found no missing numbered requirement, scope creep or introduced regression. The closing agent confirmed the complete diff and callers, inspected both feedback captures, and repeated the real-file Lucena flow against Main's shared Fathom helper.

- ✅ 1: `ui/main.gd:34,161` constructs, parents and injects the adapter; `ui/solving.gd:128` starts it on Commit. `core/grader.gd:38` consumes only probe answers. The lifecycle regression checks construction, startup, injection and freeing.
- ✅ 2: `core/grader.gd:48` compares the mover's result and root-move DTZ with the one-ply margin in `core/tunables.gd:39`. Tests cover exact/over-margin boundaries, drawing moves and winning zeroing/mate DTZ 1.
- ✅ 3: `core/grader.gd:60` reports strictly better defender results or longer losing defences without failing the line; `ui/solving.gd:226` renders the SAN advice. Both grading and visible-text regressions pass, including equally good defences without advice.
- ✅ 4: `core/grader.gd:53` stops at the first failure; untouched later plies remain unmarked and grey through `ui/solving.gd:229`. Grader and screen tests check the tail.
- ✅ 5: `core/grader.gd:66` follows both sides' best moves for the position's full line length, truncating at an actual terminal position. The five-ply correction and real mate regressions pass.
- ✅ 6: `ui/solving.gd:234` advances each validated ply, reveals marks, stops before a failed move and shows the best-move arrow. Both material-draw and 50-move-draw playback regressions pass; live Game rules remain unchanged.
- ✅ 7: `ui/solving.gd:29,193` supplies Retry, the existing next-unsolved/solved-fallback selection, all three banners and both failure reasons. Focused screen tests and the real Lucena flow cover retry and Next.
- ✅ 8: `core/course.gd:240` atomically records cumulative solved status and first try only on the first passing commit, preserving unrelated progress and existing first-try results. Course reload tests and the unit-page screen checks pass.
- ✅ 9: `core/course.gd:174` derives practice completion; `ui/unit_page.gd:44` selects Continue after solved/total reaches the practice-pool total. The recording and screen regressions verify completion and the following part.
- ✅ 10: `core/grader.gd:39,67` propagates probe errors, including during correction; `ui/solving.gd:136,172` returns to entry with the error and records nothing. Tests also cover duplicate Commit and delayed callbacks after leaving the screen.

Affected callers, failure paths and interactions examined: Main ownership/navigation, Solving entry/grading/feedback transitions, black-first SAN numbering, legal entry validation, exact DTZ boundaries, drawing moves, equal/weaker defences, terminal correction, playback after automatic draw thresholds, Retry/Next and reopening solved positions, progress reload/read/write failure preservation, asynchronous errors and stale callbacks, unit-page counts and Continue. The separately saved `from_your_game` collection does not change fixed practice-pool counts, consistent with LEARN-002 criterion 3 and spec L9/LEARN-009's separate Continue priority; its creation and Home integration remain REV-011/LEARN-009 work. Not exercised live: physical mouse/keyboard input, native Windows startup or Lc0. No new unresolved defect was identified in these boundaries.

Independent runtime verification: the Spec reviewer ran all six grader tests, the Course recording test and six feedback/lifecycle tests: **13 passed, 0 failed**, with no script errors ([script](</run/media/lage/New Volume/Scratch/LEARN-006/review/spec-check.gd>), [log](</run/media/lage/New Volume/Scratch/LEARN-006/review/spec-check.log>)). The closing agent independently reran [the real Lucena smoke](</run/media/lage/New Volume/Scratch/LEARN-006/real-smoke.gd>) with an isolated external data root: **14 checks passed**, `REAL_SMOKE_ERRORS []`, exit 0 ([review log](</run/media/lage/New Volume/Scratch/LEARN-006/review/real-smoke.log>)). The real best move was `a1g1` at DTZ 9; the DTZ-11 detour failed as too slow, its retry solved without first try, the next position solved first try, and Back refreshed the unit to 2 solved and 50% (1 of 2). Inspected [failed feedback](</run/media/lage/New Volume/Scratch/LEARN-006/feedback-miss.png>) and [solved feedback](</run/media/lage/New Volume/Scratch/LEARN-006/feedback-solved.png>); marks, correction arrow, banners and controls are visible.

Red/green proof retained: `c350f38` → `2596f45` establishes grading; `adc3eaf` → `b2535ae` adds the result/DTZ/defence/failure rules; `1d7e2c5` → `1edf979` adds durable recording (test-harness numeric correction in `661660d`); `d83668a` → `8ded8f5` adds feedback; `80a3552` → `27039da` repairs held-draw playback. The stage-2 evidence above records failing and passing counts; later test-only commits strengthen correction and lifecycle coverage. Primary-file scope and test/production separation pass across the full history.

Gate reused at tested commit `7aab4973270048eb29c9be91d76f2499846717c4`: `godot --headless -s tests/run.gd`, **637 passed, 0 failed**, exit 0. All three real-file tablebase tests ran. Existing skips are two graphical pixel checks and six live Lc0 methods; feedback captures and the real helper were verified separately. The official `Assert-GateEvidence` helper validated the command, tested commit, exit marker, log SHA-256 and identical code before and after integration. No source changed in review/rebase, so the full gate was not rerun. `git diff --check` passed.

Proxy disclosure: the existing `Proxy decided (opus-5.5 xhigh)` line was checked against [its receipt](/tmp/sweatshop-proxy/20261108-020737-LEARN-006-0937d8.json). The approved split puts the exact-DTZ native probe and packaging in LEARN-010; this ticket consumes that merged interface without weakening grading or changing its contract. No new proxy call was made.

Delivery: rebase onto `sweatshop/learning/2026-11-07-2234` was a no-op. Integrated without squash in merge `8e49570`; this closure commits `Stage: done` and the ledger entry together on the session branch. No PR or push is part of this stage.

Acceptance: pending | Linux automated Lucena acceptance and feedback captures passed as linked above. Native Windows CI execution and release startup from an accented folder remain pending under [LEARN-010's approved verification](117-LEARN-010-tablebase-probe.md#verification); no Windows result is claimed.
Disclosure: decision | none | [Prior proxy receipt](/tmp/sweatshop-proxy/20261108-020737-LEARN-006-0937d8.json): LEARN-010 owns the shared helper; the prerequisite and this consumer are integrated with exact root-move DTZ preserved.
Disclosure: pending | release | [LEARN-010 verification](117-LEARN-010-tablebase-probe.md#verification): actual Windows CI and accented-folder release startup remain release conditions. The Linux end-to-end Lucena check previously pending there has now passed in this ticket's independently repeated real-file smoke.
