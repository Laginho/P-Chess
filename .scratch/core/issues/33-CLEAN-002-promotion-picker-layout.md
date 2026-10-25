# CLEAN-002: Keep an open promotion picker aligned on flip and resize
Stage: blocked
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/board_view.gd (open-picker layout when orientation or size changes)
  - ui/promotion_picker.gd (picker geometry)
  - tests/test_board_view.gd (scene-backed picker geometry regression)

#### What to build

An open promotion picker should remain aligned with its promotion square when the board flips or the window resizes. UI-002's review identified that its buttons retain their original pixel positions, although choosing a piece still plays the correct move. The inherited note in [UI-007](20-UI-007-premoves.md) is tracked in this open follow-up before that ticket closes. This is a pre-existing cosmetic defect, not an unfulfilled UI-007 criterion.

#### Acceptance criteria

1. With a promotion picker open, flipping the board keeps its buttons aligned with the promotion square and its column directed toward the board's centre.
2. Resizing the board while the picker is open updates button positions and sizes to the board's new square geometry.
3. Choosing a piece after either change still submits the original promotion exactly once; cancellation leaves the game unchanged. Normal and premove promotion paths retain their existing behavior.

#### Verification

    Manual: open a promotion picker, flip and resize the board, choose an underpromotion; repeat and cancel.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_board_view.gd`: instantiate the real BoardView scene under the runner root, open a promotion picker through board input, change orientation and size, and compare its button rectangles with the promotion square geometry. Verify choosing/cancelling still targets the original promotion. Red because the flip setter and resize handler currently redraw only the board, leaving picker button geometry unchanged.

## Comments

- Created by UI-007 stage 3 on 2026-10-25 from the confirmed cosmetic issue recorded in [UI-002](../../side/issues/09-UI-002-board-feedback.md), Resolution / Examined, and inherited by UI-007. Source inspection still shows `BoardView.flipped` and `resized` only request redraws, while `PromotionPicker.open` sets button geometry once. No repair or new runtime behavior was authored during this review.
- Blocked for stage 1 to confirm the proposed criteria and scene-backed test seam before implementation. This follow-up does not block integration of UI-007 and adds no release condition to its contract.
- 2026-10-25 Stage 1 (human, Bruno): approved criteria 1-3 and the scene-backed `tests/test_board_view.gd` seam as written. Reposition the open picker on flip/resize (not close it). Low priority: cosmetic.
- 2026-10-25 Stage 2 (Claude Opus 5.5): `PromotionPicker.open(textures, white)` now only creates the buttons; the new `PromotionPicker.layout(at, cell, down)` places them. `BoardView._layout_picker()` computes the geometry from `_promoting` and runs on open, in the `flipped` setter and on `resized`, so the column, its direction toward the centre and the waiting pawn's `_drag_pos` follow the promotion square. `layout` skips buttons queued for deletion (a picker closed this frame). Callers examined: `_open_picker` is the only caller of `open`; `flipped` is also set on boards built without a scene, where `_promoting` is empty and nothing runs. Red: `de0f78e` gave 241 passed, 1 failed, only the new test, failing its flipped/resized rectangle asserts (choose/cancel asserts already held). Green: `6ef730d` gave 242 passed, 0 failed. Manual check in Verification not run (headless session).
- Gate run note: `godot --headless --import` leaves untracked `*.uid`/`*.import` files that `gate-evidence.ps1` treats as a dirty tree; the gate ran with a process-scoped `core.excludesFile` (env `GIT_CONFIG_*`) hiding only those two patterns, nothing committed or shared changed.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\claude\C--Users-bruno-Desktop-Pastinha-Programas-Projects-P-Chess--claude-worktrees-clean-002-947561\1299719d-3e60-4879-8e0c-179a9cce9e1f\scratchpad\gate-CLEAN-002.json

Acceptance: pending | the manual flip/resize/underpromotion check in Verification was not run (headless sessions); criteria 1–3 are exercised through the real BoardView scene in `tests/test_board_view.gd`.

#### Resolution (2026-10-25)
Verdict: Approve

Stage 3 (Claude Opus 5.5), Standards + Spec against the numbered criteria. PR [Laginho/P-Chess#11](https://github.com/Laginho/P-Chess/pull/11), merged without squash as `5e74015`.

1. ✅ The `flipped` setter calls `_layout_picker()`; the scene test checks all four button rects at (700,700) with the column going up after the flip.
2. ✅ `resized` calls `_layout_picker()`; the test resizes to 480×600 and checks 60 px buttons on the centred board's promotion square.
3. ✅ After flip + resize the test chooses (knight) and cancels on both the normal and the premove path: one move or premove `a7a8n`, `move_played` once on the normal path only, nothing on cancel.

- Files: only `ui/board_view.gd`, `ui/promotion_picker.gd`, `tests/test_board_view.gd` and this ticket. No code authored in stage 3.
- Test-first: `f38a8a7` (was `de0f78e`) is test + ticket only, red 241 passed / 1 failed per stage 2's log; `35691c9` (was `6ef730d`) is production only, green 242 / 0. `e4d8a69` is the handoff.
- Examined: every exit that clears `_promoting` (`_end_snap_back`, `_cancel_interaction`, `_commit`, the `game` setter), so a flip or resize after the picker closes does nothing; `ui/main.gd:300` is the only external `flipped` writer; `tests/test_session.gd` builds an off-tree board without `_ready` (no `resized` hook; `open` + `layout` still run); `layout` skips buttons queued for deletion; `_open_picker` is the only `PromotionPicker.open` caller. Not examined: windowed rendering (manual check above).
- Gate: stage 2's receipt (code `6ef730d`, log hash verified) was valid, but `main` moved (`a5fbc5b`, `AGENTS.md` only), so after the rebase the gate ran again on `e4d8a69`: **242 passed, 0 failed**, 3 skipped (no Lc0), exit 0. Receipt: C:\Users\bruno\AppData\Local\Temp\claude\C--Users-bruno-Desktop-Pastinha-Programas-Projects-P-Chess--claude-worktrees-clean-002-review-240bcb\e08c9689-3ad6-4b20-9e19-88b0804dc854\scratchpad\gate-CLEAN-002-review.json. PR CI `test` passed.
- Findings: none on either axis. No `Proxy decided` lines.

Disclosure: pending | none | manual windowed check from Verification not run; deferred by stage 3 (this session) because stage 1 rated the defect cosmetic and low priority and the scene test covers every criterion.

- 2026-10-25 Review ended at to-review (exit 0); branch clean-002 holds the review; left for a human
