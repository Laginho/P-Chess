# REV-007: Side lines in the Review, and the Best move arrow setting
Stage: to-implement
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/review.gd (side-line state, move-list rows, navigation, `Esc`, class-table collapse, blue arrow on game positions)
  - ui/review.tscn (only if the Back to game control needs a node)
  - ui/board_view.gd (a best-move arrow property, drawn translucent blue under `review_arrow` and the drawings)
  - core/settings.gd (`DEFAULTS`: `best_move_arrow`)
  - ui/settings.gd (the row)
  - ui/main.gd (`_apply`: the board settings and `best_move_arrow` also reach the Review's board)
  - tests/test_review.gd, tests/test_board_view.gd, tests/test_settings.gd
  - docs/spec.md (§15.6 side lines and arrow, §15.10 the new setting)

#### What to build

Spec: `.scratch/review-explore/spec.md`. In the Review you can play moves from any position and walk them as a temporary side line, then go Back to game. No engine yet: side-line positions show no eval, lines, classes or arrows. Also a new **Best move arrow** setting that draws the stored best move of the shown game position as a translucent blue arrow, and the Review's board starts following your board settings.

Today the Review's `BoardView` already accepts moves for both sides, but nothing listens to `move_played`, so a dragged move just sits on the board until the next navigation.

#### Acceptance criteria

1. At game ply N, a legal move (drag or click-click) that is not game move N+1 starts a side line: the board shows it with its sound, and the move appears as a row under the row of move N, visibly distinct from game rows, in a block that holds a **Back to game** button.
2. At game ply N outside a line, playing game move N+1 just shows ply N+1; no line starts.
3. Inside a line, ←/→ and Previous/Next step from the branch position to the line's last move and stop there. At a line position, playing the line's next move steps forward; playing any other move replaces every line move after that position.
4. Back to game and `Esc` discard the line and show ply N. Clicking a game move, clicking the graph, First or Last discard the line and show that ply. From History, `Esc` in a line is Back to game and a second `Esc` is Back to History. `F` flips in a line as it does elsewhere.
5. A line never changes the summary, the class table counts, the graph (its marker stays at ply N), Copy PGN, Open in Lichess or any file on disk.
6. In the wide layout, entering a line collapses the class table behind the "Move classes" button as the compact layout does; Back to game, or any other way out of the line, restores it. The compact layout is unchanged.
7. In a side-line position the eval bar shows no score, and the board shows no class icon and no green or blue arrow.
8. With `best_move_arrow` on, a game position with stored analysis shows its stored `best_move` (the move from the shown position) as a translucent blue arrow, `#3f94e0` at about 65% from one constant, drawn under the green arrow and the user's drawings; terminal positions, positions without analysis and side-line positions show none. Off, none anywhere. Changing it in Settings while the Review is open redraws at once.
9. Settings has a "Best move arrow" check row right after "Legal-move dots", default on, saved like the others.
10. The Review's board follows board theme, piece theme, click-click, auto-queen, legal dots and animation length, at start and when changed.
11. Gate green.

#### Verification

    Manual: post-game Review and History Review; start a line, overwrite it, walk it, leave it each way; toggle Best move arrow.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- tests/test_review.gd, through the Review scene: a played off-game move adds a line row under the branch row (red: no row, nothing listens); the game's next move advances the ply (red: the board changes, `_ply` does not); overwrite, ←/→ bounds, each way out discards the line and lands on the right ply; summary, counts, graph and `_pgn` unchanged by a line; wide layout collapses and restores the class table.
- tests/test_board_view.gd: the best-move arrow draws only when set (red: the property does not exist).
- tests/test_settings.gd: `best_move_arrow` defaults to true and round-trips (red: unknown key).
- tests/test_review.gd: the blue arrow follows `best_move` of the shown game position and the setting (red: none drawn).

## Comments

- 2026-11-05 Written from the grill (spec.md). Prototype of the engine-lines placement: branch `prototype/review-engine-lines` (`251ff4c`); the engine block itself is REV-008.
