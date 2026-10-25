# CLEAN-003: Consider shared cleanup for isolated history tests
Stage: done
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - tests/test_history.gd (isolated-storage cleanup)
  - tests/test_session.gd (isolated-storage cleanup)
  - tests/test_premove.gd (isolated-storage cleanup)
  - tests/test_input_modes.gd (isolated-storage cleanup)
  - New: tests/history_storage.gd (shared test-only cleanup, if extraction is approved)

#### What to build

Consider consolidating the repeated cleanup of isolated History storage in the four scene-test harnesses. [HIST-001](21-HIST-001-history-stats.md) recorded this optional possible Duplicated Code observation in its first review and re-review. No runtime defect was found; a shared helper should be introduced only if it makes ownership and cleanup clearer.

#### Acceptance criteria

1. Any approved extraction keeps cleanup restricted to each harness's owned storage root and its `games` child, tolerating absent directories without accessing normal player history or stats.
2. Existing isolated History injection, startup assertions and behavior assertions remain unchanged; no production code changes.
3. The bound gate passes with the refactored harnesses.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None new: this is a mechanical test-only refactor. Validation is the existing History tests plus the gate, unchanged in count. Preserve the existing production-backed tests; do not invent a behavior failure.

## Comments

- Created by HIST-001 stage 3 on 2026-10-25 to retain the non-blocking review observation in an open destination. The same directory-existence correction was previously needed in multiple harnesses. This follow-up does not block HIST-001 integration or release.
- Blocked for stage-1 triage and confirmation of the proposed scope and validation approach. No helper or refactor was implemented during review.
- 2026-10-25 Stage 1 (human, Bruno): approved the extraction into new test-only `tests/history_storage.gd`, used by the four harnesses, with criteria 1-3. Reason: the same directory-existence fix already had to be repeated across copies. Low priority.
- 2026-10-25 Stage 2 (opus-5.5): extracted the cleanup into test-only `tests/history_storage.gd` (`static func clean(folder)`, the former loop verbatim: `games` child then root, each only if it exists). `test_history.gd` drops `_clean` and its 13 callers use the helper; the session, premove and input-modes harnesses replace their inline `tree_exiting` lambdas with `func(): HistoryStorage.clean(<own folder>)`. Each harness keeps its own `user://test_<x>_history_%d` root and its History injection and assertions unchanged; no production files changed. No new tests, per the ticket: the diff adds or removes no `func test_` line. Commit 95b3633 is test-only; there is no production commit for this ticket.
- Gate on 95b3633: exit 0, 241 passed, 0 failed, 4 skipped (Lc0 engine-dependent tests: no `engine/lc0/lc0.exe` in this fresh worktree), no script or parse errors. Log hash 478E2C1F244331A76E24CAF5ADE9F4683F3E6D2AD087A2478C28E75E8911E929. The helper ran with Godot's generated untracked `*.uid`/`*.import` excluded through a process-only `core.excludesFile`, since a fresh-worktree import otherwise makes `git status` non-empty.
- Out of scope, noted for a possible `CLEAN-*`: `tests/test_badges.gd` and `tests/test_book.gd` keep their own `_clean` helpers (not in Primary files; not checked whether they clean History storage).

Gate evidence: C:\Users\bruno\AppData\Local\Temp\claude\C--Users-bruno-Desktop-Pastinha-Programas-Projects-P-Chess--claude-worktrees-clean-003-review-05c0f7\6daf1038-61d2-4c75-b591-44ebfe992ea7\scratchpad\CLEAN-003-review-gate2.json

#### Resolution (2026-10-25)

Verdict: Approve

Stage 3 (opus-5.5). This was a two-axis `code-review` of `origin/main...clean-003`. The branch was rebased onto main twice; the final commits are `6e839d4` (test-only refactor) and `094437c` (handoff metadata). The review made no fix commits.

Criteria:
1. ✅ `tests/history_storage.gd` `clean(folder)` is token-for-token the removed `_clean` from `test_history.gd`. It loops over `[folder/games, folder]`, checks that each one exists, removes its files and then the directory. It only acts on the folder each harness passes in: `user://test_history_%d`, `user://test_session_history_%d`, `user://test_premove_history_%d`, and the input-modes `history_folder`. It never touches normal player history or stats.
2. ✅ Only `tests/` and this ticket changed. No assertion lines and no History injection lines changed, and no production file changed. The diff adds or removes no `func test_` line. `tests/run.gd` collects only `test_*.gd`, so the helper is not run as a test.
3. ✅ Gate result below.

Examined:
- The callers: all 13 former `_clean(folder)` calls in `test_history.gd`, and the `tree_exiting` lambdas in the session, premove and input-modes harnesses. Each lambda captures the same local it used before (`folder`, `folder`, `history_folder`).
- Absent-directory tolerance, which is unchanged.
- The test-runner discovery rule.
- Primary files: 5 of 5 in use, nothing outside them.
- The commit split: one test-only commit, and no production commit by the ticket's design.

Not examined:
- The 4 Lc0-dependent tests SKIP in this worktree (there is no `engine/lc0/lc0.exe`). They do not use the History cleanup.

Red-green: none, by the ticket's design (a mechanical test-only refactor with no new tests). Validation is the existing History-backed tests plus the gate, with the count unchanged against main (see Gate).

Standards axis: the repo has no documented standards. Two baseline judgement calls, neither blocking:
- Possible remaining Duplicated Code outside Primary files (see the follow-up).
- A weak Mysterious Name: `HistoryStorage` reads like a production class. The `tests/` path and the header comment make the purpose clear, so it is left as is.

Spec axis: nothing missing, no scope creep, nothing implemented wrong.

Follow-up: [CLEAN-007](38-CLEAN-007-remaining-history-test-cleanup.md) (blocked, needs triage). `tests/test_review.gd` and `tests/test_clock_input_order.gd` still hold verbatim copies of the same lambda. Stage 2's note about `test_badges`/`test_book` goes there too: those two also clean `openings`/`repertoires`, so they are not straight duplicates. No Proxy decided lines in this ticket.

Gate: run twice, because main moved twice during the review. Each run used `godot --headless --import` and then `gate-evidence.ps1`.
- First run, rebased onto `a5fbc5b`, tested commit `e4c1876`: exit 0, **241 passed, 0 failed**. Its log hash equals stage 2's run.
- Then CLEAN-002 and CLEAN-005 merged, so the branch was rebased onto `1ef4287` (commits now `6e839d4` test-only and `094437c` metadata) and gated again on the tested commit `094437c1ba799eb8e53a30673f910cb7ed5d0af8`: exit 0, **245 passed, 0 failed**. 245 is main's 241 plus the 4 tests CLEAN-002 and CLEAN-005 added; this diff adds none. 4 SKIP (Lc0 absent), no FAIL or script-error lines. Log SHA-256 `91AFB86885F7173F4715F59558BA233DCE42371FFB2C74E66DBDDDABFBB743FE`. Receipt: `C:\Users\bruno\AppData\Local\Temp\claude\C--Users-bruno-Desktop-Pastinha-Programas-Projects-P-Chess--claude-worktrees-clean-003-review-05c0f7\6daf1038-61d2-4c75-b591-44ebfe992ea7\scratchpad\CLEAN-003-review-gate2.json`.
- PR CI (`test`) passed.

Acceptance: passed | gate log above. The test-only refactor keeps the whole suite green.
Disclosure: deferred | none | [CLEAN-007](38-CLEAN-007-remaining-history-test-cleanup.md): the remaining History-cleanup duplicates outside this ticket's Primary files, for an optional stage-1 triage.

Merge: PR #13 merged into main as `5620dca`. Between the tested commit `094437c` and the merge, only CLEAN-005 tracker files (its ticket and the ledger) changed, so the merged code equals the tested code.
