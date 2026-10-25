# OPEN-003: Repertoire import and My repertoire mode
Stage: to-review
Blocked by: CORE-006, OPEN-002
Review: agent
Difficulty: normal

- Primary files:
  - New: bot/repertoire.gd
  - bot/book.gd
  - New: ui/repertoire_import.tscn, ui/repertoire_import.gd
  - ui/setup.tscn, ui/setup.gd (My repertoire mode)
  - ui/main.gd (OPEN-003 lifecycle only: load the saved repertoire before starting play, route its book to Maia in My repertoire mode, preserve the shared catalog for history recognition, and handle actual game colours, rematches, mode changes and load failures)
  - New: tests/test_repertoire.gd
  - New: tests/fixtures/pgn/repertoire_*.pgn
  - tests/test_catalog.gd (only migrate the temporary My repertoire-disabled assertion in test_setup_lists_saved_selections_and_emits_catalog_choice_while_free_stays_compatible to expect the mode enabled; preserve all other assertions)

#### What to build

Import your repertoire as a PGN, choose its colour, and practise it in My repertoire mode: Maia plays the PGN's moves for its side, with the same book weight as Catalog mode (§6.2–§6.4).

#### Acceptance criteria

1. Importing a PGN with variations, comments, NAGs and several games (Lichess study chapters) merges everything into one move tree; identical moves from different games merge.
2. The human colour is chosen at import and saved with the repertoire under `user://`. Starting My repertoire from setup adopts and displays that saved colour. Rematches preserve the existing colour-swap behavior without modifying the repertoire's saved colour.
3. A line is one root-to-leaf path of the tree.
4. In My repertoire mode the imported tree's root-to-leaf paths replace the catalog's lines for Maia, with OPEN-002's target selection, practice counts and book weights unchanged. Maia uses the continuations for its actual side in the current game, including a colour-swapped rematch using the same tree. The saved repertoire must load successfully before a new game clock or Maia move request starts; failure reports an error and allows retry without falling back to a stale or catalog practice book. Switching to Catalog or Free restores that mode's existing behavior. History continues recognizing openings from the shared catalog in every mode.
5. A PGN with an illegal move reports the error with its move number and saves nothing.

#### Verification

    Manual: import a two-chapter study as white, play as white; Maia answers with the PGN's black moves.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_repertoire.gd`: production Repertoire/Book tests for merging chapters and variations, root-to-leaf counts, persistence of the human colour, book construction, and illegal-move diagnostics without saving; real import/setup/Main scene tests for import-to-start, saved-colour adoption, actual Maia-side continuations, swapped-colour rematches, Catalog/My repertoire/Free switching, preserved catalog history recognition, and failed repertoire loads followed by successful retry. Isolate storage and fake the external engine, while exercising the actual scene wiring. Red because the repertoire implementation and lifecycle integration do not exist.

## Comments

Proxy decided (gpt-6-astra high, fallback): Add narrowly scoped Main repertoire lifecycle wiring and real-scene tests in test_repertoire.gd; use the imported human colour for setup starts and the actual game colour for rematches — OPEN-003 requires replacing Maia's catalog book, while OPEN-002 preserves catalog-based history recognition and §9.1 requires swapped-colour rematches.

Disclosure: decision | none | OPEN-003 Comments, proxy scope/colour amendment: adds the existing Main lifecycle seam and scene tests, preserves shared-catalog history and swapped-colour rematches; no migration or additional release condition.

- Stage-2 harness correction: `Bh6` is legal after `1. d4 d5`; the illegal-move sample now uses `Bh5`. The correction is a separate test-only commit; the missing-import API red proof still applies, and the corrected test is rerun against the committed parser before restoring persistence implementation.

- Stage-2 scene-harness correction: probe Setup rather than an unready Main, whose dynamically allocated review/settings screens are not parented until `_ready`. Verify weighting by emitted production moves (a policy/cut that chooses e5 only with the imported weights), rather than inspecting Maia's pending request internals. Re-proved red against the pre-integration Main before restoring the implementation.

Proxy decided (gpt-6-astra high, fallback): Update only the temporary My repertoire-disabled assertion in test_catalog.gd to expect the mode enabled — OPEN-003 now implements the feature that the OPEN-001 assertion explicitly deferred; preserve every Catalog/Free assertion.

Disclosure: decision | none | OPEN-003 Comments, legacy setup assertion migration: replaces OPEN-001's temporary disabled-mode expectation with the now-implemented My repertoire behavior; all Catalog/Free assertions remain unchanged. No additional integration or release condition.

- First complete gate: `216 passed, 1 failed`, exit 1. The sole failure was the OPEN-001 temporary assertion `repertoire still belongs to OPEN-003`, now migrated as approved above. No production failure or script error was reported. The complete gate is rerun after the test-only migration.

#### Stage 2 handoff (2026-10-25)

- Branch: `OPEN-003-repertoire-import`, from `sweatshop/core/2026-10-25-0159` at `68cf569`. Both dependencies are committed `done`. Only approved Primary files and this ticket changed; every production commit excludes test edits.
- Implemented PGN import with the existing production parser: all chapters validate before saving; UCI children merge within each starting-position root, retaining comments/NAGs and nested variations. Short duplicate chapters do not add leaves. Lines contain stable content-derived IDs, UCI moves and position keys, including their initial/final positions.
- Public API: `Repertoire.new()` has `storage_dir` (default `user://repertoires`), `tree`, `lines`, and human `colour`. `parse(text, human_colour)`, `import_pgn(text, human_colour, name)`, and `load_saved(name)` return an empty string on success or a user-facing diagnostic. Failed validation, loading or saving preserves prior live data; import validates before opening a temporary file and atomically replaces `<name>.json` only on success. `names()` lists saved names. Version-1 JSON stores the original annotated PGN and human colour and is validated again on reload.
- `Book.load_repertoire(lines, actual_maia_side)` replaces its lines and selection state without changing target selection or weights. Main creates a separate practice book and retains the shared catalog for history recognition. Setup emits `opening: "My repertoire"`, `repertoire: <saved name>` and the imported human colour; the disabled colour control displays that choice. Explicit rematches use their existing swapped colour without changing the import. A failed saved-repertoire load reports an error before a new clock or policy request, and supports retry.
- Read around changed callers before integration: Main `_start` is reached by Setup `started`, review rematch, and Space rematch; setup refreshes are reached by picker saves, visibility and opening-mode changes. The new Book method is called by Main and repertoire tests; existing `begin_game`, `weights` and opening recognition are unchanged. Covered empty stores/PGNs/books, duplicate prefixes, nested branches, illegal moves in later chapters, unsafe filenames/colours, corrupt/missing saves, mode switching, actual Maia side, rematches, history and once-only counts. Final regression tests also protect missing-engine guidance and dismiss obsolete repertoire errors in Free.
- Red/green evidence (logs under `C:\Users\Lage\AppData\Local\Temp`): tree `14649ec` → `47d685a`: **0 passed, 1 failed → 1 passed, 0 failed**, `OPEN-003-tree-{red,green}.log`; persistence `7ff4a9f` + corrected harness `61f91a6` → `2680c95`: **1 passed, 1 failed → 2 passed, 0 failed**, `OPEN-003-save-corrected-red.log` / `OPEN-003-save-green.log`; Book `2e574d8` → `7bafa80`: **2 passed, 1 failed → 3 passed, 0 failed**, `OPEN-003-book-{red,green}.log`; import/setup `dd922a7` → `c673e12`: **3 passed, 1 failed → 4 passed, 0 failed**, `OPEN-003-ui-{red,green}.log`; Main `c2dc6a6` + corrected harness `be8141a` → `f90aeb6`: **4 passed, 2 failed → 6 passed, 0 failed**, `OPEN-003-lifecycle-corrected-red.log` / `OPEN-003-lifecycle-green.log`; setup diagnostics `6f77003` → `f7d4b51`: **6 passed, 1 failed → 7 passed, 0 failed**, `OPEN-003-status-{red,green}.log`. The initial tree red was sandboxed and additionally reported environment log/certificate access errors; its assertion failed because the production importer did not exist. Subsequent focused and full runs used normal local engine/user-directory access.
- Final bound gate on clean committed `e2702c13ea2cb37359e99ae70d28571330f6d6ee`: `godot --headless -s tests/run.gd` through `gate-evidence.ps1` → **217 passed, 0 failed**, exit 0; no SKIP, FAIL, script errors or engine errors. Existing malformed-theme/time-table warning cases remain expected. Log SHA-256: `DBF7D5DFBF1733CE603970B31F89C2DC9EFA427693320C7AD2AC8525886A3E8B`. Final diff/commit separation reviewed; `git diff --check` passes. Only tracker metadata follows the tested commit.
- Scripted product acceptance: actual Main/import/setup controls with real Lc0 Maia-1500, isolated preferences/history/repertoires and a small catalog fixture for history. Imported the three-chapter study (including a duplicate prefix) as White, obtaining four paths; started My repertoire; human `e4` received real Maia `e5` (strong weights: e5 **100**, c5 **15**, d5 **1**); finished practice incremented its target exactly once; swapped-colour rematch received real Maia White `e4`; imported human White remained unchanged. **0 acceptance failures**, no script/engine errors. Original game disabled artificial think delay; the rematch used normal lifecycle timing. Script: `C:\Users\Lage\AppData\Local\Temp\OPEN-003-acceptance.gd`; log: `C:\Users\Lage\AppData\Local\Temp\OPEN-003-acceptance.log`; saved evidence: `C:\Users\Lage\AppData\Roaming\Godot\app_userdata\[P] Chess\OPEN-003-acceptance-231560`. This is headless automation; visual layout, native file-dialog interaction and hands-on play were not assessed.

Acceptance: passed | C:\Users\Lage\AppData\Local\Temp\OPEN-003-acceptance.log — production import/setup/game controls with real Maia-1500, merged study, imported-colour start, imported replies, durable practice count and swapped-colour rematch; headless acceptance, without visual assessment.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\OPEN-003-green-gate.json
