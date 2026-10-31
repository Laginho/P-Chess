# CLEAN-011: Isolated-root history tests still share the real analysis cache folder
Stage: to-review
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
