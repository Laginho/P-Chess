# HIST-002: Review screen
Stage: done
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

#### Stage 2 handoff (2026-10-25)

Implemented `ui/review.gd` / `ui/review.tscn` and the wiring in `ui/main.gd`. Every existing result path presents the result/reason and a scrollable SAN table with both sides' charged milliseconds displayed as seconds. Export actions use `DisplayServer.clipboard_set` and `OS.shell_open`; PGN includes players, result, time control, termination and per-move clock snapshots. Space is handled before focused GUI controls consume it; rematch swaps colours and replaces the game. Back to setup clears the active clock so Space on setup cannot start a hidden game. Export buttons remain keyboard reachable.

Read-around: `_ready` wires setup, board, engine and draw signals; `_start` is called by setup, the existing Space handler and the review rematch signal; `_show_result` is called by move completion, flags, claimed draws and double-Esc resignation. The new setup action only operates after a finished game. Examined empty games, odd move counts, each side's first move, first/later premoves, zero snapshots (including retained mates), focus mode, repeated result handling and rematches. Existing clock, history and bot behavior is preserved; the full suite exercises their integration.

Red/green cycles (all tests call production code):

- `1f5c717` → `b30caa1`: absent review script → 3 passed, 0 failed; charged-time fixtures cover ordinary increments, first premoves, zero snapshots and empty/no-increment games.
- `2cf8974` → `b774514`: missing `lichess_url` → 4 passed, 0 failed; exact encoded mate movetext and a finished empty game.
- `2a9cea3` → `44beecc`: Main has no Review (4 passed, 2 failed) → 6 passed, 0 failed; real-Main mate/focus, no-move resignation, flag and claimed draw.
- `fd070d5` → `08bbdb4`: absent export buttons (6 passed, 1 failed) → 7 passed, 0 failed; production button payloads parsed by the PGN reader and checked against literal moves/clocks/headers.
- `2f98842` → `0a71f81`: focused Tree consumes Space and Setup action is absent (7 passed, 2 failed) → 9 passed, 0 failed; real viewport input, fresh rematch export and return/start from setup.

Full bound gate at `0a71f81`: `godot --headless -s tests/run.gd` — **189 passed, 0 failed**, exit 0. Test-only and production-only commits remain separate; only this ticket changes after the tested commit. `git diff --check` passes, and the changed files are restricted to Primary files plus ticket metadata. The initial unprivileged baseline run hit sandbox denial of Godot's user storage and was stopped; the final gate ran with the required storage permissions and passed. Tests isolate history/settings from player data.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\hist002-gate.json

Acceptance: pending | Automated session and payload checks pass. The Verification step to finish a game interactively, use the real clipboard, open Lichess and compare its moves has not been performed; visual layout has not been manually inspected.
Disclosure: pending | release | HIST-002 Verification / Stage 2 handoff: interactive clipboard/browser and visual acceptance remain before release. Headless tests verify production action wiring and exact content through the proxy-approved system boundaries.

#### Resolution (2026-10-25)

Verdict: Approve

Independent Standards and Spec sub-agents reviewed `396b21b5787357c3b3a9c604a2341dce2ffbe25f...9ec5a4cfb6b862a34f6b6b7388355527735e65cf`, the complete ticket and the relevant sections of docs/spec.md. This review authored no production or test changes. Rebase onto `sweatshop/core/2026-10-25-0159` was already up to date; the ticket was merged without squash as `30fb579`. The merge tree is identical to the reviewed ticket tree.

##### Standards

No hard documented-standard violations. All eleven commit stats preserve separate test-only and production-only commits; the initial contract amendment and final handoff change only permitted ticket metadata. All source and test changes stay within Primary files. No concrete new security or accessibility regression was found.

One optional possible Duplicated Code observation: `ui/review.gd:_game_pgn` repeats the player/control/result/termination headers and clock-record construction in `core/history.gd:save`. Current outputs agree for the metadata Main supplies. Sharing this construction would touch History outside Primary files, so the observation is retained for stage-1 triage in [CLEAN-004](35-CLEAN-004-finished-game-pgn-builder.md). No refactor was performed during this review.

##### Spec

1. ✅ Main presents review from the existing result path for terminal moves, ordinary/reentrant flags, claimed draws and double-Esc resignation. The result and reason, including visible history-write errors, appear in review. Empty games and focus mode are covered.
2. ✅ The tested pure function uses each side's previous post-move clock, the initial clock for its first move, and only awarded increments. Ordinary first moves show 0 ms; first and later premoves retain their 100 ms charge; zero snapshots receive no increment. The SAN table displays both sides' charged times in seconds.
3. ✅ Copy PGN invokes the production clipboard callable with the current game's PGN, players, time control, result, termination and exact clock snapshots. Button-driven payload tests parse it through the real PGN reader. Actual system clipboard operation remains manual acceptance.
4. ✅ The browser action receives the specified Lichess analysis URL plus URI-encoded SAN movetext and result. Exact mate and empty-game URLs are tested. Browser opening and Lichess's imported-move comparison remain manual acceptance.
5. ✅ Review handles Space before focused GUI controls consume it. Rematch swaps colours with the same other settings and resets moves, clocks and export state. Return to setup hides review and clears the active clock; a new setup game starts normally.

No missing/partial requirement, incorrect implementation or material scope creep was found. Badges remain assigned to OPEN-004. Standards: 0 hard violations and 1 optional cleanup observation. Spec: 0 findings.

Examined: the entire diff and every commit stat; all callers of Main's `_start` and `_show_result`; BoardView's synchronous move emission and rejection after game end; Clock first moves, increments, premoves and zero snapshots; history save-once and error reporting; PGN writing/parsing; review's focus/input ordering, empty/odd move lists and export callables; setup/rematch state; and Maia's generation/game guards against stale replies. Not experimentally examined: interactive rendering at default/minimum window sizes, the real system clipboard/browser or Lichess import, exported builds, or real disk-full/permission failures.

Red/green: inspected the five separate committed cycles and retained focused logs in `C:\Users\Lage\AppData\Local\Temp\hist002-{red,green}-*.log`. Missing review script: **0 passed, 1 failed** → **3 passed, 0 failed**. Missing URL function: **0 passed, 1 failed** → **4 passed, 0 failed**. Missing Main review: **4 passed, 2 failed** → **6 passed, 0 failed**. Missing export controls: **6 passed, 1 failed** → **7 passed, 0 failed**. Focused Space/setup navigation: **7 passed, 2 failed** → **9 passed, 0 failed**. Early pure-test logs also report restricted user-log/certificate access; their test failures identify the absent production script/function. Scene and final gate logs have no script errors.

Gate: the installed `Assert-GateEvidence` helper validated the existing receipt against the reviewed HEAD and merge `30fb579`: bound command `godot --headless -s tests/run.gd`, tested commit `0a71f81b4ba8fb5ac6864a685982cb928a974610`, **189 passed, 0 failed**, exit 0. The log SHA-256 `3B7770A723C411C43925B6126AEF299415AE759AF15E46BBDE7A1C444623DDFF` and exit marker match; the tested commit exists. Only permitted tracker metadata differs from that code, so its green gate is reused. Expected malformed-fixture warnings only. `git diff --check` passes.

Proxy review: the existing `Proxy decided (gpt-6-astra high, fallback)` amendment is satisfied: reconstruction preserves CLOCK-001/UI-007's first-move, premove and zero-clock semantics, and scene integration tests use isolated History/settings with replaceable external clipboard/browser boundaries. The older CLOCK-001 note is now reflected in criterion 2's awarded-increment wording. No new proxy decision or contract amendment was made during this review.

Acceptance: pending | Automated session/payload checks and independent review pass. The Verification step to finish a game interactively, copy its PGN, open it in Lichess and compare moves, plus visual layout inspection, remains before release.
Disclosure: decision | none | The existing proxy-approved clock exceptions and scene-test seams are implemented and independently approved; no additional integration dependency.
Disclosure: deferred | none | [CLEAN-004](35-CLEAN-004-finished-game-pgn-builder.md) retains the optional repeated-PGN-construction observation for triage. It is not a demonstrated runtime defect or a release condition.
Disclosure: pending | release | HIST-002 Verification / this Resolution: real clipboard/browser behavior, imported-move comparison and visual layout remain unverified.
