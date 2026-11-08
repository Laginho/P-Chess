# LEARN-009: The new Home and Continue, with review checks
Stage: to-review
Blocked by: LEARN-008
Review: human
Difficulty: normal

- Primary files:
  - ui/home.gd, ui/home.tscn (`configure`, `_layout_home`: Continue card, Course button, Play row with Custom)
  - ui/main.gd (wiring Continue to each target)
  - core/course.gd (the Continue target and review checks, spec §L9)
  - ui/solving.gd (a review-check mode: 3 positions, one commit each)
  - tests/test_home.gd (including test-only updates to the layout assertions this redesign replaces: `test_home_shows_quick_play_and_navigation_icons`, `test_quick_play_tiles_are_landscape_with_centred_labels`, `test_home_restores_quick_play_size_when_engine_warning_is_hidden`, `test_missing_engine_message_does_not_overlap_navigation_at_minimum_window`)
  - tests/test_course.gd
  - tests/test_course_screens.gd
  - docs/spec.md (§15.8, Home)
  - scripts/screens.gd (`Main` board refresh)

#### What to build

Home as designed in `Main.dc.html` (spec §L9, §L11): a large Continue card first, naming the target ("Continue: Rook endgames, solving 4/12"); the Course button; the Play row (1+0, 3+2, 5+0, Custom) with the Maia level picker; History, Profile, Settings and Quit. Home's board shows the position Continue will open. Continue's order comes from the course module, including the review checks 7 and 30 days after mastery.

#### Acceptance criteria

1. With no rating saved, the Continue card says "Start the course" and opens the rating dialog.
2. The course module's Continue target, in order: a due review check; else the first from-your-game position not yet solved; else the current unit's first unfinished part; else the next unit's first part; else "done".
3. A review check is due 7 days after the mastered date and again 30 days after it; it draws 3 positions from the unit's practice and test pools.
4. A review check is solved on the solving board with one commit per position; any miss marks the unit "needs review" and keeps the mastered date; a fully passed check marks that check done and clears "needs review".
5. The card shows the target's eyebrow (Continue, Review check, From your game, or Unit done), the unit title and a detail line ("Solving · 4/12", "3 positions · mastered 7 days ago", "1 new position from your games"); for "done" it says "Unit done, go play some slow games" and points to Custom game and the Play row.
6. Clicking the card opens the target screen directly (the solving board, the theory pointer, the play-out start, the test start, or the review check).
7. Home's board shows the target's position (the next position, the first play-out's, or the start position when done).
8. Quick play, the level picker, Custom, History, Profile, Settings and Quit behave as before; the missing-engine message still disables quick play and doesn't overlap the buttons at 800×600.
9. `docs/spec.md` §15.8 describes the new Home.

#### Verification

    Manual: compare Home at 1280×800 with docs/design/learning/png/Main.png; click Continue in each state.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_course.gd`: the Continue order across fixture progress, with the time passed in: review check at day 7 and day 30, own-game position before the next part, "done" at the end; a missed check gives needs review and keeps mastery (red: no target function).
- `tests/test_home.gd`: the card shows the target from a fixture progress file and opens it; quick play unchanged; the replaced layout assertions rewritten for the new layout (red: no card).

## Resolution

- Continue selects due reviews, positions from games, unfinished parts and subsequent units; review misses survive leaving the board and passing a check clears the review status.
- Home shows the target and its board, opens the selected activity, and retains the Play row and navigation. The 1280×800 capture was compared with `docs/design/learning/png/Main.png`; automated screen tests exercise the card's destinations.
- `godot --headless -s tests/run.gd`: 662 passed, 0 failed at commit `130a6e0`.

Gate evidence: /run/media/lage/New Volume/Scratch/learn009-gate-final.json

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L9, §L11. `Review: human`: the Home redesign is the first thing Bruno sees.
- Stage 2 criteria check, independently reviewed against the committed diff:
  - ✅ 1: `ui/home.gd:124`, `ui/main.gd:570`; `tests/test_home.gd:7` checks the visible start label and rating dialog.
  - ✅ 2: `core/course.gd:211`; `tests/test_course.gd:4`, `tests/test_course.gd:37` and `tests/test_course.gd:71` check priority, incomplete mastered units, next unit and done.
  - ✅ 3: `core/course.gd:207`, `core/course.gd:211`; `tests/test_course.gd:71` checks both deadlines, local-date boundary, distinct positions and eligible pools.
  - ✅ 4: `ui/solving.gd:58`, `ui/main.gd:649`, `core/course.gd:254`; `tests/test_course_screens.gd:8` checks three commits, an interrupted miss and preserved mastery, and `tests/test_course.gd:71` checks clearing on a later pass.
  - ✅ 5: `ui/home.gd:124`, `ui/home.gd:179`; `tests/test_home.gd:7`, `tests/test_home.gd:38` and `tests/test_home.gd:102` check visible labels and the completed message at 800×600.
  - ✅ 6: `ui/main.gd:570`, `ui/main.gd:616`; `tests/test_home.gd:7`, `tests/test_home.gd:38` and `tests/test_home.gd:102` exercise every destination.
  - ✅ 7: `ui/home.gd:124`; `tests/test_home.gd:38` and `tests/test_home.gd:102` compare the Home board with the opened review, solving and play-out positions, and the starting board when done.
  - ✅ 8: `ui/home.gd:24`, `ui/home.gd:88`; Home and session tests cover quick play, controls and engine guidance. `tests/test_session.gd:516` replaces Home's old centred-board expectation with the approved left-aligned design while retaining Searching and Game placement checks; the replacement was proved red with a left-margin mutation and green after restoration.
  - ✅ 9: `docs/spec.md:484` documents Home and review checks; verified by reading the section.
