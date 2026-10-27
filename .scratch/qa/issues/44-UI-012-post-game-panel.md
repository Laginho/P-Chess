# UI-012: A small post-game panel instead of the full review
Stage: to-implement
Status: ready-for-agent
Blocked by: none
Review: human
Difficulty: normal

- Primary files:
  - ui/main.gd (`_show_result`)
  - ui/main.tscn
  - New: ui/game_over.gd, ui/game_over.tscn
  - tests/test_session.gd
  - docs/spec.md (§9.3)
  - tests/test_badges.gd, tests/test_book.gd, tests/test_history.gd, tests/test_review.gd (test-only: the eight tests that expected the review to open by itself open it through the panel; see Comments)

#### What to build

When a game ends, the full review screen takes over at once, a "jumpscare" (Bruno's QA, 2026-10-26). Instead the final position stays visible with a small panel centred over the board, as on Chess.com: the result, the reason and three buttons. The review screen opens only on request.

#### Acceptance criteria

1. At the end of every game (mate, resignation, flag, draw) a panel appears over the board with the headline ("White won", "Black won", "Draw"), the reason ("by resignation"), buttons Review, Rematch and New game, and a close ✕.
2. Review opens the existing review screen for that game; Rematch does what `Space` does; New game shows the setup screen.
3. ✕ or `Esc` closes the panel and leaves the final position on screen, with a Review button under the result in the side panel.
4. `Space` still starts a rematch while the panel shows.
5. Saving the game to history, the game-end sound and the review's contents are unchanged.

#### Verification

    Manual: finish a game by resignation and by flag; the panel shows, each button works, and ✕ leaves the board.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_session.gd`: after a resignation the review is hidden and the panel visible with the right headline (red: the review shows at once); each button reaches its screen; closing shows the side-panel Review button.
- `tests/test_badges.gd`, `test_book.gd`, `test_history.gd`, `test_review.gd`: after each game ends, the eight tests that expected the review to open by itself press the panel's Review button before using the review; their content assertions stay as they are. In `test_review.gd`, the checkmate (focus mode) and resignation/flag/claimed-draw tests first assert the review is hidden and the panel shows that ending's headline and reason. Red: `_open_review` without `main.review.show()`.

## Comments

- 2026-10-26 Written from Bruno's first QA session (item 5), from a Chess.com screenshot (result, reason, Game Review / New / Rematch). No rating, leaderboard or coach: the app has none.
- 2026-10-27 Stage 2 blocked: the new behavior passes the UI-012 session test, but eight existing tests in `tests/test_badges.gd`, `tests/test_book.gd`, `tests/test_history.gd` and `tests/test_review.gd` expect the review to open automatically. These files are outside Primary files and the approved test seam. Stage 1 must expand the ticket to permit updating those tests to request Review before asserting its contents. Gate: 246 passed, 8 failed; log: `C:\Users\bruno\AppData\Local\Temp\ui-012-green.log`. The red run was 253 passed, 1 failed (`test_game_over_panel_actions`); log: `C:\Users\bruno\AppData\Local\Temp\ui-012-red.log`.
- Proxy decided (opus): tests/test_badges.gd, test_book.gd, test_history.gd and test_review.gd join Primary files as test-only, limited to the eight tests that expected the review to open by itself. They press the panel's Review button after each game ends and before they use the review, and their content assertions stay byte-for-byte. — These tests encode the old §9.3 contract that criteria 1–2 replaced (spec already rewritten in 95ba561), and criterion 5 needs their content assertions to keep holding. Precedent: CLEAN-001 and CLOCK-001 added test files to Primary files the same way.
  Constraints from the proxy for stage 2: (1) the only allowed edit is emitting `pressed` on `board_view`'s `GameOver` `Panel/Content/Review` button after **every** game end, before the first assertion on or interaction with the review (tests ending two games need two presses, placed before `grab_focus`, `back.pressed.emit()` and the second `_finish`; in `test_badges.gd` the press may go inside `_finish`). (2) Forbidden: `main.review.show()` or any shortcut around the panel. (3) Content assertions unchanged byte-for-byte; keep `assert_true(review.visible)`; messages saying the review opens by itself may be reworded to "on request", nothing else; no other tests change and no production code changes. (4) `test_checkmate_opens_review_…` and `test_review_opens_for_no_move_resignation_flag_and_claimed_draw` also assert, before pressing, that the review is hidden and the panel shows a headline and reason matching `game.result`/`game.reason`; they may be renamed. (5) One test-only commit (four files + ticket metadata), red by mutant (`_open_review` without `main.review.show()`), red run recorded here. (6) Expected gate: 254 passed, 0 failed.
- 2026-10-27 Foreman: stage 2 set `blocked` without asking the proxy first; the foreman asked it, folded the answer above and set `to-implement`. Stage 2 resumes on this branch from 95ba561.
