# CLEAN-011: Isolated-root history tests still share the real analysis cache folder
Stage: done
Status: needs-triage
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - core/history.gd (`delete`: `"user://analysis"`)
  - core/analysis_queue.gd (runner output: `"user://analysis"`)
  - ui/history_screen.gd (`_analysis_text`), ui/main.gd (`_review_history_game`, post-game review path)
  - tests/test_history.gd, tests/test_history_screen.gd

#### What to build

`History` takes a root, so tests keep games and stats under a per-run `user://test_…` folder. The analysis cache does not follow that root: five production sites hardcode `user://analysis`, so the HIST-004/005/006 tests write and delete their (uniquely named) analysis JSON in the player's real cache folder. A test that aborts mid-way leaves an orphan there. Derive the analysis folder from the history root (`<root>/analysis`, identical to today's `user://analysis` when the root is `user://`), the way `ui/review.gd` already derives `<root>/games` from an analysis path, and move the tests' analysis files under their per-run folder.

#### Acceptance criteria

1. No test under `tests/` writes or deletes inside `user://analysis` or `user://games`; `grep -rn '"user://analysis\|"user://games' tests/` finds nothing.
2. Production paths are unchanged for the default root (`user://analysis/<game>.pgn.json`).
3. The gate passes with the test count unchanged.

#### Verification

    godot --headless -s tests/run.gd

## Comments

- 2026-10-31 Opened by the PR #28 review loop: the PR's HIST tests use unique names in the real analysis cache; the one test that wrote into the real `user://games` was fixed in the PR (`0d90019`). Changing where production resolves the cache is a design change, kept out of the review fix.

- The existing `test_open_review_starts_max_analysis_and_tracks_progress` now disables the queue to exercise the direct analyser: with the corrected history root, saved games correctly route through the queue instead.

- Red: 398 passed, 3 failed before the path change; deletion and history-card cache checks exposed the old shared folder.
- Verification: gate passed at 8e62da5: 401 reported passed, 0 failed, including 6 Lc0 skips (395 executed). No literal real analysis or games paths remain in tests/.

Acceptance: unknown
Gate evidence: C:\Users\bruno\AppData\Local\Temp\clean-011-gate-green.json

#### Resolution (2026-10-31)
Verdict: Approve

- Standards: no documented-standard violations or actionable baseline smells. Reviewed all eight changed files against session base `902e9ab` through `a5bf32d`. Commits keep tests and production separate. The one-line `tests/test_review.gd` harness correction qualifies as a test-only Primary file under the stage-2 exception: it selects the existing direct-analyser seam and preserves every assertion.
- Spec: no missing requirements, scope expansion or regressions found. Criterion 1 passes: the literal search for `user://analysis` and `user://games` under `tests/` is empty, and examined indirect writes use each fixture's root. Criterion 2 passes: all five changed production sites resolve `<root>/analysis/<game>.pgn.json`, preserving the default `user://analysis/<game>.pgn.json`. Criterion 3 passes: no test methods were added or removed; the verified gate reports 401 passed, 0 failed, with six Lc0 skips (395 executed), exit 0.
- Coverage: `core/history.gd`, `core/analysis_queue.gd`, `ui/history_screen.gd`, `ui/main.gd`, `tests/test_history.gd`, `tests/test_history_screen.gd`, `tests/test_review.gd` and this ticket. Connected code examined includes `ui/review.gd`, `engine/analyser.gd` and `tests/history_storage.gd`. Traced queue output and cancellation, deletion rollback and stats restoration, cached history cards, history Review, post-game Review, unsaved-game fallback and isolated-root cleanup. No affected caller or failure path identified during review remains unexamined; visual acceptance and live Lc0 execution were not performed. Acceptance remains unknown.
- Red-green proof: the existing red log records 398 passed and 3 failed before the root correction; the existing pre-harness green attempt records 400 passed and 1 failed because the saved fixture now correctly reaches the queue. During review, the corrected `test_open_review_starts_max_analysis_and_tracks_progress` also failed specifically on `review requests Max analysis` when `ui/review.gd` was mutated in memory to request Background, then passed unchanged. Probe: `C:\Users\bruno\AppData\Local\Temp\clean-011-review-harness-probe.gd`; logs: `clean-011-review-harness-mutant.log` (exit 1) and `clean-011-review-harness-green.log` (exit 0) in the same directory. No repository source was modified for the probe.
- Gate: reused the receipt above for tested commit `8e62da5`; verified its command, exit code, log SHA-256 and unchanged tested code through review and merge. The full gate was not repeated. Integration into `sweatshop/side/2026-10-31-0418` is merge commit `2c98620`; no conflicts or production fixes were required during review.
