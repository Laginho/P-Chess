# LEARN-007: Play-outs against Maia
Stage: done
Blocked by: CORE-007, CLOCK-003, LEARN-004, LEARN-006
Review: agent
Difficulty: normal

- Primary files:
  - New: ui/playout.gd, ui/playout.tscn (start screen and end card)
  - ui/main.gd (`_start` or a sibling for a course game: from a FEN, the course's Maia level, the unit's clock, no History save)
  - core/course.gd (recording play-out passes)
  - core/tunables.gd (`COURSE_HOLD_MOVES`)
  - New: core/playout_judge.gd (fail and pass rules over the probe, spec §L8)
  - New: tests/test_playout_judge.gd
  - tests/test_course.gd
  - tests/test_course_screens.gd
  - tests/test_session.gd (only if a shared helper needs the course game path)
  - scripts/screens.gd (`BOARDS`: PlayoutStart, PlayoutEnd)

#### What to build

The unit's four play-outs (spec §L8, design `PlayoutStart.dc.html`, `PlayoutEnd.dc.html`): a start screen with the task, the opponent (Maia at the course level, L4), the clock and the pass and fail rules; then a game from the position's FEN on the normal game screen; then an end card. After each of your moves the probe checks the result: a move that changes it for your side ends the play-out at once. Play-outs are not saved to History and don't count in Profile's stats.

#### Acceptance criteria

1. The start screen shows "Play-out k of 4", the four play-outs' state (passed, current, to do), the task ("White to play and win" or "… draw"), Maia's level, the clock (5+5 or No clock, from the unit page) and the pass and fail lines; Start begins the game.
2. The game starts from the play-out's FEN with you on its side, against Maia at the course level, with the unit's clock choice.
3. After each of your moves the judge asks the probe; when the result for your side changed, the play-out fails at once, before Maia replies.
4. Running out of time fails the play-out.
5. A convert passes when you promote or mate; a hold passes when the pawn is captured, with the draw kept, or after `Tunables.COURSE_HOLD_MOVES` (30) of your moves with the draw kept, or when the game ends drawn first.
6. The end card shows Converted / Held / Play-out failed / Out of time with the reason; on a failed move it shows that move with the blunder icon and a move that kept the result, from the probe, and the board shows the position after the failing move with it highlighted.
7. A pass records that play-out as passed; the end card offers Next play-out (or Back to the unit after the fourth) and Back to the unit; a fail offers Retry and Back to the unit.
8. Play-out games write nothing to `user://games/` and don't change `user://stats.cfg`.
9. When all four are passed, the play-outs part shows done and Continue moves on.

#### Verification

    Manual: lose a hold on purpose with a rook move off the third rank; pass a convert.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_playout_judge.gd`: with a fake probe: a result-changing move fails; a kept result continues; promotion passes a convert; a pawn capture or 30 held moves pass a hold (red: no judge).
- `tests/test_course_screens.gd`: Start from the unit page opens a game at the play-out's FEN against the course level, with `Session.HeldBridge`; a scripted failing move shows the end card; nothing is saved to the temporary history folder (red: no play-out).
- `tests/test_course.gd`: recording passes; play-outs done at 4 (red: no recording).

## Comments

- Stage 3 documentation correction: `_show_result` now handles sandbox game endings; course endings use `_finish_playout`. Corrected its old all-games comment without changing behavior. The flow requires a fresh bound-gate receipt after this source-file comment change.

- Criteria check by a fresh-context agent, rechecked after fixes:
  - 1 ✅ `ui/playout.gd:97`; `test_playout_start_describes_task_rules_and_all_states_including_replay` and `test_playout_starts_from_unit_and_failing_move_ends_before_maia_without_history`.
  - 2 ✅ `ui/main.gd:471`, `ui/main.gd:593`; `test_playout_starts_from_unit_and_failing_move_ends_before_maia_without_history` and `test_playout_promotion_records_pass_and_next_opens_next_position`.
  - 3 ✅ `core/playout_judge.gd:11`, `ui/main.gd:862`; `test_result_change_fails_and_result_kept_continues`, `test_playout_waits_for_probe_before_maia`, and the failing-move screen test.
  - 4 ✅ `ui/main.gd:918`; `test_playout_flag_fails_without_history_and_retry_returns_to_start` and `test_playout_flag_during_terminal_move_takes_precedence_over_mate`.
  - 5 ✅ `core/playout_judge.gd:27`; `test_promotion_and_mate_convert_and_capturing_pawn_holds` and `test_thirtieth_held_move_passes_only_if_result_kept_and_probe_errors_surface`.
  - 6 ✅ `ui/playout.gd:123`, `ui/main.gd:887`; the failing-move screen test, promotion and judge tests, and `test_fourth_playout_pass_offers_back_to_unit_without_next`.
  - 7 ✅ `core/course.gd:222`, `ui/main.gd:613`; `test_playout_passes_are_persistent_and_counted_once`, promotion, flag and fourth-play-out screen tests.
  - 8 ✅ `ui/main.gd:574`, `ui/main.gd:931`; `test_playout_disables_sandbox_actions_and_hotkeys_do_not_save_a_game` and the failing-move screen test, including shortcuts after returning to the unit.
  - 9 ✅ `ui/unit_page.gd:45`; `test_continue_moves_to_first_unfinished_part_and_disappears_when_done` and `test_playout_passes_are_persistent_and_counted_once`.
- Verification: `godot --headless -s tests/run.gd` passed 650 tests, 0 failed. The headless run skipped two pixel checks and live Lc0 tests because the engine is absent. Captured the start at 1280×800 and the end at 800×600 using the graphical fixture. Manual play against real Maia (intentional hold failure, successful convert, legal reply from the supplied FEN) and Bruno's difficulty assessment remain for release; they could not be performed without Lc0 and the Maia nets.

Gate evidence: /run/media/lage/New Volume/Scratch/LEARN-007-review/gate.json

- Updated `test_course_navigation_unit_progress_and_clock` for the new play-out screen: return from it before continuing the existing navigation assertions. Disabling its Back connection makes the updated test fail.

- Judge test harness correction: the 29-move fixture had no pawn and therefore correctly passed early; the revised position retains a pawn to isolate the move-count boundary.

- 2026-11-07 Written from `.scratch/learning/spec.md` §L4, §L8. "Not saved to History" is a spec decision (§L8) Bruno can reverse.

- 2026-11-07 CLOCK-003 integration note: the clock accepts `5+5` and `none` via `Clock.PLAY_OUT_CONTROLS`; `Clock.CONTROLS` remains the three sandbox controls. The current game and Maia paths index `Clock.CONTROLS` directly (`ui/main.gd:678,771`, `bot/maia_player.gd:143`), so the play-out integration must handle its controls before reusing those paths. An untimed clock's stable `left()` value is 0.

- 2026-11-07 RES-001 review follow-up: assess hold/convert difficulty with Bruno on the actual LEARN-004 course positions before release. The research's small random sample and WDL-preserving opponent do not validate human difficulty or 50-move-perfect play; record the manual play-out outcome here. See `docs/research/tablebase.md` and RES-001's dated Resolution; this adds no implementation criterion.

- 2026-11-07 CORE-007 review follow-up: before release, verify that a course play-out starts at its supplied FEN and real Maia replies with legal moves after the player moves. CORE-007's fake-bridge tests cover the start FEN and both current/previous-position request histories, but the headless gate skipped live Lc0 checks because the engine was unavailable. Record the real-engine outcome here with the play-out acceptance above; see `102-CORE-007-game-keeps-its-start-position.md` Resolution. This adds no implementation criterion.


### Stage 3 review and integration (2026-11-08)

#### Resolution (2026-11-08)
Verdict: Approve

Reviewed the complete `5e7acdd...3cbc730` diff and all 21 stage-2 commits with independent read-only reviewers `/root/review_standards` and `/root/review_spec`. All nine numbered criteria pass. The closing reviewer corrected one stale comment in `ui/main.gd` to identify `_show_result` as the sandbox result path; no production behavior was authored during review.

##### Standards

**0 documented-standard violations; 2 nonblocking heuristic suggestions.** All 11 changed files are within Primary files, and all stage-2 commits separate tests from production. The review covered `AGENTS.md`, tracker/domain guidance, `CONTEXT.md`, all ADRs, the learning design README and the code-review smell baseline. No `CODING_STANDARDS.md` or `CONTRIBUTING.md` exists.

- Possible Duplicated Code: `ui/playout.gd:116` advertises a literal 30 while the judge reads `Tunables.COURSE_HOLD_MOVES`. The required and shipped limit is currently 30, so no criterion fails. Future synchronization is scheduled in [CLEAN-018](118-CLEAN-018-playout-hold-rule-copy.md), pending triage.
- Possible Message Chains: `details.get_parent().get_parent()` controls the locally constructed card. The closing reviewer assessed this as a local construction detail consistent with the screen builder; retaining another card field is an optional style choice, with no confirmed defect or required repair.

##### Spec

**0 findings.** No missing numbered requirement, scope creep or introduced regression was found.

- ✅ 1: `ui/playout.gd:97` presents the task, four states, course Maia level, clock and rules. Start-screen tests cover both clock choices and replaying a passed position.
- ✅ 2: `ui/main.gd:593,471` supplies the course FEN, player side, Maia level and clock to the normal game screen. Both fake-bridge screen tests and the real-helper smoke check the supplied FEN/settings.
- ✅ 3: `core/playout_judge.gd:16` compares the root result with the played move; `ui/main.gd:881` waits for the probe before Maia. Held-probe and real losing-hold checks confirm the ordering.
- ✅ 4: `ui/main.gd:878,918` prioritizes the clock flag, including a flag during a mating move. Flag and terminal-move race regressions cover it.
- ✅ 5: `core/playout_judge.gd:24` checks result preservation before promotion, mate, pawn removal or the 30-move boundary. Judge tests cover these conditions and 29/30; the real conversion reaches promotion.
- ✅ 6: `ui/main.gd:894` supplies SAN failure/advice text; `ui/playout.gd:123` presents the final position and failed-square blunder icon. Screen tests and the real failing hold verify them.
- ✅ 7: `core/course.gd:222`, `ui/main.gd:621` and `ui/playout.gd:136` persist passes and supply Next/Retry/Back. Tests cover reload, repeated passes, retry, next position and the fourth end card.
- ✅ 8: The course move/finish paths return before the sandbox save path; guards at `ui/main.gd:316,345,932` isolate shortcuts and results. Tests and the real failure/conversion confirm empty History and untouched stats, including after Back.
- ✅ 9: Existing `ui/unit_page.gd:45` uses the persisted four-pass count to mark the part done and advance Continue. Course persistence and Continue tests cover completion.

Affected callers, failure paths and interactions examined: unit/start/end navigation; first unfinished position and replay; shared game startup and engine errors; current/previous FEN policy requests; asynchronous probe ordering and generation invalidation; clock, terminal move and premove ordering; promotion/mate/pawn/count passes; write-failure handling and progress reload; sandbox actions, result recording, History/Profile isolation and Continue. Not exercised live: actual Lc0/Maia policy, native Windows startup or physical user input. The existing manual difficulty assessment remains a release check.

Independent real-file verification: [script](</run/media/lage/New Volume/Scratch/LEARN-007-review/real-smoke.gd>) and [log](</run/media/lage/New Volume/Scratch/LEARN-007-review/real-smoke.log>), **19 checks passed**, no runtime script errors, exit 0. Main used the real Fathom helper and installed tables with isolated progress/history. In bundled hold 3 (`8/8/1RK5/r3k3/2P5/8/8/8 b - - 20 54`), `Ra1` changed draw to loss; the failure card named `Ra1` and holding alternative `Kd4`, marked the failed move and opened before any Maia request. Bundled convert 1 promoted after 23 plies, recorded a pass surviving reload and wrote no History/stats. Opponent moves in this smoke came from the real probe through `Session.HeldBridge`; this is not a live-Maia result.

Current-code graphical checks: [start at 800×600](</run/media/lage/New Volume/Scratch/LEARN-007-review/start-800.png>), [end at 800×600](</run/media/lage/New Volume/Scratch/LEARN-007-review/end-current.png>) and [end at 1280×800](</run/media/lage/New Volume/Scratch/LEARN-007-review/end-1280.png>). Headings, rules/reason, board and action buttons fit. The earlier end capture predates the final style commit; the current capture removes its empty details card. A suspected title crop was independently checked against the PNGs and [control geometry](</run/media/lage/New Volume/Scratch/LEARN-007-review/geometry-spec.gd>): at 800×600 the logical viewport is 1280×960, heading y32 and Back ending y928; no overflow was confirmed.

Test-first history retained: `04d99f1` → `2bdcc2c` adds pass recording; `acc9b2a`/`450a404` → `a4d284a` adds judging; `ba5b7ef`/`28fd820` → `e79ea91` adds the game flow; later test-only commits precede the failure-marker, startup, flag/isolation, replay-state and return-to-unit corrections. The historical test-only commits target missing public behavior, and the final gate confirms them green. The retained pawn and History public-query corrections repair test harnesses. No test/production split or Primary-files violation was found.

Foreground bound gate at tested commit `194d4a261d40f1b8db8f133cc0e06ff5c2c109f8`: `godot --headless -s tests/run.gd`, **650 passed, 0 failed**, exit 0. [Log](</run/media/lage/New Volume/Scratch/LEARN-007-review/gate.log>) and [receipt](</run/media/lage/New Volume/Scratch/LEARN-007-review/gate.json>). Real-file tablebase checks ran. Existing skips: two graphical pixel checks under headless and six live Lc0 methods because the engine is absent; current-code graphical captures and the real helper were checked separately above. The original receipt at `7601144` was valid, but the documentation-only source correction required this fresh run. The official `Assert-GateEvidence` helper validates the command, tested commit, exit marker, log SHA-256 and identical code through closure. `git diff --check` passed.

No proxy decision or contract change was introduced. The ticket contains no `Proxy decided` record requiring a receipt.

Delivery: rebase onto `sweatshop/learning/2026-11-07-2234` was a no-op. Integrated without squash in merge `2655e78`; documentation-only review correction `194d4a2` follows it. This closure records `Stage: done` and the ledger entry together on the session branch. No PR or push is part of this stage.

Acceptance: pending | Real-helper failure/conversion, automated criteria and current-code captures passed as linked above. Actual Maia play from the supplied FEN, an intentional hold failure, successful conversion and Bruno's difficulty assessment remain release checks from the original Verification and dependency notes; Lc0 and Maia nets are absent in this checkout.
Disclosure: pending | release | [Original verification and dependency notes](111-LEARN-007-play-outs.md#verification), [RES-001](101-RES-001-tablebase-and-maia-spike.md) and [CORE-007](102-CORE-007-game-keeps-its-start-position.md): verify real Maia replies legally and complete Bruno's play-out/difficulty acceptance before release. The real-helper smoke above covers FEN, grading and conversion with a scripted opponent only.
Disclosure: decision | none | [CLEAN-018](118-CLEAN-018-playout-hold-rule-copy.md) completed the nonblocking tunable-copy cleanup: the displayed hold limit now uses the judge's setting, preserving the shipped value of 30.

- 2026-11-08 PR #44 integration review (gpt-6.1-sol xhigh, P2): a hold play-out whose game ended drawn (fivefold repetition, stalemate) before the player's 30th move was recorded as failed; with the perfect opponent repeating moves, the pass test's hold could not be passed.
- Proxy decided (opus-5.5 xhigh): A — a hold play-out whose game ends drawn counts as Held; a convert that ends drawn still fails. The goal of a hold is the draw, and every one of your moves already passed the probe's draw check, so a drawn ending means the draw was kept. (receipt /tmp/sweatshop-proxy/20261108-074135-LEARN-007-6cdb7e.json)
Disclosure: decision | none | [Proxy decision above](#comments): criterion 5, spec L8 and CONTEXT.md **Hold** now accept a drawn game end as Held; fixed in the PR #44 review loop.
