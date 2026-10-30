# OPEN-005: A repertoire screen, and repertoires from opening names
Stage: done
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
  - docs/spec.md (§15.9)

#### What to build

Today a repertoire only comes from importing a PGN, through a dialog on the setup screen. This adds a repertoire screen listing the saved repertoires, with Import PGN and a new **From openings** (§15.9): pick lines by name from the catalog, as on Lichess, and save them as a repertoire.

#### Acceptance criteria

1. A repertoire screen lists the saved repertoires, with Import PGN (today's import) and From openings; the setup screen's repertoire controls open it, and it has a way back.
2. From openings opens the catalog as a tree of names only (Family → Variation → Sub-variation, for example "Caro-Kann Defense: Advance Variation"), with checkboxes and no move sequences.
3. You pick a colour (White/Black) and a name; Save stores the checked lines like an imported repertoire, and the new repertoire appears in the list and in setup.
4. A repertoire built this way works for "My repertoire" mode, "check my moves" and the review markers exactly as an imported one.
5. Saving with no line checked or an empty name is refused with a message.

#### Verification

    Manual: build a Caro-Kann repertoire as Black from names, play it in My repertoire mode.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_repertoire.gd`: two checked catalog entries saved as Black load back as lines equal to their catalog moves, and `bot/book.gd` follows them in My repertoire mode; no lines or no name is refused (red: no function).

## Comments

- 2026-10-30 Written from spec §15.9 and the design brief (screen 8). No repertoire screen existed, so this ticket creates it.

- 2026-10-30 Stage 2: catalog selections save via the existing PGN import and reload path. Focused red: missing save_openings (8 passed, 1 failed); focused green: 9 passed. Updated test_real_import_and_setup_controls_adopt_saved_colour_and_reject_invalid_files to enter through the new screen; replacing the new entry point with the old importer made its screen assertion fail.
- Gate: 271 reported passed, 0 failed, including 4 Lc0 skips (267 executed); no Lc0 executable.
- Acceptance: pending | Build a Caro-Kann repertoire as Black from names and play it in My repertoire mode; visual layout and real input remain unverified.
- Disclosure: pending | release | Manual Caro-Kann gameplay and visual/input acceptance remain outstanding.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\open-005-gate.json

#### Resolution (2026-10-30)
Verdict: Approve

- Standards: no documented-standard violations or actionable smell findings. Primary-files boundaries and separate test/production commits verified. Restored ticket character encoding without changing its requirements.
- Spec: all five numbered criteria pass the implementation review; no missing requirement or scope creep. Viewer/editor remain OPEN-006/OPEN-007.
  1. ✅ Setup opens the repertoire list; Import PGN, From openings and Back are connected.
  2. ✅ The catalog tree uses family/variation names and checkboxes without move sequences.
  3. ✅ Saving propagates the name and White/Black colour through persistence, list refresh and setup selection.
  4. ✅ Catalog lines use the existing validated PGN format; My repertoire, check-my-moves and review badges consume the same reloaded lines.
  5. ✅ Empty selection and blank name leave the picker open with an error and create no save.
- Coverage: all 9 changed files reviewed (9 reviewed, 0 skipped, 100%). OCR preview excluded all 9 as unsupported_ext, so every GDScript, scene and Markdown file was examined directly. Reviewed the full a02229c...e5f1111 diff and the unchanged importer, Book, PGN parser, main/review and badge consumers.
- Paths examined: setup entry, import and catalog saving, family/variation selection, save signals, list/setup refresh, saved-colour adoption, My repertoire startup, catalogue-mode isolation, rematches, review snapshots and badges. Failure paths included empty selection/name, invalid PGN/name/colour, missing saves, catalog-load errors and persistence errors through the reused importer. No physical keyboard/mouse, rendered-layout, live Lc0 or clean-machine acceptance was performed.
- Red-green evidence inspected: stage-2 focused logs show 8 passed/1 failed for missing save_openings, then 9 passed/0 failed. The old-entry-point mutant fails the new screen assertion (8 passed/1 failed). Test-only commits 3142a07 and 995c376 precede production commits 204a261 and 832cd44.
- Gate evidence verified with Assert-GateEvidence after rebase: tested commit 832cd443309fc9b530f5350f55a5dc7634d6062b, matching SHA-256 log hash, ExitCode: 0; 271 reported passed, 0 failed, including 4 Lc0 skips (267 executed). Only tracker metadata differs; the gate was reused without rerunning.
- Additional synthetic UI probe: 17 checks, 0 failures, exit 0. It exercised From openings, names-only tree, both validation messages, saving Black, both lists, setup startup settings, reloaded lines, Black review badges and Back. Script/log: C:/Users/bruno/AppData/Local/Temp/open005-stage3-ui-probe.gd and C:/Users/bruno/AppData/Local/Temp/open005-stage3-ui-probe.log. Godot also emitted a sandbox certificate-store startup diagnostic; the probe recorded no script errors.
- Integration: ticket branch rebased onto sweatshop/repertoire/2026-10-30-1830 without code changes and merged with --no-ff as c0a5cad. No production repair was authored during review.

Acceptance: pending | Manually build a Caro-Kann repertoire as Black from the real catalog and play it in My repertoire mode; rendered layout and physical input remain unverified. Synthetic checks above do not replace this product acceptance.
Disclosure: pending | release | The manual Caro-Kann gameplay and visual/input checks in this Resolution remain a release condition; session integration is approved with that condition recorded.
