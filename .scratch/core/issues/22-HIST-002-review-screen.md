# HIST-002: Review screen
Stage: to-implement
Blocked by: HIST-001
Review: agent
Difficulty: normal

- Primary files:
  - New: ui/review.tscn, ui/review.gd
  - ui/main.gd
  - New: tests/test_review.gd

#### What to build

After each game a review screen shows the result, the moves with the time each side spent, and buttons to copy the PGN or open the game on Lichess (§9.3). The badges are OPEN-004.

#### Acceptance criteria

1. The review opens after every game end and shows the result and its reason.
2. The move list shows the time spent on every move for both sides: the clock before the move, minus the clock after it, plus the increment (a pure function, tested).
3. Copy PGN puts the game's PGN on the clipboard.
4. Open in Lichess opens the browser on a Lichess analysis page with the game's moves (`https://lichess.org/analysis/pgn/` followed by the URL-encoded moves).
5. `Space` on the review starts the rematch (UI-004), and the review can go back to the setup screen.

#### Verification

    Manual: finish a game, copy the PGN, open it on Lichess and check the moves match.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_review.gd`: time spent per move from a fixture game with increment, and the Lichess URL for a short game. Red because neither function exists.

## Comments
