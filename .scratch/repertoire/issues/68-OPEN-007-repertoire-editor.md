# OPEN-007: Edit a repertoire on the board
Stage: to-review
Blocked by: OPEN-006
Review: agent
Difficulty: normal

- Primary files:
  - New: ui/repertoire_editor.gd
  - New: ui/repertoire_editor.tscn
  - ui/repertoire_screen.gd, ui/repertoire_screen.tscn (an Edit button)
  - bot/repertoire.gd (save edited lines)
  - tests/test_repertoire.gd
  - docs/spec.md (§15.9)

#### What to build

An editor where you extend lines and add branches by playing moves on the board (§15.9). It works on any repertoire, imported or built from names, and saves in the same format.

#### Acceptance criteria

1. Edit opens the editor from a selected line's final position, or from the start position.
2. Playing a legal move on the board extends the current line or, mid-line, adds a branch.
3. A tree list beside the board shows the branches; clicking a node shows its position.
4. Right-clicking a move deletes it and everything after it.
5. Save writes the repertoire in the existing format, and it then works in My repertoire mode and the review; Cancel discards every change.
6. No comments, NAGs or main-line marking.

#### Verification

    Manual: add a branch to an imported repertoire, delete a sub-line, save, play it in My repertoire mode.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_repertoire.gd`: extending a line, branching mid-line and deleting a sub-tree give the expected lines after save and reload; Cancel leaves the file unchanged (red: no editor).

## Comments

- 2026-10-30 Written from spec §15.9 and the design brief (screen 9).

- 2026-10-30 Stage 2: focused extension red 10 passed / 1 failed (editor absent), green 11 / 0; annotation preservation red 11 / 1, green 12 / 0; screen entry red 12 / 1, green 13 / 0; subtree deletion mutation red 13 / 1, green 14 / 0. Gate: 276 reported passed, 0 failed, including 4 Lc0 skips (272 executed).
- Acceptance: pending | Manually add a branch to an imported repertoire, delete a sub-line, save, and play it in My repertoire mode; inspect rendered layout and physical input.
- Disclosure: pending | release | Manual editor layout, physical input and My repertoire acceptance remain outstanding.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\open007-gate.json
