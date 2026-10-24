# UI-002: Board feedback and promotion
Stage: to-implement
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
