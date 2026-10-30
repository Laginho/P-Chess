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
Gate evidence: C:\Users\bruno\AppData\Local\Temp\open007-reopen-gate.json

#### Stage 3 review (2026-10-30)
Verdict: Reopen — criteria 1, 2, 4 and 5 fail; preserve the implementation branch and repair the four findings below.

- Reviewed the complete `fc4ae15011bdd5eb89082a72f2e3e4a8855495cd...5f837550b8edbd7686652ad3ec496a84a1fc66e9` diff against the session base `sweatshop/repertoire/2026-10-30-1830`, with independent Standards and Spec reviews. Coverage: 7 changed files, 7 reviewed, 0 skipped. No production changes were authored in review; no merge or push was performed.
- Standards: 0 documented violations and 0 material baseline smells. All 8 commits respect Primary files and the test/production/metadata split. Inspected the extension, annotation, entry/Cancel and deletion red/green logs, including the deletion mutation proof. Spec: 4 confirmed findings, no scope creep.

1. **P1 — criterion 1, editor entry is inaccessible** (`ui/repertoire_screen.tscn:55`, `ui/repertoire_screen.gd:49`): Edit starts with `disabled = true`, and neither repertoire selection nor line selection enables it. Selecting a valid saved repertoire leaves the button disabled; dispatched mouse input produces no `pressed` event and the editor stays hidden. `tests/test_repertoire.gd:483` emits `pressed` directly and therefore bypasses the defect. Enable Edit after a valid repertoire loads, and disable it when selection is cleared or loading fails. Test actual button availability/activation for both root and selected-line entry.
2. **P2 — criterion 4, actual right-click breaks the tree refresh** (`ui/repertoire_editor.gd:109`): `_mouse_selected()` synchronously calls `_refresh()` during Tree mouse selection. Godot rejects `tree.clear()` and `create_item()` in that callback (`:61-65`), ending in a null `set_text` call. The underlying subtree is deleted, but its TreeItems remain and the board still shows the removed position; selecting a stale node then refers to a missing child. Defer the refresh until the mouse selection event finishes. Exercise real input dispatch and assert that the tree and board update without script errors; emitting `item_mouse_selected` directly does not enter Godot's selection guard.
3. **P2 — criterion 2, legal continuations can be rejected** (`ui/repertoire_editor.gd:46`): `_show_position()` creates a normal `Game`, which ends immediately on insufficient material. The accepted imported PGN `[SetUp "1"] [FEN "7k/8/8/8/8/8/8/KB6 w - - 0 1"] 1. Ba2 *` reaches a position where `h8g7` is legal, but `BoardView.play("h8g7")` returns false because `Game.reason` is `insufficient material`. Permit legal editor continuations independently of automatic game adjudication, without changing normal gameplay rules.
4. **P2 — criterion 5 / imported-annotation preservation regression** (`bot/repertoire.gd:168`): serializing `comments_before` as ordinary comments in a linear chapter changes their attachment. Import `1. e4 e5 ({Sicilian} 1... c5) *` and save without changing that branch: `c5.comments_before` becomes empty and `e4.comments` gains `Sicilian`, because the emitted chapter is `e4 {Sicilian} c5 *`. Preserve the annotation's branch association through save/reload. Criterion 6 still excludes annotation editing controls; this finding concerns existing imported data.

- Criterion verdicts: 1 ❌ entry disabled; 2 ❌ legal continuation above; 3 ✅ ordinary node selection shows the correct position (post-deletion stale state is finding 2); 4 ❌ event-time refresh; 5 ❌ annotation attachment (existing-format load, normal branch persistence and Cancel otherwise pass); 6 ✅ no comments/NAG/main-line controls.
- Examined callers, failure paths and interactions: Setup selection/refresh/start, imported and catalog-built repertoires, custom-FEN and multiple-root trees, selected-line/root entry, both board orientations, legal-move branching, Tree selection and right-click event timing, Save/error/atomic-write paths, Cancel isolation, My repertoire book preparation and review consumers. The save format remains readable by those consumers; the annotation regression is described above. Rendered layout, physical input, live Lc0 play and human product acceptance were not verified.
- Gate evidence was verified and reused: command matches the binding, exit 0, SHA-256 matches the log, and only this tracker ticket differs from tested commit `2d740be7bd53d50488bdc178d6cd082c3b8e01ee`. Result: 276 reported passed, 0 failed, including 4 Lc0 skips (272 executed). No gate rerun: production did not change. Stage-2 focused logs show extension 10/1 → 11/0, annotations 11/1 → 12/0, entry 12/1 → 13/0, and deletion mutation 13/1 → 14/0.
- Additional synthetic input evidence: `C:/Users/bruno/AppData/Local/Temp/open007-review-ui-probe.gd` and `.log`, 12 checks / 4 failed assertions, exit 1. One assertion reproduces finding 1; three reproduce finding 2 (engine errors, stale tree and stale board). Tree-node click, board-drag branching, underlying subtree deletion and save/reload pass through direct editor entry. The final probe uses embedded windows at the requested size and `Input.parse_input_event` so Tree receives the correct mouse position. Earlier `Window.push_input` attempts left its mouse position stale and are not evidence of a product defect.
- Additional save/position evidence: `C:/Users/bruno/AppData/Local/Temp/open007-spec-review-probe.gd` and `.log`, exit 0, records the accepted FEN, legal move rejected for insufficient material, and annotation arrays before/after save. Both probes report the environment's root-certificate-store warning; no network operation was needed for these reproductions.

Acceptance: pending | [Verification](#verification): the four implementation findings above must be repaired; manual editor layout, physical input and My repertoire acceptance remain outstanding.
Disclosure: pending | integration | This open ticket tracks all four findings; repair and re-review are required before session integration.
Disclosure: pending | release | [Verification](#verification): manual editor layout, physical input and My repertoire acceptance remain release conditions after implementation approval.

- 2026-10-30 Reopened stage 2: enabled Edit only after successful load and reset it on refresh/failure; kept editor moves legal after automatic draws; deferred Tree refresh after right-click; retained leading variation comments on PGN round-trip. Focused red/green: availability 14/1 to 15/0; draw, comment and actual right-click reproductions each failed before and passed after their fixes. Gate: 280 reported passed, 0 failed, including 4 Lc0 skips (276 executed).
- Acceptance: pending | [Verification](#verification): manually inspect editor layout and physical input, add and delete a branch, save, and play in My repertoire mode.
- Disclosure: pending | integration | The four reopened findings require stage-3 re-review.
- Disclosure: pending | release | Manual editor layout, physical input, and My repertoire acceptance remain outstanding.
