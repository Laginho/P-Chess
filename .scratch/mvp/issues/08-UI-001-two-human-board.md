# UI-001: Two-human game on a board
Stage: to-implement
Blocked by: CORE-004, CORE-005
Review: agent
Difficulty: normal

- Primary files:
  - project.godot (main scene, window size)
  - New: ui/main.tscn, ui/main.gd
  - New: ui/board_view.tscn, ui/board_view.gd
  - New: ui/move_list.tscn, ui/move_list.gd
  - New: themes/pieces/cburnett/ (wK.svg … bP.svg)
  - New: docs/THIRD_PARTY.md
  - New: tests/test_board_view.gd

#### What to build

The first playable screen: two humans play a full game in one window by dragging pieces (§8.1, §8.7). The board renders with the default look (Lichess brown `#f0d9b5` / `#b58863`, cburnett pieces); loading other themes is UI-003.

#### Acceptance criteria

1. The app opens on the start position, white at the bottom; `F` flips the board.
2. Dragging a piece of the side to move makes it follow the mouse every frame; dropping it on a legal square plays the move; an illegal drop snaps it back with a tween. Pieces of the other side cannot be picked up.
3. The window opens at 1280×800, cannot shrink below 800×600, and the board stays square and scales with the window.
4. A side panel shows the move list in SAN, updated after every move.
5. Coordinates are drawn on the board edge and follow the flip.
6. When the game ends (any rule from CORE-004), input stops and the result and its reason are shown.
7. The pixel-to-square mapping is correct for both orientations at any board size (pure function, tested).
8. `docs/THIRD_PARTY.md` credits the cburnett pieces (Wikimedia Commons, BSD-3) with a source link.

#### Verification

    Manual: play Fool's mate and a game with castling, en passant and promotion to queen.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_board_view.gd`: pixel-to-square and square-to-pixel for white and black at two board sizes. Red because `ui/board_view.gd` does not exist.

## Comments
