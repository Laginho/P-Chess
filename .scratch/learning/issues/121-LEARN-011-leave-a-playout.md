# LEARN-011: A way back to the unit during a play-out
Stage: to-implement
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
