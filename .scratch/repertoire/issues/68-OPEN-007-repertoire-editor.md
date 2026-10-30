# OPEN-007: Edit a repertoire on the board
Stage: done
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

#### Resolution (2026-10-30)
Verdict: Approve

- Re-reviewed `5f837550b8edbd7686652ad3ec496a84a1fc66e9...21cc6cc03ffef156be8185c62dcc70c3de7e6b8d` after the four reopened repairs, using independent Standards and Spec reviewers. Coverage: 5 changed files, 5 reviewed, 0 skipped; the original 7-file implementation review remains recorded above. No production behavior was authored during this review.
- Standards: 0 documented violations and 0 material baseline smells. The four new test-only commits alternate with production-only fixes; all changes remain within Primary files, with reopen/handoff metadata separate.
- Spec: 0 new findings and no scope creep. All four previous findings are resolved. Criterion 1 passes: Edit enables only after successful load, resets after refresh/failure, and real dispatched clicks open both the root and a selected line's final position. Criterion 2 passes: the editor permits legal moves after automatic draws while Game/Board continue validating legality; normal gameplay still uses Game. Criterion 3 passes: tree-node selection shows the matching position. Criterion 4 passes: right-click removes the move and descendants, then refreshes Tree/board after the deferred queue drains. Criterion 5 passes: save/reload preserves branches and leading variation annotations in the existing format; Cancel isolation and Book/Badges consumers remain valid. Criterion 6 passes: no annotation or main-line editing controls were added.
- Rechecked callers, failure paths and interactions: repertoire selection/refresh, invalid saved JSON, root/selected-line entry, normal Game and BoardView legality checks, draw positions, Tree mouse dispatch/deferred rebuilding, PGN RAV parsing and merged annotations, custom-FEN/Black roots, and Setup/Book/Badges consumers. No additional affected path was identified. Rendered layout, physical device input and live My repertoire play were not verified.
- Red/green evidence inspected: availability 14 passed / 1 failed -> 15 / 0; the legal-draw reproduction failed on the rejected move and missing saved continuation; annotation reproduction failed on misplaced/missing leading comments; real right-click reproduction failed on Tree selection-guard errors and stale Tree/board. Each corresponding focused green log reports 0 failures. Source/test commits remain separate.
- Gate receipt `C:/Users/bruno/AppData/Local/Temp/open007-reopen-gate.json` was verified after rebase: bound command, exit 0, log SHA-256 and code equality against tested commit `14aa98d2472c67a5574cdbadc0ae77124f933b24` all match. Result: 280 reported passed, 0 failed, including 4 Lc0 skips (276 executed). Reused the receipt because production did not change; no full gate rerun.
- Additional synthetic input probe: `C:/Users/bruno/AppData/Local/Temp/open007-rereview-ui-probe.gd` and `.log`, 15 checks passed, 0 failures, exit 0. Covered actual Edit activation at root/leaf, tree-node selection, board drag branching, right-click subtree removal, deferred Tree/board refresh and save/reload. The probe waits for the deferred queue; its earlier one-frame observation ran before that refresh and is not a product defect.
- Independent serialization probe: `C:/Users/bruno/AppData/Local/Temp/open007-spec-rereview-nesting.gd` and `.log`, 3 exact tree/line round-trips passed, exit 0, covering nested leading comments, NAGs/post-comments, sibling branches and a Black-to-move FEN root. Probe startup reported environment log/certificate-store warnings; no product script/Tree errors occurred.
- Rebased onto `sweatshop/repertoire/2026-10-30-1830` (already current), merged the ticket history without squash as `ac455eb`, and recorded Stage: done with the ledger in this closure commit. The earlier integration disclosures are resolved by this re-review. No push or PR was performed; the session driver owns publication.

Acceptance: pending | [Verification](#verification): manually add a branch to an imported repertoire, delete a sub-line, save and play in My repertoire mode; inspect rendered layout and physical input. Automated implementation checks passed.
Disclosure: decision | none | [Resolution](#resolution-2026-10-30): all four reopened findings are repaired and independently re-reviewed; session integration is approved.
Disclosure: pending | release | [Verification](#verification): manual editor layout, physical input and My repertoire acceptance remain release conditions.
