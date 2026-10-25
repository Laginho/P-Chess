# OPEN-004: Review badges and repertoire check
Stage: implementing
Blocked by: HIST-002, OPEN-003
Review: agent
Difficulty: normal

- Primary files:
  - New: bot/badges.gd
  - ui/review.tscn, ui/review.gd
  - ui/setup.gd (repertoire to check)
  - core/settings.gd, ui/settings.tscn, ui/settings.gd ("Check my moves")
  - New: tests/test_badges.gd

#### What to build

The review marks where the game was in book and how your moves matched your repertoire (§6.4, §9.3). Nothing shows during the game.

#### Acceptance criteria

1. **Book**: every move whose position and move appear in the catalog (any line, checked or not) gets the badge, up to the first move that leaves the catalog; no Book badge after that.
2. "Check my moves against my repertoire" is a setting, off by default, usable in every opening mode with the repertoire picked on the setup screen.
3. With it on, **Repertoire** marks each of your moves that matches the PGN, and **Left repertoire** marks the first of your moves that does not, showing the expected move or moves.
4. Nothing about books or the repertoire is shown during the game.
5. Badges come from a pure function over the game and the books, tested on fixture games.

#### Verification

    Manual: play out of your repertoire on move 5; the review shows Repertoire to move 4 and Left repertoire with the expected move.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_badges.gd`: Book badges up to the exit, Repertoire / Left repertoire with the expected moves, and no badges with the setting off. Red because `bot/badges.gd` does not exist.

## Comments

- Stage 2 caller inspection: `ui/main.gd` is the caller of `review.present` and owns game start, rematches, settings and the setup catalog/repertoire. Existing review/export/time and setup colour/error behavior must remain intact. The new pure seam takes UCI moves and book paths; boundaries include empty games/books, unchecked lines, first exit and later transpositions back into the catalog. Tests live in `tests/test_badges.gd` as contracted.
