# CLEAN-014: Keep the current Review side-line move visible
Status: needs-triage
Blocked by: none
Review: agent
Difficulty: normal

#### What to investigate

Non-blocking usability follow-up from the [REV-007 stage-3 review](90-REV-007-side-line.md). At 1280×800, start a line at ply 0 and play 20 legal moves. `_show_line` selects the current row but does not scroll it into view. In the reviewed build (`4565ab7`), the Tree is 361 px tall, the selected row begins at y=498 with height 26, and the scroll offset remains `(0, 0)`. The latest moves and Back to game row are below the visible area until the user scrolls manually. Game navigation already schedules `ensure_cursor_is_visible`; line navigation does not.

One reproduction line is `1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bg5 Be7 5. e3 O-O 6. Nf3 h6 7. Bh4 b6 8. cxd5 exd5 9. Bd3 Bb7 10. O-O Nbd7`. External evidence: `/run/media/lage/New Volume/Scratch/rev007-review/long-line.png` and `probe.log`.

Stage 1 should specify the desired scroll behavior, including whether to keep Back to game visible and what should happen when the user deliberately scrolls away, then approve Primary files and a viewport-based test seam. This follow-up has no Stage because it is an unapproved triage item, not a ticket ready for driver implementation. It adds no criterion to REV-007.

## Comments

- 2026-11-05 Opened during REV-007 review; no source changes made. The written REV-007 criteria require the rows and navigation, but do not explicitly require automatic scrolling, so this is separate from its three blocking contract failures.

Acceptance: pending | Scroll behavior awaits stage-1 specification and implementation.
Disclosure: pending | none | Non-blocking usability follow-up to REV-007; no integration or release hold imposed by this observation.
