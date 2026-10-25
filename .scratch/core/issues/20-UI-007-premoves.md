# UI-007: Premoves
Stage: to-implement
Blocked by: UI-005
Review: agent
Difficulty: hard

- Primary files:
  - New: ui/premove_queue.gd
  - ui/board_view.gd
  - ui/main.gd
  - core/clock.gd (premove cost)
  - core/settings.gd, ui/settings.tscn, ui/settings.gd
  - New: tests/test_premove.gd

#### What to build

Premoves in three styles (§8.2): off, Lichess (one premove) and Chess.com (a queue, the default). This is what makes bullet against Maia feel right.

#### Acceptance criteria

1. Premove style setting: off / Lichess / Chess.com, default Chess.com.
2. While Maia is to move, the human can enter moves for their own pieces; each is checked against the position as it would stand after the moves already queued, and shows as a ghost piece.
3. Lichess style holds one premove: a new one replaces it. Chess.com style queues them in order.
4. When Maia moves, the first queued premove is played at once if it is legal, costs 0.1 s from the human's clock (plus the increment as usual) and plays the premove sound. The next premove waits for Maia's next move.
5. When a premove is illegal at the moment it is due, it and the rest of the queue are dropped.
6. A right click cancels the whole queue.
7. With auto-queen set to "only on premoves", premoved promotions become queens.
8. The queue logic is pure and tested without a window.

#### Verification

    Manual: a 1+0 game queueing three premoves; one becomes illegal and the queue empties.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_premove.gd`: queueing on the ghost position, Lichess replacement, execution order, drop on illegal, cancel, the 0.1 s charge with a fake clock. Red because `ui/premove_queue.gd` does not exist.

## Comments

- 2026-10-24 From the UI-002 review (a note, not a criterion until stage 1 folds it in):
  - `BoardView.play()` (Maia's move) does not handle a piece the human is holding, or a promotion picker that is open. `_commit` clears `_drag_from` but leaves `_held_moves` behind. The next drop can then play a move from an earlier position, and an open picker commits an illegal promotion. Criterion 2 makes exactly this state normal, since the human holds pieces while Maia is to move. If BOT-004 has not already fixed it, this ticket must. Details are in UI-002's Resolution.
  - Pressing F or resizing the window while the promotion picker is open leaves its buttons where they were. This is cosmetic, and picking still plays the right move.
- 2026-10-24 From UI-004's reopen (a note): BoardView's `game` setter now clears the board's interaction state when a new game is assigned (a rematch). The premove queue must be cleared in that same setter.
