# UI-011: A held piece survives Maia's move
Stage: implementing
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: hard

- Primary files:
  - ui/board_view.gd (`_commit`, `_cancel_interaction` and the hold state)
  - tests/test_premove.gd (the reply-during-drag test)
  - tests/test_board_view.gd

#### What to build

Dragging a piece while Maia thinks, then Maia moves: the drag is dropped and the piece snaps back (Bruno's QA, 2026-10-26). `BoardView._commit` calls `_cancel_interaction()` for every move, Maia's included. On Lichess and Chess.com the drag carries on, and the drop counts against the new position.

#### Acceptance criteria

1. When Maia moves (or a premove executes) while you hold a piece by dragging or by click-selection, the hold continues if the held square still holds the same piece in the position input now uses.
2. If that move captured or moved the held piece, the hold ends, as now.
3. Dropping after the reply plays a normal move when it is legal and your turn (normal clock charge, not the premove cost), or queues a premove when it is Maia's turn again (a premove just executed).
4. The held piece's legal-move dots update to the new position.
5. An open promotion picker still closes when Maia moves (unchanged).

#### Verification

    Manual: a 1+0 game; start dragging before Maia replies and drop after; the move plays.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_premove.gd` / `tests/test_board_view.gd`: hold a piece, Maia replies without touching it, release on a legal square: the move plays (red: the hold was cancelled). Maia captures the held piece: nothing plays. `test_a_reply_cancels_an_unfinished_drag_before_running_the_due_premove` changes its expectation: the release on g5 now queues `f3g5`.

## Comments

- 2026-10-26 Written from Bruno's first QA session (item 4). Reverses UI-007's "Maia replies cancel held input" for drags and selections only; pickers still close.
- 2026-10-27 Stage 2 scope: `_commit` is reached by `play` (Maia/premoves) and `_submit` (drag, click-selection, promotion). `_cancel_interaction` also serves settings, right-click cancellation and game end; those callers keep cancellation. Input must be reconciled after synchronous `move_played` listeners execute the due premove. Check null/invalid ghost positions, changed/captured sources, legal-target changes, snap-back and promotion cancellation, both colours and both hold modes at the approved BoardView/Main test seams. No config, exports or fixtures need changing.
