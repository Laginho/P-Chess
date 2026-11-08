# UI-039: Reach Review's "Practise in Rook endgames" link with the keyboard
Stage: implementing
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/review.gd (the from-your-game marker row and its activation)
  - tests/test_review.gd (the existing Review seam)

#### What to build

REV-011's marker row in Review's move list is unselectable in every column (`ui/review.gd:1446`) and opens the unit only on a left mouse click (`ui/review.gd:348`). Keyboard users can walk the moves but never reach "Practise in Rook endgames". Found by the PR #44 integration review (gpt-6.1-sol xhigh, P2).

#### Acceptance criteria

1. The practice link is reachable by keyboard (Tab or the move list's arrow keys), has an accessible name, and Enter or Space opens the unit with the position as "From your game".
2. Selecting a chess move with the keyboard or mouse is unchanged; the marker never becomes a move.
3. The mouse click keeps working.

#### Verification

    Focused Review tests with input events.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_review.gd`: with a reviewed game that produces the marker, send keyboard input events to reach and activate the link; check `unit_requested` and that move selection is unchanged.

## Comments

- 2026-11-08 Opened by the PR #44 review loop (foreman) as the refutation of review finding 4: REV-011's criteria name no keyboard access; the gap is real and is new work.

- Triage by the driver: ready-for-agent — the marker opens only by mouse, leaving keyboard users unable to reach the saved position.
