# OPEN-006: View a repertoire on a board
Stage: to-review
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
