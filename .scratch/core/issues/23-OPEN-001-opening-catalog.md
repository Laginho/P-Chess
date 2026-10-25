# OPEN-001: Opening catalog picker
Stage: done
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

- 2026-10-25 Stage 2 reopen: only criterion 4 remains. Approved seam: `Book.load_tsv/search` in `tests/test_catalog.gd`. Callers inspected: picker `_rebuild` consumes normalized paths in parent-before-child order; existing catalog tests expect family matches to retain descendants, variation matches to retain ancestors, empty search to show all nodes, and unmatched search to return none. Regression covers original full names, punctuation-spanning mixed-case substrings, normalized path compatibility and exclusion of unrelated branches. The existing name tree, checkbox and selection IDs must stay stable.

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

Gate evidence: C:\Users\Lage\AppData\Local\Temp\OPEN-001-search-green-gate.json

#### Resolution (2026-10-25)

Verdict: Reopen — criterion 4 misses substrings of committed opening names after tree-path normalization.

Independent Standards and Spec sub-agents reviewed `4b9fdebcbecad17b0c3becdb88bccd8d2788731b...41d9b06`, the full ticket and the opening/setup sections of `docs/spec.md`. This review authored no production or test changes. The ticket branch remains `OPEN-001-opening-catalog`; it has not been merged into `sweatshop/core/2026-10-25-0159`. No ledger line exists to remove.

##### Standards

No hard documented-standard violations or baseline smells worth flagging. Every commit stat preserves separate test-only and production-only changes; ticket metadata is the only additional scope. Source, scenes, data, attribution and tests stay within Primary files. The tests call production APIs and real scenes. Catalog dictionaries and check states fit the approved seam without additional abstractions.

##### Spec

1. ✅ All five TSV files are committed, and `docs/THIRD_PARTY.md` identifies upstream commit `a6189a30dc273ccb21fc2536a9a2fefd5592a67a` and CC0. The pinned upstream README and COPYING agree with the attribution.
2. ✅ The production loader and test cover all 3,865 rows, with exact per-volume counts and unique selection IDs. All committed rows have nonempty fields.
3. ✅ The documented Family → Variation → Sub-variation pattern forms a tree, with shared name nodes retaining transposed entries.
4. ❌ **P2: substring search loses original punctuation.** `bot/book.gd:88` replaces every colon-space with comma-space; line 91 then reconstructs paths with a colon after the first label. Line 107 searches only those reconstructed paths. The committed row at `data/openings/c.tsv:306`, `Vienna Gambit, with Max Lange Defense: Cunningham Defense`, loads without errors but becomes `Vienna Gambit: with Max Lange Defense, Cunningham Defense`. Both the original full-name query and its literal substring `Max Lange Defense: Cunningham` return `[]`; `Cunningham` finds the row. Comma-only names are affected too: `Polish Opening, with d5` becomes `Polish Opening: with d5`, and its original full-name query returns `[]`. Forty-six committed rows have a comma before any colon, including comma-only names. Search must retain case-insensitive matching of the original names while keeping matching nodes and ancestors visible. Add regressions for both punctuation patterns in the already-approved `tests/test_catalog.gd` seam before repairing production code.
5. ✅ Checks include hidden descendants and a family's own row; ancestors show partial state. Real Tree checkbox editing is covered.
6. ✅ Named selections round-trip, replace existing saves and support empty selections. Unsafe names and corrupt/missing selections fail without losing current checks. Setup lists new saves immediately, passes the selected name for Catalog, preserves Free settings and blocks Catalog Start when no selection exists.
7. ✅ The loader calls the existing SAN parser, records start/intermediate/final position keys, reports invalid SAN or move-number-only rows and retains valid neighbours.

Standards: 0 findings. Spec: 1 P2 finding, criterion 4. No other missing requirement, incorrect implementation or material scope creep was found. Book weighting and repertoire import remain assigned to OPEN-002/003. No proxy decision or contract amendment was made in this review.

Examined: the full production/test/scene diff and every commit stat; all data-row shapes and IDs; Book's loader, prefix cache, tree/check/search and persistence paths; real picker controls, worker ownership/join and shutdown; Setup's started/settings signal, Main's start/rematch/setup callers and Free compatibility; Board's SAN/copy/position-key APIs; filtered check propagation, duplicate name paths, empty selections, malformed SAN and JSON, unsafe filenames and missing selection files. Not experimentally examined: actual mouse/keyboard interaction, minimum-size layout, exported builds, live Lc0, worker-start failure or disk-full/permission failures. The existing 1280×800 screenshot was inspected and the recorded full-catalog acceptance script/log were checked.

Reproduction: `C:\Users\Lage\AppData\Local\Temp\OPEN-001-spec-search.gd` calls the production `load_tsv` and `search` methods with the exact committed Vienna and Polish rows. `C:\Users\Lage\AppData\Local\Temp\OPEN-001-spec-search.log` records successful loading, the normalized paths, both failed Vienna queries, the successful simple query and the failed Polish full-name query. Godot also logs restricted root-certificate-store access; the production calls complete with no catalog errors, so that environment warning does not explain the search results.

Red/green: inspected the five retained red logs and the committed test/production separation. Missing loader: **189 passed, 1 failed**. Missing tree/check API: **2 passed, 2 failed**. Missing persistence: **4 passed, 2 failed**. Missing picker/setup integration: **6 passed, 3 failed**. Unreported move-number-only row: **8 passed, 1 failed**. The final gate is green, but these tests do not cover the original-punctuation queries above; stage 2 must add that regression in its own red test commit.

Gate: the installed `Assert-GateEvidence` helper verified the existing receipt against reviewed HEAD. Command `godot --headless -s tests/run.gd`, tested commit `1ccbe622f0f2090c44474775a2cbbb9aa387b133`, **198 passed, 0 failed**, exit 0. Log SHA-256 `820586DC89C525FA8841DE4ACB2910CB711F6AE69EC6EC2BCD765E0776ECB4B6` and exit marker match; only permitted ticket metadata differs from tested code. No full-gate repeat was needed. `git diff --check` passes.

Acceptance: pending | The recorded Sicilian/Najdorf real-scene scenario passes with 33 selected lines and the chosen setup name; general substring acceptance fails for original names as reproduced above.
Disclosure: pending | integration | This Resolution, criterion 4: original-punctuation substring searches must pass regression tests and independent re-review before integration. The unresolved defect remains scheduled on this reopened ticket.

#### Stage 2 re-review handoff (2026-10-25)

- Corrected the criterion-4 finding on the preserved `OPEN-001-opening-catalog` branch. `Book` now maps original opening names to their existing terminal tree paths and includes those name matches in search results. The normalized tree paths, ancestor ordering, checkbox state and selection IDs remain unchanged. Matching stays case insensitive; normalized-path queries remain supported.
- Test-only commit `8566c4e` adds a public-API regression for both reported names: Vienna's comma-before-colon name and Polish's comma-only name. It checks full names, punctuation-spanning mixed-case substrings, normalized-path compatibility, unrelated-branch exclusion and empty search. Authorized red run: **9 passed, 1 failed**, exit 1; only the new regression failed, on five original-punctuation queries. Log: `C:\Users\Lage\AppData\Local\Temp\OPEN-001-search-red-authorized.log`. A preliminary restricted run reproduced the same search failure but also denied existing `user://` persistence tests; its **5 passed, 5 failed** result is not the isolated red proof.
- Production-only commit `24ba0df` repaired original-name matching. Its first full gate exposed removal of the empty-query guard (**195 passed, 4 failed**, including cascading picker failures). Production-only follow-up `ec26eac` restores the guard; the existing and new empty-search assertions catch this behavior. Failed gate log: `C:\Users\Lage\AppData\Local\Temp\OPEN-001-search-final-gate.log`.
- Final bound gate ran through `gate-evidence.ps1` on clean committed tip `ec26eacdb160fdfd9e09b7cf8b58cd1d3fc8beba`: `godot --headless -s tests/run.gd` -> **199 passed, 0 failed**, exit 0, including all ten catalog tests and the real picker/setup tests. No SKIP lines. Log: `C:\Users\Lage\AppData\Local\Temp\OPEN-001-search-green-gate.log`; SHA-256 `747A6805554B9989375AA7D8A224DC6560C7152E8E4F03A690CCBCB976996023`. The current Gate evidence line points to its receipt.
- Final diff and `git diff --check` pass; tests and production changes remain in separate commits and within Primary files. Only this tracker handoff follows tested production. No contract changes, proxy decisions or new dependencies. This correction changes no visual layout; manual mouse/keyboard acceptance was not repeated. The previous full-catalog Sicilian/Najdorf scenario remains recorded above.

Acceptance: passed | The original-punctuation regression and all 199 tests pass on `ec26eac`; prior real-scene Sicilian/Najdorf acceptance remains recorded above. Independent stage-3 re-review is next.
Disclosure: pending | integration | Criterion-4 correction in `24ba0df` and `ec26eac` has red/green evidence; independent stage-3 re-review must confirm the repair before session integration.

#### Resolution (2026-10-25)

Verdict: Approve

Independent Standards (`/root/standards_review`) and Spec (`/root/spec_review`) sub-agents re-reviewed `0e05af227ed3d162d5e8eae3311200092d91e4af...53c255e31111b0ecc16ea4df5657706799ec830a`, including the criterion-4 finding and every intervening commit. This review authored no production or test changes and made no contract changes or proxy decisions.

##### Standards

No documented-standard violations or meaningful baseline smells. The correction touches only `bot/book.gd`, `tests/test_catalog.gd` and permitted ticket metadata. `8566c4e` contains tests and ticket metadata; `24ba0df` and `ec26eac` contain production only; `53c255e` contains the handoff only. The regression exercises public loader/search APIs with independent expected paths. No unrelated refactor or dependency was introduced.

##### Spec

4. ✅ Original names and punctuation-spanning mixed-case substrings now match, including both reported Vienna and Polish examples. Normalized-path queries remain compatible; matching nodes and ancestors retain parent-before-child order. Empty searches show all nodes, unmatched searches show none, and unrelated branches remain excluded.

Criteria 1, 2, 3, 5, 6 and 7 retain their prior ✅ verdicts: their behavior is unchanged by this correction. The original-name index is populated only for successfully parsed rows, accumulates across TSV volumes and resets with a catalog reload. Duplicate names map to their existing deterministic tree path. Tree structure, checkbox state and saved selection IDs remain unchanged. No missing requirement, scope creep, incorrect implementation or previous-pass miss was found. Standards: 0 findings. Spec: 0 findings.

Examined: the incremental production/test/ticket diff, every commit stat, original-name normalization and index lifecycle, family/variation/empty/unmatched search behavior, picker `_rebuild` ordering, setup callers and existing catalog tests. Manual mouse/keyboard interaction, visual layout, exported builds and live Lc0 were not repeated in this re-review; the earlier full-catalog Sicilian/Najdorf acceptance and screenshot remain recorded above. Book weighting remains OPEN-002.

Red/green: inspected the retained authorized red log for `8566c4e`: **9 passed, 1 failed**, with five failed original-punctuation queries in the new regression. The committed correction's bound gate reports **199 passed, 0 failed**, exit 0, including all ten catalog tests and the real picker/setup tests, with no SKIP lines. The separate production follow-up `ec26eac` restores the empty-query guard after the recorded intermediate gate failure.

Gate: `Assert-GateEvidence` verified the receipt against reviewed HEAD, after rebase and against the merged session tree. Command: `godot --headless -s tests/run.gd`; tested commit: `ec26eacdb160fdfd9e09b7cf8b58cd1d3fc8beba`; receipt: `C:\Users\Lage\AppData\Local\Temp\OPEN-001-search-green-gate.json`; log SHA-256: `747A6805554B9989375AA7D8A224DC6560C7152E8E4F03A690CCBCB976996023`. Hash and exit marker match; production is identical, so the existing green run was reused. `git diff --check` passes.

Integration: rebase onto `sweatshop/core/2026-10-25-0159` was already up to date. Merged without conflicts or squash as `36cfe6b961d09f6208cf069b1c4ad39051968d69`; its tree exactly matches the reviewed ticket tip. Stage and ledger are closed together on the session branch. No PR or push is part of this stage.

Acceptance: passed | [Catalog regression and real-scene tests](../../../tests/test_catalog.gd) pass in the 199/199 gate; the earlier Sicilian/Najdorf selection scenario remains valid. Independent re-review confirms the original-punctuation repair.
Disclosure: decision | none | The earlier criterion-4 integration condition is resolved by [this independent re-review](#resolution-2026-10-25-1) and unchanged-code gate verification. No unresolved finding or accepted deferral remains on OPEN-001.
