# UI-002: Board feedback and promotion
Stage: to-review
Blocked by: UI-001
Review: agent
Difficulty: normal

- Primary files:
  - ui/board_view.tscn, ui/board_view.gd
  - New: ui/promotion_picker.tscn, ui/promotion_picker.gd
  - ui/main.tscn, ui/main.gd (material counter)
  - New: tests/test_material.gd

#### What to build

The board feels like Lichess (§8.4): moves slide, the last move and a checked king are highlighted, legal targets show as dots, promotion opens a picker, and a counter shows the material difference.

#### Acceptance criteria

1. Moves that were not dragged (later: the bot's, premoves) slide over 120 ms by default; the length is a parameter and 0 means instant. A dragged move does not slide.
2. The from and to squares of the last move are highlighted; a king in check is highlighted.
3. Picking up a piece shows a dot on each empty legal target and a ring on each capture; a parameter turns the dots off.
4. A pawn reaching the last rank opens a picker with queen, rook, bishop and knight; cancelling puts the pawn back.
5. A material counter shows the captured pieces and the `+N` difference next to the side that is ahead (pawn 1, minor 3, rook 5, queen 9); the difference comes from a pure function that is tested.

#### Verification

    Manual: a two-human game showing each item above.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_material.gd`: material difference for the start position, after an exchange, and after a promotion. Red because the function does not exist.

## Comments

- Stage 2 (2026-10-24): the pure function is `ui/main.gd`'s static `material_balance(board)` → `{"diff", "w", "b"}`; `material` would shadow `CanvasItem.material`, a parse error. Red at 91aca8c: `Static function "material_balance()" not found in base "res://ui/main.gd"`. Green at e20b658: 56 passed, 0 failed (51 before + 5 new).
- Criterion 1: the only non-dragged path is the new `BoardView.play(move)`, which nothing in a two-human game calls yet (the bot will). `slide_seconds` (default 0.12) and `show_targets` are `@export`s. Only the moving piece slides; a castling rook jumps (`shortcut:` comment in `_commit`).
- Criteria 1–4 have no automated test (none named in the ticket). A throwaway headless script driving `ui/main.tscn` (not committed) checked: drag e2e4 holds `["e2e3", "e2e4"]` and does not slide; `play("d7d5")` slides and clears after 0.3 s; `slide_seconds = 0` is instant; the e7–e8 drop opens the picker with 4 buttons, cancel leaves the pawn on e7, picking n plays `e7e8n`; after exd5 the white label reads `♟ +1`. The manual two-human check of the ticket's Verification is still owed.
- Callers read: `_legal_move` (removed) had only `_drop`; `main.gd` is the only user of `BoardView`; `test_board_view.gd` uses only the unchanged static mapping.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-side\0678b999-a13e-4fe3-8c72-db673ccd0e5f\scratchpad\UI-002-gate.json
