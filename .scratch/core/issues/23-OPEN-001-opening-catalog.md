# OPEN-001: Opening catalog picker
Stage: to-review
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

- 2026-10-25 Stage 2: approved seams are the catalog/selection API in `bot/book.gd` and the real picker/setup scenes, tested in `tests/test_catalog.gd`. Existing callers of setup's `started(settings)` are `Main._start` and tests; Free must keep its settings shape, and Catalog adds the saved selection name. `Book` and the picker are new, with no existing callers. Boundaries to cover: invalid SAN among valid rows, duplicate name paths, partial/empty selection, filtered check propagation, unsafe save names, missing/corrupt selection files, and Catalog with no saved selection. UI-004 is done on the session base.

#### Stage 2 handoff (2026-10-25)

- Branch: `OPEN-001-opening-catalog`, based on `sweatshop/core/2026-10-25-0159` (`4b9fdeb`). All changes are inside Primary files. Each test commit is separate from production changes.
- Data: all five upstream TSV blobs match the downloaded bytes at `a6189a30dc273ccb21fc2536a9a2fefd5592a67a`; counts are a=823, b=781, c=1250, d=644, e=367, total 3,865. `docs/THIRD_PARTY.md` records the pinned source, CC0 licence and raw-file export requirement.
- Red/green evidence: `5ee2921` failed with missing `bot/book.gd` (189 passed, 1 failed); `157023e` passed both loader tests. `563b2b4` failed both new tree/check tests (2 passed, 2 failed); `35aedf2` left the empty-search case red (3 passed, 1 failed), fixed by `a09e076`. `2634763` then showed all four existing catalog tests green and both persistence tests red (4 passed, 2 failed); `31e6db0` passed all six. `a2f2480` failed the three real-scene tests (6 passed, 3 failed); `c628739` passed all nine. `7de1229` proved a move-number-only row was silently skipped (8 passed, 1 failed); `1ccbe62` reports it, and the final bound gate passed 198 tests with 0 failures, exit 0.
- The initial unprivileged full run could not write Godot's `user://` files and was stopped; the repeat with the required access produced the valid first red result above. No production or test logic was changed to bypass the filesystem restrictions.
- API for OPEN-002: `Book.new(); load_catalog()` populates `entries` with `{id, eco, name, pgn, moves: PackedStringArray, positions: PackedStringArray}`. Positions include the start and the final key, so `moves[i]` connects `positions[i]` to `positions[i + 1]`. IDs are `eco + ":" + pgn`, unique across the pinned catalog; multiple transposed rows can share one name node. `errors` reports source/row/SAN and skips bad rows without losing valid neighbours.
- Tree/selection API: `roots`, `nodes[path] = {label, parent, children, lines}` (lines includes descendants), `search(query)` returns visible paths including ancestors, `set_checked(path, bool)`, `check_state(path)` returns 0 unchecked / 1 checked / 2 partial, and `selected_ids()` returns the chosen row IDs. A family's own row participates in its checkbox state. `selection_names()`, `save_selection(name)` and `load_selection(name)` use `user://openings/<name>.json`; save/load return an error string or `""`. JSON is `{version: 1, lines: [id]}`. Failed loads preserve the current selection; saves replace atomically via a temporary file. Tests inject `selection_dir` to avoid personal files.
- Setup preserves Free's existing settings and emits `selection: <saved name>` alongside `opening: "Catalog"`. Catalog without saved selections disables Start while keeping the picker accessible. New saves refresh and select the name in setup immediately. Actual bot weighting is OPEN-002, as specified here; My repertoire remains disabled for OPEN-003.
- Acceptance scenario exercised the real setup/picker and full catalog: search `Sicilian`, edit the Najdorf checkbox through `Tree.edit_selected()`, save `Najdorf practice`, close the picker and Start in Catalog. Result: 33 selected lines and the expected saved name in the emitted settings, with no logged errors. Initial threaded loading took 16,558 ms with 2,110 main-loop frames processed; the loaded catalog is reused for subsequent picker openings. Log: `C:\Users\Lage\AppData\Local\Temp\OPEN-001-acceptance.log`.
- Visual verification: rendered the real picker at 1280x800 with the OpenGL renderer; checked hierarchy, partial parent marks, search and save/load controls. Corrected its initially translucent background. Screenshot: `C:\Users\Lage\AppData\Local\Temp\OPEN-001-picker.png`. Final diff and `git diff --check` passed; no generated files are included.

Acceptance: passed | full-catalog setup/picker scenario described above; bound gate 198/198 on `1ccbe622f0f2090c44474775a2cbbb9aa387b133`; visual layout inspected. Independent stage-3 review remains next.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\OPEN-001-final-gate.json
