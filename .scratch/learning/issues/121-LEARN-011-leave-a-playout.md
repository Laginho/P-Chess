# LEARN-011: A way back to the unit during a play-out
Stage: done
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/main.gd (play-out game state: the action, cancelling Maia, the probe and the clock)
  - ui/playout.gd or the game side panel (where the action lives)
  - tests/test_course_screens.gd (the existing play-out seam)

#### What to build

An ordinary course play-out (from the unit page) hides New game, Rematch, Resign and Offer draw, and its guard disables Escape (`ui/main.gd:525`). With the clock set to none, the only ways back to the course are to finish, to fail on purpose, or to close the app. Found by the PR #44 integration review (gpt-6.1-sol xhigh, P2). Pass-test play-outs already have this exit: `_start_test_playout()` shows the side panel's button as "Back to the unit" (`ui/main.gd:707`), and its handler calls `_show_unit()`, which cancels the play-out. Add the same "Back to the unit" action to ordinary play-outs; reusing that button and `_show_unit(_playout_unit)` is the obvious route.

#### Acceptance criteria

1. During an ordinary play-out, a visible, keyboard-reachable "Back to the unit" action returns to the unit page. Pass-test play-outs keep their existing exit unchanged.
2. Leaving cancels a pending Maia request, a pending probe and the clock; a late reply finds nothing to act on, and nothing is written to History, stats or course progress.
3. Leaving records neither a pass nor a fail for that play-out.

#### Verification

    Focused play-out tests, including leaving while Maia and while the probe are pending.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_course_screens.gd`: start a play-out, press the action while Maia is held and while the probe is held; check the unit page shows, no request completes into the game, and no History, stats or progress entry appears.

## Comments

- 2026-11-08 Opened by the PR #44 review loop (foreman) as the refutation of review finding 3: new behaviour beyond LEARN-007/LEARN-008's criteria, which define exits only on the end card.
- 2026-11-08 Narrowed by the PR #44 review loop: pass-test play-outs already show "Back to the unit" (`ui/main.gd:707`), so the ticket covers ordinary play-outs only, and criterion 1 now matches the test section (the unit page).
- Triage by the driver: ready-for-agent — ordinary play-outs have no way back while active; the existing unit and button seams cover the fix.

- 2026-11-08 Attempt 1 failed: exit 0. Log tail: O LEARN-011 está implementado no branch `LEARN-011`: o botão **Back to the unit** sai do play-out, invalida respostas pendentes e para o relógio sem registrar resultado ou progresso. /  / O ticket permanece em **`implementing`**: o gate terminou com **682 testes aprovados e 1 falha**, em um teste de tablebase alheio à mudança. Confirmei que o teste passa isoladamente com o fixture em LF; o checkout original usa CRLF. A regra do repositório só permite repetir o gate após uma mudança de código, então não há recibo verde para o handoff. /  / Os testes focados passaram, incluindo respostas tardias e Enter. Não verifiquei o percurso inicial por Tab nem fiz validação gráfica.

- Stage 2 criteria check (independent agent): criterion 1: ui/main.gd:198 and 527; tests/test_course_screens.gd:1295 and 1325 exercise routed Enter, repeated Enter and the pass-test exit.
- Stage 2 criteria check: criterion 2: ui/main.gd:752; tests/test_course_screens.gd:1285-1316 hold Maia and probe replies and a running clock. Removing clock.stop() failed both clock assertions.
- Stage 2 criteria check: criterion 3: ui/main.gd:617 and 752; tests/test_course_screens.gd:1316 checks unchanged progress and no History or stats after late replies.
- Stage 2 validation: focused course screens passed 31/31 before the keyboard follow-up; the two updated targeted tests passed. Red tests exposed the missing exit and a second Enter escaping to Home. A temporary test-edit encoding error was corrected in f38c8b7.
- Gate attempt: 682 passed, 1 failed, exit 1; log: C:/Users/bruno/AppData/Local/Temp/learn011-gate.log. The unrelated test_recorded_fathom_transcript_is_parsed_without_live_tables fails with this Windows checkout's CRLF fixture (index LF); it passed in isolation with the fixture temporarily converted to LF, then the original checkout was restored. No green gate receipt exists, so Stage remains implementing.

- 2026-11-08 Driver retry: attempt 1 ended short of to-review (exit 0). Resume from this branch's commits; edits the stage left uncommitted are saved in run-log/recovery.txt.

- Stage 2 retry criteria check (independent agent): criterion 1: ui/main.gd:198-202, 527-528; tests/test_course_screens.gd:1271 and 1346 cover Tab, Enter and the pass-test exit.
- Stage 2 retry criteria check: criterion 2: ui/main.gd:751-767 and 1078; tests/test_course_screens.gd:1271 hold Maia and probe replies and check the clock and late replies. Probe cancellation is logical: the shared tablebase process finishes its current request and the stale callback is ignored.
- Stage 2 retry criteria check: criterion 3: ui/main.gd:617-626 and 797-812; tests/test_course_screens.gd:1271 checks unchanged progress, History and stats.
- Stage 2 retry: Enter on a focused game exit after the end card appeared incorrectly opened Home; tests/test_course_screens.gd:918 failed before ui/main.gd:803 hid the action and passed after. The existing exit test now reaches it by Tab.
- Gate retry: 683 passed, 0 failed, exit 0; graphical pixel checks and Linux tablebase/native-helper checks skipped. Log: C:/Users/bruno/AppData/Local/Temp/learn011-retry-gate.log.
Gate evidence: C:/Users/bruno/AppData/Local/Temp/learn011-retry-gate.json

- Proxy decided (opus-5.5 xhigh): Resolve the conflict inside the ticket file and continue the rebase. Don't block, and don't expand Primary files. The conflict touches only LEARN-011's own tracker history (`## Comments`), changes no criterion and no product code, and closed tickets have handled this case the same way. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261108-143949-LEARN-011-fcb16d.json)

#### Resolution (2026-11-08)
Verdict: Approve

- Standards: 0 findings. Independent Standards review examined the complete three-file diff against `6568009...b5fb56b`, the documented conventions and connected code. The changes stay within Primary files and reuse the existing button and unit navigation.
- Spec: 0 findings. Independent Spec review confirmed all three criteria and found no scope creep or actionable regression. Review authored no production or test changes.
- Examined callers, failure paths and interactions: ordinary and pass-test entry, `_start`, the NewGameButton handler, `_show_unit`, every `_cancel_playout` caller, completion/start-error paths, `_on_move_played` and `_next_turn` callbacks, Maia's FIFO and generation guards, tablebase serialization, clock teardown, premoves, analysis resumption, unit rendering and the end card. Native pointer input, rendered pixels, screen-reader behavior and this exit with live engines were not exercised during review.
- Criterion 1 ✅ `ui/main.gd:198` routes the existing action to the ordinary unit while retaining the pass-test branch first; `ui/main.gd:527` shows and labels it during ordinary play. `test_leaving_playout_ignores_pending_replies_and_records_nothing` reaches it through Tab and activates it with repeated Enter. The pass-test exit remains covered by `test_pass_test_playout_back_still_returns_to_the_unit`. The end-card scenario verifies Enter cannot activate the former game exit behind the result.
- Criterion 2 ✅ `_cancel_playout` (`ui/main.gd:751`) invalidates Maia and probe callbacks, stops and detaches the clocks, cancels premoves, disables board input and resumes analysis. The leaving scenario holds each reply in turn, returns to the unit and delivers the late reply; neither moves nor History, stats or course data change. Probe cancellation is logical: the shared native request may finish, but its obsolete callback cannot affect the game.
- Criterion 3 ✅ Leaving bypasses `_finish_playout` and its pass-recording operation. The leaving scenario compares the course file before and after both late replies, and the retained pass-test exit records no test attempt.
- Red/green proof: inspected the separate test-only and production-only commits, plus the recorded [initial red log](<C:/Users/bruno/AppData/Local/Temp/learn011-red.log>), [keyboard red log](<C:/Users/bruno/AppData/Local/Temp/learn011-key-red.log>), [keyboard green log](<C:/Users/bruno/AppData/Local/Temp/learn011-key-green.log>) and [clock mutant log](<C:/Users/bruno/AppData/Local/Temp/learn011-clock-mutant.log>). They expose the missing action, repeated Enter leaving for Home, and an unstopped clock. The green gate includes all 32 course-screen scenarios. These are stage-2 executions inspected during review, not rerun here.
- Gate: reused the receipt for tested commit `3afebec61a753de520003da17b87f2cee5654c63`: `godot --headless -s tests/run.gd`, 683 passed, 0 failed, exit 0. Verified its command, log hash, successful exit and identical code with `Assert-GateEvidence` before rebase, on rebased `5a35e04` and on merge `51b942d`. `git diff --check` passed. Two pixel checks and three Linux real-tablebase/native-helper checks were skipped in that run.
- Rebase/integration: rebased onto `sweatshop/learning/2026-11-08-1410` and merged with `--no-ff` as `51b942d`. Conflicts touched only this ticket's Comments; both histories were retained and the triage em dash restored. The recorded `Proxy decided (opus-5.5 xhigh)` decision permits that administrative reconciliation without changing Primary files or criteria. Production and tests remain identical to the tested commit. No push or PR belongs to this stage's session flow.

Acceptance: pending | Automated exit, late-reply isolation and retained pass-test behavior passed in the [green gate log](<C:/Users/bruno/AppData/Local/Temp/learn011-retry-gate.log>). Bruno's native UI and real-engine play-out checks remain part of the [feature acceptance](../spec.md#acceptance-scenarios).
Disclosure: decision | none | [Proxy receipt](<C:/Users/bruno/AppData/Local/Temp/sweatshop-proxy/20261108-143949-LEARN-011-fcb16d.json>): reconcile the ticket's administrative rebase conflicts, preserving both histories; no contract, integration or release change.
Disclosure: pending | release | [Feature acceptance](../spec.md#acceptance-scenarios) retains Bruno's manual play-out and native-engine checks. This headless review adds no integration condition and does not complete those checks.
