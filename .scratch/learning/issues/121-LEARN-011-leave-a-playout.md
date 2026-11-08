# LEARN-011: A way back to the unit during a play-out
Stage: to-implement
Status: needs-triage
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/main.gd (play-out game state: the action, cancelling Maia, the probe and the clock)
  - ui/playout.gd or the game side panel (where the action lives)
  - tests/test_course_screens.gd (the existing play-out seam)

#### What to build

A play-out hides New game, Rematch, Resign and Offer draw, and its guard disables Escape (`ui/main.gd:525`). With the clock set to none, the only ways back to the course are to finish, to fail on purpose, or to close the app. Found by the PR #44 integration review (gpt-6.1-sol xhigh, P2). Add one always-visible action, "Back to the unit", during a course play-out and a pass-test play-out.

#### Acceptance criteria

1. During a play-out, a visible, keyboard-reachable "Back to the unit" action returns to the unit page (the pass test returns to its start, with the attempt not recorded).
2. Leaving cancels a pending Maia request, a pending probe and the clock; a late reply finds nothing to act on, and nothing is written to History, stats or course progress.
3. Leaving records neither a pass nor a fail for that play-out.

#### Verification

    Focused play-out tests, including leaving while Maia and while the probe are pending.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_course_screens.gd`: start a play-out, press the action while Maia is held and while the probe is held; check the unit page shows, no request completes into the game, and no History, stats or progress entry appears.

## Comments

- 2026-11-08 Opened by the PR #44 review loop (foreman) as the refutation of review finding 3: new behaviour beyond LEARN-007/LEARN-008's criteria, which define exits only on the end card.
