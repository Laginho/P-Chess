| When | Ticket | Kind | Evidence |
|---|---|---|---|
| 2026-10-24T01:38-03:00 | CORE-001 | human-rescue | Bruno decided: stage 2 lineup switched from haiku-5.5 to opus-5.5 high after two failed attempts (ticket comment, session commit eb77644) |
| 2026-10-24T01:48-03:00 | CORE-001 | automatic-recovery | Foreman: valid handoff parked because Gate evidence was a bullet; unbulleted on core-001 (20b3196), to-review restored on session |
| 2026-10-24T02:05-03:00 | BOT-003 | proxy-decision | Proxy decided (opus): run gate-evidence.ps1 via Bash as powershell -NoProfile -File (BOT-003 ticket Comments, session sweatshop/bot/2026-10-24-0159) |
| 2026-10-24T02:11-03:00 | CORE-002 | proxy-decision | Proxy decided (opus): defer the int64-overflow move-counter path in Board.from_fen, no follow-up ticket (CORE-002 ticket Comments, session merge ee7a582) |
| 2026-10-24T02:31-03:00 | CORE-003 | proxy-decision | Proxy decided (opus): defer both outside-FEN en-passant findings in Board.from_fen, no follow-up ticket (CORE-003 ticket Comments, 5e58f82) |
| 2026-10-24T02:46-03:00 | CORE-004 | proxy-decision | Proxy decided (opus): retry gate-evidence.ps1 once via Bash as a single `powershell -NoProfile -File` command; no hand-made receipt (CORE-004 ticket Comments, 9ffd39a) |
| 2026-10-24T02:53-03:00 | CORE-004 | proxy-decision | Proxy decided (opus): defer the Game.new(invalid FEN) null-board crash with the other outside-FEN deferrals (CORE-004 ticket Comments, 6ec90a9) |
| 2026-10-24T03:24-03:00 | BOT-002 | proxy-decision | Proxy decided (opus): option A, build on a Lc0 fixture rebuilt from the v0.32.1 format and labelled, Acceptance pending integration (BOT-002 ticket Comments, b1ce1d5) |
| 2026-10-24T03:31-03:00 | CORE-005 | automatic-recovery | Foreman: valid handoff parked because the ticket held two `Gate evidence:` lines and the driver read attempt 1's stale one; renamed it superseded on CORE-005-san, to-review restored on session (1a11bcb) |
| 2026-10-24T03:50-03:00 | UI-001 | proxy-decision | Proxy decided (opus): reproduce the 12 cburnett SVGs from known path data, labelled in docs/THIRD_PARTY.md, Acceptance pending integration (UI-001 ticket Comments, 80564e0) |
| 2026-10-24T04:20-03:00 | BOT-002 | human-rescue | Bruno approved (relayed by the coordinating foreman) reverting BOT-002 merge 8a8cf74 on the core session (dce636a) so PR #3 could merge without its Needs your call; BOT-002 blocked behind BOT-001 |
| 2026-10-24T04:30-03:00 | - | routine-approval | Bruno approved merging core session PR #3; merged by the coordinating foreman (d63bae0) |
| 2026-10-24T11:59-03:00 | BOT-003 | routine-approval | Bruno approved reopening BOT-003 ("sim", relayed by launching session) after an independent gpt-6.1-sol xhigh review of PR #2 said do not merge; reopen commit d1dcdd1 |
