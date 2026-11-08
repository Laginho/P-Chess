# LEARN-002: Course map and unit page
Stage: to-review
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

- Stage 2 criteria check (independent subagent, read-only; rechecked after fixes):
  - 1 ✅ `core/course.gd:94` and `:107`; `test_stage_follows_converted_rating_and_loads_units` checks the converted rating boundary and loaded units.
  - 2 ✅ `core/course.gd:118`; `test_unit_progress_and_status_are_derived_from_saved_work`, `test_passed_test_and_failed_review_determine_mastery` and `test_failed_playout_is_in_progress` cover the four statuses and failed work.
  - 3 ✅ `core/course.gd:118`, `ui/unit_page.gd:19` and `ui/course_map.gd:16`; `test_unit_progress_and_status_are_derived_from_saved_work` and `test_map_shows_only_selected_stage_and_unit_page_reports_progress` check counts, rate, empty state and display.
  - 4 ✅ `ui/main.gd:176`, `ui/main.gd:498` and `ui/rating_dialog.gd:52`; `test_course_navigation_unit_progress_and_clock` and `test_new_rating_lands_on_the_map` cover saved and fresh ratings and Edit.
  - 5 ✅ `core/course.gd:94`, `core/course.gd:107` and `ui/course_map.gd:16`; `test_missing_unit_files_are_not_listed` and `test_map_shows_only_selected_stage_and_unit_page_reports_progress` cover missing units and distinct stages. The proxy clarified the fixed four-part structure above.
  - 6 ✅ `ui/unit_page.gd:42`; `test_continue_moves_to_first_unfinished_part_and_disappears_when_done` and `test_map_shows_only_selected_stage_and_unit_page_reports_progress` cover the ordered labels, progress and each Continue state.
  - 7 ✅ `core/course.gd:170` and `ui/unit_page.gd:87`; `test_clock_choice_persists_and_preserves_other_progress` and `test_course_navigation_unit_progress_and_clock` cover the default, save, reload and selected control.
  - 8 ✅ `ui/unit_page.gd:82`; `test_course_navigation_unit_progress_and_clock` checks all four requests and that unimplemented screens leave the unit visible.
  - 9 ✅ `ui/main.gd:216`, `:219`, `:477` and `:486`; `test_course_navigation_unit_progress_and_clock` checks both Back actions.
- Red/green: new stage, progress and clock tests failed for missing public methods before implementation; screen navigation failed before the screens existed. Additional tests failed against mutants removing first-rating navigation, part identifiers, saved clock selection, visible rate and stage cards. The stage fixture change required updating a test rating to keep it in the intended stage.
- Resolution: shipped the stage index and two Wikipedia seed positions, course map and unit page, persisted clock and navigation. The remaining play-out/test content and individual screens belong to LEARN-003 onward. The focused suite passed 13 tests; `godot --headless -s tests/run.gd` passed 590 tests. Captured the map and unit at 1280×800 and the unit at 800×600; persistence was verified by reloading the store in tests, not by a manual application restart.
Gate evidence: /run/media/lage/New Volume/Scratch/LEARN-002-resume/gate.json

#### Resolution (2026-11-08)
Verdict: Reopen — criterion 2: a pending review check clears needs review before a later check passes.

Reviewed the full diff `a8641ff...27c5099` and all sixteen ticket commits. Independent read-only reviewers `/root/review_standards` and `/root/review_spec` examined Standards and Spec; the closing reviewer confirmed the failure below through the production course module. No production repairs or contract changes were authored in this review. The branch and all implementation commits are preserved; there is no merge or ledger entry.

- Standards: 0 documented violations; 1 possible Duplicated Code smell. `save_clock_choice()` repeats `save_rating()`'s read-preserve-write, temporary-file, flush and rename sequence. This is a maintenance observation, not a criterion failure; tracked in [CLEAN-017](116-CLEAN-017-shared-course-persistence.md).
- Spec: 1 finding, criterion 2. No other confirmed criterion failure, scope creep or regression was found.
- ✅ 1: `core/course.gd:94–115` loads the index and selected stage's unit files using the converted rating. The fixture tests cover the 1199/1200 chess.com-scale boundary and exclude missing unit files.
- ❌ 2: `core/course.gd:155–162` scans review records backwards, accepting the presence of `passed` or `missed` as an outcome. It ignores an explicit `done: false`. For a mastered unit, a failed completed check followed by a pending check with `missed: false` incorrectly returns `mastered`. The failed check remains the latest completed outcome, so the expected status is `needs review` until a later check passes. Spec §L2 names the `due`, `done`, `missed` progress fields; §L9 states that passing a later check clears needs review. LEARN-009 owns scheduling, but this ticket already owns deriving status from saved progress.
- ✅ 3: `core/course.gd:118–167` derives practice-pool progress, play-out passes, test state and the first-try percentage/counts. Existing tests cover empty progress, mixed solves and attempts, and displayed values.
- ✅ 4: `ui/main.gd:176–182,498–503` and `ui/rating_dialog.gd:52` route saved/first ratings to the map and Edit to Profile. Screen tests cover these paths.
- ✅ 5: `ui/course_map.gd:16–74` renders the selected stage's real units and all four parts. Fixture tests switch between distinct stages and exclude missing unit files.
- ✅ 6: `ui/unit_page.gd:42–84` preserves part order and selects exactly the first unfinished part for Continue, or none when all are finished. Tests cover each Continue state; seed data displays 0/4 and Not taken for the unfinished play-outs and test.
- ✅ 7: `core/course.gd:170–194` and `ui/unit_page.gd:87–95` default to 5+5 and persist either clock choice while preserving other progress. Tests reload the store and verify the selected control and failed-save behavior.
- ✅ 8: `ui/unit_page.gd:82` emits the unit and each of the four part identifiers. Screen tests assert every request and that unavailable part screens leave the unit visible.
- ✅ 9: `ui/main.gd:216–219,477–487` wires both Back actions, covered through Main in the navigation test.

Reproduction: save a unit with `mastered_date: "2026-11-01"` and these review checks:

```json
[
  {"due": "2026-11-08", "done": true, "missed": true},
  {"due": "2026-12-01", "done": false, "missed": false}
]
```

`Course.unit_progress()` returns `mastered`; the same progress without the pending record returns `needs review`. Marking the later record `done: true, missed: false` correctly returns `mastered`. The isolated Godot 4.7.2 probe exercises production code and reports 2 controls passed, 1 failure, exit 1: [probe](</run/media/lage/New Volume/Scratch/LEARN-002-review/review-status.gd>), [output](</run/media/lage/New Volume/Scratch/LEARN-002-review/review-status.log>). No player data was read or changed by this probe.

Remaining stage-2 work: in `tests/test_course.gd`, commit a failing fixture-progress regression for a failed completed review followed by a pending review; retain a control where a completed successful review clears needs review. Then repair the outcome selection in `core/course.gd` so pending records do not override the latest completed result, preserve the existing completed-record cases, and produce fresh green gate evidence. Continue on this branch. The numbered criteria and Primary files remain unchanged.

Affected callers, failure paths and interactions examined: Main initialization, Home Course entry, first-rating dialog save and failure behavior, map → unit → map → Home navigation, map Edit → Profile → map including rating edits, stage conversion/boundaries, missing/invalid unit data, progress loading and preservation, status precedence, empty pools, Continue labels, clock save failures/reload, all part requests, board previews, Settings screen coverage and sandbox entry after returning Home. Inspected the existing map and unit captures, including [800×600 unit](</run/media/lage/New Volume/Scratch/LEARN-002/unit-small.png>); all four parts, buttons, rate and clock fit. Not exercised live: physical input, a full interactive application restart, the Windows build or Lc0. Scheduling and review-check writers are future LEARN-009 work; this review probes their documented saved-progress fields directly.

Test-first review: all source/test changes stay inside Primary files, and each commit keeps tests separate from production. The initial red/green pairs are `d00ad88` → `e7710c2` (stage selection), `e54fdb9` → `73ef26e` (progress), `409e4bc` → `94d49d6` (clock), `38202cf` → `e1828c0` (screens), `4e521a2` → `ff956e4` (completion/failed work), and `8476e73` → `3beea20` (missing units). Later test-only commits strengthen display/request coverage; the stage-2 comments above record their mutation evidence. The missing pending-review case explains why the current suite stays green despite the criterion-2 failure.

Gate: reused the recorded `godot --headless -s tests/run.gd` run at `49a07dd579fa749c95a73b33313cd23c014f541d`: 590 passed, 0 failed, exit 0. The official `Assert-GateEvidence` helper verified command, exit marker, log SHA-256 and identical tested code. No source changed in review, so no full gate rerun was needed. The existing run skips one graphical pixel check and six live Lc0 checks. `git diff --check` passed. The green gate does not cover the newly reproduced failure.

Proxy disclosure: the existing `Proxy decided (opus-5.5 xhigh)` line above was checked against [its receipt](/tmp/sweatshop-proxy/20261108-000755-LEARN-002-28867a.json). It clarifies criterion 5: all four fixed parts stay visible, while placeholder stages/units are excluded; LEARN-004 still supplies the missing play-out/test content. No new proxy call or contract change was made during review.

Acceptance: pending | Criterion 2 fails the isolated production probe. The ticket's manual open-unit, clock-toggle and application-restart verification also remains outstanding; automated reload tests and inspected captures support the other criteria.
Disclosure: pending | integration | [Criterion-2 reproduction](</run/media/lage/New Volume/Scratch/LEARN-002-review/review-status.log>): repair status selection and add the regression before integrating this ticket.
Disclosure: decision | release | [Proxy decision receipt](/tmp/sweatshop-proxy/20261108-000755-LEARN-002-28867a.json): the fixed four-part structure is visible with unfinished seed content; complete LEARN-004 and the planned part screens before release.
Disclosure: pending | release | Complete the ticket's manual application-restart clock check before release and record its result.
Disclosure: deferred | none | [CLEAN-017](116-CLEAN-017-shared-course-persistence.md) tracks duplicated persistence logic as optional maintenance, with no current behavior defect or release condition.

#### Stage 2 follow-up (2026-11-08)

- Criterion 2 ✅ Independent read-only check: `core/course.gd:150` derives mastery and `:160` skips explicitly pending checks; `tests/test_course.gd:143` covers a failed completed check followed by pending checks, and a later completed success. Existing tests cover the four statuses and completed records without a `done` field. The check found no additional defect in the reopened criterion.
- Red/green: `ba34d0b` failed twice for the intended pending-review regression; `6f2ebc1` passes it and preserves earlier completed-record behavior. The map and unit page are the callers of `unit_progress`; they receive the corrected status without an interface change.
- Gate: `godot --headless -s tests/run.gd` at `6f2ebc1` passed 591 tests, 0 failed. One graphical pixel check and six live Lc0 checks were skipped by the existing suite. The manual application-restart clock check remains pending; this session has no display.
