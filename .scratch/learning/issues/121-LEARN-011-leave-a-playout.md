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

An ordinary course play-out (from the unit page) hides New game, Rematch, Resign and Offer draw, and its guard disables Escape (`ui/main.gd:525`). With the clock set to none, the only ways back to the course are to finish, to fail on purpose, or to close the app. Found by the PR #44 integration review (gpt-6.1-sol xhigh, P2). Pass-test play-outs already have this exit: `_start_test_playout()` shows the side panel's button as "Back to the unit" (`ui/main.gd:707`), and its handler calls `_show_unit()`, which cancels the play-out. Add the same "Back to the unit" action to ordinary play-outs; reusing that button and `_show_unit(_playout_unit)` is the obvious route.

#### Acceptance criteria

1. During an ordinary play-out, a visible, keyboard-reachable "Back to the unit" action returns to the unit page. Pass-test play-outs keep their existing exit unchanged.
2. Leaving cancels a pending Maia request, a pending probe and the clock; a late reply finds nothing to act on, and nothing is written to History, stats or course progress.
3. Leaving records neither a pass nor a fail for that play-out.

#### Verification

    Focused play-out tests, including leaving while Maia and while the probe are pending.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_course_screens.gd`: start a play-out, press the action while Maia is held and while the probe is held; check the unit page shows, no request completes into the game, and no History, stats or progress entry appears.

## Comments

- 2026-11-08 Opened by the PR #44 review loop (foreman) as the refutation of review finding 3: new behaviour beyond LEARN-007/LEARN-008's criteria, which define exits only on the end card.
- 2026-11-08 Narrowed by the PR #44 review loop: pass-test play-outs already show "Back to the unit" (`ui/main.gd:707`), so the ticket covers ordinary play-outs only, and criterion 1 now matches the test section (the unit page).
