# OPEN-004: Review badges and repertoire check
Stage: implementing
Blocked by: HIST-002, OPEN-003
Review: agent
Difficulty: normal

- Primary files:
  - New: bot/badges.gd
  - ui/review.tscn, ui/review.gd
  - ui/setup.gd (repertoire to check)
  - ui/main.gd (OPEN-004 composition only: pass catalog data, the check-my-moves setting, the selected repertoire and actual human side to review; snapshot the game's repertoire, load it in every opening mode when needed, and report load failures before starting a new game; preserve existing bot modes, history recognition and swapped-colour rematches)
  - core/settings.gd, ui/settings.tscn, ui/settings.gd ("Check my moves")
  - New: tests/test_badges.gd

#### What to build

The review marks where the game was in book and how your moves matched your repertoire (§6.4, §9.3). Nothing shows during the game.

#### Acceptance criteria

1. **Book**: every move whose position and move appear in the catalog (any line, checked or not) gets the badge, up to the first move that leaves the catalog; no Book badge after that.
2. "Check my moves against my repertoire" is a setting, off by default, usable in every opening mode with the repertoire picked on the setup screen. This setting controls Repertoire and Left repertoire only; Book remains enabled. Selecting a repertoire for checking in Free or Catalog does not change the chosen human colour or Maia's opening mode. Checking uses the actual human side, including rematches. A required saved-repertoire load failure reports an error and permits retry without using stale repertoire data.
3. With checking on and a selected repertoire loaded, compare each human move's position and move against all imported PGN paths, using position keys without move counters so transpositions count. Matching human moves receive Repertoire until the first unmatched human move, which receives the sole Left repertoire marker. Show the distinct expected continuations in SAN when present. When none exist, including after an opponent deviation or beyond a PGN leaf, show "No continuation in repertoire" instead of inventing an expected move. Opponent moves never receive repertoire badges. No repertoire badges appear after the human exit, even if play later returns to a known position.
4. Nothing about books or the repertoire is shown during the game.
5. Badges come from a pure function over the game and the books, tested on fixture games.

#### Verification

    Manual: play out of your repertoire on move 5; the review shows Repertoire to move 4 and Left repertoire with the expected move.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_badges.gd`: Book badges up to the exit, Repertoire / Left repertoire with the expected moves, and no repertoire badges with the setting off, while Book badges remain. Cover opponent deviation, PGN leaf, transposition, actual-colour/rematch, and real Setup/Main/Review wiring, including failed-load retry and no in-game badges. Red because `bot/badges.gd` does not exist.

## Comments

Proxy decided (gpt-6-astra high, fallback): Allow narrowly scoped Main composition and lifecycle wiring; keep Book independent of the repertoire toggle and mark only the first unmatched human move, with explicit no-continuation text where the PGN supplies none — Main owns setup/preferences/review composition, and OPEN-004 criteria 1–3 distinguish catalog recognition from human repertoire checking.

Disclosure: decision | none | OPEN-004 proxy scope and badge clarification: preserves opening modes, history and swapped-colour rematches; no migration or additional integration/release condition.

- Test harness correction: the first run could not infer the fixture board FEN type; declared it explicitly as String. This is a test-only correction; rerun must fail because the production badge module is missing.
- Repertoire fixture correction: the transposition fixture originally did not cover the intermediate black Nf6, so it required a valid earlier exit. Extend that fixture chapter through Nf6; Bg7 still requires matching the other chapter by position. The corrected tests are red against the Book-only implementation and green with repertoire evaluation.

- Stage 2 caller inspection: `ui/main.gd` is the caller of `review.present` and owns game start, rematches, settings and the setup catalog/repertoire. Existing review/export/time and setup colour/error behavior must remain intact. The new pure seam takes UCI moves and book paths; boundaries include empty games/books, unchecked lines, first exit and later transpositions back into the catalog. Tests live in `tests/test_badges.gd` as contracted.
