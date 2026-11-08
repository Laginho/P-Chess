# LEARN-009: The new Home and Continue, with review checks
Stage: to-implement
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

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L9, §L11. `Review: human`: the Home redesign is the first thing Bruno sees.
