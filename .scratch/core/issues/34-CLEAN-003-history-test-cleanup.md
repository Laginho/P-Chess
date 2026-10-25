# CLEAN-003: Consider shared cleanup for isolated history tests
Stage: to-review
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

Gate evidence: C:\Users\bruno\AppData\Local\Temp\claude\C--Users-bruno-Desktop-Pastinha-Programas-Projects-P-Chess--claude-worktrees-clean-003-9b09af\7f6b3e0d-982d-491f-9442-ed960dee3939\scratchpad\CLEAN-003-gate.json
