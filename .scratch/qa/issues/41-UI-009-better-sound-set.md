# UI-009: Find a better free sound set
Stage: blocked
Status: needs-info
Blocked by: none
Review: human
Difficulty: normal

- Primary files:
  - New: themes/sounds/<name>/ (one `.ogg` per event)
  - docs/THIRD_PARTY.md
  - core/settings.gd (the `sound_theme` default, once Bruno picks)

#### What to build

The bundled sets sound poor, the capture sound worst of all (Bruno's QA, 2026-10-26). Find one or more freely licensed sets whose move and capture sounds are short, clearly different and pleasant, bundle them in the existing folder format (UI-003), and let Bruno pick the default by ear.

Constraints already known: Lichess's `standard` set is not free (spec §8.6), and the only other Lichess set beyond the four bundled ones, `lisp`, is CC BY-NC-SA 4.0 (lila `COPYING.md`), so it is out. Candidates to research: CC0 packs (Kenney, freesound.org CC0), or recording or synthesising our own wood clicks.

#### Acceptance criteria

1. At least two new candidate sets are bundled, each with move, capture, castle, check, game start and game end files; capture is audibly distinct from move.
2. Each new set's licence permits redistribution in the GPL-3 release zip, and `docs/THIRD_PARTY.md` credits its source and licence.
3. The `sound_theme` default is the set Bruno picks.

#### Verification

    Manual: Bruno plays a game with each candidate set and picks one.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None at a GDScript seam: assets and a default. The folder loader is covered by `tests/test_themes.gd`.

## Comments

- 2026-10-26 Written from Bruno's first QA session (item 2). Blocked on research: someone finds candidate sets and checks their licences, then Bruno listens.
