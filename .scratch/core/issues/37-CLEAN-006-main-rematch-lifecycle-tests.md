# CLEAN-006: Preserve real-Main rematch interaction lifecycle coverage
Stage: done
Status: ready-for-agent
Blocked by: CLEAN-001
Review: agent
Difficulty: normal

- Primary files:
  - tests/test_session.gd (real-Main rematch, promotion and held-piece scenarios)

#### What to build

Commit the real-Main lifecycle regression coverage owed by [UI-004](17-UI-004-setup-end-hotkeys.md#comments). That ticket's reviews checked promotion-picker, held-piece and snap-back cleanup with an uncommitted in-tree probe; existing committed tests exercise the BoardView game assignment rather than the complete Main rematch path. Its open destination was [CLOCK-002 Comments](32-CLOCK-002-move-after-flag.md#comments), but these tests are outside CLOCK-002's numbered criteria. The active-tree runner prerequisite now exists; reliable assertions after tween completion may need additional runner support.

#### Acceptance criteria

1. A real Main rematch after a flag with the promotion picker open closes the picker, removes its buttons and clears the pending promotion.
2. A real Main rematch after a flag with a piece held clears the held piece and old targets; a legal move in the new game still works.
3. A real Main rematch while an old snap-back tween exists kills that tween: a piece picked up immediately in the new game remains held after the old tween's completion time.
4. The tests reach Main's actual rematch path and fail against the relevant missing cleanup, including removal of `_snap.kill()` for criterion 3. Existing runner error reporting and suite counts remain reliable.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_session.gd`, awaiting the old tween's completion with the runner support from [CLEAN-001](../../bot/issues/33-CLEAN-001-async-think-time-tests.md). Instantiate real Main with isolated storage, a held engine and silent audio, then flag and rematch through Main. Existing behavior may already be green; demonstrate regression sensitivity with the previously documented missing-cleanup mutations rather than inventing a production defect.

## Comments

- Created by CLOCK-002 stage 3 on 2026-10-25 as the open destination for UI-004's deferred coverage before CLOCK-002 closes. Prior evidence is recorded in UI-004's reviews: both real-Main repros and the snap-back race passed the uncommitted probe; removing only `_snap.kill()` failed the race check.
- Blocked for stage-1 triage and confirmation of the proposed test boundary and completion mechanism. This preserves an existing coverage obligation; it is not a new production defect or an integration/release blocker for CLOCK-002.
- 2026-10-25 Stage 1 (human, Bruno): approved criteria 1-4 and the real-Main `tests/test_session.gd` seam. The runner change belongs to CLEAN-001, so this ticket is blocked by it and `tests/run.gd` is not a primary file here.
- 2026-10-25 Stage 2 (opus-5.5): test-only a1f433a adds three real-Main tests to `tests/test_session.gd`: `test_a_main_rematch_after_a_flag_closes_the_open_promotion_picker` (criterion 1; reaches the picker by playing 1. a4 b5 2. axb5 a6 3. bxa6 Bb7 4. axb7 Nc6 through Main and dragging b7 to a8), `test_a_main_rematch_after_a_flag_drops_the_held_piece` (criterion 2) and `test_a_main_rematch_kills_the_old_snap_back` (criterion 3, awaits a real timer of 3 × `SNAP_BACK_SECONDS`). Each flags through `main.clock.flagged` and rematches through Main's Space key, with mouse input placed from the live board's own corner and size after one frame of layout. No production change: the cleanup already exists, so the commit is green on base, as the ticket anticipated, and the red proof is by mutation (criterion 4).
- What the mutations found: UI-004's documented mutants (the `game` setter's reset, or only its `_snap.kill()`) no longer fail on the real Main path. Since UI-004, every game end runs `Main._show_result` → `board_view.cancel_premoves()` → `_cancel_interaction()`, which kills `_snap`, closes the picker and drops the held piece at the flag, before Space reaches the setter. The relevant cleanup on Main's path therefore lives in two sites, and each single-site mutant is equivalent there: removing the setter's reset gives `248 passed, 3 failed` (only the off-tree board tests and `test_input_modes`), removing only the setter's `_snap.kill()` gives `251 passed, 0 failed`, and removing only `_cancel_interaction`'s `_snap.kill()` gives `251 passed, 0 failed`. The off-tree tests above still separate the setter on its own.
- Red proof on the real path (all mutations restored before the gate, logs in the session notes folder `clean-006-mutant-*.log`): (a) setter reset removed and `_show_result`'s `board_view.cancel_premoves()` removed → `244 passed, 7 failed`; the criterion-1 test fails on the visible picker, pending `b7a8` and 4 buttons left; the criterion-2 test fails on `e2` held with targets `e2e3`/`e2e4`. Its last assertion (e7e6 plays) does not separate this mutant, because Maia's e2e4 runs `_commit` → `_cancel_interaction` and drops the stale piece. (b) both `_snap.kill()` calls removed (setter and `_cancel_interaction`) → `250 passed, 1 failed`, only `test_a_main_rematch_kills_the_old_snap_back` (`expected "e7", got ""`).
- Green: gate exit 0, `251 passed, 0 failed` on a1f433a (248 before plus the 3 new tests). The log shows Godot attributing later backtraces of expected `push_warning`s to the timer test's resumed frame; base logs show the same artefact on `_run` after CLEAN-001's timer test, and warnings are not collected as errors.
- Callers examined: the `game` setter (Main `_start`, `_ready`, tests), `_cancel_interaction` (`cancel_premoves`, `_commit`, `premove_style`), Main `_show_result` (flag, resign, terminal moves). Not examined: the app in a window, by a person.
Gate evidence: C:\Users\bruno\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_ea9dedf1-afd3-427a-be68-f9943a87cc6f\clean-006-gate.json

#### Resolution (2026-10-25)

Verdict: Approve

- Reviewer: opus-5.5, stage 3. Rebased onto main at 4b39a70 (after CLEAN-004) with no conflicts. Merged as PR https://github.com/Laginho/P-Chess/pull/16 (6e51ddb). The review is posted as a PR comment.
- Files: `tests/test_session.gd` only (test-only, no production change).
- Criteria 1–3 ✅ by the three tests named in Stage 2's comment.
- Criterion 4 ✅ This settles the reading stage 2 left open. On Main's real path, `_snap` is killed in two places: the `game` setter and `_show_result` → `cancel_premoves` → `_cancel_interaction`. Removing `_snap.kill()` from only one site still leaves the tween killed, so it is an equivalent mutant on this path. "Removal of `_snap.kill()`" means both sites, and the two-site proof satisfies the criterion. The off-tree board tests still cover the setter on its own.
- Red proof: I reproduced the two-site `_snap.kill()` mutant here, giving `252 passed, 1 failed`, and only `test_a_main_rematch_kills_the_old_snap_back` fails (`expected "e7", got ""`). The mutant for criteria 1–2 is cited from stage 2's log `clean-006-mutant-no-reset-no-end-cleanup.log` (244/7) and was not rerun here.
- Gate: on 43a70e6, exit 0, `253 passed, 0 failed`, 4 skipped (no lc0). The three new tests appear as PASS. CI passed on PR 16. Review receipt: C:\Users\bruno\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_ea9dedf1-afd3-427a-be68-f9943a87cc6f\clean-006-review-gate.json. It supersedes the stage-2 receipt above, which was taken on pre-rebase a1f433a.
- What I examined: the `game` setter, `_cancel_interaction` and its callers (`cancel_premoves`, `_commit`), Main `_show_result`, and CLEAN-001's awaiting runner. I did not examine the app in a window.
- No Proxy decided lines. No contract change.
- Acceptance: passed | review receipt above, PR https://github.com/Laginho/P-Chess/pull/16
