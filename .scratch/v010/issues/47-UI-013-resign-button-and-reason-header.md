# UI-013: Resign button and the Reason header
Stage: implementing
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/main.gd (`ResignKey`, `_process`, `_show_result`)
  - ui/main.tscn (side panel, between the clocks)
  - core/pgn.gd (`finished_game`)
  - tests/test_session.gd
  - tests/test_pgn.gd
  - tests/test_history.gd (test-only: the exact-header assertions near lines 171 and 255)
  - tests/test_review.gd (test-only: the exact-header assertion near line 186)
  - docs/spec.md (Â§15.2, Â§15.7)

#### What to build

Resigning gets a button: a flag between the clocks that, like `Esc`, asks for a second click within 2 s (Â§15.2). Every saved PGN also records why the game ended, in a `Reason` header, because `Termination: Normal` cannot tell an agreed draw from a claimed repetition (Â§15.7).

#### Acceptance criteria

1. During a game the side panel shows a resign button (a flag) between the two clocks.
2. The first click arms it and the side panel shows "Click again to resign"; a second click within 2 s resigns, exactly as `Esc` twice does. After 2 s the hint goes and the next click arms again.
3. The button and `Esc` share one arming window: a click then `Esc` within 2 s resigns, and so does `Esc` then a click.
4. The button is disabled when no game is running (setup, game over, engine stopped).
5. Every PGN saved from now on carries a `Reason` header with `game.reason` (`checkmate`, `resignation`, `time`, `repetition`, `stalemate`, `50-move`, `insufficient material`). Every other header stays as it is.

#### Verification

    Manual: resign with two clicks, then let the hint expire and check one click does nothing.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_session.gd`: a click then a second click within 2 s resigns; click, 2 s, click does not; click then `Esc` resigns (red: no button).
- `tests/test_pgn.gd`: `finished_game` of a resigned game has `Reason: resignation` (red: no header).
- `tests/test_history.gd`, `tests/test_review.gd`: the exact-header dictionaries gain `Reason` (test-only update, red with the PGN test).

## Comments

- 2026-10-30 Written from spec Â§15 (PR #24). v0.1.0 ships as one build, so the spec's `v0.0.x` patch split is gone (Â§15.1).
