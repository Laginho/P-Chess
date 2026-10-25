# CLEAN-002: Keep an open promotion picker aligned on flip and resize
Stage: blocked
Status: needs-triage
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
