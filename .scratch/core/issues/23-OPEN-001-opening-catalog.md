# OPEN-001: Opening catalog picker
Stage: to-implement
Blocked by: UI-004
Review: agent
Difficulty: normal

- Primary files:
  - New: data/openings/a.tsv … e.tsv
  - New: bot/book.gd (catalog loading)
  - New: ui/opening_picker.tscn, ui/opening_picker.gd
  - ui/setup.tscn, ui/setup.gd (Catalog mode)
  - docs/THIRD_PARTY.md
  - New: tests/test_catalog.gd

#### What to build

The opening catalog from Lichess's TSVs as a searchable tree with checkboxes, and named selections the setup screen can choose for Catalog mode (§6.1). The book weight that uses them is OPEN-002.

#### Acceptance criteria

1. The `lichess-org/chess-openings` TSVs are committed under `data/openings/`, and `docs/THIRD_PARTY.md` names the upstream commit and its CC0 licence.
2. Every row loads; the test asserts the row count of the committed files.
3. Names become a tree: "Family: Variation, Sub-variation" gives Family → Variation → Sub-variation.
4. Search filters the tree by a case-insensitive substring.
5. Checking a node checks all its descendants; a partly checked parent shows that state.
6. A selection is saved with a name under `user://openings/` and can be loaded back; the setup screen lists saved selections for Catalog mode.
7. Each line's moves are parsed with the SAN code into position keys; a row that does not parse is reported and skipped.

#### Verification

    Manual: search "Sicilian", check Najdorf, save it, pick it in setup.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_catalog.gd`: row count, the name tree for three sample names, search, check propagation, save and load of a selection. Red because the catalog code does not exist.

## Comments
