# LEARN-003: Theory pointer
Stage: implementing
Blocked by: LEARN-002
Review: agent
Difficulty: normal

- Primary files:
  - core/course.gd (recording that the theory pointer was opened)
  - New: ui/theory_pointer.gd, ui/theory_pointer.tscn
  - ui/main.gd (opening it from the unit page's part request)
  - tests/test_course.gd
  - tests/test_course_screens.gd
  - scripts/screens.gd (`BOARDS`: Theory)

#### What to build

The first part of a unit only points elsewhere (design `Theory.dc.html`, CONTEXT "Theory pointer"): the goal line, the search terms as buttons that copy themselves, the books with their chapters, and "Read up, then come back.", with Back to the unit and Next: Solving. Opening it marks the part done.

#### Acceptance criteria

1. The screen shows the unit's goal, its 3–5 search terms and its 1–2 books with chapters, from the unit file, and no other explanatory text.
2. Clicking a search term copies it to the clipboard.
3. Opening the screen marks the theory pointer done in `user://course.json`; the unit page then shows it done and moves Continue to the next part.
4. Back to the unit returns to the unit page; Next: Solving emits the solving part request.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_course.gd`: recording the theory pointer marks it done (red: no function).
- `tests/test_course_screens.gd`: opening the theory pointer from the unit page shows the fixture's terms and marks it done; clicking a term puts it on the clipboard (red: no screen).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L1, §L11.
