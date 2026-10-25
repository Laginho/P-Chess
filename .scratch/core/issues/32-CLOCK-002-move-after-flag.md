# CLOCK-002: A move dropped after the time ran out
Stage: done
Blocked by: CLOCK-001
Review: agent
Difficulty: normal

- Primary files:
  - ui/main.gd
  - tests/test_clock_input_order.gd (new; real Main under the runner root, as tests/test_session.gd does)

#### What to build

When the human's time runs out, a piece they drop in that same frame is not played: the game ends on time, as if the drop had come a moment later. Today `core/clock.gd` only learns the time ran out at the next `_process` tick, and Godot handles input before `_process`, so a drop up to one frame (~16 ms) after the clock hit 0 is played first, and `Clock.moved` flags after it. Found in CLOCK-001's review.

#### Acceptance criteria

1. A piece dropped after the human's clock reached 0, before the next frame's tick, snaps back as in CLOCK-001 criterion 8: no move, no move sound, no `move_played`. The game ends `time` by CORE-004's flag rule on the position before the drop.
2. In 3+2, a drop in the frame the human's clock crossed the low-time threshold (10 s) still plays the low-time sound once, though the increment lifts the clock back above it.
3. A piece dropped while time is left plays as before.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_clock_input_order.gd`, on the seam the human chose (option (a), `Human decided (Bruno)` under Comments): instance `ui/main.tscn` under the runner's root (the runner already defers `_run` from `_initialize`, since UI-004's 6075057), with the fake engine, settings file and silent sound theme `tests/test_session.gd` uses, and await a few frames for `_ready`; swap `main.clock` for a `Clock` on a fake time source; push input through `main._unhandled_key_input` and `board_view._gui_input`, with no `_process` tick between the time crossing and the drop.
  - Criterion 1: the human's clock at 0 on the fake source, a legal drop: the piece snaps back, no `move_played`, no move sound, the move list unchanged, the game over `time` (a case where the late move would mate or take the opponent's last mating material shows the rule read the position before the drop).
  - Criterion 2: 3+2, the fake source crosses 10 s in the frame of the drop: the low-time sound plays exactly once.
  - Criterion 3: time left, the same drop plays as before.
  - Red because `Main` only ticks the clock in `_process`, after the board's input.

## Comments

- 2026-10-24 Created at CLOCK-001's close (stage 3). Today the late move stays on the board and in the move list, and the flag rule then reads the position after it: a mating late move stands as checkmate, and a late capture of the opponent's last mating material turns a loss on time into a draw. The 3+2 low-time sound can be skipped the same way. Candidate fix: `ui/main.gd` ticks the clock in `_input`, which Godot runs before the board's `_gui_input`, so the flag lands first and CLOCK-001's `_commit` guard snaps the piece back.
- Question for stage 1 (why this is `blocked`): which test seam? `ui/main.gd` needs the tree for its `@onready` nodes, starts Lc0 in `_ready`, and `_start` hard-codes `Time.get_ticks_msec`, so no existing test reaches the input order. Options: (a) instance `ui/main.tscn` under the test runner's root, swap `main.clock` for one on a fake time source, and push a mouse event through the viewport; (b) a seam `tests/test_board_view.gd` can reach, e.g. BoardView ticks a clock it is given before `_commit`, which adds `ui/board_view.gd` to Primary files.
- 2026-10-24 From UI-004's re-review (a note, not a criterion until stage 1 folds it in): option (a) works headless. A `SceneTree` script that defers its work from `_initialize` (`call_deferred`), adds `ui/main.tscn` to the root and awaits a few frames gets `_ready`, running tweens and the promotion picker's buttons, and can push input through `main._unhandled_key_input` and `board_view._gui_input`. The runner calls tests straight from `_initialize`, so this needs a `tests/run.gd` change. The same seam would host the test UI-004 owes: a rematch (Space after a flag) through the real `Main._start` clears the open picker, the held piece and a running snap-back tween. That was checked in review only, by an uncommitted probe.
- 2026-10-25 Human decided (Bruno): test seam option (a), "pode destravar o clock-002 também, aceito sua sugestão" (relayed by the supervisor session). Instance `ui/main.tscn` headless under the runner's root, deferring from `_initialize` with `call_deferred` and awaiting a few frames; swap `main.clock` for a clock on a fake time source; send input through `main._unhandled_key_input` and `board_view._gui_input`. UI-004's re-review showed it works, and `tests/test_session.gd` already runs this way. Folded into Primary files and `## Tests stage 2 writes`; Stage back to `to-implement`.
- Related: BOT-005 c2 clamps Maia's delay to its clock left, so Maia's move can land at 0 by design (note in BOT-005 ## Comments). UI-007's premoves also commit a move at the instant the opponent moves.
- Stage 2 (2026-10-25): callers examined before the red test: Godot dispatches global `_input` before BoardView's `_gui_input`; normal drops and promotion choices reach `_submit`/`_commit`, then `Main._on_move_played` accounts for the clock. `_process` must keep ticking without input. Premoves charge separately in `_next_turn`; Maia uses `_on_maia_move`/`BoardView.play`, outside this human-input fix. Boundary cases: no clock before setup, untimed first moves, exactly zero, a stopped clock, and the 10 s threshold before increment. The real scene becomes ready synchronously under the already-deferred runner, as in `test_session.gd`; no runner change or frame wait is needed. The mouse helper dispatches global input through the viewport before board-local GUI input, without a frame tick.
- First red: the new mating-drop test fails because late `d8h4` is accepted as `Qh4#`, emits `move_played` and move/check sounds, and appends SAN. Full gate before the fix: exit 1, 231 passed, 1 failed (`%TEMP%/CLOCK-002-red-1.log`). The initial sandbox run had unrelated user-data permission failures; this red was reproduced with access to Godot's user-data directory.
- Stage 2 additional coverage: all four tests now send the entire mouse event through the real viewport, including GUI delivery, so moving the tick after GUI input cannot masquerade as a fix. This strengthens the initial helper, which dispatched global input before a direct board-local GUI call. `RecordingSounds` records the audio output boundary while retaining the real sound player and a silent theme. Covered: late mate at exactly zero (and no repeated flag on later ticks/input), 10.001 s to 10 s followed by increment to 12 s and a second threshold crossing, the same mate with 1 ms left, setup with no clock, and untimed first moves after arbitrarily much fake time. Focused result: 4 passed, 0 failed. Mutation red: temporarily replacing `_input` with `_unhandled_input` gives 1 passed, 3 failed, including the skipped low-time warning; restored before committing (`%TEMP%/CLOCK-002-mutation-input-order.log`). No additional production change was needed for these cases.

#### Stage 2 handoff (2026-10-25)

- Production: `169364a` adds `Main._input` to tick the clock before GUI input, preserving the existing idle-frame tick. No other production files changed.
- Criterion 1: the viewport-delivered late `Qh4#` leaves the queen on d8, keeps the move history and SAN list unchanged, emits no move or move sound, and loses `1-0` by `time` on the pre-drop position. Subsequent input/frame ticks do not repeat the flag.
- Criterion 2: a drop crossing from 10.001 s to 10 s plays `low_time` before `move`; the increment raises the clock to 12 s, and crossing the threshold again does not repeat the warning.
- Criterion 3: the same mate at 1 ms plays once, updates SAN, emits the expected sounds and earns the increment. Setup without a clock and untimed first moves remain available.
- Test-first evidence: `c46c44c` is test-only plus ticket metadata (red: 231 passed, 1 failed); `169364a` is production-only (focused green: 1 passed, 0 failed). `63345fc` adds the other cases and real viewport GUI delivery in a test-only/metadata commit (focused green: 4 passed, 0 failed; wrong-order mutation: 1 passed, 3 failed).
- Gate: `godot --headless -s tests/run.gd` at `63345fc182c3f7b3a91fb1e2a10d6be38b44d389`, exit 0, **235 passed, 0 failed**. The committed tree was clean; `gate-evidence.ps1` captured the commit, exit status and log hash. Final diff inspection and `git diff --check` passed. Existing malformed-fixture warnings are expected.
- Limitations: validation used headless Main with fake time, a held engine and recorded silent audio; no windowed or exported-build check was performed. Independent stage-3 review remains pending.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\CLOCK-002-core-gate.json

Acceptance: passed | numbered criteria 1–3 exercised through real Main and viewport input in `tests/test_clock_input_order.gd`; full gate 235/235 on `63345fc`.

#### Resolution (2026-10-25)
Verdict: Approve

##### Standards

No documented-standard breaches or meaningful baseline smells found. The production change stays within `ui/main.gd` and explains the input-order requirement. Tests cover the regression and threshold boundaries through real viewport delivery using established scene-fixture conventions. Commit separation and changed-file scope match the ticket-flow constraints. Independent axis: `standards_review`.

##### Spec

No missing requirements, scope creep or incorrect implementation found. Independent axis: `spec_review`.

1. ✅ `Main._input` ticks before GUI delivery. The late mating-drop test verifies a time loss on the pre-drop position, unchanged position/history/SAN, no move signal or move sound, and cleared held-piece state. Later ticks and input do not repeat the flag.
2. ✅ The 3+2 test crosses from 10.001 s to 10 s on the drop, verifies `low_time` before `move`, the increment to 12 s, and no repeated warning at a second threshold crossing.
3. ✅ The same mating drop with 1 ms left commits exactly once, updates SAN, emits the expected sounds and earns the increment. Setup with no clock and untimed first moves remain available.

- Review scope: all four ticket commits and their full diffs; Main's global/frame/key input, setup/start/rematch, flag/result/move handlers and clock wiring; BoardView's GUI delivery, cancellation, promotion, submit/commit and programmatic play; `Clock.tick`, `moved`, `stop` and warning/flag idempotence; `Game.flag` and its pre-move material rule; premove charging and Maia's delayed programmatic reply. Boundary cases examined: no clock, untimed/stopped clocks, exactly zero, 1 ms remaining and repeated low-time crossings. No windowed, exported-build or physical-audio check was performed.
- Files: `ui/main.gd` adds only the pre-GUI tick; `tests/test_clock_input_order.gd` adds four real-Main viewport tests. No production or test changes were authored in stage 3.
- Test-first evidence checked: `c46c44c` changes tests/tracker only (red log: **231 passed, 1 failed**, late `Qh4#` incorrectly stood); `169364a` changes production only (focused green: **1 passed, 0 failed**, recorded at handoff); `63345fc` strengthens tests only plus tracker metadata (focused green: **4 passed, 0 failed**; wrong-order `_unhandled_input` mutation log: **1 passed, 3 failed**, restored). `98852bd` is tracker-only handoff. No test/production mixed commit.
- Gate evidence reused: bound command `godot --headless -s tests/run.gd`, tested commit `63345fc182c3f7b3a91fb1e2a10d6be38b44d389`, **235 passed, 0 failed**, exit 0. The receipt's command, commit, exit status and log SHA256 were checked using `Assert-GateEvidence`; the log contains all four new tests passing and no FAIL/script-error records. SHA256: `73A0A9F7B62B539F4187D40A590C9056A3249D393AB15A82280E369E1220D787`. Production/tests remain identical after the no-op rebase and local session merge. The unchanged gate was not rerun.
- Both axes: **0 findings**. Final scope/whitespace checks passed. Integrated locally into `sweatshop/core/2026-10-25-0159` without squash; the ledger points to the merge commit. No PR or push in this session flow.
- Inherited notes remain open elsewhere before this ticket closes: Maia's late programmatic move goes to [CLEAN-005](36-CLEAN-005-maia-move-after-flag.md); UI-004's additional real-Main promotion/held-piece/snap-back lifecycle coverage goes to [CLEAN-006](37-CLEAN-006-main-rematch-lifecycle-tests.md). These were comments, not numbered CLOCK-002 requirements. No deferral was accepted on the human's behalf.

Disclosure: pending | release | [CLEAN-005](36-CLEAN-005-maia-move-after-flag.md) retains BOT-005/CLOCK-001's known Maia-at-zero race. This human-input fix does not tick before `_on_maia_move`; a delayed programmatic move can still land before the frame tick. Stage-1 scope/criteria approval and a fix remain required; no accepted deferral.

Disclosure: pending | none | [CLEAN-006](37-CLEAN-006-main-rematch-lifecycle-tests.md) retains UI-004's owed committed real-Main rematch/promotion/held-piece/snap-back coverage. Prior review probes and BoardView tests are evidence, but these lifecycle tests were not added by CLOCK-002.
