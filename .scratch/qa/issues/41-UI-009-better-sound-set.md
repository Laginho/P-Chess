# UI-009: Find a better free sound set
Stage: done
Status: wontfix
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
- 2026-10-27 Research done, two candidate sets tried on a throwaway branch: `wood` (Kenney Impact Sounds: wood knock for move, plank for capture) and `chips` (Kenney Casino Audio: chip lay for move, chips colliding for capture). Both share Kenney Interface Sounds for check, promote, low time, game start and game end. All three packs are CC0 1.0; the per-event mapping and credits are in `docs/THIRD_PARTY.md`, "Sounds: Kenney". Loudness is close to `sfx` (mean −22 to −29 dB against −25 dB), so the ear test is not really a volume test. Rejected: PyChess sounds (GPL-3+ per Debian's copyright file, so the licence is fine, but `move1` lasts 30 ms and `capture1` 17 ms, tiny clicks), and Lichess `lisp` (CC BY-NC-SA). Unverified: whether capture is clearly different from move by ear, wood/plank especially. Waiting on Bruno: open the project from the worktree, play a game with each set (Settings → sound theme) and pick one; that pick becomes the `sound_theme` default (criterion 3).
- 2026-10-27 Closed as wontfix by Bruno. He auditioned `wood` and `chips` and liked neither; the branch is deleted. No freely licensed set beats the bundled ones: the sets players know (Lichess `standard`, chess.com) are non-free, so they cannot ship. The release keeps `sfx` as the default. For his own machine Bruno installs those sets as user themes under `%APPDATA%\Godot\app_userdata\[P] Chess\themes\sounds\` (UI-003 folder format), which stays outside the repo and the release zip.
