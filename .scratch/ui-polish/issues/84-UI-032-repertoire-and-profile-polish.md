# UI-032: Editor's new moves in green, short line names, dd/mm chart dates
Stage: to-review
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/repertoire_editor.gd (moves added in this editor session)
  - ui/repertoire_screen.gd (line names, around the "opening family" comment at line ~228)
  - ui/accuracy_chart.gd (axis date labels)
  - tests/test_repertoire.gd, tests/test_profile.gd

#### What to build

Follow-up of the UI redo (`.scratch/ui-redo/spec.md`): three taste calls the PR #34 fidelity pass left to Bruno, which he approved on 2026-10-31.

1. **New moves in light green.** In the repertoire editor, moves added during the current editing session (not yet saved) show in the light green the canvas uses for them (`docs/design/v0.1.0/RepertoireEditor.dc.html` has the exact colour). After Save, or for moves that were already saved, they show as normal.
2. **Shorter line names**, as the canvas draws them (`Repertoire.dc.html`): within one opening family, "Advance: Short Variation" instead of today's "Advance Variation, Short Variation". The full name stays in the tooltip and the accessible name.
3. **Chart dates as `dd/mm`** on the Profile accuracy chart's axis ("14/09"), instead of "2026.08.06". Bruno chose this over the canvas's "Sep 14". The chart otherwise keeps the spec: every analysed game, 0–100 axis.

#### Acceptance criteria

1. Moves added since the editor opened (or since the last Save) render in the canvas's light green; saved moves and moves after Save render in the normal colour.
2. Line names in the Repertoires list follow the canvas's short form for every family in the fixture; full names stay in tooltip and accessible name.
3. Profile's chart axis labels read `dd/mm`.
4. Captures of Repertoire, RepertoireEditor and Profile at 1280×800 and 800×600 compared with the reference PNGs by eye; nothing clipped. Gate green.

#### Verification

`scripts/screens.gd` (usage in `docs/design/v0.1.0/README.md`), isolated root; cite the PNGs in a comment.

    godot --headless -s tests/run.gd

## Comments

- 2026-10-31 Opened by the parent session after PR #34 merged, from the fidelity pass's "for Bruno" list. The other calls on that list (current-move highlight shape, accuracy with "%", eval with a sign, panel buttons disabled after the game) were accepted as they are.
- 2026-10-31 Implemented the three changes; updated `test_viewer_line_names_drop_the_shared_opening_family` for the new display contract. Focused red/green checks covered new move colour, line names, and both PGN and filename dates. Full gate: 489 passed, 0 failed.
- Visual comparison with `docs/design/v0.1.0/png/Repertoire.png`, `RepertoireEditor.png`, and `Profile.png`: captures are `C:/Users/bruno/AppData/Local/Temp/pchess-ui032-captures-20261031/{Repertoire,RepertoireEditor,Profile}-{1280x800,800x600}.png`. At 800x600 Profile scrolls and the chart is below the initial viewport; the editor capture shows the new move selected, so its unselected green is covered by the focused test rather than that capture.
- Acceptance: pending | Inspect the scrolled Profile chart at 800x600 and the unselected new move visually; the captures above do not show those states.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/ui032-gate.json
