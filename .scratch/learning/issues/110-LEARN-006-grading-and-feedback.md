# LEARN-006: Grading a line, and the feedback
Stage: to-implement
Blocked by: CI-005, LEARN-005, LEARN-010
Review: agent
Difficulty: hard

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
