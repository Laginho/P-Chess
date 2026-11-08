# CLEAN-014: Keep the current Review side-line move visible
Stage: to-implement
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/review.gd (`_show_line`)
  - tests/test_review.gd

#### What to build

Every navigation inside a Review side line scrolls the move list so the current line move is visible, as game navigation already does (`_moves.ensure_cursor_is_visible`, deferred, in `_show_ply`). That covers a move played on the board, Next/Previous inside the line, and a click on a line row; all three go through `_show_line`. When the current move is the line's last, the "Back to game" row below it is scrolled into view as well. Classification and analysis updates never scroll, so a user who scrolls away keeps that position until their next navigation.

Non-blocking usability follow-up from the [REV-007 stage-3 review](90-REV-007-side-line.md). At 1280×800, start a line at ply 0 and play 20 legal moves. `_show_line` selects the current row but does not scroll it into view. In the reviewed build (`4565ab7`), the Tree is 361 px tall, the selected row begins at y=498 with height 26, and the scroll offset remains `(0, 0)`. The latest moves and Back to game row are below the visible area until the user scrolls manually. Game navigation already schedules `ensure_cursor_is_visible`; line navigation does not.

One reproduction line is `1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bg5 Be7 5. e3 O-O 6. Nf3 h6 7. Bh4 b6 8. cxd5 exd5 9. Bd3 Bb7 10. O-O Nbd7`. External evidence: `/run/media/lage/New Volume/Scratch/rev007-review/long-line.png` and `probe.log`.

#### Acceptance criteria

1. After playing the reproduction line (20 moves from ply 0) at 1280×800 and at 800×600, the selected line row and the "Back to game" row both lie inside the move list's visible area.
2. Stepping back inside the line with Previous keeps the selected line row inside the visible area.
3. At line index 0 nothing scrolls, and a live classification update (`_refresh_line_classes`) does not change the scroll offset.
4. The gate is green.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- tests/test_review.gd: reuse the window-size loop of `test_cached_history_keeps_final_move_visible_after_layout` (1280×800 and 800×600). Play the reproduction line on the board from ply 0, await a frame, and assert that `get_item_area_rect` of the selected row and of the "Back to game" row lies within `list.size`. Then press Previous and assert the same for the selected row. Red today because the scroll offset stays at (0, 0).

## Comments

- 2026-11-05 Opened during REV-007 review; no source changes made. The written REV-007 criteria require the rows and navigation, but do not explicitly require automatic scrolling, so this is separate from its three blocking contract failures.

- 2026-11-08 Triaged in a stage-1 grill with Bruno through the proxy: scroll on navigation only, Back to game shown at the line end, viewport test at two sizes.
- Proxy decided (opus-5.5 xhigh): 5 settled, 0 escalated (receipt /tmp/sweatshop-proxy/20261108-125958-HIST-010-b9505f.json)
- Proxy decided (opus-5.5 xhigh): 3 settled, 0 escalated (receipt /tmp/sweatshop-proxy/20261108-130224-HIST-010-5b620a.json)

Acceptance: pending | Scroll behavior awaits stage-1 specification and implementation.
Disclosure: pending | none | Non-blocking usability follow-up to REV-007; no integration or release hold imposed by this observation.
