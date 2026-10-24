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
