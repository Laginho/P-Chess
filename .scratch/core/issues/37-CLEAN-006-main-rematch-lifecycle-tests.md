# CLEAN-006: Preserve real-Main rematch interaction lifecycle coverage
Stage: to-implement
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
