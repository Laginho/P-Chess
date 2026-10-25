# CLEAN-004: Consider shared finished-game PGN construction
Stage: done
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - core/history.gd (finished-game PGN construction)
  - ui/review.gd (clipboard PGN construction)
  - core/pgn.gd (shared pure builder, if extraction is approved)
  - tests/test_history.gd, tests/test_review.gd, tests/test_pgn.gd (existing export assertions and any approved shared-builder seam)

#### What to build

Consider sharing the finished-game headers and per-move clock-record construction currently repeated in History.save and Review._game_pgn. [HIST-002](22-HIST-002-review-screen.md) recorded this optional possible Duplicated Code observation during stage-3 review. The current exports agree for Main's supplied metadata; this is a maintainability consideration, not a demonstrated defect. Introduce a shared builder only if it makes the two callers clearer and preserves their existing responsibilities.

#### Acceptance criteria

1. Any approved extraction preserves player colours/names, time control, result, termination, exact per-move clocks and History's optional Opening header.
2. Saved and copied PGNs continue to represent the current game after a rematch. Existing history write-error behavior and review export actions remain unchanged.
3. Existing production-backed PGN round-trip and session tests, plus the bound gate, pass.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_pgn.gd`: the shared builder in `core/pgn.gd` produces the headers and per-move clock records both callers need, including the optional Opening header. Red because the builder does not exist yet. Preserve the existing History and Review export assertions unchanged; do not invent a behavior failure in the callers.

## Comments

- Created by HIST-002 stage 3 on 2026-10-25 as the open destination for the optional duplicated-PGN-construction observation. No refactor was performed during review, and this follow-up does not block HIST-002 integration or release.
- Blocked for stage-1 triage and confirmation of the proposed scope and validation approach.
- 2026-10-25 Stage 1 (human, Bruno): approved the extraction of a shared pure builder into `core/pgn.gd`, called by `History.save` and `Review._game_pgn`, with criteria 1-3. Reason: saved and copied PGNs are one format kept in two copies, which will drift.
- 2026-10-25 Stage 2 (opus-5.5): extracted `Pgn.finished_game(game, clocks, settings, opening_name := "") -> Dictionary` into `core/pgn.gd`; `History.save` and `Review.present` now call `Pgn.write(Pgn.finished_game(...))`. History keeps its validation, book-based Opening lookup and write-error handling; Review passes no opening, as before. `Review._game_pgn` and History's now-unused `Clock` preload are removed. Existing History/Review/session export assertions are unchanged.
- Red: 32c3c26 (test-only) failed to load `tests/test_pgn.gd` because `finished_game()` did not exist (235 passed, 1 failed). Green: d0a5d20 (production only).
- Harness fix, 992b329 (test-only): the order check compared `keys().back()` — a StringName, since `headers.Opening = ...` stores `&"Opening"` — with the String `"Opening"` and failed on type alone. Now wrapped in `str()`. Re-proved red by mutating production (Opening header dropped from `finished_game`): the new test and existing History/Book/Repertoire Opening tests fail (242 passed, 5 failed); production restored.
- Gate at 992b329: 247 passed, 0 failed, 4 skipped (no Lc0 in this worktree), exit 0.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\p-chess-gate-evidence\CLEAN-004-gate.json

#### Resolution (2026-10-25)

Verdict: Approve

Stage 3 (opus-5.5) reviewed both axes inline in this session, with no sub-agents. Rebased onto main `6168e60` (after CLEAN-001's runner change); merged without squash as `6eb1441` via [PR #15](https://github.com/Laginho/P-Chess/pull/15), CI green.

##### Standards

Commit stats alternate correctly: `d82dc9f` test-only red (plus ticket metadata), `0f831fa` production-only, `9fb4e4a` test-only harness fix, `63d9740` ticket only. Code changes stay inside Primary files. The extraction is verbatim; History drops its unused `Clock` preload, Review keeps its own (still used by `charged_times`). No stale documentation: `_game_pgn` remains only in HIST-002's historical Resolution. Nit, not a finding: one blank line instead of two before `test_header_backslashes_read_back_unchanged` in `tests/test_pgn.gd`.

##### Spec

1. ✅ `Pgn.finished_game` emits White/Black per colour, TimeControl, Result, Termination (`Time forfeit` on a flag), one `clock_ms` per move, and Opening last when named; History still resolves the opening from its book before calling it.
2. ✅ Both callers build from the game, clocks and settings passed at call time, so rematches export the current game; History's validation and write-error paths and Review's clipboard/browser callables are untouched.
3. ✅ Existing History, Review and session export tests are unchanged and pass, with the gate below.

Examined: `History.save` (called from Main's result path) and `Review.present` (called from Main), History's write-error branches, Review's export callables. Not examined: interactive clipboard/Lichess behaviour (HIST-002's pending manual item).

Red/green, reproduced in review: `tests/test_pgn.gd` from `9fb4e4a` against main's production fails to load because `finished_game` is missing — **238 passed, 1 failed** (the whole file counts as one failure; its other tests did not run in that state). Branch head: **250 passed, 0 failed, 4 skipped** (no Lc0), exit 0.

Gate evidence: C:\Users\bruno\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_ea9dedf1-afd3-427a-be68-f9943a87cc6f\clean-004-review-gate.json (tested `63d9740`, the merged ticket tree).

No `Proxy decided` lines in this ticket. The `core/pgn.gd` placement (it now preloads `clock.gd` and names "You"/"Maia") is the extraction Bruno approved in stage 1.

Acceptance: passed | gate above and PR #15 CI. Pure refactor; saved and copied PGNs keep their content.
Disclosure: pending | release | HIST-002's manual clipboard/Lichess check remains owned by [HIST-002](22-HIST-002-review-screen.md); this ticket adds nothing to it.
