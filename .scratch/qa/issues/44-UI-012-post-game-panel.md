# UI-012: A small post-game panel instead of the full review
Stage: to-merge
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

- 2026-10-27 Stage 2 mutant red: replacing `main.review.show()` with `pass` in `_open_review` yielded 245 passed, 9 failed (exit 1); review visibility assertions fail after pressing the panel button. Production restored. Log: `C:\Users\bruno\AppData\Local\Temp\ui-012-mutant.log`.
- 2026-10-27 Stage 2 gate: 254 passed, 0 failed (exit 0), tested commit `52dfde3`; manual resignation/flag and panel-button verification remains pending.
- Gate evidence: C:\Users\bruno\AppData\Local\Temp\ui-012-stage3-final-gate.json

#### Model trial (gpt-6.1-terra high, stage 2)

- Attempts to reach `to-review`: 2. Attempt 1 wrote the red test and the panel, then stopped at `blocked` (eight existing tests outside Primary files still expected the review to open by itself). Attempt 2, after the foreman folded the proxy decision, reached `to-review`.
- Tests red for the right reason: yes. `test_game_over_panel_actions` failed on the missing panel / eager review (253 passed, 1 failed); for the updated tests, the mutant `_open_review` without `main.review.show()` gave 245 passed, 9 failed.
- Gate on the first green: 254 passed, 0 failed, exit 0 (tested `52dfde3`). Attempt 1's first gate after production was 246 passed, 8 failed.
- Time: attempt 1 ~2.5 min (09:55–09:57), attempt 2 ~2 min (10:02–10:04); ~9.5 min wall clock including the foreman's proxy round.
- Stage-3 ❌: 0. One optional Standards note (Feature Envy: `ui/game_over.gd` calls into Main, including `_start` and `_show_setup`), not a defect.
- Reopens: 0.
- Proxy calls: 1, made by the foreman; terra made none.
- Misread: the skill's "a question goes to the proxy; only an escalation is a `blocked`". Terra blocked on a scope question the proxy answered at once, and wrote "Stage 1 must expand the ticket" instead of asking (Codex fallback chain: `claude -p`, then gpt-6-astra). It read the ticket itself correctly. Cosmetic: a stray blank line inside `## Comments`.
- Verdict: fast, clean test-first work with correct code, but it stops on proxy-answerable questions instead of asking. Unattended, that costs a blocked round trip.

#### Resolution (2026-10-27)
Verdict: Approve

- Stage 3, Models (terra): gpt-6.1-sol xhigh. Review: human; no session branch. Leave the PR into main open for Bruno; no merge or done/ledger entry in this stage.
- Reviewed the complete diff and every commit's file separation. Independent Standards and Spec reviews examined `deb79541e80bb3fb440864938cfee81e2f0133b0` against merge-base `c2ef1f1` (requested fixed point `37d0db1`). Rebased onto `origin/main` `a56478fedf7538ba6f694b856ab23b5976cea8e3`, including UI-008 and UI-010, without conflicts. `git range-diff` reports all six ticket patches unchanged; docs/spec.md retains the upstream premove and volume changes. The final fetch also brought UI-010 closure/trial metadata after the first integration gate; the evidence checker rejected that older receipt, so the gate ran for the final rebased tree. No production or test fixes authored in stage 3.
- Examined callers and failure paths: every `_show_result` entry (terminal move, resignation, flag, claimed draw), automatic draw generation, repeated result callbacks, premove/promotion/drag cancellation, pending Maia moves, history-error propagation, engine-stop and failed catalog/repertoire starts. Cross-feature review covered panel lifetime across rematch/setup, current-game review contents/exports, focus/flip, Esc/Space and side-panel Review. Not examined manually: rendered panel, physical keyboard/mouse dispatch, audible sound and live Lc0 play; see Bruno's checks below.

Standards:
- 0 documented violations; 1 possible Feature Envy, a non-blocking judgement call: `ui/game_over.gd` reads Main state and calls `main.review.show()`, `main._start(main.rematch(main.settings))` and `main._show_setup()`. The existing review uses action signals instead. Reviewer disposition: an optional design alternative, not a confirmed defect or unmet rule; no refactor requested for this small panel.

Spec:
- 0 findings: no missing/partial requirements, scope creep or incorrect implementation identified.
- Criterion 1: pass in code/headless tests. The shared ending path creates the panel; mate in focus mode and resignation/time/repetition assert the hidden review, headline and reason before pressing Review. Rendering still needs human acceptance.
- Criterion 2: pass. Panel Review opens the prepared review; Rematch calls the existing colour-swapping start path; New game opens setup.
- Criterion 3: pass. Close/Esc hide the panel and expose the side Review action for the same game.
- Criterion 4: pass by input-path inspection and existing rematch tests. Panel `_input` consumes Space and calls the same rematch path; physical dispatch remains a manual check.
- Criterion 5: pass in code/headless tests. History save guard, game-end sound call, review preparation, clocks, badges and export assertions remain intact.

Proxy/test-first verification:
- `Proxy decided (opus)` above is preserved. All six constraints checked: only the eight authorized existing tests (including the permitted shared `_finish`) changed; panel presses precede review use after each game; no `main.review.show()` or other panel bypass exists in tests; existing content/visibility assertions are unchanged byte-for-byte; the specified ending assertions precede Review; `52dfde3` / rebased `b5a8bf5` changes only the four authorized test files plus ticket metadata. The proxy's expected pre-integration gate was 254/0; UI-010 adds three tests, making the rebased gate 257/0.
- Red proof inspected: initial test-only `e5b9eda` / `a511841`, 253 passed / 1 failed for missing panel and eager review, exit 1 (`ui-012-red.log`); production-only `95ba561` / `df7786f` followed. Authorized test-only mutant proof: `_open_review` without `main.review.show()`, 245 passed / 9 failed, exit 1 (`ui-012-mutant.log`), then restored production and stage-2 green 254/0. These logs are local evidence under `C:\Users\bruno\AppData\Local\Temp`; counts and failure causes are recorded here for review elsewhere.
- Rebased gate: `godot --headless -s tests/run.gd`, 257 passed / 0 failed, exit 0, tested commit `cdbd1f431252315e9f5e91c5ea91dc7d984ed1e7`. Four live-engine tests print SKIP because `engine/lc0/lc0.exe` is absent (the runner includes these in its pass count). Full output: `C:\Users\bruno\AppData\Local\Temp\ui-012-stage3-final-gate.log`; hashed receipt is the Gate evidence above. Only this ticket changes after the tested commit.

Acceptance: pending | Bruno must run the manual panel checks below; neither stage 2 nor stage 3 ran them. Automated evidence is the rebased gate and the ending/action tests above.
Disclosure: decision | unknown | The actual `Proxy decided (opus)` decision above expands test-only scope, preserving content assertions; its original decision does not state an integration/release impact. Stage 3 verified every constraint.
Disclosure: pending | integration | Bruno's manual panel acceptance below remains required before the human merge; automated tests do not establish rendered layout, physical input or audible output. Live Lc0 integration also remains unexecuted in this worktree.

Manual checks for Bruno before merge:
1. Finish games by resignation and by flag; also exercise mate and a draw. Check White won / Black won / Draw and the matching reason, a small panel centred over the final board, and that the review does not open automatically.
2. Press Review and inspect that game's result, move list, both clocks, badges, Copy PGN and Open in Lichess; confirm history saves once and the game-end sound still plays once.
3. Press Rematch, then repeat with Space while the panel is visible: colours swap, other settings stay, the old panel disappears and play works in the new game.
4. Press New game, change settings and start: setup opens, the old panel/side Review do not persist, and the new game uses the chosen settings.
5. Test both close X and Esc: the exact final position stays visible, the side Review appears under the result and opens that finished game's review.
6. Repeat the panel/close/side-Review and Space checks in F11 focus mode and after resizing to 800x600 and 1280x800; check panel placement, readable text and reachable buttons with the real mouse and keyboard.

Review totals: Standards 0 rule violations / 1 optional design smell; Spec 0 findings. No confirmed unresolved implementation defect.
