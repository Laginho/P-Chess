# OPEN-003: Repertoire import and My repertoire mode
Stage: to-implement
Blocked by: CORE-006, OPEN-002
Review: agent
Difficulty: normal

- Primary files:
  - New: bot/repertoire.gd
  - bot/book.gd
  - New: ui/repertoire_import.tscn, ui/repertoire_import.gd
  - ui/setup.tscn, ui/setup.gd (My repertoire mode)
  - New: tests/test_repertoire.gd
  - New: tests/fixtures/pgn/repertoire_*.pgn

#### What to build

Import your repertoire as a PGN, choose its colour, and practise it in My repertoire mode: Maia plays the PGN's moves for its side, with the same book weight as Catalog mode (§6.2–§6.4).

#### Acceptance criteria

1. Importing a PGN with variations, comments, NAGs and several games (Lichess study chapters) merges everything into one move tree; identical moves from different games merge.
2. The colour you play is chosen at import and saved with the repertoire under `user://`.
3. A line is one root-to-leaf path of the tree.
4. In My repertoire mode the PGN's lines replace the catalog's, and the book weight of OPEN-002 applies unchanged to Maia's moves.
5. A PGN with an illegal move reports the error with its move number and saves nothing.

#### Verification

    Manual: import a two-chapter study as white, play as white; Maia answers with the PGN's black moves.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_repertoire.gd`: merging two games with a shared start into one tree, the line count, the book built from it, and the illegal-move error. Red because `bot/repertoire.gd` does not exist.

## Comments
