# UI-032: Editor's new moves in green, short line names, dd/mm chart dates
Stage: done
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

#### Resolution (2026-10-31)
Verdict: Approve

##### Standards

- No findings. Reviewed the complete six-file diff from `396626a03bf17470e64f29afc5173edb835a3175` to `29a44c2ff88bea7a54072599860793676324def4`, all seven commits, AGENTS.md and the tracker rules. All production and test changes stay in Primary files; each test-only commit precedes its production-only commit.

##### Spec

1. ✅ New moves use `#a6cf7a`; saved moves keep the normal colour. Selected moves retain dark text on the green background. Save rebuilds the persisted tree through PGN without the transient marker; reopening starts clean.
2. ✅ The fixture's three Advance lines use `Advance: ...`; Classical, Exchange, Panov and Two Knights retain their short names. Full names remain in tooltip and accessibility_name.
3. ✅ Both PGN and filename dates render as `dd/mm`; all analysed games and the 0–100 axis remain intact.
4. ✅ Compared Repertoire, RepertoireEditor and Profile captures at 1280×800 and 800×600 with the three reference PNGs. The unselected new `4.c3` is light green, and scrolling Profile at 800×600 exposes the complete chart with `06/08` and `03/10` labels. Content wraps, ellipsizes or scrolls without overflowing its panels. Gate: 489 passed, 0 failed, exit 0.

- Coverage: editor present/play/select/delete/Save/Cancel/reopen; successful and failed save paths through `Repertoire.save_edited()` and `import_pgn()`; list refresh and catalog naming; Profile's PGN/filename date sources and chart rendering. The edited tree is a deep copy, so cancelling or a failed save preserves saved data. Physical input, a screen reader and live engines were not exercised in this review.
- Red/green evidence read: `ad18857` fails because the new move has the normal colour (45 passed, 1 failed); `01b6448` fails on the old long names (1 passed, 1 failed); `1d164bd` fails on the missing date formatter (4 passed, 1 failed). Subsequent production commits pass the focused naming/date checks (2/0 and 5/0) and the full gate, including the editor regression.
- Verified the existing gate receipt's command, exit code, log SHA-256 and equality of production with tested commit `7addff6f2c9569ab758f79ddce290c2f798f7704`. Rebase was already up to date and review changed no production, so the gate was reused. `git diff --check` passed.
- Visual evidence: `C:/Users/bruno/AppData/Local/Temp/pchess-ui032-captures-20261031/Repertoire-{1280x800,800x600}.png`; supplemental `RepertoireEditor-{1280x800,800x600}.png` and `Profile-{1280x800,800x600}.png` in `C:/Users/bruno/AppData/Local/Temp/pchess-ui032-review-2c00bdf8c68e44f8bd3ebaaae119d2cb/`. The supplemental script reuses `scripts/screens.gd` in a temporary directory, selects an existing move after adding `4.c3`, and scrolls Profile before capture. APPDATA and PCHESS_SCREENSHOTS_ROOT were isolated before each launch; all four captures exited 0.
- Integrated into `sweatshop/ui-polish/2026-10-31-2256` with merge commit `7da7a056006e848b0a458b9b2ac8f8a056dec523`; no production repairs were needed. Standards: 0 findings; Spec: 0 findings.

Acceptance: passed | All four numbered criteria verified; supplemental captures above complete the two previously pending visual states.
