# LEARN-001: The rating sentence
Stage: implementing
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - New: core/course.gd (the progress file and the rating, spec §L2, §L4; LEARN-002 extends this module)
  - New: ui/rating_dialog.gd, ui/rating_dialog.tscn
  - ui/home.gd, ui/home.tscn (a Course button, `course_requested` signal)
  - ui/main.gd (`_ready`: wiring the Course button and the dialog)
  - ui/profile.gd, ui/profile.tscn (the rating sentence field)
  - New: tests/test_course.gd
  - tests/test_profile.gd
  - tests/test_home.gd
  - New: tests/fixtures/course/ (progress fixtures, if needed)

#### What to build

The player states their rating once, in one sentence: "I'm rated [1600] in rapid on [chess.com ▾ / lichess]" (design `RatingModal.dc.html`, `Profile.dc.html`). Home gets a Course button; with no rating saved, it opens the dialog, which has no skip. Profile shows the same sentence, editable. The course module stores it in `user://course.json` and derives the chess.com-scale rating and the course's Maia level (spec §L4, ADR 0003). Until LEARN-002 adds the course map, saving the dialog returns to Home.

#### Acceptance criteria

1. With no rating in `user://course.json`, the Course button opens the rating dialog; it can't be dismissed without a valid rating (Esc and clicking outside do nothing).
2. A valid rating is a whole number from 100 to 3500; anything else keeps Start the course disabled. The site is chess.com or lichess, chess.com by default.
3. Choosing lichess shows "Shown as N on the chess.com scale", with N = the number minus 300.
4. Saving writes the number and the site to `user://course.json`; with a rating saved, the Course button no longer opens the dialog.
5. The course module gives the chess.com-scale rating (Lichess minus 300) and the Maia level: chess.com + 300, rounded to the nearest hundred with halves up, clamped to 1100–1900, as `maia-<level>`. Examples: 1600 chess.com → `maia-1900`; 1100 lichess → `maia-1100`; 1249 chess.com → `maia-1500`; 1250 chess.com → `maia-1600`; 2000 chess.com → `maia-1900`.
6. Profile shows the sentence with the saved number and site; editing and saving there updates `user://course.json`, with the same validation as criterion 2.
7. A missing or unreadable `user://course.json` reads as empty; a read error never causes the file to be overwritten with less than it held.
8. The sandbox's Maia level picker and its saved choice are unchanged.

#### Verification

    Manual: on a fresh profile, click Course, try to dismiss the dialog, enter 1400 lichess, check Profile shows the same sentence.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_course.gd`: rating round-trip through a temporary `course.json`; the conversion and Maia-level examples in criterion 5; an unreadable file reads as empty and isn't overwritten (red: no module).
- `tests/test_home.gd`: with no rating, Course opens the dialog and Esc doesn't close it (red: no button).
- `tests/test_profile.gd`: Profile shows and saves the rating sentence (red: no field).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L2, §L4.
