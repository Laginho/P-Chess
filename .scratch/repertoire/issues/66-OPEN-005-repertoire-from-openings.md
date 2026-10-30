# OPEN-005: A repertoire screen, and repertoires from opening names
Stage: to-review
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - New: ui/repertoire_screen.gd
  - New: ui/repertoire_screen.tscn
  - ui/opening_picker.gd, ui/opening_picker.tscn (a names-only mode)
  - ui/repertoire_import.gd, ui/repertoire_import.tscn
  - ui/setup.gd, ui/setup.tscn (open the screen from the repertoire controls)
  - bot/repertoire.gd (save lines built from catalog entries)
  - tests/test_repertoire.gd
  - docs/spec.md (Â§15.9)

#### What to build

Today a repertoire only comes from importing a PGN, through a dialog on the setup screen. This adds a repertoire screen listing the saved repertoires, with Import PGN and a new **From openings** (Â§15.9): pick lines by name from the catalog, as on Lichess, and save them as a repertoire.

#### Acceptance criteria

1. A repertoire screen lists the saved repertoires, with Import PGN (today's import) and From openings; the setup screen's repertoire controls open it, and it has a way back.
2. From openings opens the catalog as a tree of names only (Family â†’ Variation â†’ Sub-variation, for example "Caro-Kann Defense: Advance Variation"), with checkboxes and no move sequences.
3. You pick a colour (White/Black) and a name; Save stores the checked lines like an imported repertoire, and the new repertoire appears in the list and in setup.
4. A repertoire built this way works for "My repertoire" mode, "check my moves" and the review markers exactly as an imported one.
5. Saving with no line checked or an empty name is refused with a message.

#### Verification

    Manual: build a Caro-Kann repertoire as Black from names, play it in My repertoire mode.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_repertoire.gd`: two checked catalog entries saved as Black load back as lines equal to their catalog moves, and `bot/book.gd` follows them in My repertoire mode; no lines or no name is refused (red: no function).

## Comments

- 2026-10-30 Written from spec Â§15.9 and the design brief (screen 8). No repertoire screen existed, so this ticket creates it.

- 2026-10-30 Stage 2: catalog selections save via the existing PGN import and reload path. Focused red: missing save_openings (8 passed, 1 failed); focused green: 9 passed. Updated test_real_import_and_setup_controls_adopt_saved_colour_and_reject_invalid_files to enter through the new screen; replacing the new entry point with the old importer made its screen assertion fail.
- Gate: 271 reported passed, 0 failed, including 4 Lc0 skips (267 executed); no Lc0 executable.
- Acceptance: pending | Build a Caro-Kann repertoire as Black from names and play it in My repertoire mode; visual layout and real input remain unverified.
- Disclosure: pending | release | Manual Caro-Kann gameplay and visual/input acceptance remain outstanding.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\open-005-gate.json
