# OPEN-003: Repertoire import and My repertoire mode
Stage: implementing
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
