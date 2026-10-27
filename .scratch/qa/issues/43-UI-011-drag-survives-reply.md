# UI-011: A held piece survives Maia's move
Stage: done
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: hard

- Primary files:
  - ui/board_view.gd (`_commit`, `_cancel_interaction` and the hold state)
  - tests/test_premove.gd (the reply-during-drag test)
  - tests/test_board_view.gd

#### What to build

Dragging a piece while Maia thinks, then Maia moves: the drag is dropped and the piece snaps back (Bruno's QA, 2026-10-26). `BoardView._commit` calls `_cancel_interaction()` for every move, Maia's included. On Lichess and Chess.com the drag carries on, and the drop counts against the new position.

#### Acceptance criteria

1. When Maia moves (or a premove executes) while you hold a piece by dragging or by click-selection, the hold continues if the held square still holds the same piece in the position input now uses.
2. If that move captured or moved the held piece, the hold ends, as now.
3. Dropping after the reply plays a normal move when it is legal and your turn (normal clock charge, not the premove cost), or queues a premove when it is Maia's turn again (a premove just executed).
4. The held piece's legal-move dots update to the new position.
5. An open promotion picker still closes when Maia moves (unchanged).

#### Verification

    Manual: a 1+0 game; start dragging before Maia replies and drop after; the move plays.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_premove.gd` / `tests/test_board_view.gd`: hold a piece, Maia replies without touching it, release on a legal square: the move plays (red: the hold was cancelled). Maia captures the held piece: nothing plays. `test_a_reply_cancels_an_unfinished_drag_before_running_the_due_premove` changes its expectation: the release on g5 now queues `f3g5`.

## Comments

- 2026-10-26 Written from Bruno's first QA session (item 4). Reverses UI-007's "Maia replies cancel held input" for drags and selections only; pickers still close.
- 2026-10-27 Stage 2 scope: `_commit` is reached by `play` (Maia/premoves) and `_submit` (drag, click-selection, promotion). `_cancel_interaction` also serves settings, right-click cancellation and game end; those callers keep cancellation. Input must be reconciled after synchronous `move_played` listeners execute the due premove. Check null/invalid ghost positions, changed/captured sources, legal-target changes, snap-back and promotion cancellation, both colours and both hold modes at the approved BoardView/Main test seams. No config, exports or fixtures need changing.

#### Stage 2 handoff (2026-10-27)

- Branch: `UI-011`, based on `sweatshop/qa/2026-10-27-1653` (`a827dc9`). Production change: `275ff98`; final tested code: `57032aa3b1bc7cd4b05a3322029d48db77ea46f1`.
- `_commit` reconciles drag/selection after synchronous move listeners, so a due premove can turn the held ghost into the live piece. Matching sources keep their pointer/selection and receive fresh legal/geometric targets; missing/replaced pieces, invalid projections and ended games cancel. Promotion pickers and snap-back still cancel. A dragged piece does not also slide when the due premove lands on its held square.
- Updated the retired `test_a_reply_cancels_an_unfinished_drag_before_running_the_due_premove` expectation as required by this ticket, now `test_a_reply_and_due_premove_preserve_an_unfinished_drag`: releasing on g5 queues `f3g5`. Drag and click-selection both cover this sequence.
- Test-only commits: `2631d41`, `ee86b59`, `ced5eed`, `57032aa`; production-only commit: `275ff98`. `git show --stat` confirms separation. Later coverage was proved red against the original production source and green against the restored implementation.
- Initial red: `2631d41`, 258 passed / 1 failed; after replacing the retired expectation: 257 passed / 2 failed. Initial green at `275ff98`: 259 passed / 0 failed. Logs: `C:/Users/bruno/AppData/Local/Temp/p-chess-ui-011/cycle-1-red.log`, `cycle-1-contract-red.log`, `cycle-1-green.log` in the same folder.
- Final red proof: all final tests with only `ui/board_view.gd` temporarily replaced by its `a827dc9` version, then restored byte-for-byte in `finally`: 260 passed / 4 failed, exit 1. Failures are lost drag/selection, lost ghost hold, stale/empty targets and cancellation of a blocked but still-held pawn. [Full red log](C:/Users/bruno/AppData/Local/Temp/p-chess-ui-011/final-baseline-red.log).
- Final gate: `godot --headless -s tests/run.gd` at `57032aa3b1bc7cd4b05a3322029d48db77ea46f1`: **264 passed, 0 failed; exit 0**. [Full green log](C:/Users/bruno/AppData/Local/Temp/p-chess-ui-011/final-green.log). Covers both colours/orientations and hold modes, ordinary 350 ms clock charge, continued premove queueing, en passant after a reply, empty legal targets, captured/moved sources, invalid remaining ghosts, animation state, and the existing promotion-picker cancellation regression.
- Acceptance: pending | [Verification](#verification): headless scenarios pass; the manual 1+0 drag across a real Maia reply has not been run.
- Disclosure: pending | release | [Verification](#verification): complete the manual 1+0 check before release; visual pointer/animation behavior has automated state coverage but no interactive confirmation in this session.

Gate evidence: C:\Users\bruno\AppData\Local\Temp\p-chess-ui-011\final-green.json

#### Resolution (2026-10-27)
Verdict: Approve

- Stage 3 reviewed the entire diff from `a827dc99e5001347469814c5d877c77b98cc6b6d` through `04e7121`, including every commit's file separation. Independent Standards and Spec reviewers found no issues. No production or test changes were authored during review.
- Examined callers: `BoardView.play`, `_submit`, Main's `_on_maia_move`, `_on_move_played` and `_next_turn`, including synchronous due-premove execution. Failure paths and interactions examined: moved/captured sources, null or invalid ghost projections, empty legal targets, en passant, game end/flag, ordinary clock charge versus premove charge, promotion-picker cancellation, snap-back, settings/right-click cancellation and slide suppression. Both hold modes and colours/orientations are covered by the tests. Physical mouse dispatch, rendered animation and a live Maia 1+0 game were not checked in this review.

Standards:
- 0 findings: Primary-file boundaries and surrounding conventions are respected; no dependency or speculative abstraction was added. Test-only commits `2631d41`, `ee86b59`, `ced5eed` and `57032aa` remain separate from production-only `275ff98`. Ticket metadata carries the stage transitions.

Spec:
- 0 findings: no missing/partial criteria, unrequested behavior or regression identified.
- Criterion 1: pass. Drag and click-selection are reconciled after move listeners finish, preserving the hold when its source still matches the current input position, including a ghost becoming live after a due premove.
- Criterion 2: pass. Captured/replaced pieces, a moved live source, invalid projections and ended games clear the hold and its targets.
- Criterion 3: pass. A legal drop on the human turn commits normally (the clock test charges 350 ms); a drop after the due premove queues the next move during Maia's turn.
- Criterion 4: pass. Targets are rebuilt from current legal moves or premove geometry; tests cover new en passant targets and a preserved hold with no legal targets.
- Criterion 5: pass. The promotion picker still closes before listeners process Maia's move; existing promotion cancellation coverage is preserved.

Verification and delivery:
- Inspected the recorded red proof: final tests against the original `a827dc9` BoardView yield 260 passed / 4 failed, exit 1; failures identify lost drag/selection, ghost continuation and refreshed targets. Production was restored before the green run. The retired reply-cancels-drag expectation was changed in a test-only commit to match this ticket.
- Reused the unchanged-code gate: `godot --headless -s tests/run.gd`, 264 passed / 0 failed, exit 0, tested commit `57032aa3b1bc7cd4b05a3322029d48db77ea46f1`. Validated the receipt with `Assert-GateEvidence`, including log SHA-256, exit marker, tested commit and equality of all files except this ticket and its ledger. `git diff --check` passed. The gate was not rerun because production and tests are unchanged.
- The ticket branch was already based on the session tip; integrated with merge commit `c7c1f40` into `sweatshop/qa/2026-10-27-1653`, preserving all commits. The driver owns session publication.

Acceptance: pending | [Verification](#verification): headless scenarios pass; a real 1+0 Maia reply while holding and then dropping the piece remains unchecked.
Disclosure: pending | release | [Verification](#verification): complete that interactive check before release, including pointer continuity and animation. Automated state coverage supports integration; visual acceptance remains pending.

Review totals: Standards 0 findings; Spec 0 findings. No confirmed unresolved implementation defect.
