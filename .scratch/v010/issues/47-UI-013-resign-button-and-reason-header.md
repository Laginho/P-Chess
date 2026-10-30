# UI-013: Resign button and the Reason header
Stage: to-review
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
  - docs/spec.md (§15.2, §15.7)

#### What to build

Resigning gets a button: a flag between the clocks that, like `Esc`, asks for a second click within 2 s (§15.2). Every saved PGN also records why the game ended, in a `Reason` header, because `Termination: Normal` cannot tell an agreed draw from a claimed repetition (§15.7).

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

- 2026-10-30 Written from spec §15 (PR #24). v0.1.0 ships as one build, so the spec's `v0.0.x` patch split is gone (§15.1).

- Stage 2: PGN tests red (10 passed, 3 failed), then green (13 passed); session tests red (14 passed, 2 failed), then green (16 passed). Updated exact-header assertions in `test_finished_game_builds_the_headers_and_clock_records_both_exports_share`, `test_finished_game_names_a_flag_and_an_optional_opening_last`, `test_finished_game_saves_one_pgn_with_headers_moves_and_exact_clocks`, the opening header assertion in `test_history.gd`, and the PGN export assertion in `test_review.gd`.
- Gate: 273 passed, 0 failed, exit 0. The sandbox logged failure to read the Windows root certificate store; the test runner completed successfully.
- Acceptance: pending | Manual two-click resignation and expiry check in the running application.

Gate evidence: C:\Users\bruno\AppData\Local\Temp\ui013-reopen-gate.json

#### Resolution (2026-10-30)

Verdict: Reopen — criterion 1 lacks the flag; the new focused button can resign through Settings.

Reviewed `476c3fe753c275b5022138112cc7b3fe36e7dece...910bfb8f85ec3d454635fddcf6c51d8197d4a908` against this ticket and spec §15.2/§15.7. Standards and Spec were reviewed independently in parallel. All nine changed files were reviewed manually (9/9, 100%, none skipped); OCR excluded all nine as `unsupported_ext`, so its empty reviewable list was not treated as coverage.

- Standards: no documented-standard violations or material smell findings. The test/production/test/production/metadata commit sequence and Primary-file boundaries are respected.
- Spec, P2, `ui/main.tscn:78`: criterion 1 asks for a flag, but the scene sets `text = "?"` and supplies no icon. Replace it with a flag glyph or icon and verify the displayed control.
- Spec, P2 regression, `ui/main.gd:173-176` and `ui/main.tscn:75-79`: a mouse click arms ResignButton and leaves it focused. Clicking Settings preserves that focus because Settings/Open is not focusable. Space then reaches the background button in GUI dispatch before Settings' `_unhandled_key_input` barrier, calls `_resign`, ends the game and saves a resignation while Settings remains open. Prevent the shared resign action from acting through Settings while preserving ordinary button/keyboard confirmation. Add a regression in the approved `tests/test_session.gd` seam using viewport input dispatch, rather than only direct `pressed.emit()` or `_unhandled_key_input()` calls.

Numbered criteria:

1. ❌ Button placement is correct between the clocks, including flipped sides; its visible content is `?`, not a flag.
2. ✅ Shared two-second confirmation, hint text and expiry are implemented; the separate modal regression above still blocks integration.
3. ✅ Click/Esc and Esc/click use the same `ResignKey` instance.
4. ✅ Initial setup, game over and engine stop disable the button through scene defaults, `_show_result` and `_show_setup`.
5. ✅ `finished_game` adds `game.reason` without changing existing headers. History.save and Review.present both use it; optional Opening remains last.

Examined callers and failure paths: initial start/rematch, setup, engine stop, flag/checkmate/resignation/draw result handling, confirmation expiry, Settings arbitration, F11 focus mode, History.save and review/Copy PGN export. Stage-2 red/green logs were inspected: PGN 10 passed/3 failed then 13/0; session 14/2 then 16/0. The retained green gate receipt was validated against the reviewed HEAD, including tested-code equality, SHA-256 and recorded exit status: 273 passed, 0 failed, no `SKIP` records, exit 0. The log includes the Windows root-certificate-store error and fixture warnings; the runner completed successfully. No gate rerun and no production change during review.

The modal regression was reproduced separately with Godot 4.7.2 headless and `Viewport.push_input`: mouse press/release at ResignButton, mouse press/release at Settings/Open, then Space press/release. Observed: armed=true and focus=ResignButton; Settings visible=true with the same focus; then game over=true, reason=resignation, Settings still visible=true. Probe exit 0. Local evidence: `C:\Users\bruno\AppData\Local\Temp\ui013-stage3-focus-probe.gd` and `C:\Users\bruno\AppData\Local\Temp\ui013-stage3-focus-probe.log`. This proves GUI event routing, not physical keyboard/mouse or rendered-layout acceptance.

Acceptance: pending | Running-application checks remain: visible flag, ordinary two-click resignation, expiry followed by a fresh first click, both click/Esc orders, and no resignation through Settings. Rendered UI and physical input were not exercised in this review.
Disclosure: pending | integration | Both P2 findings above remain assigned to this open UI-013 ticket. No accepted deferral; return to stage 2 on `ui-013`, retaining the implementation commits. No session merge or ledger entry.

#### Stage 2 reopen (2026-10-30)

- The viewport input regression failed before the fix and passed afterwards: a click arms Resign, opening Settings retains focus, and Space must not end the game. `_resign` now ignores input while the Settings panel is visible; the button text is the flag glyph `⚑`.
- Gate: 274 passed, 0 failed, exit 0, tested commit `ce4bd06`. The log includes the Windows root-certificate-store error and fixture warnings. An initial wrapper launch failed before Godot started; the gate above ran once after correcting the wrapper.
- Acceptance: pending | Verify the visible flag and the ordinary two-click, expiry, mixed click/Esc, and Settings input scenarios in the running application with physical input.
