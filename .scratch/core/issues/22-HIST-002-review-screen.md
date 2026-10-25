# HIST-002: Review screen
Stage: implementing
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
2. The move list shows the time charged for every recorded move for both sides, computed by a tested pure function: the mover's previous post-move clock (or the time control's initial clock for its first move), minus its current post-move clock, plus the increment actually awarded. A side's first move receives no increment: an ordinary first move shows 0 ms and a first premove shows 100 ms. Later moves add the configured increment when the recorded post-move clock is positive; a zero snapshot receives no increment, regardless of the game's final result or reason.
3. Copy PGN puts the game's PGN on the clipboard.
4. Open in Lichess opens the browser on a Lichess analysis page with the game's moves (`https://lichess.org/analysis/pgn/` followed by the URL-encoded moves).
5. `Space` on the review starts the rematch (UI-004), and the review can go back to the setup screen.

#### Verification

    Manual: finish a game, copy the PGN, open it on Lichess and check the moves match.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_review.gd`: time spent per move from a fixture game with increment, and the Lichess URL for a short game. Red because neither function exists.
- `tests/test_review.gd`: pure time reconstruction covers both sides' ordinary first moves, first and subsequent premoves, ordinary moves with increment, zero-clock final snapshots with either a flag or terminal-move result, and an empty move list.
- `tests/test_review.gd`: instantiate `ui/main.tscn` and `ui/review.tscn` under the runner root with isolated History/settings, a held engine and an injected fake clock. Exercise session signals, controls and input entry points for automatic review/result/reason display, Copy PGN's payload, Space rematch with swapped colours and fresh review state, and return to setup. Include termination without recorded moves. Clipboard/browser callables may inspect outgoing payloads in headless tests; actual clipboard/browser behavior remains manual Verification. Red because the review and its session wiring do not exist.

## Comments

- Proxy decided (gpt-6-astra high, fallback): criterion 2 reconstructs charged time using only awarded increments, preserving 100 ms first premoves and zero-clock no-increment snapshots; scene integration tests in tests/test_review.gd are approved for criteria 1/3/5 — existing clock/history behavior establishes these exceptions and the existing isolated session harness provides the test seam.

Disclosure: decision | none | Proxy amendment above preserves CLOCK-001/UI-007 clock semantics and approves scene tests within existing Primary files; no additional integration or release dependency.

- 2026-10-24 From CLOCK-001's close (a note, not a criterion until stage 1 folds it in): CLOCK-001 makes a side's first move untimed, with no increment (its criterion 2, `Proxy decided (opus)`). Criterion 2's formula here (clock before − clock after + increment) then shows 2 s for each side's first move in 3+2. The proxy's draft for criterion 2: "2. The move list shows the time spent on every move for both sides: the clock before the move, minus the clock after it, plus the increment; a side's first move is untimed and shows 0 s (a pure function, tested)." History: CLOCK-001 ## Comments.
