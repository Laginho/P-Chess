# UI-007: Premoves
Stage: to-review
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

Gate evidence: C:\Users\Lage\AppData\Local\Temp\UI-007-stage2-gate.json

Acceptance: pending | The automated 1+0 scene scenario queues three moves, executes one, then drops the remaining queue after Maia captures the pawn required by the next move (`test_main_queues_human_moves_and_executes_one_per_maia_reply`). A person has not yet played the manual Verification game or checked the ghost rendering and premove audio.
Disclosure: pending | release | Manual visual/audio acceptance remains as described above; headless tests validate input, move order, signals, settings, clock boundaries and promotion interruption, but do not judge appearance or sound quality.
