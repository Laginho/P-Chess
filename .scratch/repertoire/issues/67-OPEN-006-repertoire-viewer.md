# OPEN-006: View a repertoire on a board
Stage: done
Blocked by: OPEN-005
Review: agent
Difficulty: normal

- Primary files:
  - ui/repertoire_screen.gd
  - ui/repertoire_screen.tscn
  - ui/board_view.gd (read-only use; touch only for a read-only mode if REV-005 has not added one)
  - tests/test_repertoire.gd
  - docs/spec.md (§15.9)

#### What to build

The repertoire screen gets a board beside the list (§15.9), so you can see what a repertoire holds.

#### Acceptance criteria

1. Selecting a repertoire lists its lines by name (the catalog name where a line matches one, otherwise its moves).
2. A board beside the list shows positions from the repertoire colour's side, and cannot be moved on.
3. Clicking a line shows its final position with the last move highlighted; ←/→ step back and forth through that line.

#### Verification

    Manual: open a repertoire, click a line, step through it.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_repertoire.gd`: selecting a Black repertoire flips the board; clicking a line shows its final FEN; ← then → return to it (red: no viewer).

## Comments

- 2026-10-30 Written from spec §15.9. Blocked by OPEN-005 because that ticket creates the screen.

- 2026-10-30 Stage stopped (incomplete handoff): Invalid committed handoff: Illegal characters in path. See C:\Users\bruno\Desktop\Pastinha\Programas\Projects\P-Chess\.artifacts-build\lanes\repertoire\.scratch\run-log\OPEN-006-implement-20261030-184720.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.
- 2026-10-30 Foreman repair: the stop above was a corrupt `Gate evidence:` path in the stage-2 handoff (backslashes dropped by the writer; see OPEN-006-implement-20261030-184720.txt). The evidence JSON is intact (Code 84cfd26 = the feat commit, gate exit 0, 272 passed). Path repaired on the ticket branch (71b2b4a); work unchanged, sent to review.
- 2026-10-30 Stage 2: focused red 9 passed, 1 failed (viewer missing); green 10 passed, 0 failed. Gate 272 reported passed, 0 failed, including 4 Lc0 skips (268 executed).
- Acceptance: pending | Manually open a repertoire, select a line, and step with the physical arrow keys; inspect rendered layout and board highlighting.
- Disclosure: pending | release | Manual viewer layout, highlighting, and physical input acceptance remain outstanding.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\open-006-gate.json

#### Resolution (2026-10-30)
Verdict: Approve

- Reviewed `7322f84...5a834ca` after rebasing onto `sweatshop/repertoire/2026-10-30-1830`; merged without squash as `847eccd`. Rebase conflicts affected ticket metadata only; both the foreman repair history and implementation handoff were preserved. No production behavior was authored during review.
- Standards: no findings. All changes respect Primary files, and the test-only (`e7b9703`), production-only (`2a02c46`) and metadata commits retain the required split.
- Spec: no findings. Criterion 1 passes: exact catalog line/start-position matching supplies names, with moves as fallback. Criterion 2 passes: the existing board is beside the line list, follows the repertoire colour and ignores GUI mouse input. Criterion 3 passes: selection shows the saved final position and last move, and arrow navigation clamps between root and leaf.
- Coverage: 4 changed files, 4 reviewed, 0 skipped, 100%. OCR delegate preview excluded all four as `unsupported_ext`; the ticket, `tests/test_repertoire.gd`, `ui/repertoire_screen.gd` and its scene were reviewed directly with the resolved default rules.
- Examined callers and failure paths: Setup selection/reload/start, importer save/refresh, nested opening picker, asynchronous catalog completion and selection changes, unavailable catalog fallback, saved-file errors, imported/custom-FEN lines, board highlighting and mouse dispatch. No additional cross-feature path was identified as affected. Rendered layout, visual highlighting and physical keyboard/device input were not examined.
- Red/green evidence inspected: `open006-red.log` has 9 passed / 1 failed because the viewer was absent; `open006-green.log` has 10 passed / 0 failed. The gate receipt's command, successful exit, log SHA-256 and code equality against the rebased/merged code were verified. Gate result: 272 reported passed, 0 failed, 4 Lc0 skips (268 executed), exit 0. Existing evidence was reused because production did not change.
- Additional headless probe through actual popup Viewport dispatch: 15 checks passed, exit 0. Covered catalog labels/move fallback, both orientations, one-ply stepping and endpoint clamps, mouse move rejection, and arrow caret editing in the importer and opening picker without changing the viewer. Probe/log: `C:/Users/bruno/AppData/Local/Temp/open006-review-probe-20261030.gd` and `C:/Users/bruno/AppData/Local/Temp/open006-review-probe-20261030.log`. This is synthetic input evidence, separate from manual acceptance.

Acceptance: pending | [Manual verification](#verification): open a repertoire, select a line and use physical arrows; inspect rendered layout and last-move highlighting. Headless verification above passed.
Disclosure: pending | release | [Manual verification](#verification) remains a release condition; this implementation approval permits session integration.
