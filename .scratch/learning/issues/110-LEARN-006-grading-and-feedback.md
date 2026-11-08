# LEARN-006: Grading a line, and the feedback
Stage: to-implement
Blocked by: CI-005, LEARN-005
Review: agent
Difficulty: hard

- Primary files:
  - New: engine/tablebase.gd (the probe, spec §L5, built the way RES-001 recommends)
  - New: core/grader.gd (grading a committed line against a probe, spec §L6)
  - core/course.gd (recording commits: solved, first try)
  - core/tunables.gd (`COURSE_DTZ_MARGIN`)
  - ui/solving.gd, ui/solving.tscn (the feedback state)
  - ui/board_view.gd (only if the playback needs a hook it lacks)
  - ui/main.gd (creating the probe beside the other engines)
  - New: tests/test_grader.gd
  - New: tests/test_tablebase.gd
  - tests/test_course.gd
  - tests/test_course_screens.gd
  - scripts/screens.gd (`BOARDS`: SolvingFeedback)

#### What to build

Commit grades the line by tablebase and shows the feedback designed in `SolvingFeedback.dc.html` (spec §L6, §L7). The probe is the bundled Stockfish with the bundled tablebase files; the grader only talks to the probe interface, so tests use a fake. The line plays back one ply at a time with ✓/✗ on your moves; at the first ✗ it stops and shows the correct move and line; Next and Retry follow. The course records solved and first try.

#### Acceptance criteria

1. The probe answers, for a FEN: win, draw or loss for the side to move, the distance to zeroing where available, and the best move; it starts Stockfish with `SyzygyPath` set to the bundled folder and reports a clear error when the files are missing.
2. A move of yours passes when the result for your side after it equals the result before it and, when that result is a win, its distance to zeroing is at most the best move's plus `Tunables.COURSE_DTZ_MARGIN`. Any other move of yours fails. A hold position's every drawing move passes.
3. Opponent moves in the line never fail it; where the probe's best defence differs from the one entered, the feedback shows "Better defence: <SAN>" beside it.
4. Grading stops at your first failing move; moves after it are shown greyed and unmarked.
5. The correct line shown after a ✗ starts with the probe's best move at that point and continues with best moves for both sides up to the position's line length.
6. Feedback plays the line back on the board ply by ply, each of your moves gaining ✓ or ✗; at the first ✗ the board shows the position before it with an arrow for the correct move.
7. The banner says "Solved, first try", "Solved" or "Not solved" with the reason (result changed, or too slow); Retry clears the line on the same position, Next opens the next position (the same rule as LEARN-005 criterion 9).
8. The first commit of a position records first try if it passes; any passing commit records solved; a later pass never records first try. The unit page's solved count and first-try rate update.
9. When every practice position is solved, the solving part shows done and Continue moves on.
10. If the probe fails (engine or files missing), Commit shows an error and records nothing.

#### Verification

    Manual: in the Lucena position, commit a correct line, then a line with a slow detour; retry it correctly; check the unit page counts.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_grader.gd`: with a scripted fake probe: a result-keeping line passes; a result-changing move fails; a winning move over the margin fails ("too slow"); an opponent's weaker defence passes with the better one reported; grading stops at the first failure (red: no grader).
- `tests/test_tablebase.gd`: through the fake UCI engine, the probe sends `SyzygyPath` and parses a scripted reply into result, distance and best move; missing files give an error (red: no probe).
- `tests/test_course.gd`: first try only on the first commit; solved on any pass; solving done when all are solved (red: no recording).
- `tests/test_course_screens.gd`: committing with a fake probe shows the feedback state with ✓/✗ and Retry/Next (red: no feedback state).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L5–§L7. `hard`: the grading rules interact (result, margin, stopping) and the probe parses engine output. How the probe gets a distance per move depends on RES-001; if RES-001 says Stockfish can't give it, this ticket uses RES-001's alternative and says so in its first commit.

- 2026-11-07 RES-001 review follow-up (integration condition): Stockfish 19 computes root-move DTZ internally but does not expose it through UCI scores. RES-001 recommends evaluating Fathom (MIT); that requires a native adapter/helper, packaging and tests absent from this ticket's Primary files and fake-UCI seam. Before implementation, reconcile spec L5, criterion 1 and the test seam through stage 1/the proxy; preserve the DTZ-margin requirement unless Bruno approves a product change. Do not infer DTZ from centipawns or silently replace a failed tablebase probe with engine evaluation. This comment records the open decision, not approval to change the contract. See `docs/research/tablebase.md` and RES-001's dated Resolution.
