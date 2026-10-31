# REV-006: Review summary, eval graph and tooltips
Stage: implementing
Blocked by: REV-004, REV-005
Review: agent
Difficulty: normal

- Primary files:
  - ui/review.gd
  - ui/review.tscn
  - New: ui/eval_graph.gd
  - tests/test_review.gd
  - docs/spec.md (§15.6)

#### What to build

The review's side panel gets its summary and graph (§15.6): both players with their accuracy, a table counting each class per side, a clickable eval graph, and "?" tooltips that explain the numbers.

#### Acceptance criteria

1. The summary shows both players and each side's accuracy (REV-004), "–" for a side with no moves.
2. A table counts each side's moves per class, each move once under its final class.
3. An eval graph of the PV1 score across the game; clicking it jumps the board to that move; the current move is marked; it follows the board's orientation.
4. A "?" beside the accuracy and one beside the table show tooltips that explain in plain English how accuracy is computed and each class's threshold, with the numbers read from `core/tunables.gd`.
5. While the analysis runs, the graph and counts fill in as positions land; the summary shows once the whole game is done.

#### Verification

    Manual: review an analysed game; click the graph; hover both "?".
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_review.gd`: from fixture JSON, the accuracies and per-class counts match `core/accuracy.gd` and `core/classification.gd`; a graph click at a ply moves the board there; the tooltip text contains the current thresholds (red: no summary).

## Comments

- 2026-10-30 Written from spec §15.6.
