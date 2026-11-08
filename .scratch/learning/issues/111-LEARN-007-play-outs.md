# LEARN-007: Play-outs against Maia
Stage: to-implement
Blocked by: CORE-007, CLOCK-003, LEARN-004, LEARN-006
Review: agent
Difficulty: normal

- Primary files:
  - New: ui/playout.gd, ui/playout.tscn (start screen and end card)
  - ui/main.gd (`_start` or a sibling for a course game: from a FEN, the course's Maia level, the unit's clock, no History save)
  - core/course.gd (recording play-out passes)
  - core/tunables.gd (`COURSE_HOLD_MOVES`)
  - New: core/playout_judge.gd (fail and pass rules over the probe, spec §L8)
  - New: tests/test_playout_judge.gd
  - tests/test_course.gd
  - tests/test_course_screens.gd
  - tests/test_session.gd (only if a shared helper needs the course game path)
  - scripts/screens.gd (`BOARDS`: PlayoutStart, PlayoutEnd)

#### What to build

The unit's four play-outs (spec §L8, design `PlayoutStart.dc.html`, `PlayoutEnd.dc.html`): a start screen with the task, the opponent (Maia at the course level, L4), the clock and the pass and fail rules; then a game from the position's FEN on the normal game screen; then an end card. After each of your moves the probe checks the result: a move that changes it for your side ends the play-out at once. Play-outs are not saved to History and don't count in Profile's stats.

#### Acceptance criteria

1. The start screen shows "Play-out k of 4", the four play-outs' state (passed, current, to do), the task ("White to play and win" or "… draw"), Maia's level, the clock (5+5 or No clock, from the unit page) and the pass and fail lines; Start begins the game.
2. The game starts from the play-out's FEN with you on its side, against Maia at the course level, with the unit's clock choice.
3. After each of your moves the judge asks the probe; when the result for your side changed, the play-out fails at once, before Maia replies.
4. Running out of time fails the play-out.
5. A convert passes when you promote or mate; a hold passes when the pawn is captured, with the draw kept, or after `Tunables.COURSE_HOLD_MOVES` (30) of your moves with the draw kept.
6. The end card shows Converted / Held / Play-out failed / Out of time with the reason; on a failed move it shows that move with the blunder icon and a move that kept the result, from the probe, and the board shows the position after the failing move with it highlighted.
7. A pass records that play-out as passed; the end card offers Next play-out (or Back to the unit after the fourth) and Back to the unit; a fail offers Retry and Back to the unit.
8. Play-out games write nothing to `user://games/` and don't change `user://stats.cfg`.
9. When all four are passed, the play-outs part shows done and Continue moves on.

#### Verification

    Manual: lose a hold on purpose with a rook move off the third rank; pass a convert.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_playout_judge.gd`: with a fake probe: a result-changing move fails; a kept result continues; promotion passes a convert; a pawn capture or 30 held moves pass a hold (red: no judge).
- `tests/test_course_screens.gd`: Start from the unit page opens a game at the play-out's FEN against the course level, with `Session.HeldBridge`; a scripted failing move shows the end card; nothing is saved to the temporary history folder (red: no play-out).
- `tests/test_course.gd`: recording passes; play-outs done at 4 (red: no recording).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L4, §L8. "Not saved to History" is a spec decision (§L8) Bruno can reverse.

- 2026-11-07 RES-001 review follow-up: assess hold/convert difficulty with Bruno on the actual LEARN-004 course positions before release. The research's small random sample and WDL-preserving opponent do not validate human difficulty or 50-move-perfect play; record the manual play-out outcome here. See `docs/research/tablebase.md` and RES-001's dated Resolution; this adds no implementation criterion.

- 2026-11-07 CORE-007 review follow-up: before release, verify that a course play-out starts at its supplied FEN and real Maia replies with legal moves after the player moves. CORE-007's fake-bridge tests cover the start FEN and both current/previous-position request histories, but the headless gate skipped live Lc0 checks because the engine was unavailable. Record the real-engine outcome here with the play-out acceptance above; see `102-CORE-007-game-keeps-its-start-position.md` Resolution. This adds no implementation criterion.
