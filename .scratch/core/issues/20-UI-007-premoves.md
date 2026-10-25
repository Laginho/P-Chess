# UI-007: Premoves
Stage: done
Blocked by: UI-005
Review: agent
Difficulty: hard

- Primary files:
  - New: ui/premove_queue.gd
  - ui/board_view.gd
  - ui/main.gd
  - core/clock.gd (premove cost)
  - core/settings.gd, ui/settings.tscn, ui/settings.gd
  - New: tests/test_premove.gd

#### What to build

Premoves in three styles (§8.2): off, Lichess (one premove) and Chess.com (a queue, the default). This is what makes bullet against Maia feel right.

#### Acceptance criteria

1. Premove style setting: off / Lichess / Chess.com, default Chess.com.
2. While Maia is to move, the human can enter moves for their own pieces; each is checked against the position as it would stand after the moves already queued, and shows as a ghost piece.
3. Lichess style holds one premove: a new one replaces it. Chess.com style queues them in order.
4. When Maia moves, the first queued premove is played at once if it is legal, costs 0.1 s from the human's clock (plus the increment as usual) and plays the premove sound. The next premove waits for Maia's next move.
5. When a premove is illegal at the moment it is due, it and the rest of the queue are dropped.
6. A right click cancels the whole queue.
7. With auto-queen set to "only on premoves", premoved promotions become queens.
8. The queue logic is pure and tested without a window.

#### Verification

    Manual: a 1+0 game queueing three premoves; one becomes illegal and the queue empties.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_premove.gd`: queueing on the ghost position, Lichess replacement, execution order, drop on illegal, cancel, the 0.1 s charge with a fake clock. Red because `ui/premove_queue.gd` does not exist.

## Comments

- 2026-10-25 Stage 2 pre-test inspection: the confirmed seam is the pure queue in `ui/premove_queue.gd`, exercised from `tests/test_premove.gd` with the real Board/Game; that same test file will exercise the named BoardView/Main/settings/clock integration. Callers inspected: BoardView `_commit` is reached by drops, promotion picks and `play`; Main `_on_move_played` advances the clock and calls `_next_turn`; Maia replies call `BoardView.play`; Main `_start` replaces `game`; `Clock.moved` is also used by clock/time-model tests. Boundary coverage will include an empty/disabled queue, same-piece ghost moves, replacement, both colours, stale/illegal entries, a reply during a drag or promotion picker, rematch, and a premove charge at flag. Existing normal-move clock semantics and right-drag annotations must remain intact.

- 2026-10-25 From UI-006 stage 2 (proxy-approved integration handoff, not a new criterion): Main still uses `MOUSE_FILTER_IGNORE` during Maia's turn. When adding opponent-turn input, reconcile right-click premove cancellation with BoardView's right-drag arrows/right-click circles; drawing is currently available only while the board accepts input. The shared promotion decision is `PromotionPicker.should_auto_queen(mode, premove, alt)`; persisted `auto_queen` values are `off`, `on`, `only on premoves`. UI-006 now clears held move targets after `_commit`, but the existing pending-picker integration note below still needs inspection.

- 2026-10-24 From the UI-002 review (a note, not a criterion until stage 1 folds it in):
  - UI-006 now clears `_drag_from`, `_selected` and `_held_moves` in `_commit`, resolving the held-target cleanup described by the UI-002 review. `BoardView.play()` (Maia's move) still leaves an open promotion picker visible after clearing `_promoting`; inspect picker cancellation when adding opponent-turn input. Criterion 2 makes input overlap with Maia's move normal. Details of the original finding remain in UI-002's Resolution.
  - Pressing F or resizing the window while the promotion picker is open leaves its buttons where they were. This is cosmetic, and picking still plays the right move.
- 2026-10-24 From UI-004's reopen (a note): BoardView's `game` setter now clears the board's interaction state when a new game is assigned (a rematch). The premove queue must be cleared in that same setter.

#### Stage 2 handoff (2026-10-25)

Implemented on `UI-007`, based on session commit `8f9fa43`. Production tip: `e6d776b`.

- Criteria 1–3, 5, 8: a pure `PremoveQueue` validates against copied human-only positions, supports off / single replacement / ordered queue, and rechecks each due move on the real board. Settings persist with Chess.com as default and apply immediately. Ghost pieces show the queued position; Lichess also keeps the live source visible for replacing its single move.
- Criterion 4: Main executes one due premove synchronously after Maia's move. `Clock.moved(side, premove := false)` preserves existing callers; premoves cost exactly 100 ms before any normal increment, and flag before the move can play. The first move still gets no increment, but a premove pays its fixed cost. Premove sound replaces the ordinary move/capture/castle event; promotion/check events still apply.
- Criteria 6–7: right click clears the queue, including through the promotion overlay, while right-drag arrows and right-click circles still work. Premove promotions use the shared auto-queen/Alt policy; picker choices enqueue. Maia replies cancel held input and close pending pickers. Flags, mate and rematches clear the queue.
- Only Primary production/test files changed. `ui/settings.tscn` needed no edit because its existing form builds rows dynamically. No refactoring outside the ticket and no proxy decisions.

Red/green evidence, each cycle with tests committed separately from production:

| Test commit | Red result / reason | Production commit | Focused green |
|---|---|---|---|
| `6e135ab` | 0 passed, 1 failed: queue script absent | `333fd89` | 1 passed, 0 failed |
| `f6b3366` | 1 passed, 3 failed: style/take absent | `16eeec0` | 4 passed, 0 failed |
| `73a785b` | 0 passed, 1 failed: clock premove argument absent | `a5fd609` | 7 passed, 0 failed |
| `1516a9e` | 7 passed, 1 failed: opponent-turn input/queue not integrated | `d14badd` | 8 passed, 0 failed |
| `a8df4bd` | 10 passed, 3 failed: right click, flag and mate retain queued moves | `0980965` | 13 passed, 0 failed |
| `f12a1d2` | 13 passed, 4 failed: settings/promotion routing and picker interruption absent | `e6d776b` | 17 passed, 0 failed |

Focused command: `godot --headless --log-file build/ui007-tests.log -s tests/run.gd -- build/ui007-tests`, with an ignored copy of `tests/test_premove.gd` in that directory. The final gate used the original test file. Fake time is retained for each scene's lifetime, and only the external engine is replaced in scene tests.

Full bound gate through `gate-evidence.ps1`, on committed clean code `e6d776b`: `godot --headless -s tests/run.gd` → **169 passed, 0 failed**, exit 0. Final diff and every commit's file separation checked. Log: `C:\Users\Lage\AppData\Local\Temp\UI-007-stage2-gate.log`.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\UI-007-stage2-king-capture-gate.json

Acceptance: pending | The automated 1+0 scene scenario queues three moves, executes one, then drops the remaining queue after Maia captures the pawn required by the next move (`test_main_queues_human_moves_and_executes_one_per_maia_reply`). A person has not yet played the manual Verification game or checked the ghost rendering and premove audio.
Disclosure: pending | release | Manual visual/audio acceptance remains as described above; headless tests validate input, move order, signals, settings, clock boundaries and promotion interruption, but do not judge appearance or sound quality.

- Proxy decided (gpt-6-astra high, fallback): reopen UI-007 for criterion 2; queued moves must not capture the opposing king in the specified ghost position — unknown Maia replies are handled by execution-time revalidation and do not excuse accepting an invalid move against the current ghost.

#### Resolution (2026-10-25)

Verdict: Reopen — criterion 2 accepts an opposing-king capture in the ghost position (`e2e4`, then queued `f1c4`, `d1h5`, `h5f7`, `f7e8`).

Stage 3 reviewed `b206a36300d0de13f81ee4cae2208e3e906c4597...62443c6` against the session branch, with independent Standards and Spec sub-agents. The implementation remains on `UI-007`; it is not integrated into the session. No production or test changes were authored during review. Only the criterion-2 finding below remains for stage 2.

Examined: the complete diff and every commit's file statistics; queue projection, style changes and execution; Board copying, legal-move generation and repeated human turns; BoardView drag/drop, click-click, promotion/Alt, picker interruption, right-click cancellation, annotations and animation cleanup; Main's move callbacks and synchronous premove signal recursion; clock first moves, increments, fixed charges and flag callbacks; Maia replies; settings persistence/application; result and rematch cleanup. No interactive visual/audio acceptance, exported-build check or real mouse-gesture assessment was performed.

##### Standards

No documented-standard violations or material baseline smells found. All production/test changes stay within Primary files. All six red/green cycles separate test-only commits from production-only commits; the first test commit also carries permitted ticket metadata. The 17 tests use production queue, BoardView, Main, settings and clock behavior. No unrelated refactoring was found.

##### Spec

One finding: criterion 2 requires checking a new move against the current ghost position, but `ui/premove_queue.gd:20-23,59-67` forces repeated human turns and trusts `Board.legal_moves()`. The generator assumes ordinary alternating play and checks the moving king's safety; it can therefore offer a capture of the opposing king on these projected positions. `BoardView._draw` renders that invalid ghost. The actual game remains protected by `take()` rechecking legality on the live board. No other missing numbered requirement or scope creep was found.

Criteria:

1. ✅ Off / Lichess / Chess.com are validated and persisted; Chess.com is the default and the settings screen applies changes immediately.
2. ❌ Ghost validation accepts an opposing-king capture. Reproduction: create the initial Game, play `e2e4`, then enqueue `f1c4`, `d1h5`, `h5f7`, `f7e8` for White. Every enqueue returns `true`; the ghost has `Q` on e8 and zero black kings. The live board retains one black king and only `e2e4` in its move history. Preserve the accepted prefix and both kings when rejecting the invalid append. Add a production-backed regression in the existing `tests/test_premove.gd` seam, then repair within the current Primary files; keep due-move revalidation intact.
3. ✅ Lichess replaces its single entry from the live input position; Chess.com preserves ordered queued moves.
4. ✅ Main executes one legal due move synchronously, charges the fixed 100 ms before the usual increment/flag decision and emits the premove sound; the next entry waits for another Maia reply. First-move increment behavior is preserved.
5. ✅ An illegal due move drops itself and the rest of the queue without a premove charge or execution.
6. ✅ Right press clears the queue, including through the promotion overlay, while right-drag arrows and right-click circles remain available.
7. ✅ Premove promotions honor the shared auto-queen policy, including "only on premoves" and Alt/picker underpromotion.
8. ✅ The queue is a pure RefCounted component and its tests run headless. The new criterion-2 edge needs additional coverage.

Reproduction command: `godot --headless --log-file build/ui007-review-probe.log -s build/ui007-review-probe.gd`. The ignored probe calls the production Game and PremoveQueue; its output is `enqueue ...: true` for all four entries, `ghost e8=Q`, `ghost black kings=0`, `live black kings=1`, `live moves=["e2e4"]`. The command exits 0 because it is an observational probe, not an assertion-based regression test. It also emits the environment's root-certificate-store startup error, unrelated to the queue result. The reproduction above is retained here so it can be repeated without the local probe file.

Gate: verified the existing receipt with the installed `Assert-GateEvidence` helper: the bound command on `e6d776b31ee796dc5788fad43908a4e99d637366` exited 0 with **169 passed, 0 failed**; the log SHA-256 and exit marker match, the tested commit exists, and only ticket metadata follows it. The retained suite does not cover this ghost-position boundary. Every test/production commit pair and the final diff were inspected; `git diff --check` passes. No gate rerun was needed for this metadata-only review.

Proxy review: the actual `(gpt-6-astra high, fallback)` answer above confirms criterion 2 applies independently of criterion 5. Unknown future Maia replies do not change the enqueue-time reference position. No criterion text or Primary files were changed.

Acceptance: pending | The automated suite passes for its covered scenarios, but the criterion-2 failure above must be corrected and reviewed. The manual 1+0 game, ghost appearance and audio acceptance from Verification also remain pending.
Disclosure: decision | integration | Proxy decision under Comments: criterion-2 ghost validation must reject opposing-king captures before UI-007 can be approved or integrated; live execution is protected by revalidation.
Disclosure: pending | integration | The criterion-2 finding remains scheduled on this reopened UI-007 ticket; stage 2 must add the regression test first and make a scoped repair on the preserved branch.
Disclosure: pending | release | Manual visual/audio acceptance remains pending as recorded in the Stage 2 handoff.

#### Stage 2 reopen work (2026-10-25)

The remaining scope is the criterion-2 king-capture finding. The confirmed test seam remains the public PremoveQueue API in `tests/test_premove.gd`, backed by the real Game/Board. Before the red test, inspected `enqueue` (BoardView `_submit`), `input_position` (BoardView `_pick_up` through `_input_position`), `position` (BoardView `_draw` and queue projection), and `take` (Main's due-move execution). Repeated human turns can offer opposing-king captures through Board.legal_moves; rejecting an append must preserve the accepted prefix, both kings, and the live position/history. Both colours are covered. Due-move validation on the live board remains in scope for regression checks.

#### Stage 2 re-review handoff (2026-10-25)

The criterion-2 finding is corrected on the preserved `UI-007` branch. Production tip: `e9c1b1667ddc7ab694b7ff765afc13bb9f301742`.

- `enqueue` rejects moves onto either king before changing the queue. The regression reproduces the original White sequence and its Black counterpart, preserving the accepted prefix, both kings, and the live position/history.
- `position` applies the same restriction when replaying queued moves on an updated board. If Maia's king has moved onto a later queued destination, the preview returns null rather than rendering a captured king. Projection leaves the queue intact; `take` still validates each due move on the live board, with its existing illegal-tail behavior unchanged.
- Production changes are limited to four added/changed lines in `ui/premove_queue.gd`; the two regressions are in the confirmed `tests/test_premove.gd` seam. No other production files, contract changes, or new proxy decisions.

Red/green evidence, with each test committed before its separate production fix:

| Test commit | Red result / reason | Production commit | Focused green |
|---|---|---|---|
| `cbbc577` | 17 passed, 1 failed: White and Black ghost queues accept opposing-king captures, change the accepted prefix and remove a king | `8427406` | 18 passed, 0 failed |
| `97164d6` | 18 passed, 1 failed: reprojection after `c4b3` returns a board without the black king instead of null | `e9c1b16` | 19 passed, 0 failed |

Focused runs used `godot --headless --log-file build/<cycle>.log -s tests/run.gd -- build/ui007-tests` with an ignored copy of the current test file, as in the original implementation. They required filesystem access to Godot's test `user://` storage; a preliminary sandboxed run also failed the existing settings test for denied writes. The red counts above come from runs with that access, where only the intended regression failed.

The bound gate ran once through `gate-evidence.ps1` on committed, clean production tip `e9c1b16`: `godot --headless -s tests/run.gd` → **171 passed, 0 failed**, exit 0. It used the original test files. Log: `C:\Users\Lage\AppData\Local\Temp\UI-007-stage2-king-capture-gate.log`; receipt is the current Gate evidence line above. Final diff, test/production commit separation and `git diff --check` checked. Only this tracker handoff follows the tested code.

Acceptance: pending | Automated regressions and the full gate pass. Independent stage-3 re-review of the criterion-2 repair remains; the original manual 1+0 game, ghost appearance and premove audio checks have not been performed.
Disclosure: pending | integration | The reopened criterion-2 finding now has a tested correction in `8427406` and `e9c1b16`; independent stage-3 review must confirm it before session integration.
Disclosure: pending | release | The original manual visual/audio acceptance remains pending; this scoped repair does not assess rendering or sound quality.

#### Resolution (2026-10-25, re-review)

Verdict: Approve

Independent Standards and Spec sub-agents reviewed `284f717...678c408`, the reopened criterion-2 finding and every subsequent commit. Both returned no findings. This review authored no production or test changes. The branch was rebased without conflicts onto session `b206a36`; the resulting production and test files are identical to the reviewed versions. Merged `UI-007` into `sweatshop/core/2026-10-25-0159` without squash as `ce7205d`.

Examined: both queue entry points (`enqueue` and `position`), repeated-human-turn Board move generation, both-colour king captures, accepted-prefix and live-board/history preservation, reprojection after Maia's king enters a queued destination, BoardView's null-projection drawing/input paths, Lichess replacement and the unchanged live legality check in `take`/Main. No additional miss in previously reviewed code was identified. Interactive visual/audio acceptance, exported builds and real mouse-gesture feel remain unexamined.

##### Standards

No documented-standard violations or material baseline smells. Both repair cycles preserve test/production separation: `cbbc577` (tests plus permitted ticket metadata) then `8427406` (production only), followed by `97164d6` (tests only) then `e9c1b16` (production only); `678c408` is ticket metadata only. Their rebased equivalents are `6c0b22c`, `d4d288a`, `b61f49d`, `d656b28` and `8682dd0`. Production remains within `ui/premove_queue.gd`, and tests within the approved `tests/test_premove.gd` seam. No unrelated refactoring.

##### Spec

2. ✅ The ghost rejects a king capture before changing the accepted queue. The regression covers the original White sequence and its Black counterpart, retaining both kings and the live game/history. Reprojection also returns null if Maia's king enters a later queued destination; BoardView safely displays the live board and declines further invalid ghost input. A valid due move still executes through `take`, independently of an invalid later preview. Criteria 1 and 3–8 retain the passing results of the first review; the unchanged live legality check still drops an illegal due move and its tail.

Red/green: inspected the retained focused logs and committed regressions. The enqueue regression failed for both colours before `8427406` (**17 passed, 1 failed**) and passed after it (**18 passed, 0 failed**). The reprojection regression then failed before `e9c1b16` (**18 passed, 1 failed**) and passed after it (**19 passed, 0 failed**). Both regressions exercise the real PremoveQueue/Game/Board.

Gate: validated the current `Gate evidence:` receipt using the installed `Assert-GateEvidence` helper before and after rebase. The bound command `godot --headless -s tests/run.gd`, on `e9c1b1667ddc7ab694b7ff765afc13bb9f301742`, exited 0 with **171 passed, 0 failed**. The log hash and exit marker match; the tested commit exists. Only tracker metadata differs from that tested code, and the merge has the same tree as rebased `UI-007`. The green gate is reused because no production or tests changed. `git diff --check` passes.

Proxy review: the existing `(gpt-6-astra high, fallback)` decision requiring criterion-2 king preservation is satisfied by the reviewed repair. No new proxy decision or contract change. The earlier integration holds are resolved by this approval and merge.

Acceptance: pending | Automated acceptance and the criterion-2 re-review pass. The manual 1+0 game, ghost appearance and premove audio checks remain as recorded in the original Verification/handoff.
Disclosure: decision | none | The existing proxy requirement to preserve both kings in ghost positions is implemented and independently approved; its prior integration condition is resolved.
Disclosure: pending | release | Manual visual/audio acceptance remains pending as described above.
Disclosure: deferred | none | [CLEAN-002](33-CLEAN-002-promotion-picker-layout.md) tracks the inherited UI-002 cosmetic picker-layout issue on flip/resize. It is outside UI-007's numbered criteria, predates this change and no longer relies on a note in a closed ticket.
