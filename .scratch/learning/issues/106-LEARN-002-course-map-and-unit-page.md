# LEARN-002: Course map and unit page
Stage: implementing
Blocked by: LEARN-001
Review: agent
Difficulty: normal

- Primary files:
  - core/course.gd (unit data, statuses, part progress, first-try rate, clock choice: spec §L1–§L3)
  - New: data/course/course.json (the stage index)
  - New: data/course/rook-endgames.json (theory pointer, plus the Lucena and Philidor positions from Wikipedia; LEARN-004 completes it)
  - New: ui/course_map.gd, ui/course_map.tscn
  - New: ui/unit_page.gd, ui/unit_page.tscn
  - ui/main.gd (`_ready`, a `_show_course_map` and `_show_unit` beside `_show_history`)
  - ui/rating_dialog.gd (after saving, open the course map instead of Home)
  - tests/test_course.gd
  - New: tests/test_course_screens.gd
  - New: tests/fixtures/course/ (a small unit file and progress files)
  - scripts/screens.gd (`BOARDS`: CourseMap, Unit)

#### What to build

The course gets its first real screens (design `CourseMap.dc.html`, `Unit.dc.html`). The Course button opens the course map: the rating sentence with Edit, the stage, and one card per unit with its status and the four parts' progress. A unit card opens the unit page: the four parts with their progress and an Open button each (the next unfinished one says Continue), the first-try rate, and the play-out clock toggle. Data comes from `data/course/` and progress from `user://course.json`, through the course module.

#### Acceptance criteria

1. The course module loads the stage index and its units, and picks the stage whose rating range holds the player's chess.com-scale rating.
2. A unit's status is new (nothing done), in progress (anything done, test not passed), mastered (test passed) or needs review (mastered, last review check failed), from progress alone.
3. Part progress: theory pointer done or not; solving as solved/total over the practice pool; play-outs as passed/4; pass test as not taken, not passed or passed. The first-try rate is first-try solves over positions committed at least once, shown as a percentage with the counts ("3 of 4"), or "–" before any commit.
4. With a rating saved, the Course button opens the course map; the map's Edit opens Profile; a fresh rating from the dialog lands on the course map.
5. The course map shows only the player's stage and the units its data lists; no placeholder stage or unit ("coming soon") appears. Each listed unit shows its four parts (CONTEXT "Part", spec §L1), also while the unit file doesn't yet have its play-outs or test pool (LEARN-004).
6. The unit page lists the four parts in order with their progress; exactly one Open button says Continue: the first unfinished part, or none when all are done. Until LEARN-004 fills the unit, Play-outs reads 0/4 and Pass test reads Not taken, and both count as unfinished.
7. The clock toggle shows 5+5 or No clock, defaults to 5+5, and its choice survives a restart (saved in `user://course.json`).
8. Each part's Open button emits a part request with the unit and part; parts whose screen doesn't exist yet do nothing.
9. Back on the unit page returns to the course map; back on the course map returns to Home.

#### Verification

    Manual: open Course, open the unit, flip the clock, restart, check it stuck.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_course.gd`: stage pick by rating; the four statuses and part progress from fixture progress; first-try rate counts and the "–" case (red: missing functions).
- `tests/test_course_screens.gd`: from `main.tscn`, Course with a saved rating opens the map; the unit card opens the unit page; the Continue label sits on the first unfinished part; the clock choice persists (red: no screens).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L1–§L3, §L11. The stage name is still open (design shows `[Stage name]`); use the index's name field and leave the text to LEARN-004.

- Proxy decided (opus-5.5 xhigh): Keep all four parts on the unit page and the course-map card; reword criterion 5 so it bans placeholder units and stages, not the four fixed parts. Criterion 6 stays as written. (receipt /tmp/sweatshop-proxy/20261108-000755-LEARN-002-28867a.json)
- Criterion 5 follows story 13 and ADR 0001: the four parts are the unit structure. Seed play-outs and test data remain for LEARN-004; the empty parts show 0/4 and Not taken until then.
